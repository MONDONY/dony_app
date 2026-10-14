import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/referral_code_screen.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeReferralEvent extends Fake implements ReferralEvent {}

const _progress = OnboardingProgress(
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
    OnboardingStep.identity,
    OnboardingStep.payouts,
  },
);

/// Il reste l'identité à faire : le parrainage ne doit plus filer droit sur
/// `/home` dans ce cas — c'était exactement le bug de bout en bout que ce
/// lot corrige.
const _progressWithIdentityLeft = OnboardingProgress(
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
);

Future<void> _wrap(
  WidgetTester tester,
  ReferralBloc bloc, {
  OnboardingProgress progress = _progress,
  PendingReferralCodeStore? store,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<ReferralBloc>.value(
          value: bloc,
          child: ReferralCodeScreen(
            progress: progress,
            pendingCodeStore: store,
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home route')),
      ),
      GoRoute(
        path: '/first-steps',
        builder: (_, _) => const Scaffold(body: Text('First steps route')),
      ),
      GoRoute(
        path: '/kyc/verify',
        builder: (_, _) => const Scaffold(body: Text('KYC route')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockReferralBloc bloc;
  late _MockAuthRepository authRepository;

  setUpAll(() {
    registerFallbackValue(_FakeReferralEvent());
  });

  setUp(() {
    bloc = _MockReferralBloc();
    authRepository = _MockAuthRepository();
    when(() => authRepository.markOnboardingSeen()).thenAnswer((_) async {});

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

  testWidgets(
    '« Passer pour l\'instant » marque l\'onboarding vu puis va vers l\'accueil '
    '— écran terminal réel du parcours sans code parrain',
    (tester) async {
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc);

      // « Passer pour l'instant » vit dans le SingleChildScrollView du
      // formulaire : hors de la fenêtre de test par défaut (800x600) tant
      // qu'on ne l'y a pas fait défiler.
      await tester.ensureVisible(find.text('Passer pour l\'instant'));
      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      verify(() => authRepository.markOnboardingSeen()).called(1);
      expect(find.text('First steps route'), findsOneWidget);
    },
  );

  testWidgets(
    'code parrain appliqué : « Continuer vers l\'accueil » marque l\'onboarding '
    'vu puis va vers l\'accueil',
    (tester) async {
      when(() => bloc.state).thenReturn(const ReferralRedeemed());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      verify(() => authRepository.markOnboardingSeen()).called(1);
      expect(find.text('First steps route'), findsOneWidget);
    },
  );

  testWidgets(
    'un échec réseau de markOnboardingSeen ne bloque jamais la sortie vers '
    'l\'accueil — même philosophie que ResidenceAddressCubit.skip()',
    (tester) async {
      when(
        () => authRepository.markOnboardingSeen(),
      ).thenAnswer((_) async => throw Exception('hors ligne'));
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc);

      await tester.ensureVisible(find.text('Passer pour l\'instant'));
      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('First steps route'), findsOneWidget);
    },
  );

  testWidgets(
    'il reste l\'identité à faire : « Passer pour l\'instant » va vers '
    '/kyc/verify, pas vers /home, et ne marque pas l\'onboarding vu — le '
    'trou de bout en bout corrigé par ce lot',
    (tester) async {
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc, progress: _progressWithIdentityLeft);

      await tester.ensureVisible(find.text('Passer pour l\'instant'));
      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      verifyNever(() => authRepository.markOnboardingSeen());
      expect(find.text('KYC route'), findsOneWidget);
      expect(find.text('Home route'), findsNothing);
    },
  );

  testWidgets(
    'il reste l\'identité à faire : code parrain appliqué puis « Continuer '
    'vers l\'accueil » va aussi vers /kyc/verify, pas vers /home',
    (tester) async {
      when(() => bloc.state).thenReturn(const ReferralRedeemed());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc, progress: _progressWithIdentityLeft);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      verifyNever(() => authRepository.markOnboardingSeen());
      expect(find.text('KYC route'), findsOneWidget);
    },
  );

  testWidgets('en anglais, le formulaire est traduit', (tester) async {
    useEnglish();
    when(() => bloc.state).thenReturn(const ReferralInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await _wrap(tester, bloc);

    expect(find.text('Apply code'), findsOneWidget);
  });

  group('code venu d\'un lien d\'invitation', () {
    late PendingReferralCodeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = PendingReferralCodeStore();
      await store.save('ABOU1890');
    });

    testWidgets('champ pré-rempli, coche et mention, aucun envoi automatique', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc, store: store);

      expect(find.widgetWithText(TextField, 'ABOU1890'), findsOneWidget);
      expect(
        find.textContaining('Votre code parrain est déjà rempli'),
        findsOneWidget,
      );
      expect(
        find.text("Code reconnu, venu de votre lien d'invitation"),
        findsOneWidget,
      );
      verifyNever(() => bloc.add(any(that: isA<ReferralRedeemRequested>())));

      await tester.ensureVisible(find.text('Appliquer le code'));
      await tester.tap(find.text('Appliquer le code'));
      await tester.pump();

      final event =
          verify(
                () =>
                    bloc.add(captureAny(that: isA<ReferralRedeemRequested>())),
              ).captured.single
              as ReferralRedeemRequested;
      expect(event.code, 'ABOU1890');
    });

    testWidgets('code modifié : la mention du lien disparaît', (tester) async {
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc, store: store);
      await tester.enterText(find.byType(TextField), 'AUTRE123');
      await tester.pump();

      expect(
        find.text("Code reconnu, venu de votre lien d'invitation"),
        findsNothing,
      );
    });

    testWidgets('passer l\'étape efface le code gardé', (tester) async {
      when(() => bloc.state).thenReturn(const ReferralInitial());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc, store: store);
      await tester.ensureVisible(find.text('Passer pour l\'instant'));
      await tester.tap(find.text('Passer pour l\'instant'));
      await tester.pumpAndSettle();

      expect(store.current, isNull);
    });
  });
}
