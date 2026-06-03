# PostHog Tracking — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instrumenter 38 events PostHog (Tiers 1+2+3) dans les BLoCs et écrans de dony Flutter.

**Architecture:** Appels explicites dans les BLoC handlers pour les events avec propriétés métier. `AnalyticsService` passé en dernier paramètre constructeur de chaque BLoC concerné. `AnalyticsBlocObserver` pour les erreurs globales uniquement.

**Tech Stack:** posthog_flutter 5.25.2, flutter_bloc, GetIt, mocktail

---

### Task 1 : Helper de test partagé + AnalyticsEvents

**Files:**
- Create: `test/helpers/mock_analytics_backend.dart`
- Create: `lib/core/services/analytics_events.dart`
- Modify: `test/core/services/analytics_service_test.dart`

- [ ] **Écrire le helper de mock partagé**

```dart
// test/helpers/mock_analytics_backend.dart
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsBackend extends Mock implements AnalyticsBackend {}

class MockHiveService extends Mock implements HiveService {}

class MockBox extends Mock implements Box<dynamic> {}

/// Crée un AnalyticsService déjà configuré + consenti (isEnabled = true).
AnalyticsService makeEnabledAnalytics(MockAnalyticsBackend backend) {
  final hive = MockHiveService();
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(true);
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => backend.optIn()).thenAnswer((_) async {});
  when(() => backend.optOut()).thenAnswer((_) async {});
  when(() => backend.reset()).thenAnswer((_) async {});
  when(() => backend.capture(any(), any())).thenAnswer((_) async {});
  when(() => backend.screen(any(), any())).thenAnswer((_) async {});
  when(() => backend.identify(any(), any())).thenAnswer((_) async {});
  final service = AnalyticsService(hive, backend: backend);
  return service;
}

/// Crée un AnalyticsService configuré mais sans consentement (isEnabled = false).
AnalyticsService makeDisabledAnalytics(MockAnalyticsBackend backend) {
  final hive = MockHiveService();
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(false);
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => backend.optIn()).thenAnswer((_) async {});
  when(() => backend.optOut()).thenAnswer((_) async {});
  when(() => backend.reset()).thenAnswer((_) async {});
  when(() => backend.capture(any(), any())).thenAnswer((_) async {});
  when(() => backend.screen(any(), any())).thenAnswer((_) async {});
  when(() => backend.identify(any(), any())).thenAnswer((_) async {});
  final service = AnalyticsService(hive, backend: backend);
  return service;
}
```

- [ ] **Créer `lib/core/services/analytics_events.dart`**

```dart
// lib/core/services/analytics_events.dart
abstract final class AnalyticsEvents {
  // Auth
  static const signupStarted            = 'signup_started';
  static const otpSubmitted             = 'otp_submitted';
  static const signupCompleted          = 'signup_completed';
  static const analyticsConsentAnswered = 'analytics_consent_answered';
  static const loginSuccess             = 'login_success';
  static const loginFailed              = 'login_failed';

  // KYC
  static const kycStarted   = 'kyc_started';
  static const kycCompleted = 'kyc_completed';
  static const kycFailed    = 'kyc_failed';

  // Announcements
  static const announcementCreated = 'announcement_created';
  static const announcementViewed  = 'announcement_viewed';

  // Bids
  static const bidSubmitted = 'bid_submitted';
  static const bidAccepted  = 'bid_accepted';
  static const bidRejected  = 'bid_rejected';

  // Payments
  static const paymentInitiated    = 'payment_initiated';
  static const paymentSucceeded    = 'payment_succeeded';
  static const paymentFailed       = 'payment_failed';
  static const mobileMoneyAwaiting = 'mobile_money_awaiting';

  // Tracking / QR
  static const qrScanSuccess     = 'qr_scan_success';
  static const deliveryConfirmed = 'delivery_confirmed';

  // Package Request
  static const packageRequestCreated    = 'package_request_created';
  static const packageRequestSearched   = 'package_request_searched';
  static const negotiationOfferMade     = 'negotiation_offer_made';
  static const negotiationOfferAccepted = 'negotiation_offer_accepted';

  // Messaging
  static const conversationOpened = 'conversation_opened';
  static const messageSent        = 'message_sent';

  // Wallet
  static const walletTopupStarted   = 'wallet_topup_started';
  static const walletTopupCompleted = 'wallet_topup_completed';

  // Ratings
  static const ratingSubmitted = 'rating_submitted';

  // Cancellations
  static const cancellationInitiated = 'cancellation_initiated';
  static const rematchAccepted       = 'rematch_accepted';

  // Profile
  static const becomeTravelerStarted = 'become_traveler_started';
  static const upgradeToProStarted   = 'upgrade_to_pro_started';

  // Referral
  static const referralShared = 'referral_shared';

  // Settings
  static const analyticsConsentChanged  = 'analytics_consent_changed';
  static const accountDeletionRequested = 'account_deletion_requested';

  // Errors (BlocObserver)
  static const blocError = 'bloc_error';
}
```

- [ ] **Mettre à jour `analytics_service_test.dart`** pour importer le helper partagé — remplacer les classes `_MockBackend`, `_MockHive`, `_MockBox` en haut du fichier par :

```dart
import '../../helpers/mock_analytics_backend.dart';
```

Et remplacer `_MockBackend` par `MockAnalyticsBackend`, `_MockHive` par `MockHiveService`, `_MockBox` par `MockBox` dans tout le fichier.

- [ ] **Écrire le test de smoke pour AnalyticsEvents**

```dart
// test/core/services/analytics_events_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all event names are non-empty snake_case strings', () {
    final events = [
      AnalyticsEvents.signupStarted,
      AnalyticsEvents.otpSubmitted,
      AnalyticsEvents.signupCompleted,
      AnalyticsEvents.analyticsConsentAnswered,
      AnalyticsEvents.loginSuccess,
      AnalyticsEvents.loginFailed,
      AnalyticsEvents.kycStarted,
      AnalyticsEvents.kycCompleted,
      AnalyticsEvents.kycFailed,
      AnalyticsEvents.announcementCreated,
      AnalyticsEvents.announcementViewed,
      AnalyticsEvents.bidSubmitted,
      AnalyticsEvents.bidAccepted,
      AnalyticsEvents.bidRejected,
      AnalyticsEvents.paymentInitiated,
      AnalyticsEvents.paymentSucceeded,
      AnalyticsEvents.paymentFailed,
      AnalyticsEvents.mobileMoneyAwaiting,
      AnalyticsEvents.qrScanSuccess,
      AnalyticsEvents.deliveryConfirmed,
      AnalyticsEvents.packageRequestCreated,
      AnalyticsEvents.packageRequestSearched,
      AnalyticsEvents.negotiationOfferMade,
      AnalyticsEvents.negotiationOfferAccepted,
      AnalyticsEvents.conversationOpened,
      AnalyticsEvents.messageSent,
      AnalyticsEvents.walletTopupStarted,
      AnalyticsEvents.walletTopupCompleted,
      AnalyticsEvents.ratingSubmitted,
      AnalyticsEvents.cancellationInitiated,
      AnalyticsEvents.rematchAccepted,
      AnalyticsEvents.becomeTravelerStarted,
      AnalyticsEvents.upgradeToProStarted,
      AnalyticsEvents.referralShared,
      AnalyticsEvents.analyticsConsentChanged,
      AnalyticsEvents.accountDeletionRequested,
      AnalyticsEvents.blocError,
    ];
    for (final e in events) {
      expect(e, isNotEmpty);
      expect(e, matches(RegExp(r'^[a-z][a-z_]+$')));
    }
    expect(events.toSet().length, events.length, reason: 'Duplicate event name');
  });
}
```

