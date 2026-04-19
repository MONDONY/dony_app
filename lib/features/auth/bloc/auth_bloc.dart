import 'dart:async';

import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final FirebaseAuth _firebaseAuth;

  String? _pendingPhoneNumber;

  AuthBloc(this._authRepository, {FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthPhoneVerified>(_onPhoneVerified);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

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
    } catch (_) {
      // Not registered yet — keep phone number from Firebase for registration
      _pendingPhoneNumber = firebaseUser.phoneNumber;
      emit(const AuthInitial());
    }
  }

  Future<void> _onSendOtpRequested(
    AuthSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    _pendingPhoneNumber = event.phoneNumber;

    // verifyPhoneNumber() retourne immédiatement — les callbacks arrivent plus tard.
    // Le Completer maintient ce handler en vie jusqu'au premier callback significatif.
    final completer = Completer<void>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: event.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-vérification Android — pas d'écran OTP
        try {
          await _firebaseAuth.signInWithCredential(credential);
          if (!isClosed) {
            add(const AuthRegisterRequested([]));
          }
        } catch (e) {
          if (!isClosed && !emit.isDone) {
            emit(AuthError(_friendlyError(e)));
          }
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!emit.isDone) {
          emit(AuthError(_friendlyFirebaseError(e)));
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!emit.isDone) {
          emit(AuthOtpSent(
            verificationId: verificationId,
            phoneNumber: event.phoneNumber,
          ));
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future;
  }

  Future<void> _onPhoneVerified(
    AuthPhoneVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      await _firebaseAuth.signInWithCredential(credential);
      emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_friendlyFirebaseError(e)));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

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

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _firebaseAuth.signOut();
    _pendingPhoneNumber = null;
    emit(const AuthInitial());
  }

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
