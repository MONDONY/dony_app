import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LocalAuthService _localAuthService;
  final FirebaseAuth _firebaseAuth;

  String? _pendingPhoneNumber;

  AuthBloc(
    this._authRepository,
    this._localAuthService, {
    FirebaseAuth? firebaseAuth,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthPhoneVerified>(_onPhoneVerified);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
  }

  // ─── Vérification au démarrage (splash) ────────────────────────────────────

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      emit(const AuthInitial());
      return;
    }
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Firebase OK mais pas encore inscrit en backend
        _pendingPhoneNumber = firebaseUser.phoneNumber;
        emit(const AuthInitial());
      } else {
        // Erreur réseau/serveur → ne pas forcer la re-inscription
        emit(AuthError('Impossible de récupérer votre profil. Vérifiez votre connexion.'));
      }
    } catch (_) {
      _pendingPhoneNumber = firebaseUser.phoneNumber;
      emit(const AuthInitial());
    }
  }

  // ─── Envoi OTP ───────────────────────────────────────────────────────────

  Future<void> _onSendOtpRequested(
    AuthSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    _pendingPhoneNumber = event.phoneNumber;

    final completer = Completer<void>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: event.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-vérification Android
        try {
          await _firebaseAuth.signInWithCredential(credential);
          if (!isClosed) add(AuthPhoneVerified(verificationId: '', smsCode: '', autoVerified: true));
        } catch (e) {
          if (!isClosed && !emit.isDone) emit(AuthError(_friendlyError(e)));
        }
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!emit.isDone) emit(AuthError(_friendlyFirebaseError(e)));
        if (!completer.isCompleted) completer.complete();
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!emit.isDone) {
          emit(AuthOtpSent(verificationId: verificationId, phoneNumber: event.phoneNumber));
        }
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  // ─── Vérification OTP + détection compte existant ────────────────────────
  //
  // Après OTP validé, on tente getProfile() pour savoir si l'user est déjà inscrit :
  //   • 200 → AuthAuthenticated → OTP screen va à /auth/local (PIN existant)
  //   • 404 → AuthOtpVerified  → OTP screen va à /auth/role  (nouveau compte)

  Future<void> _onPhoneVerified(
    AuthPhoneVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // 1. Connexion Firebase (sauf si auto-vérifié, déjà fait)
      if (!event.autoVerified) {
        final credential = PhoneAuthProvider.credential(
          verificationId: event.verificationId,
          smsCode: event.smsCode,
        );
        await _firebaseAuth.signInWithCredential(credential);
      }

      // 2. Vérifier si l'utilisateur est déjà inscrit en backend
      try {
        final user = await _authRepository.getProfile();
        // Compte existant → déjà authentifié, écran PIN suffira
        emit(AuthAuthenticated(user));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          // Nouveau numéro → flux de création de compte
          emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
        } else {
          emit(AuthError('Erreur serveur. Réessayez.'));
        }
      } catch (_) {
        // En cas d'erreur inattendue → traiter comme nouveau compte
        emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_friendlyFirebaseError(e)));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Inscription (nouveau compte) ─────────────────────────────────────────

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.register(
        phoneNumber: _pendingPhoneNumber ?? '',
        roles: event.roles,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Déconnexion → retour à /auth/phone ──────────────────────────────────
  //
  // On déconnecte Firebase seulement. Le PIN est CONSERVÉ.
  // Après re-authentification OTP :
  //   • numéro existant → AuthAuthenticated → /auth/local (PIN screen, même PIN)
  //   • numéro inconnu  → AuthOtpVerified    → /auth/role  (nouveau compte)

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // ⚠️ NE PAS clearPin() — le PIN doit survivre au logout
    await _firebaseAuth.signOut();
    _pendingPhoneNumber = null;
    emit(const AuthInitial());
  }

  // ─── Suppression de compte ────────────────────────────────────────────────

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.deleteAccount();
      await _localAuthService.clearPin();
      await _firebaseAuth.signOut();
      _pendingPhoneNumber = null;
      emit(const AuthAccountDeleted());
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _friendlyFirebaseError(FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' => 'Numéro de téléphone invalide',
        'invalid-verification-code' => 'Code de vérification incorrect',
        'code-expired' => 'Le code a expiré. Demandez un nouveau code.',
        'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
        'session-expired' => 'Session expirée. Recommencez.',
        _ => e.message ?? 'Erreur d\'authentification',
      };

  String _friendlyError(Object e) =>
      e.toString().contains('Ce numéro est déjà associé')
          ? 'Ce numéro est déjà associé à un compte'
          : 'Une erreur est survenue. Réessayez.';
}