- [ ] **Lancer les tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app-analytics
flutter test test/core/services/analytics_events_test.dart test/core/services/analytics_service_test.dart -v
```

Résultat attendu : tous verts.

- [ ] **Commit**

```bash
git add lib/core/services/analytics_events.dart test/helpers/mock_analytics_backend.dart test/core/services/analytics_events_test.dart test/core/services/analytics_service_test.dart
git commit -m "feat(analytics): add AnalyticsEvents constants and shared test helper"
```

---

### Task 2 : AnalyticsBlocObserver + wire up dans main.dart

**Files:**
- Create: `lib/core/services/analytics_bloc_observer.dart`
- Create: `test/core/services/analytics_bloc_observer_test.dart`
- Modify: `lib/main.dart`

- [ ] **Écrire le test**

```dart
// test/core/services/analytics_bloc_observer_test.dart
import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_bloc_observer.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../helpers/mock_analytics_backend.dart';

class _FakeBloc extends Fake implements BlocBase<Object?> {
  @override
  Type get runtimeType => _FakeBloc;
}

void main() {
  late MockAnalyticsBackend backend;

  setUp(() {
    backend = MockAnalyticsBackend();
  });

  test('onError captures bloc_error event with bloc_name and error_type', () async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    clearInteractions(backend);

    final observer = AnalyticsBlocObserver(analytics);
    final fakeBloc = _FakeBloc();
    final error = Exception('test error');

    observer.onError(fakeBloc, error, StackTrace.empty);

    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.blocError,
      {
        'bloc_name': '_FakeBloc',
        'error_type': '_Exception',
      },
    )).called(1);
  });

  test('onError is no-op when analytics disabled', () async {
    final analytics = makeDisabledAnalytics(backend);
    await analytics.onConfigured();
    clearInteractions(backend);

    final observer = AnalyticsBlocObserver(analytics);
    observer.onError(_FakeBloc(), Exception('x'), StackTrace.empty);

    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Lancer le test pour vérifier qu'il échoue**

```bash
flutter test test/core/services/analytics_bloc_observer_test.dart -v
```

Résultat attendu : FAIL — `AnalyticsBlocObserver` n'existe pas.

- [ ] **Créer `lib/core/services/analytics_bloc_observer.dart`**

```dart
// lib/core/services/analytics_bloc_observer.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

class AnalyticsBlocObserver extends BlocObserver {
  const AnalyticsBlocObserver(this._analytics);

  final AnalyticsService _analytics;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    unawaited(_analytics.logEvent(
      AnalyticsEvents.blocError,
      properties: {
        'bloc_name': bloc.runtimeType.toString(),
        'error_type': error.runtimeType.toString(),
      },
    ));
  }
}
```

- [ ] **Modifier `lib/main.dart`** — ajouter après `await getIt<AnalyticsService>().onConfigured()` :

```dart
// Après la ligne : await getIt<AnalyticsService>().onConfigured();
Bloc.observer = AnalyticsBlocObserver(getIt<AnalyticsService>());
```

Ajouter l'import en haut :

```dart
import 'package:dony/core/services/analytics_bloc_observer.dart';
```

- [ ] **Lancer les tests**

```bash
flutter test test/core/services/analytics_bloc_observer_test.dart -v
```

Résultat attendu : tous verts.

- [ ] **Commit**

```bash
git add lib/core/services/analytics_bloc_observer.dart lib/main.dart test/core/services/analytics_bloc_observer_test.dart
git commit -m "feat(analytics): add AnalyticsBlocObserver for global error tracking"
```

---

### Task 3 : AuthBloc — login_success + login_failed

**Files:**
- Modify: `lib/features/auth/bloc/auth_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/auth/bloc/auth_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/auth/bloc/auth_bloc_analytics_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}
class _MockLocalAuth extends Mock implements LocalAuthService {}
class _MockFirebaseAuth extends Mock implements FirebaseAuth {}
class _MockUser extends Mock implements User {}

void main() {
  late _MockAuthRepo repo;
  late _MockLocalAuth localAuth;
  late _MockFirebaseAuth firebaseAuth;
  late MockAnalyticsBackend backend;

  final fakeUser = UserModel(
    id: 'u1', phoneNumber: '+33600000000', firstName: 'Test',
    lastName: 'User', roles: ['SENDER'], createdAt: DateTime(2024),
  );

  setUp(() {
    repo = _MockAuthRepo();
    localAuth = _MockLocalAuth();
    firebaseAuth = _MockFirebaseAuth();
    backend = MockAnalyticsBackend();

    final mockUser = _MockUser();
    when(() => firebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.phoneNumber).thenReturn('+33600000000');
  });

  AuthBloc makeBloc({bool analyticsEnabled = true}) {
    final analytics = analyticsEnabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return AuthBloc(
      repo,
      localAuth,
      analytics: analytics,
      firebaseAuth: firebaseAuth,
    );
  }

  group('login_success', () {
    test('fires on AuthCheckRequested when profile exists', () async {
      when(() => repo.getProfile()).thenAnswer((_) async => fakeUser);
      final bloc = makeBloc();
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      await Future<void>.delayed(Duration.zero);
      verify(() => backend.capture(
        AnalyticsEvents.loginSuccess,
        {'method': 'check'},
      )).called(1);
    });
  });

  group('login_failed', () {
    test('fires on AuthCheckRequested when server error', () async {
      when(() => repo.getProfile()).thenThrow(
        const NetworkException('Server error', code: 'server-error'),
      );
      final bloc = makeBloc();
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      await Future<void>.delayed(Duration.zero);
      verify(() => backend.capture(
        AnalyticsEvents.loginFailed,
        any(),
      )).called(1);
    });
  });

  group('consent off', () {
    test('no event fires when analytics disabled', () async {
      when(() => repo.getProfile()).thenAnswer((_) async => fakeUser);
      final bloc = makeBloc(analyticsEnabled: false);
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => backend.capture(any(), any()));
    });
  });
}
```

- [ ] **Lancer le test pour vérifier qu'il échoue**

```bash
flutter test test/features/auth/bloc/auth_bloc_analytics_test.dart -v
```

- [ ] **Modifier `lib/features/auth/bloc/auth_bloc.dart`**

Ajouter les imports :

```dart
import 'dart:async';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
```

Ajouter le champ et le paramètre :

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LocalAuthService _localAuthService;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppleSignInCallback _appleSignIn;
  final AnalyticsService? _analytics;  // ← ajouter

  AuthBloc(
    this._authRepository,
    this._localAuthService, {
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppleSignInCallback? appleSignIn,
    AnalyticsService? analytics,       // ← ajouter
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _appleSignIn = appleSignIn ?? ...,
        _analytics = analytics,        // ← ajouter
        super(const AuthInitial()) {
```

Dans `_onCheckRequested`, après `emit(AuthAuthenticated(user))` :

```dart
unawaited(_analytics?.logEvent(AnalyticsEvents.loginSuccess, properties: {'method': 'check'}));
```

Après `emit(AuthError(unwrapDioError(e)))` dans `_onCheckRequested` :

```dart
unawaited(_analytics?.logEvent(AnalyticsEvents.loginFailed, properties: {'error_type': e.response?.statusCode?.toString() ?? 'network'}));
```

Dans `_onPhoneVerified`, après `emit(AuthAuthenticated(user))` (compte existant) :

```dart
unawaited(_analytics?.logEvent(AnalyticsEvents.loginSuccess, properties: {'method': 'phone'}));
```

Dans `_checkProfileAfterOAuth`, après `emit(AuthAuthenticated(user))` :

```dart
unawaited(_analytics?.logEvent(AnalyticsEvents.loginSuccess, properties: {'method': 'social'}));
```

Dans `_onEmailOtpVerifyRequested`, après `emit(AuthAuthenticated(user))` :

```dart
unawaited(_analytics?.logEvent(AnalyticsEvents.loginSuccess, properties: {'method': 'email'}));
```

- [ ] **Modifier `lib/core/di/injection.dart`** — ajouter `analytics` au `AuthBloc` :

```dart
getIt.registerFactory<AuthBloc>(
  () => AuthBloc(
    getIt<AuthRepository>(),
    getIt<LocalAuthService>(),
    analytics: getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/auth/bloc/auth_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/auth/bloc/auth_bloc.dart lib/core/di/injection.dart test/features/auth/bloc/auth_bloc_analytics_test.dart
git commit -m "feat(analytics): track login_success and login_failed in AuthBloc"
```

---

### Task 4 : Écrans auth — signup_started, otp_submitted, signup_completed, analytics_consent_answered

**Files:**
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- Modify: `lib/features/auth/presentation/screens/pin_setup_screen.dart`
- Modify: `lib/features/auth/presentation/screens/analytics_consent_screen.dart`

> Ces events sont des actions utilisateur directes, sans BLoC intermédiaire. Pas de tests unitaires BLoC à écrire — le comportement est déjà couvert par les widget tests existants.

- [ ] **`phone_auth_screen.dart`** — dans le handler qui soumet le numéro de téléphone (juste avant `context.read<AuthBloc>().add(...)`), ajouter :

```dart
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

// Dans le handler onSubmit :
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.signupStarted,
  properties: {'method': 'phone'},
));
```

- [ ] **`otp_verification_screen.dart`** — dans le handler qui soumet le code OTP, ajouter :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.otpSubmitted,
  properties: {'attempt_count': _attemptCount},
));
```

Si la variable de comptage de tentatives n'existe pas, l'ajouter comme `int _attemptCount = 0` dans le state, incrémentée à chaque soumission.

- [ ] **`pin_setup_screen.dart`** — dans `_handleComplete`, juste après `await getIt<LocalAuthService>().savePin(_pin)` et avant la navigation :

```dart
unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.signupCompleted));
```

- [ ] **`analytics_consent_screen.dart`** — dans `_respond`, juste avant `context.go('/home')` :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.analyticsConsentAnswered,
  properties: {'granted': granted},
));
```

- [ ] **Vérifier la compilation**

```bash
flutter analyze lib/features/auth/
```

Résultat attendu : no issues.

- [ ] **Commit**

```bash
git add lib/features/auth/presentation/screens/
git commit -m "feat(analytics): track signup funnel events in auth screens"
```

---

### Task 5 : KycBloc — kyc_started, kyc_completed, kyc_failed

**Files:**
- Modify: `lib/features/kyc/bloc/kyc_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/kyc/bloc/kyc_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/kyc/bloc/kyc_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockKycRepo extends Mock implements KycRepository {}

void main() {
  late _MockKycRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockKycRepo();
    backend = MockAnalyticsBackend();
  });

  KycBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return KycBloc(repo, a);
  }

  test('kyc_started fires on KycSessionRequested success', () async {
    when(() => repo.createSession()).thenAnswer((_) async => {
      'stripeUrl': 'https://stripe.com', 'sessionId': 'sess_1',
    });
    final bloc = makeBloc();
    bloc.add(KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycSessionCreated);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycStarted, any())).called(1);
  });

  test('kyc_failed fires on KycSessionRequested error', () async {
    when(() => repo.createSession()).thenThrow(Exception('KYC error'));
    final bloc = makeBloc();
    bloc.add(KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycError);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycFailed, any())).called(1);
  });

  test('kyc_completed fires on KycStatusRefreshed when verified', () async {
    when(() => repo.getStatus()).thenAnswer((_) async => {
      'kycStatus': 'VERIFIED', 'verificationStatus': 'verified',
    });
    final bloc = makeBloc();
    bloc.add(KycStatusRefreshed());
    await bloc.stream.firstWhere((s) => s is KycStatusLoaded);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.kycCompleted, any())).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.createSession()).thenAnswer((_) async => {
      'stripeUrl': 'https://stripe.com', 'sessionId': 'sess_1',
    });
    final bloc = makeBloc(enabled: false);
    bloc.add(KycSessionRequested());
    await bloc.stream.firstWhere((s) => s is KycSessionCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Lancer le test pour vérifier qu'il échoue**

```bash
flutter test test/features/kyc/bloc/kyc_bloc_analytics_test.dart -v
```

- [ ] **Modifier `lib/features/kyc/bloc/kyc_bloc.dart`**

```dart
import 'dart:async';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

class KycBloc extends Bloc<KycEvent, KycState> {
  final KycRepository _repository;
  final AnalyticsService _analytics;  // ← ajouter

  KycBloc(this._repository, this._analytics) : super(const KycInitial()) {
    // handlers inchangés
  }

  Future<void> _onSessionRequested(KycSessionRequested event, Emitter<KycState> emit) async {
    emit(const KycLoading());
    try {
      final data = await _repository.createSession();
      emit(KycSessionCreated(stripeUrl: data['stripeUrl'] as String, sessionId: data['sessionId'] as String));
      unawaited(_analytics.logEvent(AnalyticsEvents.kycStarted));  // ← ajouter
    } catch (e) {
      emit(KycError(unwrapDioError(e)));
      unawaited(_analytics.logEvent(AnalyticsEvents.kycFailed, properties: {'reason': e.toString()}));  // ← ajouter
    }
  }

  Future<void> _onStatusRefreshed(KycStatusRefreshed event, Emitter<KycState> emit) async {
    try {
      final data = await _repository.getStatus();
      emit(KycStatusLoaded(kycStatus: data['kycStatus'] as String, verificationStatus: data['verificationStatus'] as String));
      if ((data['kycStatus'] as String) == 'VERIFIED') {
        unawaited(_analytics.logEvent(AnalyticsEvents.kycCompleted));  // ← ajouter
      }
    } catch (e) {
      emit(KycError(unwrapDioError(e)));
    }
  }
}
```

- [ ] **Modifier `lib/core/di/injection.dart`**

```dart
getIt.registerFactory<KycBloc>(
  () => KycBloc(getIt<KycRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/kyc/bloc/kyc_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/kyc/bloc/kyc_bloc.dart lib/core/di/injection.dart test/features/kyc/bloc/kyc_bloc_analytics_test.dart
git commit -m "feat(analytics): track kyc_started, kyc_completed, kyc_failed in KycBloc"
```

---

### Task 6 : AnnouncementBloc + écran — announcement_created, announcement_viewed

**Files:**
- Modify: `lib/features/matching/bloc/announcement_bloc.dart`
- Modify: `lib/features/matching/presentation/screens/announcement_detail_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/matching/bloc/announcement_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/matching/bloc/announcement_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}
class _MockHive extends Mock implements HiveService {}
class _MockBox extends Mock implements Box<dynamic> {}

void main() {
  late _MockAnnouncementRepo repo;
  late MockAnalyticsBackend backend;
  late _MockHive hive;

  final fakeAnnouncement = AnnouncementModel(
    id: 'ann1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    pricePerKg: 15.0,
    availableKg: 10.0,
    departureDate: DateTime(2024, 12, 1),
  );

  setUp(() {
    repo = _MockAnnouncementRepo();
    backend = MockAnalyticsBackend();
    hive = _MockHive();
    final box = _MockBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
  });

  AnnouncementBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return AnnouncementBloc(repo, hive, a);
  }

  test('announcement_created fires with corridor and price on success', () async {
    when(() => repo.createAnnouncement(
      departureCity: any(named: 'departureCity'),
      arrivalCity: any(named: 'arrivalCity'),
      departureDate: any(named: 'departureDate'),
      departureTime: any(named: 'departureTime'),
      arrivalTime: any(named: 'arrivalTime'),
      pickupAddress: any(named: 'pickupAddress'),
      deliveryAddress: any(named: 'deliveryAddress'),
      availableKg: any(named: 'availableKg'),
      pricePerKg: any(named: 'pricePerKg'),
      transportMode: any(named: 'transportMode'),
      description: any(named: 'description'),
      acceptedContentTypes: any(named: 'acceptedContentTypes'),
      refusedTypes: any(named: 'refusedTypes'),
      acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
      capacityUnit: any(named: 'capacityUnit'),
      pricingMode: any(named: 'pricingMode'),
    )).thenAnswer((_) async => fakeAnnouncement);

    final bloc = makeBloc();
    bloc.add(AnnouncementCreateRequested(
      departureCity: 'Paris', arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 12, 1),
      availableKg: 10.0, pricePerKg: 15.0,
    ));
    await bloc.stream.firstWhere((s) => s is AnnouncementCreated);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.announcementCreated,
      {'corridor': 'Paris→Dakar', 'available_kg': 10.0, 'price_per_kg': 15.0},
    )).called(1);
  });

  test('no event when analytics disabled', () async {
    when(() => repo.createAnnouncement(
      departureCity: any(named: 'departureCity'),
      arrivalCity: any(named: 'arrivalCity'),
      departureDate: any(named: 'departureDate'),
      departureTime: any(named: 'departureTime'),
      arrivalTime: any(named: 'arrivalTime'),
      pickupAddress: any(named: 'pickupAddress'),
      deliveryAddress: any(named: 'deliveryAddress'),
      availableKg: any(named: 'availableKg'),
      pricePerKg: any(named: 'pricePerKg'),
      transportMode: any(named: 'transportMode'),
      description: any(named: 'description'),
      acceptedContentTypes: any(named: 'acceptedContentTypes'),
      refusedTypes: any(named: 'refusedTypes'),
      acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
      capacityUnit: any(named: 'capacityUnit'),
      pricingMode: any(named: 'pricingMode'),
    )).thenAnswer((_) async => fakeAnnouncement);

    final bloc = makeBloc(enabled: false);
    bloc.add(AnnouncementCreateRequested(
      departureCity: 'Paris', arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 12, 1),
      availableKg: 10.0, pricePerKg: 15.0,
    ));
    await bloc.stream.firstWhere((s) => s is AnnouncementCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/matching/bloc/announcement_bloc.dart`**

Ajouter les imports :

```dart
import 'dart:async';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
```

Mettre à jour le constructeur :

```dart
class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;
  final HiveService _hive;
  final AnalyticsService _analytics;  // ← ajouter

  AnnouncementBloc(this._repository, this._hive, this._analytics) : super(AnnouncementInitial()) {
```

Dans `_onCreateRequested`, après `emit(AnnouncementCreated(announcement))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.announcementCreated,
  properties: {
    'corridor': '${event.departureCity}→${event.arrivalCity}',
    'available_kg': event.availableKg,
    'price_per_kg': event.pricePerKg,
  },
));
```

- [ ] **`announcement_detail_screen.dart`** — dans `initState` ou `didChangeDependencies`, ajouter :

```dart
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

// Dans initState :
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(
    AnalyticsEvents.announcementViewed,
    properties: {
      'announcement_id': widget.announcementId,
      'corridor': '${widget.departureCity}→${widget.arrivalCity}',
    },
  ));
});
```

Adapter les propriétés selon les champs disponibles dans le widget.

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<AnnouncementBloc>(
  () => AnnouncementBloc(
    getIt<AnnouncementRepository>(),
    getIt<HiveService>(),
    getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/matching/bloc/announcement_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/matching/bloc/announcement_bloc.dart lib/features/matching/presentation/screens/announcement_detail_screen.dart lib/core/di/injection.dart test/features/matching/bloc/announcement_bloc_analytics_test.dart
git commit -m "feat(analytics): track announcement_created and announcement_viewed"
```

---

### Task 7 : BidBloc — bid_submitted, bid_rejected

**Files:**
- Modify: `lib/features/matching/bloc/bid_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/matching/bloc/bid_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/matching/bloc/bid_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepo extends Mock implements BidRepository {}

void main() {
  late _MockBidRepo repo;
  late MockAnalyticsBackend backend;

  final fakeBid = BidModel(
    id: 'bid1',
    announcementId: 'ann1',
    weightKg: 5.0,
    pricePerKg: 12.0,
  );

  setUp(() {
    repo = _MockBidRepo();
    backend = MockAnalyticsBackend();
  });

  BidBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return BidBloc(repo, a);
  }

  test('bid_submitted fires with correct properties on BidCreateRequested', () async {
    when(() => repo.createBid(
      announcementId: any(named: 'announcementId'),
      weightKg: any(named: 'weightKg'),
      declaredValueEur: any(named: 'declaredValueEur'),
      description: any(named: 'description'),
      contentCategory: any(named: 'contentCategory'),
      recipientName: any(named: 'recipientName'),
      recipientPhone: any(named: 'recipientPhone'),
      gridItems: any(named: 'gridItems'),
    )).thenAnswer((_) async => fakeBid);

    final bloc = makeBloc();
    bloc.add(BidCreateRequested(
      announcementId: 'ann1',
      weightKg: 5.0,
      declaredValueEur: 100.0,
      description: 'test',
    ));
    await bloc.stream.firstWhere((s) => s is BidCreated);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.bidSubmitted,
      {'announcement_id': 'ann1', 'weight_kg': 5.0, 'price_per_kg': 12.0},
    )).called(1);
  });

  test('bid_rejected fires on BidRejectRequested', () async {
    when(() => repo.rejectBid(any())).thenAnswer((_) async => fakeBid);
    final bloc = makeBloc();
    bloc.add(BidRejectRequested(bidId: 'bid1'));
    await bloc.stream.firstWhere((s) => s is BidRejected);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.bidRejected, {'bid_id': 'bid1'})).called(1);
  });

  test('no events when disabled', () async {
    when(() => repo.createBid(
      announcementId: any(named: 'announcementId'),
      weightKg: any(named: 'weightKg'),
      declaredValueEur: any(named: 'declaredValueEur'),
      description: any(named: 'description'),
      contentCategory: any(named: 'contentCategory'),
      recipientName: any(named: 'recipientName'),
      recipientPhone: any(named: 'recipientPhone'),
      gridItems: any(named: 'gridItems'),
    )).thenAnswer((_) async => fakeBid);

    final bloc = makeBloc(enabled: false);
    bloc.add(BidCreateRequested(announcementId: 'ann1', weightKg: 5.0, declaredValueEur: 100.0, description: 'test'));
    await bloc.stream.firstWhere((s) => s is BidCreated);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/matching/bloc/bid_bloc.dart`**

```dart
import 'dart:async';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

class BidBloc extends Bloc<BidEvent, BidState> {
  final BidRepository _repository;
  final AnalyticsService _analytics;  // ← ajouter
  bool _checkoutInProgress = false;

  BidBloc(this._repository, this._analytics) : super(BidInitial()) {
    // handlers inchangés
  }
```

Dans `_onCreateRequested`, après `emit(BidCreated(bid))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.bidSubmitted,
  properties: {
    'announcement_id': bid.announcementId,
    'weight_kg': bid.weightKg ?? 0.0,
    'price_per_kg': bid.pricePerKg ?? 0.0,
  },
));
```

Dans `_onRejectRequested`, après `emit(BidRejected(bid))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.bidRejected,
  properties: {'bid_id': bid.id},
));
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<BidBloc>(
  () => BidBloc(getIt<BidRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/matching/bloc/bid_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/matching/bloc/bid_bloc.dart lib/core/di/injection.dart test/features/matching/bloc/bid_bloc_analytics_test.dart
git commit -m "feat(analytics): track bid_submitted and bid_rejected in BidBloc"
```

---

### Task 8 : BidAcceptanceBloc — bid_accepted

**Files:**
- Modify: `lib/features/matching/bloc/bid_acceptance_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/matching/bloc/bid_acceptance_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/matching/bloc/bid_acceptance_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockBidRepo extends Mock implements BidRepository {}
class _MockStripe extends Mock implements Stripe {}

void main() {
  late _MockBidRepo repo;
  late _MockStripe stripe;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockBidRepo();
    stripe = _MockStripe();
    backend = MockAnalyticsBackend();
  });

  BidAcceptanceBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return BidAcceptanceBloc(repo, stripe, a);
  }

  test('bid_accepted fires with bid_id on acceptance', () async {
    when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
      (_) async => AcceptanceResponse(status: AcceptanceStatus.accepted),
    );
    final bloc = makeBloc();
    bloc.add(BidAcceptRequested(bidId: 'bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.bidAccepted, {'bid_id': 'bid1'})).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
      (_) async => AcceptanceResponse(status: AcceptanceStatus.accepted),
    );
    final bloc = makeBloc(enabled: false);
    bloc.add(BidAcceptRequested(bidId: 'bid1'));
    await bloc.stream.firstWhere((s) => s is BidAccepted);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/matching/bloc/bid_acceptance_bloc.dart`**

```dart
import 'dart:async';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';

class BidAcceptanceBloc extends Bloc<BidAcceptanceEvent, BidAcceptanceState> {
  final BidRepository _repo;
  final Stripe _stripe;
  final AnalyticsService _analytics;  // ← ajouter

  BidAcceptanceBloc(this._repo, this._stripe, this._analytics) : super(BidAcceptanceInitial()) {
    on<BidAcceptRequested>(_accept);
    on<BidAcceptWithCardRequested>(_acceptWithCard);
  }
```

Dans `_handleResponse`, dans le case `AcceptanceStatus.accepted` :

```dart
case AcceptanceStatus.accepted:
  emit(BidAccepted());
  unawaited(_analytics.logEvent(AnalyticsEvents.bidAccepted, properties: {'bid_id': bidId}));  // ← ajouter
  return;
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<BidAcceptanceBloc>(
  () => BidAcceptanceBloc(
    getIt<BidRepository>(),
    Stripe.instance,
    getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/matching/bloc/bid_acceptance_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/matching/bloc/bid_acceptance_bloc.dart lib/core/di/injection.dart test/features/matching/bloc/bid_acceptance_bloc_analytics_test.dart
git commit -m "feat(analytics): track bid_accepted in BidAcceptanceBloc"
```

---

### Task 9 : PaymentBloc + écrans — payment_succeeded, payment_failed, payment_initiated, mobile_money_awaiting

**Files:**
- Modify: `lib/features/payments/bloc/payment_bloc.dart`
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Modify: `lib/features/matching/presentation/screens/mobile_money_awaiting_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/payments/bloc/payment_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/payments/bloc/payment_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockPaymentRepo extends Mock implements PaymentRepository {}

void main() {
  late _MockPaymentRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockPaymentRepo();
    backend = MockAnalyticsBackend();
  });

  PaymentBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return PaymentBloc(repo, a);
  }

  test('payment_succeeded fires on PaymentSheetCompleted', () async {
    // PaymentSheetReady est requis comme état courant
    final bloc = makeBloc();
    // Setup état PaymentSheetReady via BidCheckoutPaymentRequested
    bloc.emit(PaymentSheetReady(
      clientSecret: 'cs_test',
      amount: 45.0,
      commissionAmount: 5.0,
      paymentId: 'pay_1',
    ));
    bloc.add(PaymentSheetCompleted());
    await bloc.stream.firstWhere((s) => s is PaymentEscrowPending);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(
      AnalyticsEvents.paymentSucceeded,
      {'method': 'card', 'amount': 45.0, 'payment_id': 'pay_1'},
    )).called(1);
  });

  test('payment_failed fires on PaymentFailed event', () async {
    final bloc = makeBloc();
    bloc.add(PaymentFailed(message: 'Card declined'));
    await bloc.stream.firstWhere((s) => s is PaymentError);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(
      AnalyticsEvents.paymentFailed,
      any(),
    )).called(1);
  });

  test('no events when disabled', () async {
    final bloc = makeBloc(enabled: false);
    bloc.emit(PaymentSheetReady(
      clientSecret: 'cs_test', amount: 45.0, commissionAmount: 5.0, paymentId: 'pay_1',
    ));
    bloc.add(PaymentSheetCompleted());
    await bloc.stream.firstWhere((s) => s is PaymentEscrowPending);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/payments/bloc/payment_bloc.dart`**

Ajouter champ `AnalyticsService _analytics` et l'injecter.

Dans `_onPaymentSheetCompleted` :

```dart
Future<void> _onPaymentSheetCompleted(PaymentSheetCompleted event, Emitter<PaymentState> emit) async {
  final current = state;
  if (current is PaymentSheetReady) {
    emit(PaymentEscrowPending(current.amount));
    unawaited(_analytics.logEvent(
      AnalyticsEvents.paymentSucceeded,
      properties: {
        'method': 'card',
        'amount': current.amount,
        'payment_id': current.paymentId,
      },
    ));
  }
}
```

Dans `_onPaymentFailed` :

```dart
Future<void> _onPaymentFailed(PaymentFailed event, Emitter<PaymentState> emit) async {
  emit(PaymentError(NetworkException(event.message, code: 'payment-failed')));
  unawaited(_analytics.logEvent(
    AnalyticsEvents.paymentFailed,
    properties: {'method': 'card', 'error_code': 'payment-failed'},
  ));
}
```

- [ ] **`payment_screen.dart`** — dans le handler du bouton "Payer", avant de déclencher le paiement :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.paymentInitiated,
  properties: {'method': 'card', 'amount': widget.amount},
));
```

- [ ] **`mobile_money_awaiting_screen.dart`** — dans `initState` :

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(
    AnalyticsEvents.mobileMoneyAwaiting,
    properties: {'provider': widget.provider},
  ));
});
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<PaymentBloc>(
  () => PaymentBloc(getIt<PaymentRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/payments/bloc/payment_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/payments/bloc/payment_bloc.dart lib/features/payments/presentation/screens/payment_screen.dart lib/features/matching/presentation/screens/mobile_money_awaiting_screen.dart lib/core/di/injection.dart test/features/payments/bloc/payment_bloc_analytics_test.dart
git commit -m "feat(analytics): track payment events in PaymentBloc and screens"
```

---

### Task 10 : TrackingBloc + écran — qr_scan_success, delivery_confirmed

**Files:**
- Modify: `lib/features/tracking/bloc/tracking_bloc.dart`
- Modify: `lib/features/tracking/presentation/screens/reception_confirm_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/tracking/bloc/tracking_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/tracking/bloc/tracking_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockTrackingRepo extends Mock implements TrackingRepository {}
class _MockOfflineSync extends Mock implements OfflineSyncService {}

void main() {
  late _MockTrackingRepo repo;
  late _MockOfflineSync offlineSync;
  late MockAnalyticsBackend backend;

  final fakeEvent = TrackingEventModel(id: 'ev1', type: 'PICKUP', bidId: 'bid1');

  setUp(() {
    repo = _MockTrackingRepo();
    offlineSync = _MockOfflineSync();
    backend = MockAnalyticsBackend();
  });

  TrackingBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return TrackingBloc(repo, offlineSync, a);
  }

  test('qr_scan_success fires with scan_type on online scan', () async {
    when(() => offlineSync.queueScan(
      bidId: any(named: 'bidId'),
      eventType: any(named: 'eventType'),
      gpsLat: any(named: 'gpsLat'),
      gpsLon: any(named: 'gpsLon'),
      photoPath: any(named: 'photoPath'),
    )).thenAnswer((_) async {});
    when(() => repo.uploadTrackingPhoto(any(), any())).thenAnswer((_) async => 'photo_key');
    when(() => repo.postScan(
      bidId: any(named: 'bidId'),
      eventType: any(named: 'eventType'),
      gpsLat: any(named: 'gpsLat'),
      gpsLon: any(named: 'gpsLon'),
      photoUrl: any(named: 'photoUrl'),
    )).thenAnswer((_) async => fakeEvent);

    final bloc = makeBloc();
    bloc.add(QrScanSubmitRequested(bidId: 'bid1', eventType: 'PICKUP'));
    await bloc.stream.firstWhere((s) => s is QrScanSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.qrScanSuccess,
      {'scan_type': 'PICKUP', 'bid_id': 'bid1'},
    )).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.postScan(
      bidId: any(named: 'bidId'),
      eventType: any(named: 'eventType'),
      gpsLat: any(named: 'gpsLat'),
      gpsLon: any(named: 'gpsLon'),
      photoUrl: any(named: 'photoUrl'),
    )).thenAnswer((_) async => fakeEvent);

    final bloc = makeBloc(enabled: false);
    bloc.add(QrScanSubmitRequested(bidId: 'bid1', eventType: 'PICKUP'));
    await bloc.stream.firstWhere((s) => s is QrScanSuccess);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/tracking/bloc/tracking_bloc.dart`**

Ajouter `AnalyticsService _analytics` au constructeur.

Dans `_onScanSubmit`, après `emit(QrScanSuccess(result))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.qrScanSuccess,
  properties: {'scan_type': event.eventType, 'bid_id': event.bidId},
));
```

- [ ] **`reception_confirm_screen.dart`** — dans le handler de confirmation :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.deliveryConfirmed,
  properties: {'bid_id': widget.bidId},
));
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<TrackingBloc>(
  () => TrackingBloc(
    getIt<TrackingRepository>(),
    getIt<OfflineSyncService>(),
    getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/tracking/bloc/tracking_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/tracking/bloc/tracking_bloc.dart lib/features/tracking/presentation/screens/reception_confirm_screen.dart lib/core/di/injection.dart test/features/tracking/bloc/tracking_bloc_analytics_test.dart
git commit -m "feat(analytics): track qr_scan_success and delivery_confirmed"
```

