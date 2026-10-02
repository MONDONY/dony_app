import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/screens/intent_step_screen.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockIntentCubit extends MockCubit<IntentFormState>
    implements IntentCubit {}

class _MockActivationCubit extends MockCubit<ActivationState>
    implements ActivationCubit {}

void main() {
  setUpAll(() => registerFallbackValue(IntentSource.signup));

  Future<void> pump(
    WidgetTester tester,
    _MockIntentCubit cubit,
    StreamController<IntentFormState> states, {
    IntentStepArgs args = const IntentStepArgs(next: '/auth/referral-code'),
  }) async {
    whenListen(
      cubit,
      states.stream,
      initialState: const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
      ),
    );
    final router = GoRouter(
      initialLocation: intentStepRoute,
      routes: [
        GoRoute(
          path: intentStepRoute,
          builder: (_, _) => BlocProvider<IntentCubit>.value(
            value: cubit,
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
}
