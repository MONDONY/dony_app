import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/apple_token_revoker.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Scopes demandés à Google lors de la connexion.
///
/// Doit rester non vide. Le plugin Android construit la chaîne du jeton
/// d'accès en concaténant `oauth2:` et les scopes : une liste vide donne
/// `oauth2:` tout court, que Google rejette (`MISSING_SCOPE`,
/// `BAD_REQUEST`). L'échec remonte depuis `authentication` et fait tomber
/// toute la connexion, alors même que Firebase ne consomme que l'`idToken`.
const googleSignInScopes = <String>['email'];

typedef AppleSignInCallback =
    Future<AuthorizationCredentialAppleID> Function(
      List<AppleIDAuthorizationScopes> scopes,
    );

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LocalAuthService _localAuthService;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppleSignInCallback _appleSignIn;
  final AnalyticsService? _analytics;
  final AppleTokenRevoker _appleTokenRevoker;

  String? _pendingPhoneNumber;
  Timer? _otpTimer;

  /// Jeton de la session visiteur en cours, capturé juste avant la bascule
  /// vers le compte réel.
  ///
  /// Le parcours téléphone passe par un custom token : l'UID du visiteur n'est
  /// jamais conservé, et les favoris posés en session anonyme appartiennent
  /// donc à un autre compte que celui créé à l'inscription. Ce jeton est le
  /// seul moyen de les réclamer ensuite.
  String? _pendingGuestIdToken;

  AuthBloc(
    this._authRepository,
    this._localAuthService, {
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppleSignInCallback? appleSignIn,
    AnalyticsService? analytics,
    AppleTokenRevoker? appleTokenRevoker,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: googleSignInScopes),
       _appleSignIn =
           appleSignIn ??
           ((scopes) => SignInWithApple.getAppleIDCredential(scopes: scopes)),
       _analytics = analytics,
       _appleTokenRevoker = appleTokenRevoker ?? AppleTokenRevoker(),
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
    on<AuthAvatarUploadRequested>(_onAvatarUploadRequested);
    on<AuthProfileRefreshRequested>(_onProfileRefreshRequested);
    on<AuthGuestSessionRequested>(_onGuestSessionRequested);
  }

  @override
  Future<void> close() {
    _otpTimer?.cancel();
    return super.close();
  }

  Future<void> _clearHiveAccountData() async {
    await Hive.box(HiveService.userPrefsBox).clear();
    await Hive.box<Map>(HiveService.offlineQueueBox).clear();
  }

  // ─── Vérification au démarrage (splash) ────────────────────────────────────

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final firebaseUser = _firebaseAuth.currentUser;
    // Une session anonyme n'a pas de compte serveur : `GET /auth/me` lui
    // répondrait 404. Le garde-fou d'`app.dart` évite déjà de dispatcher
    // l'événement dans ce cas, mais la garde doit tenir ici aussi — c'est le
    // seul endroit qui reste juste si un autre chemin d'appel apparaît.
    if (firebaseUser == null || firebaseUser.isAnonymous) {
      emit(const AuthInitial());
      return;
    }
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.loginSuccess,
          properties: {'method': 'check'},
        ),
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        // Firebase OK mais pas encore inscrit en backend
        _pendingPhoneNumber = firebaseUser.phoneNumber;
        emit(const AuthInitial());
      } else {
        // 401/403/5xx/timeout sur ce tout premier appel authentifié → écran
        // d'erreur avec réessai, SANS signOut(). Un 401/403 ici peut être
        // transitoire (backend en cold start, vérification du token Firebase
        // pas encore prête côté Admin SDK) et pas une vraie révocation —
        // déclencher un signOut() sur ce seul signal forçait l'utilisateur à
        // se reconnecter à chaque redémarrage pendant un cold start. Un
        // logout réel ne doit venir que d'une action utilisateur explicite
        // (AuthLogoutRequested) ou d'un signal serveur non ambigu.
        emit(AuthError(unwrapDioError(e)));
        unawaited(
          _analytics?.logEvent(
            AnalyticsEvents.loginFailed,
            properties: {'error_type': statusCode?.toString() ?? 'network'},
          ),
        );
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
    try {
      await _authRepository.sendPhoneOtp(event.phoneNumber);
      emit(AuthOtpSent(verificationId: '', phoneNumber: event.phoneNumber));
      _otpTimer?.cancel();
      _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed) add(const AuthOtpTimerTicked());
      });
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
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
      // 1. Vérification backend du code + échange contre un ID token Firebase
      final customToken = await _authRepository.verifyPhoneOtp(
        _pendingPhoneNumber ?? '',
        event.smsCode,
      );
      // Capture AVANT la bascule : après `signInWithCustomToken`, l'utilisateur
      // courant est le nouveau compte et la session anonyme est perdue à
      // jamais. C'est le seul instant où son jeton est encore lisible.
      await _captureGuestIdToken();
      await _firebaseAuth.signInWithCustomToken(customToken);

      // 2. Vérifier si l'utilisateur est déjà inscrit en backend
      try {
        final user = await _authRepository.getProfile();
        // Compte existant → déjà authentifié, écran PIN suffira.
        // La réclamation vaut aussi ici : c'est la sortie normale du mode
        // visiteur pour quelqu'un qui avait déjà un compte. Il a parcouru
        // sans se connecter, mis des trajets en favori, puis s'est connecté.
        await _claimGuestData();
        emit(AuthAuthenticated(user));
        unawaited(
          _analytics?.logEvent(
            AnalyticsEvents.loginSuccess,
            properties: {'method': 'phone'},
          ),
        );
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
    } on DioException catch (e) {
      emit(AuthError(unwrapDioError(e)));
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
      await _refreshIdTokenAfterRegistration();
      await _claimGuestData();
      // Nouveau compte → effacer tout PIN résiduel d'un compte précédent
      // (le PIN est lié à l'appareil, pas à l'utilisateur Firebase)
      await _localAuthService.clearPin();
      await _clearHiveAccountData();
      emit(AuthNewAccountAuthenticated(user));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Déconnexion → retour à /auth/method ─────────────────────────────────
  //
  // On déconnecte Firebase et on vide les données Hive du compte. Le PIN est
  // CONSERVÉ. AuthInitial
  // renvoie vers le choix des méthodes de connexion (téléphone/email/
  // Google/Apple), pas vers une méthode figée. Si l'utilisateur repasse
  // par le téléphone :
  //   • numéro existant → AuthAuthenticated → /auth/local (PIN screen, même PIN)
  //   • numéro inconnu  → AuthOtpVerified   → OTP screen dispatche AuthRegisterRequested() (nouveau compte)

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // ⚠️ NE PAS clearPin() — le PIN doit survivre au logout
    await _firebaseAuth.signOut();
    await _clearHiveAccountData();
    _pendingPhoneNumber = null;
    // Le jeton invité appartenait à la session qu'on vient de quitter : le
    // garder l'exposerait à une réclamation par le compte suivant.
    _pendingGuestIdToken = null;
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
    await _clearHiveAccountData();
    _pendingPhoneNumber = null;
    _pendingGuestIdToken = null;
    emit(const AuthInitial());
  }

  // ─── Suppression de compte ────────────────────────────────────────────────

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Apple impose de révoquer le jeton Sign in with Apple au moment de la
      // suppression. L'appel est sans effet pour un compte non Apple et
      // n'échoue jamais, donc il ne peut pas bloquer la suppression
      // (cf. AppleTokenRevoker.revokeIfAppleUser).
      await _appleTokenRevoker.revokeIfAppleUser();
      await _authRepository.deleteAccount();
      await _localAuthService.clearPin();
      await _clearHiveAccountData();
      await _firebaseAuth.signOut();
      _pendingPhoneNumber = null;
      _pendingGuestIdToken = null;
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
        city: event.city,
        phoneNumber: event.phoneNumber,
        bio: event.bio,
        languages: event.languages,
      );
      emit(AuthProfileUpdated(updatedUser));
      if (event.bio != null && event.bio!.trim().isNotEmpty) {
        unawaited(_analytics?.logEvent(AnalyticsEvents.profileAboutUpdated));
      }
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // ─── Upload avatar ────────────────────────────────────────────────────────

  Future<void> _onAvatarUploadRequested(
    AuthAvatarUploadRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final updated = await _authRepository.uploadAvatar(event.filePath);
      emit(AuthProfileUpdated(updated));
      unawaited(_analytics?.logEvent(AnalyticsEvents.profilePhotoUpdated));
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
      emit(AuthEmailOtpSent(event.email));
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
      final customToken = await _authRepository.verifyEmailOtp(
        event.email,
        event.code,
      );
      // Même contrainte que sur le parcours téléphone : le jeton du visiteur
      // ne survit pas à la bascule de session.
      await _captureGuestIdToken();
      await _firebaseAuth.signInWithCustomToken(customToken);
      // User existant → Home directement ; nouveau → RoleSelection
      final user = await _authRepository.getProfile();
      // Compte existant : le visiteur récupère aussi ses favoris ici.
      await _claimGuestData();
      emit(AuthAuthenticated(user));
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.loginSuccess,
          properties: {'method': 'email'},
        ),
      );
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
      final user = await _authRepository.registerWithEmail(email: event.email);
      await _refreshIdTokenAfterRegistration();
      await _claimGuestData();
      await _localAuthService.clearPin();
      await _clearHiveAccountData();
      emit(AuthNewAccountAuthenticated(user));
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
      // Un visiteur peut s'inscrire par Google : capturer son jeton avant que
      // la session anonyme ne cède la place au compte réel.
      await _captureGuestIdToken();
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
      // Un visiteur peut s'inscrire par Apple : même capture préalable.
      await _captureGuestIdToken();
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
      // Un seul appel : le backend consomme l'OTP et écrit le numéro dans la même
      // opération. Séparer vérification et écriture laissait la seconde invocable
      // seule — on ne prouvait plus la possession du téléphone au moment d'écrire.
      final updatedUser = await _authRepository.attachPhone(
        phoneNumber: event.phoneNumber,
        code: event.code,
      );
      emit(AuthProfileUpdated(updatedUser));
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
      // Un seul appel : le backend consomme l'OTP et écrit l'adresse dans la même
      // opération. Séparer vérification et écriture laissait la seconde invocable
      // seule — on ne prouvait plus la possession de la boîte au moment d'écrire.
      final updatedUser = await _authRepository.attachEmail(
        email: event.email,
        code: event.code,
      );
      emit(AuthProfileUpdated(updatedUser));
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  void _onUserSynced(AuthUserSynced event, Emitter<AuthState> emit) {
    emit(AuthProfileUpdated(event.user));
  }

  Future<void> _onProfileRefreshRequested(
    AuthProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _authRepository.getProfile();
      emit(AuthProfileUpdated(user));
    } catch (_) {
      // Refresh silencieux — ne pas afficher d'erreur si le rechargement échoue
    }
  }

  Future<void> _checkProfileAfterOAuth(Emitter<AuthState> emit) async {
    try {
      final user = await _authRepository.getProfile();
      // Compte existant (Google/Apple) : même sortie du mode visiteur.
      await _claimGuestData();
      emit(AuthAuthenticated(user));
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.loginSuccess,
          properties: {'method': 'social'},
        ),
      );
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

  // ─── Session invitée (navigation sans compte) ─────────────────────────────
  //
  // Déclenché uniquement par le CTA "Parcourir sans compte" (jamais au
  // démarrage de l'app). En cas d'échec (hors ligne, Firebase indisponible),
  // on N'AVANCE JAMAIS de façon optimiste vers l'accueil : l'utilisateur
  // resterait sur un écran vide sans comprendre la panne. Il reste sur
  // l'écran de connexion avec un message clair ; seul le succès déclenche la
  // navigation, via le BlocListener de l'écran.

  Future<void> _onGuestSessionRequested(
    AuthGuestSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _firebaseAuth.signInAnonymously();
      emit(const AuthGuestSessionReady());
      unawaited(_analytics?.logEvent(AnalyticsEvents.guestSessionStarted));
    } catch (e) {
      emit(
        const AuthError(
          NetworkException(
            'Impossible de démarrer la navigation sans compte. '
            'Vérifiez votre connexion.',
            code: 'guest-session-failed',
          ),
        ),
      );
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.guestSessionFailed,
          properties: {
            'reason': e is FirebaseAuthException ? e.code : 'unknown',
          },
        ),
      );
    }
  }

  // ─── Reprise des données du visiteur ──────────────────────────────────────
  //
  // Le mode visiteur ne vaut que si ce qu'un visiteur met de côté survit à son
  // arrivée sur un compte — qu'il s'inscrive ou qu'il se connecte à un compte
  // existant. Comme l'UID n'est pas conservé (custom token), la seule voie est
  // de présenter le jeton anonyme à `POST /auth/guest/claim`. L'ordre est
  // impératif : capture avant la bascule de session, réclamation une fois la
  // ligne de l'appelant présente en base.

  /// Lit le jeton de la session visiteur en cours, s'il y en a une.
  ///
  /// À appeler juste AVANT toute bascule d'authentification : ensuite,
  /// `currentUser` est le nouveau compte et le jeton du visiteur est perdu.
  /// Toute erreur de lecture est absorbée : on renonce aux favoris, jamais à
  /// la connexion.
  Future<void> _captureGuestIdToken() async {
    _pendingGuestIdToken = null;
    try {
      final previous = _firebaseAuth.currentUser;
      if (previous != null && previous.isAnonymous) {
        _pendingGuestIdToken = await previous.getIdToken();
      }
    } catch (_) {
      _pendingGuestIdToken = null;
    }
  }

  /// Rattache au compte de l'appelant les données posées en visiteur.
  ///
  /// Appelée sur les deux sorties du mode visiteur :
  /// - inscription, APRÈS `POST /auth/register` — tant que la ligne de
  ///   l'appelant n'existe pas, l'endpoint répond 404 ;
  /// - connexion à un compte existant, où cette ligne est déjà là.
  ///
  /// Un échec ne doit JAMAIS faire échouer l'inscription ni la connexion.
  /// Perdre ses favoris est regrettable ; être bloqué à la porte de son compte
  /// serait bien pire. On mesure l'échec, on le journalise, et on continue.
  Future<void> _claimGuestData() async {
    final guestToken = _pendingGuestIdToken;
    _pendingGuestIdToken = null;
    if (guestToken == null) return;
    try {
      await _authRepository.claimGuestData(guestToken);
      unawaited(_analytics?.logEvent(AnalyticsEvents.guestDataClaimed));
    } catch (e) {
      final reason = unwrapDioError(e).code ?? 'unknown';
      // L'analytics ne suffit pas : l'envoi d'événements s'arrête net si le
      // consentement est refusé, et l'échec deviendrait invisible pour ces
      // utilisateurs. `AppLog` reste no-op sans DSN Sentry et ne lève jamais.
      // Ni jeton ni identifiant : seul le code métier est journalisé.
      AppLog.warn(
        'Réclamation des données invité impossible',
        data: {'reason': reason},
      );
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.guestDataClaimFailed,
          properties: {'reason': reason},
        ),
      );
    }
  }

  /// Force l'émission d'un jeton à jour après une inscription réussie.
  ///
  /// **Défense en profondeur, pas une condition de fonctionnement.** Dans
  /// l'état actuel de l'application, le jeton ne peut pas être resté anonyme
  /// à ce stade : `POST /auth/register` refuse un jeton anonyme en 422, et
  /// l'intercepteur sert l'inscription et la réclamation avec le même jeton —
  /// une inscription qui réussit prouve donc que le jeton ne l'est plus. Les
  /// autorisations viennent par ailleurs de la base, pas de claims à
  /// rafraîchir.
  ///
  /// L'appel est conservé parce qu'il ne coûte rien et qu'il redevient un
  /// vrai prérequis le jour où l'app adopterait `linkWithCredential`, qui
  /// conserve l'UID et donc un jeton en cache encore marqué anonyme.
  Future<void> _refreshIdTokenAfterRegistration() async {
    try {
      await _firebaseAuth.currentUser?.getIdToken(true);
    } catch (_) {
      // Hors ligne ou Firebase indisponible : les endpoints critiques
      // forceront de nouveau le rafraîchissement au prochain appel.
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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