---

### Task 11 : Package Request — package_request_created, negotiation events, package_request_searched

**Files:**
- Modify: `lib/features/package_request/bloc/package_request_form_bloc.dart`
- Modify: `lib/features/package_request/bloc/negotiation_bloc.dart`
- Modify: `lib/features/package_request/bloc/package_request_search_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/package_request/bloc/package_request_bloc_analytics_test.dart`
- Create: `test/features/package_request/bloc/negotiation_bloc_analytics_test.dart`

- [ ] **Écrire le test package request form**

```dart
// test/features/package_request/bloc/package_request_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
  });

  PackageRequestFormBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return PackageRequestFormBloc(repo, a);
  }

  test('package_request_created fires with corridor on step3 success', () async {
    when(() => repo.uploadPhoto(any())).thenAnswer((_) async => 'photo_url');
    when(() => repo.create(
      departureCity: any(named: 'departureCity'),
      arrivalCity: any(named: 'arrivalCity'),
      desiredDate: any(named: 'desiredDate'),
      dateToleranceDays: any(named: 'dateToleranceDays'),
      weightKg: any(named: 'weightKg'),
      parcelSize: any(named: 'parcelSize'),
      contentCategory: any(named: 'contentCategory'),
      description: any(named: 'description'),
      targetPriceEur: any(named: 'targetPriceEur'),
      photoUrl: any(named: 'photoUrl'),
      pickupNeighborhood: any(named: 'pickupNeighborhood'),
      deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
      transportMode: any(named: 'transportMode'),
    )).thenAnswer((_) async => null);

    final bloc = makeBloc();
    // Setup state with step 1 and 2 data first
    bloc.add(FormStep1Submitted(
      departureCity: 'Paris', arrivalCity: 'Dakar',
      desiredDate: DateTime(2024, 12, 1), dateToleranceDays: 3,
      transportMode: 'AIR',
    ));
    bloc.add(FormStep2Submitted(weightKg: 5.0, parcelSize: 'SMALL', contentCategory: 'CLOTHING', description: 'test'));
    bloc.add(FormStep3Submitted(targetPriceEur: 50.0));

    await bloc.stream.firstWhere((s) => s.submissionStatus == FormSubmissionStatus.success);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.packageRequestCreated,
      {'corridor': 'Paris→Dakar'},
    )).called(1);
  });
}
```

