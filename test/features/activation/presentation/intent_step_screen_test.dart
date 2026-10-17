import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/screens/intent_step_screen.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_signup_cubit.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockIntentCubit extends MockCubit<IntentFormState>
    implements IntentCubit {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockGpRepo extends Mock implements GpProRepository {}

class _MockActivationCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

void main() {
  late _MockGpRepo gpRepo;
  late GpProSignupCubit gpCubit;

  setUpAll(() {
    registerFallbackValue(IntentSource.signup);
    registerFallbackValue(GpProFrequency.weekly);
    registerFallbackValue(GpProSource.signup);
  });

  setUp(() {
    gpRepo = _MockGpRepo();
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    gpCubit = GpProSignupCubit(gpRepo, analytics);
    when(
      () => gpRepo.apply(
        frequency: any(named: 'frequency'),
        commercialName: any(named: 'commercialName'),
        documentIds: any(named: 'documentIds'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
  });

  Future<void> pump(
    WidgetTester tester,
    _MockIntentCubit cubit,
    StreamController<IntentFormState> states, {
    IntentStepArgs args = const IntentStepArgs(next: '/auth/referral-code'),
    UserIntent intent = UserIntent.sender,
  }) async {
    // Écran haut : la section GP Pro doit tenir sans défilement.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      cubit,
      states.stream,
      initialState: IntentFormState(intent: intent, destination: 'SN'),
    );
    final router = GoRouter(
      initialLocation: intentStepRoute,
      routes: [
        GoRoute(
          path: intentStepRoute,
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<IntentCubit>.value(value: cubit),
              BlocProvider<GpProSignupCubit>.value(value: gpCubit),
            ],
            child: IntentStepScreen(
              progress: const OnboardingProgress(steps: [], done: {}),
              args: args,
            ),
          ),
        ),
        GoRoute(
          path: '/auth/referral-code',
          builder: (_, _) => const Scaffold(body: Text('Parrainage')),
        ),
        GoRoute(
          path: '/auth/personal-info',
          builder: (_, state) => Scaffold(body: Text('Infos ${state.extra}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Continuer soumet avec la source SIGNUP', (tester) async {
    final cubit = _MockIntentCubit();
    when(() => cubit.submit(any())).thenAnswer((_) async {});
    final states = StreamController<IntentFormState>();
    await pump(tester, cubit, states);
    expect(find.text('Vous utilisez Yadony pour…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intent-continue')));
    verify(() => cubit.submit(IntentSource.signup)).called(1);
    await states.close();
  });

  testWidgets('saved : passe à l\'étape suivante avec son extra', (
    tester,
  ) async {
    final cubit = _MockIntentCubit();
    final states = StreamController<IntentFormState>();
    await pump(
      tester,
      cubit,
      states,
      args: const IntentStepArgs(next: '/auth/personal-info', nextExtra: 'SN'),
    );
    states.add(
      const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
        status: IntentFormStatus.saved,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Infos SN'), findsOneWidget);
    await states.close();
  });

  testWidgets('erreur : l\'inscription continue quand même', (tester) async {
    final cubit = _MockIntentCubit();
    final states = StreamController<IntentFormState>();
    await pump(tester, cubit, states);
    states.add(
      const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
        status: IntentFormStatus.error,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Parrainage'), findsOneWidget);
    await states.close();
  });

  testWidgets('saved : recharge le statut d\'activation avant la suite', (
    tester,
  ) async {
    final activation = _MockActivationCubit();
    when(() => activation.state).thenReturn(const ActivationInitial());
    when(() => activation.load()).thenAnswer((_) async {});
    getIt.registerSingleton<ActivationCubit>(activation);
    addTearDown(() => getIt.unregister<ActivationCubit>());
    final cubit = _MockIntentCubit();
    final states = StreamController<IntentFormState>();
    await pump(tester, cubit, states);
    states.add(
      const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
        status: IntentFormStatus.saved,
      ),
    );
    await tester.pumpAndSettle();
    verify(() => activation.load()).called(1);
    await states.close();
  });

  group('GP Pro', () {
    final checkbox = find.byKey(const Key('gp-pro-signup-checkbox'));

    testWidgets('absente pour « Expéditeur »', (tester) async {
      final states = StreamController<IntentFormState>();
      await pump(tester, _MockIntentCubit(), states);
      expect(checkbox, findsNothing);
      await states.close();
    });

    testWidgets('présente pour « Voyageur », fréquence masquée tant que '
        'décochée', (tester) async {
      final states = StreamController<IntentFormState>();
      await pump(
        tester,
        _MockIntentCubit(),
        states,
        intent: UserIntent.traveler,
      );
      expect(checkbox, findsOneWidget);
      expect(find.text('À quelle fréquence voyagez-vous ?'), findsNothing);
      await states.close();
    });

    testWidgets('cochée sans fréquence : « Continuer » désactivé', (
      tester,
    ) async {
      final cubit = _MockIntentCubit();
      when(() => cubit.submit(any())).thenAnswer((_) async {});
      final states = StreamController<IntentFormState>();
      await pump(tester, cubit, states, intent: UserIntent.both);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('À quelle fréquence voyagez-vous ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('intent-continue')));
      verifyNever(() => cubit.submit(any()));

      await tester.tap(find.text('Chaque semaine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('intent-continue')));
      verify(() => cubit.submit(IntentSource.signup)).called(1);
      await states.close();
    });

    testWidgets('bascule sur « Expéditeur » : « Continuer » se réactive', (
      tester,
    ) async {
      final cubit = _MockIntentCubit();
      when(() => cubit.submit(any())).thenAnswer((_) async {});
      final states = StreamController<IntentFormState>();
      await pump(tester, cubit, states, intent: UserIntent.traveler);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('intent-continue'));
      expect(tester.widget<DonyButton>(button).onPressed, isNull);

      states.add(
        const IntentFormState(intent: UserIntent.sender, destination: 'SN'),
      );
      await tester.pumpAndSettle();
      expect(checkbox, findsNothing);
      expect(tester.widget<DonyButton>(button).onPressed, isNotNull);

      states.add(
        const IntentFormState(intent: UserIntent.traveler, destination: 'SN'),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<DonyButton>(button).onPressed, isNull);
      await states.close();
    });

    testWidgets('saved : envoie la demande GP Pro puis navigue', (
      tester,
    ) async {
      final cubit = _MockIntentCubit();
      final states = StreamController<IntentFormState>();
      await pump(tester, cubit, states, intent: UserIntent.traveler);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Une fois par mois'));
      await tester.enterText(
        find.byKey(const Key('gp-pro-signup-name')),
        ' Awa Express ',
      );
      await tester.pumpAndSettle();
      states.add(
        const IntentFormState(
          intent: UserIntent.traveler,
          destination: 'SN',
          status: IntentFormStatus.saved,
        ),
      );
      await tester.pumpAndSettle();
      verify(
        () => gpRepo.apply(
          frequency: GpProFrequency.monthly,
          commercialName: 'Awa Express',
          source: GpProSource.signup,
        ),
      ).called(1);
      expect(find.text('Parrainage'), findsOneWidget);
      await states.close();
    });

    testWidgets('échec GP Pro : l\'inscription continue quand même', (
      tester,
    ) async {
      when(
        () => gpRepo.apply(
          frequency: any(named: 'frequency'),
          commercialName: any(named: 'commercialName'),
          documentIds: any(named: 'documentIds'),
          source: any(named: 'source'),
        ),
      ).thenThrow(Exception('boom'));
      final cubit = _MockIntentCubit();
      final states = StreamController<IntentFormState>();
      await pump(tester, cubit, states, intent: UserIntent.traveler);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chaque semaine'));
      await tester.pumpAndSettle();
      states.add(
        const IntentFormState(
          intent: UserIntent.traveler,
          destination: 'SN',
          status: IntentFormStatus.error,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parrainage'), findsOneWidget);
      await states.close();
    });
  });
}
