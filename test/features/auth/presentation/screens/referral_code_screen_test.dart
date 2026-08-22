import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/referral_code_screen.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockReferralBloc extends MockBloc<ReferralEvent, ReferralState>
    implements ReferralBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeReferralEvent extends Fake implements ReferralEvent {}

const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.identity,
    OnboardingStep.address,
    OnboardingStep.payouts,
  ],
  done: {
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.identity,
    OnboardingStep.address,
    OnboardingStep.payouts,
  },
);

Future<void> _wrap(WidgetTester tester, ReferralBloc bloc) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<ReferralBloc>.value(
          value: bloc,
          child: const ReferralCodeScreen(progress: _progress),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home route')),
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
      expect(find.text('Home route'), findsOneWidget);
    },
  );

  testWidgets(
    'code parrain appliqué : « Continuer vers l\'accueil » marque l\'onboarding '
    'vu puis va vers l\'accueil',
    (tester) async {
      when(() => bloc.state).thenReturn(const ReferralRedeemed());
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

      await _wrap(tester, bloc);

      await tester.tap(find.text('Continuer vers l\'accueil'));
      await tester.pumpAndSettle();

      verify(() => authRepository.markOnboardingSeen()).called(1);
      expect(find.text('Home route'), findsOneWidget);
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
      expect(find.text('Home route'), findsOneWidget);
    },
  );
}