- [ ] **Modifier `lib/features/package_request/bloc/package_request_form_bloc.dart`**

Ajouter `AnalyticsService _analytics` au constructeur. Dans `_onStep3`, après l'emit de `submissionStatus: FormSubmissionStatus.success` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.packageRequestCreated,
  properties: {'corridor': '${state.departureCity}→${state.arrivalCity}'},
));
```

- [ ] **Modifier `lib/features/package_request/bloc/negotiation_bloc.dart`**

Dans le handler `_onStart` (NegotiationStartRequested), après `emit(NegotiationLoaded(thread))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.negotiationOfferMade,
  properties: {'amount': event.proposedPriceEur.round(), 'context': 'traveler'},
));
```

Dans le handler de `NegotiationCounterRequested`, après `emit(NegotiationLoaded(thread))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.negotiationOfferMade,
  properties: {'amount': event.proposedPriceEur.round(), 'context': 'counter'},
));
```

Dans le handler de `NegotiationAcceptRequested`, après `emit(NegotiationLoaded(thread))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.negotiationOfferAccepted,
  properties: {'amount': thread.currentPriceEur?.round() ?? 0},
));
```

- [ ] **Modifier `lib/features/package_request/bloc/package_request_search_bloc.dart`**

Dans `_onFiltersChanged`, après l'emit `SearchStatus.loaded` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.packageRequestSearched,
  properties: {
    if (e.departure != null) 'departure': e.departure!,
    if (e.arrival != null) 'arrival': e.arrival!,
  },
));
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<PackageRequestFormBloc>(
  () => PackageRequestFormBloc(getIt<PackageRequestRepository>(), getIt<AnalyticsService>()),
);
getIt.registerFactory<PackageRequestSearchBloc>(
  () => PackageRequestSearchBloc(getIt<PackageRequestRepository>(), getIt<AnalyticsService>()),
);
getIt.registerFactory<NegotiationBloc>(
  () => NegotiationBloc(getIt<NegotiationRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/package_request/bloc/ -v
```

