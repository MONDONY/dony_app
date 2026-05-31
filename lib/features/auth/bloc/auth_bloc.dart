import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

typedef AppleSignInCallback = Future<AuthorizationCredentialAppleID> Function(
  List<AppleIDAuthorizationScopes> scopes,
);

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LocalAuthService _localAuthService;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppleSignInCallback _appleSignIn;

  String? _pendingPhoneNumber;
  Timer? _otpTimer;

  AuthBloc(
    this._authRepository,
    this._localAuthService, {
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppleSignInCallback? appleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _appleSignIn = appleSignIn ??
            ((scopes) => SignInWithApple.getAppleIDCredential(scopes: scopes)),
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthPhoneVerified>(_onPhoneVerified);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSwitchAccountRequested>(_onSwitchAccountRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<OnboardingCompleted>(_onOnboardingCompleted);
    on<AuthDialCodeChanged>(_onDialCodeChanged);
    on<AuthOtpTimerTicked>(_onOtpTimerTicked);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthAppleSignInRequested>(_onAppleSignInRequested);
    on<AuthEmailOtpSendRequested>(_onEmailOtpSendRequested);
    on<AuthEmailOtpVerifyRequested>(_onEmailOtpVerifyRequested);
    on<AuthRegisterWithEmailRequested>(_onRegisterWithEmailRequested);
    on<AuthAddPhoneFromProfileRequested>(_onAddPhoneFromProfileRequested);
    on<AuthAddEmailFromProfileRequested>(_onAddEmailFromProfileRequested);
    on<AuthUserSynced>(_onUserSynced);
  }

  @override
  Future<void> close() {
    _otpTimer?.cancel();
    return super.close();
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
        emit(AuthError(unwrapDioError(e)));
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

    // En debug, désactive la vérification d'app (APNs/reCAPTCHA) pour permettre
    // l'usage des numéros de test Firebase sans clé APNs configurée sur le device.
    if (kDebugMode) {
      try {
        await _firebaseAuth.setSettings(
          appVerificationDisabledForTesting: true,
        );
      } catch (_) {}
    }

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
          emit(AuthOtpSent(
            verificationId: verificationId,
            phoneNumber: event.phoneNumber,
            secondsLeft: 60,
          ));
          _otpTimer?.cancel();
          _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!isClosed) add(const AuthOtpTimerTicked());
          });
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
  //   • 200 → AuthAuthenticated → OTP screen navigue vers /auth/local (PIN existant)
  //   • 404 → AuthOtpVerified  → OTP screen dispatche AuthRegisterRequested() (nouveau compte)
  //           → AuthRegisterRequested crée le compte avec les deux rôles
  //           → AuthAuthenticated est émis → navigation vers /auth/local

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
          emit(AuthError(unwrapDioError(e)));
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
      );
      // Nouveau compte → effacer tout PIN résiduel d'un compte précédent
      // (le PIN est lié à l'appareil, pas à l'utilisateur Firebase)
      await _localAuthService.clearPin();
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
  //   • numéro inconnu  → AuthOtpVerified   → OTP screen dispatche AuthRegisterRequested() (nouveau compte)

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // ⚠️ NE PAS clearPin() — le PIN doit survivre au logout
    await _firebaseAuth.signOut();
    _pendingPhoneNumber = null;
    emit(const AuthInitial());
  }

  // ─── Changement de compte (depuis l'écran PIN) ────────────────────────────
  //
  // L'utilisateur veut se connecter à un AUTRE compte. On efface le PIN (lié à
  // l'appareil/au compte précédent) en plus de déconnecter Firebase, pour que
  // le compte suivant reparte sur une configuration PIN propre.

  Future<void> _onSwitchAccountRequested(
    AuthSwitchAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _localAuthService.clearPin();
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

  // ─── Mise à jour du profil ────────────────────────────────────────────────

  Future<void> _onUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final updatedUser = await _authRepository.updateProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        email: event.email,
        birthDate: event.birthDate,
        city: event.city,
        phoneNumber: event.phoneNumber,
      );
      emit(AuthProfileUpdated(updatedUser));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Onboarding flag ─────────────────────────────────────────────────────

  Future<void> _onOnboardingCompleted(
    OnboardingCompleted event,
    Emitter<AuthState> emit,
  ) async {
    await Hive.box('user_prefs').put('onboarding_done', true);
  }

  // ─── Code pays téléphone ─────────────────────────────────────────────────

  void _onDialCodeChanged(AuthDialCodeChanged event, Emitter<AuthState> emit) {
    emit(AuthInitial(dialCode: event.code, dialFlag: event.flag));
  }

  // ─── Timer OTP ───────────────────────────────────────────────────────────

  void _onOtpTimerTicked(AuthOtpTimerTicked event, Emitter<AuthState> emit) {
    final current = state;
    if (current is AuthOtpSent && current.secondsLeft > 0) {
      emit(current.copyWith(secondsLeft: current.secondsLeft - 1));
    } else if (current is AuthEmailOtpSent && current.secondsLeft > 0) {
      emit(current.copyWith(secondsLeft: current.secondsLeft - 1));
    }
  }

  // ─── Email OTP — envoi ────────────────────────────────────────────────────────

  Future<void> _onEmailOtpSendRequested(
    AuthEmailOtpSendRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.sendEmailOtp(event.email);
      emit(AuthEmailOtpSent(event.email, secondsLeft: 60));
      _otpTimer?.cancel();
      _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed) add(const AuthOtpTimerTicked());
      });
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Email OTP — vérification ─────────────────────────────────────────────────

  Future<void> _onEmailOtpVerifyRequested(
    AuthEmailOtpVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final customToken = await _authRepository.verifyEmailOtp(event.email, event.code);
      await _firebaseAuth.signInWithCustomToken(customToken);
      // User existant → Home directement ; nouveau → RoleSelection
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        emit(AuthEmailOtpVerified(event.email));
      } else {
        emit(AuthError(unwrapDioError(e)));
      }
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Inscription par email (post-OAuth ou post-email OTP) ────────────────────

  Future<void> _onRegisterWithEmailRequested(
    AuthRegisterWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.registerWithEmail(
        email: event.email,
      );
      await _localAuthService.clearPin();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        emit(const AuthInitial());
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
      _pendingPhoneNumber = _firebaseAuth.currentUser?.email ?? '';
      await _checkProfileAfterOAuth(emit);
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Apple Sign-In ────────────────────────────────────────────────────────

  Future<void> _onAppleSignInRequested(
    AuthAppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final appleCredential = await _appleSignIn([
        AppleIDAuthorizationScopes.email,
      ]);
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await _firebaseAuth.signInWithCredential(oauthCredential);
      _pendingPhoneNumber = _firebaseAuth.currentUser?.email ?? '';
      await _checkProfileAfterOAuth(emit);
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Ajout téléphone depuis profil (sans remplacer la session Firebase) ──────

  Future<void> _onAddPhoneFromProfileRequested(
    AuthAddPhoneFromProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      // Link to existing Firebase account instead of replacing the session.
      // Ignore errors when phone already belongs to another Firebase account:
      // user proved ownership by correctly entering the OTP, so we still
      // update the backend profile.
      try {
        await _firebaseAuth.currentUser?.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked' &&
            e.code != 'credential-already-in-use') {
          rethrow;
        }
      }
      // Update backend profile with the verified phone number
      final updatedUser = await _authRepository.updateProfile(
        phoneNumber: event.phoneNumber,
      );
      emit(AuthProfileUpdated(updatedUser));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_friendlyFirebaseError(e)));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Ajout email depuis profil (sans remplacer la session Firebase) ───────────

  Future<void> _onAddEmailFromProfileRequested(
    AuthAddEmailFromProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Validate OTP ownership on the backend — we intentionally discard the
      // returned custom token to avoid replacing the current Firebase session.
      await _authRepository.verifyEmailOtp(event.email, event.code);
      // Update backend profile; freeEmailFromDeletedAccounts runs server-side
      // if the email was previously held by a soft-deleted account.
      final updatedUser = await _authRepository.updateProfile(email: event.email);
      emit(AuthProfileUpdated(updatedUser));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  void _onUserSynced(AuthUserSynced event, Emitter<AuthState> emit) {
    emit(AuthProfileUpdated(event.user));
  }

  Future<void> _checkProfileAfterOAuth(Emitter<AuthState> emit) async {
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final email = _firebaseAuth.currentUser?.email ?? '';
        emit(AuthOAuthNewUser(email));
      } else {
        emit(AuthError(unwrapDioError(e)));
      }
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  AppException _friendlyFirebaseError(FirebaseAuthException e) {
    final (message, code) = switch (e.code) {
      'invalid-phone-number' => ('Numéro de téléphone invalide', 'invalid-phone-number'),
      'invalid-verification-code' => ('Code de vérification incorrect', 'code-incorrect'),
      'code-expired' => ('Le code a expiré. Demandez un nouveau code.', 'code-expired'),
      'too-many-requests' => ('Trop de tentatives. Réessayez plus tard.', 'too-many-attempts'),
      'session-expired' => ('Session expirée. Recommencez.', 'session-expired'),
      _ => (e.message ?? 'Erreur d\'authentification', 'firebase-auth-error'),
    };
    return NetworkException(message, code: code);
  }

  AppException _friendlyError(Object e) {
    if (e is AppException) return e;
    if (e is DioException) return unwrapDioError(e);
    if (e.toString().contains('Ce numéro est déjà associé')) {
      return const NetworkException(
        'Ce numéro est déjà associé à un compte',
        code: 'phone-already-registered',
      );
    }
    return const NetworkException(
      'Une erreur est survenue. Réessayez.',
      code: 'auth-generic-error',
    );
  }
}
