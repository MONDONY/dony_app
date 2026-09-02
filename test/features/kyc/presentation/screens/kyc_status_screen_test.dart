import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeKycEvent extends Fake implements KycEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

/// Il reste les paiements à faire : `routeAfter(identity)` doit pointer
/// vers `/payments/onboarding`, jamais vers `/home`.
const _progressPayoutsLeft = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
  },
  current: OnboardingStep.identity,
);

/// Pays hors couverture Stripe : l'identité est la dernière étape comptée,
/// `routeAfter(identity)` doit pointer vers `/home`.
const _progressNoPayouts = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
  ],
  done: {
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
  },
  current: OnboardingStep.identity,
);

Future<void> _wrap(
  WidgetTester tester, {
  required KycBloc kycBloc,
  required AuthBloc authBloc,
  OnboardingProgress? progress,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<KycBloc>.value(value: kycBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: KycStatusScreen(progress: progress),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home route')),
      ),
      GoRoute(
        path: '/payments/onboarding',
        builder: (_, _) => const Scaffold(body: Text('Payouts route')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockKycBloc kycBloc;
  late _MockAuthBloc authBloc;
  late _MockAuthRepository authRepository;

  setUpAll(() {
    registerFallbackValue(_FakeKycEvent());
    registerFallbackValue(_FakeAuthEvent());
  });

  setUp(() {
    kycBloc = _MockKycBloc();
    authBloc = _MockAuthBloc();
    authRepository = _MockAuthRepository();
    when(() => authRepository.markOnboardingSeen()).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
    getIt.registerSingleton<AuthRepository>(authRepository);
  });

  tearDown(() {
    if (getIt.isRegistered<AuthRepository>()) {
      getIt.unregister<AuthRepository>();
    }
  });

  // Régression : quand l'utilisateur quitte la page Stripe avant de valider,
  // la session reste PENDING indéfiniment — Stripe n'a rien reçu, donc rien
  // n'avancera jamais. L'écran n'offrait aucun retour vers le formulaire, ni
  // tout de suite ni après le délai d'attente : le compte restait enfermé sur
  // « Vérification en cours ».
  testWidgets('PENDING offre de rouvrir le formulaire de vérification', (
    tester,
  ) async {
    when(() => kycBloc.state).thenReturn(
      const KycStatusLoaded(
        kycStatus: 'PENDING',
        verificationStatus: 'PENDING',
      ),
    );
    when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

    await _wrap(tester, kycBloc: kycBloc, authBloc: authBloc);

    expect(find.text('Vérification en cours'), findsOneWidget);
    expect(find.text('Reprendre la vérification'), findsOneWidget);

    await tester.tap(find.text('Reprendre la vérification'));
    await tester.pump();

    verify(() => kycBloc.add(const KycSessionRequested())).called(1);
  });

  testWidgets('depuis le profil (progress null) : ni jauge, ni « Passer pour '
      'l\'instant » — une jauge d\'inscription n\'aurait aucun sens ici', (
    tester,
  ) async {
    when(() => kycBloc.state).thenReturn(
      const KycStatusLoaded(
        kycStatus: 'NOT_STARTED',
        verificationStatus: 'unverified',
      ),
    );
    when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

    await _wrap(tester, kycBloc: kycBloc, authBloc: authBloc);

    expect(find.text('Passer pour l\'instant'), findsNothing);
    expect(find.text('Commencer la vérification'), findsOneWidget);
  });

  testWidgets(
    'depuis l\'onboarding : NOT_STARTED affiche la jauge et « Passer pour '
    'l\'instant »',
    (tester) async {
      when(() => kycBloc.state).thenReturn(
        const KycStatusLoaded(
          kycStatus: 'NOT_STARTED',
          verificationStatus: 'unverified',
        ),
      );
      when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(
        tester,
        kycBloc: kycBloc,
        authBloc: authBloc,
        progress: _progressPayoutsLeft,
      );

      expect(find.text('Passer pour l\'instant'), findsOneWidget);
    },
  );

  testWidgets('« Passer pour l\'instant » va vers /home même s\'il reste les '
      'paiements : Stripe Connect exige une identité vérifiée', (tester) async {
    when(() => kycBloc.state).thenReturn(
      const KycStatusLoaded(
        kycStatus: 'NOT_STARTED',
        verificationStatus: 'unverified',
      ),
    );
    when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

    await _wrap(
      tester,
      kycBloc: kycBloc,
      authBloc: authBloc,
      progress: _progressPayoutsLeft,
    );

    await tester.tap(find.text('Passer pour l\'instant'));
    await tester.pumpAndSettle();

    // Conduire aux paiements n'offrirait qu'un refus serveur (422
    // `kyc-required`). Le parcours s'arrête donc là, et `onboarding_seen_at`
    // est bien posé : l'utilisateur a atteint l'accueil.
    verify(() => authRepository.markOnboardingSeen()).called(1);
    expect(find.text('Home route'), findsOneWidget);
    expect(find.text('Payouts route'), findsNothing);
  });

  testWidgets(
    '« Passer pour l\'instant » sans paiements applicables va vers /home et '
    'marque l\'onboarding vu — l\'identité était la dernière étape',
    (tester) async {
      when(() => kycBloc.state).thenReturn(
        const KycStatusLoaded(
          kycStatus: 'NOT_STARTED',
          verificationStatus: 'unverified',
        ),
      );
      when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(
        tester,
        kycBloc: kycBloc,
        authBloc: authBloc,
        progress: _progressNoPayouts,
      );

      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      verify(() => authRepository.markOnboardingSeen()).called(1);
      expect(find.text('Home route'), findsOneWidget);
    },
  );

  testWidgets(
    'un rejet affiche aussi « Passer pour l\'instant » depuis l\'onboarding '
    '— un rejet ne doit jamais bloquer le parcours',
    (tester) async {
      when(() => kycBloc.state).thenReturn(
        const KycStatusLoaded(
          kycStatus: 'REJECTED',
          verificationStatus: 'rejected',
          rejectionCode: 'document_unreadable',
        ),
      );
      when(() => kycBloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(
        tester,
        kycBloc: kycBloc,
        authBloc: authBloc,
        progress: _progressPayoutsLeft,
      );

      expect(find.text('Passer pour l\'instant'), findsOneWidget);
      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      // Un rejet laisse l'identité non vérifiée : les paiements restent
      // verrouillés, le parcours se termine à l'accueil.
      expect(find.text('Home route'), findsOneWidget);
    },
  );

  testWidgets('VERIFIED depuis l\'onboarding avec paiements restants : '
      'auto-navigation vers /payments/onboarding, jamais /home', (
    tester,
  ) async {
    const verified = KycStatusLoaded(
      kycStatus: 'VERIFIED',
      verificationStatus: 'verified',
    );
    whenListen<KycState>(
      kycBloc,
      Stream.value(verified),
      initialState: verified,
    );

    await _wrap(
      tester,
      kycBloc: kycBloc,
      authBloc: authBloc,
      progress: _progressPayoutsLeft,
    );

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(const AuthCheckRequested())).called(1);
    verifyNever(() => authRepository.markOnboardingSeen());
    expect(find.text('Payouts route'), findsOneWidget);
  });

  testWidgets('VERIFIED depuis l\'onboarding sans paiements applicables : '
      'auto-navigation vers /home et marque l\'onboarding vu', (tester) async {
    const verified = KycStatusLoaded(
      kycStatus: 'VERIFIED',
      verificationStatus: 'verified',
    );
    whenListen<KycState>(
      kycBloc,
      Stream.value(verified),
      initialState: verified,
    );

    await _wrap(
      tester,
      kycBloc: kycBloc,
      authBloc: authBloc,
      progress: _progressNoPayouts,
    );

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    verify(() => authRepository.markOnboardingSeen()).called(1);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets(
    'VERIFIED depuis le profil (progress null) : va vers /home sans marquer '
    'l\'onboarding vu — comportement inchangé hors onboarding',
    (tester) async {
      const verified = KycStatusLoaded(
        kycStatus: 'VERIFIED',
        verificationStatus: 'verified',
      );
      whenListen<KycState>(
        kycBloc,
        Stream.value(verified),
        initialState: verified,
      );

      await _wrap(tester, kycBloc: kycBloc, authBloc: authBloc);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      verifyNever(() => authRepository.markOnboardingSeen());
      expect(find.text('Home route'), findsOneWidget);
    },
  );

  // Régression : nginx bride /kyc à 5 req/min. Quand le poll de statut tombe
  // sur un 429 (KycError RateLimitException), repartir tous les 30 s
  // re-déclenche le 429 en boucle. Le poll doit s'espacer (60 s après le
  // premier 429) et retomber à 30 s dès qu'un statut se charge.
  testWidgets('le poll s\'espace après un 429 puis retombe à 30 s', (
    tester,
  ) async {
    final states = StreamController<KycState>.broadcast();
    addTearDown(states.close);
    const pending = KycStatusLoaded(
      kycStatus: 'PENDING',
      verificationStatus: 'PENDING',
    );
    when(() => kycBloc.state).thenReturn(pending);
    when(() => kycBloc.stream).thenAnswer((_) => states.stream);

    await _wrap(tester, kycBloc: kycBloc, authBloc: authBloc);
    // Chargement initial au montage.
    verify(() => kycBloc.add(const KycStatusRefreshed())).called(1);

    // PENDING → le poll démarre à 30 s.
    states.add(pending);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    verify(() => kycBloc.add(const KycStatusRefreshed())).called(1);

    // 429 → l'intervalle double (60 s) : rien à 30 s, un tick à 60 s.
    states.add(const KycError(RateLimitException()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    verifyNever(() => kycBloc.add(const KycStatusRefreshed()));
    await tester.pump(const Duration(seconds: 30));
    verify(() => kycBloc.add(const KycStatusRefreshed())).called(1);

    // Statut chargé → retour au rythme nominal de 30 s.
    states.add(pending);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    verify(() => kycBloc.add(const KycStatusRefreshed())).called(1);

    // Terminer sur VERIFIED comme les autres tests : coupe le poll et le
    // timeout, l'auto-navigation démonte l'écran et ses animations.
    states.add(
      const KycStatusLoaded(
        kycStatus: 'VERIFIED',
        verificationStatus: 'VERIFIED',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
  });
}