- [ ] **Commit**

```bash
git add lib/features/package_request/bloc/ lib/core/di/injection.dart test/features/package_request/bloc/
git commit -m "feat(analytics): track package request and negotiation events"
```

---

### Task 12 : Messaging — conversation_opened, message_sent

**Files:**
- Modify: `lib/features/messaging/bloc/chat/chat_bloc.dart`
- Modify: `lib/features/messaging/presentation/screens/chat_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/messaging/bloc/chat_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/messaging/bloc/chat_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestore extends Mock implements FirestoreChatRepository {}
class _MockConvRepo extends Mock implements ConversationRepository {}

void main() {
  late _MockFirestore firestore;
  late _MockConvRepo convRepo;
  late MockAnalyticsBackend backend;

  setUp(() {
    firestore = _MockFirestore();
    convRepo = _MockConvRepo();
    backend = MockAnalyticsBackend();
  });

  ChatBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return ChatBloc(firestore, convRepo, a);
  }

  test('message_sent fires on ChatTextSendRequested', () async {
    when(() => firestore.sendMessage(
      conversationId: any(named: 'conversationId'),
      body: any(named: 'body'),
      preview: any(named: 'preview'),
      senderId: any(named: 'senderId'),
    )).thenAnswer((_) async {});
    when(() => convRepo.touchLastMessage(any(), any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(ChatTextSendRequested(
      conversationId: 'conv1',
      body: 'Bonjour',
      senderId: 'user1',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verify(() => backend.capture(AnalyticsEvents.messageSent, any())).called(1);
  });

  test('no event when disabled', () async {
    when(() => firestore.sendMessage(
      conversationId: any(named: 'conversationId'),
      body: any(named: 'body'),
      preview: any(named: 'preview'),
      senderId: any(named: 'senderId'),
    )).thenAnswer((_) async {});
    when(() => convRepo.touchLastMessage(any(), any())).thenAnswer((_) async {});

    final bloc = makeBloc(enabled: false);
    bloc.add(ChatTextSendRequested(conversationId: 'conv1', body: 'Bonjour', senderId: 'user1'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/messaging/bloc/chat/chat_bloc.dart`**

Ajouter `AnalyticsService _analytics` au constructeur. Dans `_onSendText`, après l'appel `_firestoreRepo.sendMessage(...)` :

```dart
unawaited(_analytics.logEvent(AnalyticsEvents.messageSent));
```

- [ ] **`chat_screen.dart`** — dans `initState` :

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(
    AnalyticsEvents.conversationOpened,
    properties: {'context': widget.context ?? 'unknown'},
  ));
});
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<ChatBloc>(
  () => ChatBloc(
    getIt<FirestoreChatRepository>(),
    getIt<ConversationRepository>(),
    getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/messaging/bloc/chat_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/messaging/bloc/chat/chat_bloc.dart lib/features/messaging/presentation/screens/chat_screen.dart lib/core/di/injection.dart test/features/messaging/bloc/chat_bloc_analytics_test.dart
git commit -m "feat(analytics): track conversation_opened and message_sent"
```

---

### Task 13 : WalletBloc — wallet_topup_started, wallet_topup_completed

**Files:**
- Modify: `lib/features/payments/wallet/bloc/wallet_bloc.dart`
- Modify: `lib/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/payments/bloc/wallet_bloc_analytics_test.dart`

- [ ] **Écrire le test**

```dart
// test/features/payments/bloc/wallet_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_event.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_state.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockWalletRepo extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockWalletRepo();
    backend = MockAnalyticsBackend();
  });

  WalletBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return WalletBloc(repo, a);
  }

  test('wallet_topup_completed fires on WalletTopupStripeReady', () async {
    when(() => repo.topupStripe(amount: any(named: 'amount')))
        .thenAnswer((_) async => 'cs_test_secret');

    final bloc = makeBloc();
    bloc.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE'));
    await bloc.stream.firstWhere((s) => s is WalletTopupStripeReady);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.walletTopupCompleted,
      {'amount': 50.0, 'method': 'STRIPE'},
    )).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.topupStripe(amount: any(named: 'amount')))
        .thenAnswer((_) async => 'cs_test_secret');
    final bloc = makeBloc(enabled: false);
    bloc.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE'));
    await bloc.stream.firstWhere((s) => s is WalletTopupStripeReady);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
```

- [ ] **Modifier `lib/features/payments/wallet/bloc/wallet_bloc.dart`**

Ajouter `AnalyticsService _analytics`. Dans `_onTopup`, après chaque `emit(WalletTopupStripeReady(...))` ou `emit(WalletTopupRedirectReady(...))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.walletTopupCompleted,
  properties: {'amount': event.amount, 'method': event.paymentMethod},
));
```

- [ ] **`wallet_topup_amount_screen.dart`** — dans `initState` :

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.walletTopupStarted));
});
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<WalletBloc>(
  () => WalletBloc(getIt<WalletRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/payments/bloc/wallet_bloc_analytics_test.dart -v
```

- [ ] **Commit**

```bash
git add lib/features/payments/wallet/bloc/wallet_bloc.dart lib/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart lib/core/di/injection.dart test/features/payments/bloc/wallet_bloc_analytics_test.dart
git commit -m "feat(analytics): track wallet_topup events"
```

---

### Task 14 : RatingBloc, CancellationBloc

**Files:**
- Modify: `lib/features/ratings/bloc/rating_bloc.dart`
- Modify: `lib/features/cancellation/bloc/cancellation_bloc.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/ratings/bloc/rating_bloc_analytics_test.dart`
- Create: `test/features/cancellation/bloc/cancellation_bloc_analytics_test.dart`

- [ ] **Écrire le test ratings**

```dart
// test/features/ratings/bloc/rating_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRatingRepo extends Mock implements RatingRepository {}

void main() {
  late _MockRatingRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockRatingRepo();
    backend = MockAnalyticsBackend();
  });

  RatingBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return RatingBloc(repo, a);
  }

  test('rating_submitted fires with score and role_rated=sender', () async {
    when(() => repo.submitRating(bidId: any(named: 'bidId'), stars: any(named: 'stars'), comment: any(named: 'comment')))
        .thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(const RatingSubmitRequested(bidId: 'bid1', stars: 5));
    await bloc.stream.firstWhere((s) => s is RatingSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.ratingSubmitted,
      {'score': 5, 'role_rated': 'traveler'},
    )).called(1);
  });

  test('rating_submitted fires with role_rated=sender for TravelerRatingSubmitRequested', () async {
    when(() => repo.submitTravelerRating(bidId: any(named: 'bidId'), stars: any(named: 'stars'), comment: any(named: 'comment')))
        .thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(const TravelerRatingSubmitRequested(bidId: 'bid1', stars: 4));
    await bloc.stream.firstWhere((s) => s is RatingSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.ratingSubmitted,
      {'score': 4, 'role_rated': 'sender'},
    )).called(1);
  });
}
```

- [ ] **Modifier `lib/features/ratings/bloc/rating_bloc.dart`**

Ajouter `AnalyticsService _analytics`. Dans `_onSubmit` après `emit(const RatingSuccess())` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.ratingSubmitted,
  properties: {'score': event.stars, 'role_rated': 'traveler'},
));
```

Dans `_onTravelerSubmit` après `emit(const RatingSuccess())` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.ratingSubmitted,
  properties: {'score': event.stars, 'role_rated': 'sender'},
));
```

- [ ] **Écrire le test cancellation**

```dart
// test/features/cancellation/bloc/cancellation_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/cancellation_repository.dart';
import 'package:dony/features/cancellation/data/cancellation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockCancellationRepo extends Mock implements CancellationRepository {}

void main() {
  late _MockCancellationRepo repo;
  late MockAnalyticsBackend backend;

  final fakeCancellation = CancellationModel(id: 'cancel1', reason: 'changed_mind');

  setUp(() {
    repo = _MockCancellationRepo();
    backend = MockAnalyticsBackend();
  });

  CancellationBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return CancellationBloc(repo, a);
  }

  test('cancellation_initiated fires with reason', () async {
    when(() => repo.cancelTrip(announcementId: any(named: 'announcementId'), reason: any(named: 'reason')))
        .thenAnswer((_) async => fakeCancellation);

    final bloc = makeBloc();
    bloc.add(CancellationTripRequested(announcementId: 'ann1', reason: 'changed_mind'));
    await bloc.stream.firstWhere((s) => s is CancellationSuccess);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.cancellationInitiated,
      {'reason': 'changed_mind'},
    )).called(1);
  });
}
```

- [ ] **Modifier `lib/features/cancellation/bloc/cancellation_bloc.dart`**

Ajouter `AnalyticsService _analytics`. Dans `_onTripCancellationRequested`, après `emit(CancellationSuccess(result))` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.cancellationInitiated,
  properties: {'reason': event.reason},
));
```

- [ ] **`injection.dart`**

```dart
getIt.registerFactory<RatingBloc>(
  () => RatingBloc(getIt<RatingRepository>(), getIt<AnalyticsService>()),
);
getIt.registerFactory<CancellationBloc>(
  () => CancellationBloc(getIt<CancellationRepository>(), getIt<AnalyticsService>()),
);
```

- [ ] **Lancer les tests**

```bash
flutter test test/features/ratings/ test/features/cancellation/ -v
```

- [ ] **Commit**

```bash
git add lib/features/ratings/bloc/rating_bloc.dart lib/features/cancellation/bloc/cancellation_bloc.dart lib/core/di/injection.dart test/features/ratings/ test/features/cancellation/
git commit -m "feat(analytics): track rating_submitted and cancellation_initiated"
```

---

### Task 15 : Profile, Referral, Settings — become_traveler_started, upgrade_to_pro_started, referral_shared, analytics_consent_changed, account_deletion_requested

**Files:**
- Modify: `lib/features/profile/presentation/screens/become_traveler_screen.dart`
- Modify: `lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart`
- Modify: `lib/features/referral/bloc/referral_bloc.dart`
- Modify: `lib/features/settings/bloc/account_deletion_bloc.dart`
- Modify: `lib/features/settings/presentation/screens/privacy_settings_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Create: `test/features/settings/bloc/account_deletion_bloc_analytics_test.dart`
- Create: `test/features/referral/bloc/referral_bloc_analytics_test.dart`

- [ ] **Écrire le test referral**

```dart
// test/features/referral/bloc/referral_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/features/referral/data/referral_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockReferralRepo extends Mock implements ReferralRepository {}

void main() {
  late _MockReferralRepo repo;
  late MockAnalyticsBackend backend;

  final fakeInfo = ReferralInfo(code: 'DONY123', shareUrl: 'https://dony.app/r/DONY123');

  setUp(() {
    repo = _MockReferralRepo();
    backend = MockAnalyticsBackend();
  });

  ReferralBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return ReferralBloc(repo, a);
  }

  test('referral_shared fires on ReferralShared when state is loaded', () async {
    when(() => repo.getMyReferral()).thenAnswer((_) async => fakeInfo);
    final bloc = makeBloc();
    // Load first
    bloc.add(ReferralLoadRequested());
    await bloc.stream.firstWhere((s) => s is ReferralLoaded);
    clearInteractions(backend);
    // Share
    bloc.add(ReferralShared());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verify(() => backend.capture(AnalyticsEvents.referralShared, any())).called(1);
  });
}
```

- [ ] **Écrire le test account deletion**

```dart
// test/features/settings/bloc/account_deletion_bloc_analytics_test.dart
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/data/firebase_phone_reauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockDeletionRepo extends Mock implements AccountDeletionRepository {}
class _MockReauth extends Mock implements FirebasePhoneReauth {}

void main() {
  late _MockDeletionRepo repo;
  late _MockReauth reauth;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockDeletionRepo();
    reauth = _MockReauth();
    backend = MockAnalyticsBackend();
  });

  AccountDeletionBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return AccountDeletionBloc(repo, reauth, a);
  }

  test('account_deletion_requested fires on RequestDeletion success', () async {
    when(() => repo.requestDeletion()).thenAnswer((_) async {});
    final bloc = makeBloc();
    bloc.add(RequestDeletion());
    await bloc.stream.firstWhere((s) => s is AccountDeletionRequested);
    await Future<void>.delayed(Duration.zero);
    verify(() => backend.capture(AnalyticsEvents.accountDeletionRequested, any())).called(1);
  });
}
```

- [ ] **Modifier `lib/features/referral/bloc/referral_bloc.dart`**

Ajouter `AnalyticsService _analytics`. Dans `_onShared`, après `Share.share(...)` :

```dart
unawaited(_analytics.logEvent(
  AnalyticsEvents.referralShared,
  properties: {'channel': 'share_sheet'},
));
```

- [ ] **Modifier `lib/features/settings/bloc/account_deletion_bloc.dart`**

Ajouter `AnalyticsService _analytics`. Dans `_onRequestDeletion`, après `emit(const AccountDeletionRequested())` :

```dart
unawaited(_analytics.logEvent(AnalyticsEvents.accountDeletionRequested));
```

- [ ] **`become_traveler_screen.dart` et `upgrade_to_pro_screen.dart`** — dans `initState` de chacun :

```dart
// become_traveler_screen.dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.becomeTravelerStarted));
});

// upgrade_to_pro_screen.dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.upgradeToProStarted));
});
```

- [ ] **`privacy_settings_screen.dart`** — dans le handler du toggle analytics :

```dart
unawaited(getIt<AnalyticsService>().logEvent(
  AnalyticsEvents.analyticsConsentChanged,
  properties: {'granted': newValue},
));
```

- [ ] **`injection.dart`**

```dart
getIt.registerLazySingleton<ReferralBloc>(
  () => ReferralBloc(getIt<ReferralRepository>(), getIt<AnalyticsService>()),
);
getIt.registerFactory<AccountDeletionBloc>(
  () => AccountDeletionBloc(
    getIt<AccountDeletionRepository>(),
    getIt<FirebasePhoneReauth>(),
    getIt<AnalyticsService>(),  // ← ajouter
  ),
);
```

- [ ] **Lancer tous les tests**

```bash
flutter test test/features/referral/ test/features/settings/ -v
```

- [ ] **Commit**

```bash
git add lib/features/referral/bloc/referral_bloc.dart lib/features/settings/bloc/account_deletion_bloc.dart lib/features/profile/presentation/screens/ lib/features/settings/presentation/screens/privacy_settings_screen.dart lib/core/di/injection.dart test/features/referral/ test/features/settings/
git commit -m "feat(analytics): track profile, referral, and settings events"
```

---

### Task 16 : Vérification finale — tests + couverture

**Files:** aucun fichier créé, vérification uniquement.

- [ ] **Lancer tous les tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app-analytics
flutter test --coverage
```

Résultat attendu : tous verts.

- [ ] **Générer le rapport de couverture**

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Résultat attendu : couverture globale ≥ 90 %.

- [ ] **Vérifier la compilation release**

```bash
flutter analyze lib/
```

Résultat attendu : no issues.

- [ ] **Commit final**

```bash
git add -A
git commit -m "feat(analytics): complete PostHog tracking Tiers 1+2+3 (38 events)"
```
