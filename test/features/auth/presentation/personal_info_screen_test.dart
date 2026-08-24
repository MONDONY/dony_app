import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/personal_info_cubit.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/personal_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<PersonalInfoState>
    implements PersonalInfoCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.personalInfo,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {OnboardingStep.consent, OnboardingStep.country},
  current: OnboardingStep.personalInfo,
);

Widget _wrap(PersonalInfoCubit cubit, AuthBloc authBloc, {String? country}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PersonalInfoCubit>.value(value: cubit),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: PersonalInfoScreen(country: country, progress: _progress),
          ),
        ),
        GoRoute(
          path: '/auth/referral-code',
          builder: (_, state) =>
              Scaffold(body: Text('Parrainage extra=${state.extra}')),
        ),
      ],
    ),
  );
}

void main() {
  late _MockCubit cubit;
  late _MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  setUp(() {
    cubit = _MockCubit();
    authBloc = _MockAuthBloc();
    when(() => cubit.state).thenReturn(const PersonalInfoInitial());
    whenListen(
      cubit,
      const Stream<PersonalInfoState>.empty(),
      initialState: const PersonalInfoInitial(),
    );
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => authBloc.add(any())).thenReturn(null);
  });

  testWidgets(
    'le bouton Continuer est désactivé tant que le formulaire est vide',
    (tester) async {
      await tester.pumpWidget(_wrap(cubit, authBloc));
      await tester.pump(const Duration(milliseconds: 400));

      final btn = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Continuer'),
      );
      expect(btn.onPressed, isNull);
    },
  );

  testWidgets('un prénom seul ne suffit pas : Stripe ouvre un compte au nom '
      'légal complet', (tester) async {
    await tester.pumpWidget(_wrap(cubit, authBloc));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byKey(const Key('identity-first-name')), 'Awa');
    await tester.pump();

    final btn = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Continuer'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('un formulaire rempli active le bouton et appelle submit', (
    tester,
  ) async {
    when(
      () => cubit.submit(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(cubit, authBloc));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byKey(const Key('identity-first-name')), 'Awa');
    await tester.enterText(
      find.byKey(const Key('identity-last-name')),
      'Diallo',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
    await tester.pump();

    verify(() => cubit.submit(firstName: 'Awa', lastName: 'Diallo')).called(1);
  });

  testWidgets(
    'ni date de naissance ni adresse : Stripe les demande dans son formulaire',
    (tester) async {
      await tester.pumpWidget(_wrap(cubit, authBloc));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('identity-birth-date')), findsNothing);
      expect(find.byKey(const Key('residence-street')), findsNothing);
      expect(find.byKey(const Key('residence-postal')), findsNothing);
      expect(find.byKey(const Key('residence-city')), findsNothing);
    },
  );

  testWidgets('« Passer pour l\'instant » appelle skip', (tester) async {
    when(() => cubit.skip()).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(cubit, authBloc));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Passer pour l\'instant'));
    await tester.pump();

    verify(() => cubit.skip()).called(1);
  });

  testWidgets('la jauge remplace le compteur en dur du tunnel', (tester) async {
    await tester.pumpWidget(_wrap(cubit, authBloc));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DonyOnboardingGauge), findsOneWidget);
    expect(find.byType(DonyStepPill), findsNothing);
    // Position : les informations forment le 3e écran du parcours, donc
    // « 3 / 5 ».
    expect(find.text('3 / 5 · Informations'), findsOneWidget);
  });

  group('PersonalInfoSuccess (correction 1 de la revue finale du lot 2)', () {
    testWidgets(
      'rafraîchit le profil et propage le pays en extra vers le parrainage — '
      'sans ce double repli, l\'étape « pays » ET l\'étape « informations » '
      'regressaient sur /auth/referral-code (0/5 → 1/5 → 2/5 → 1/5)',
      (tester) async {
        whenListen<PersonalInfoState>(
          cubit,
          Stream.fromIterable([
            const PersonalInfoSaving(),
            const PersonalInfoSuccess(),
          ]),
          initialState: const PersonalInfoInitial(),
        );

        await tester.pumpWidget(_wrap(cubit, authBloc, country: 'FR'));
        await tester.pumpAndSettle();

        verify(
          () => authBloc.add(const AuthProfileRefreshRequested()),
        ).called(1);
        expect(find.text('Parrainage extra=FR'), findsOneWidget);
      },
    );

    testWidgets(
      'skip() aboutit au même state que submit() (PersonalInfoSuccess) '
      'et déclenche donc le même refresh + le même repli extra — skip() ne '
      'pose PAS onboarding_seen_at, il reste identité et paiements',
      (tester) async {
        // `StreamController` plutôt que `Stream.fromIterable` : ce dernier
        // émet ses valeurs dès le premier pump, avant même le tap — le
        // widget aurait déjà navigué au moment d'appuyer sur le bouton. Ici,
        // c'est `skip()` lui-même qui pilote la transition d'état, comme le
        // ferait le vrai cubit.
        final controller = StreamController<PersonalInfoState>();
        addTearDown(controller.close);
        whenListen<PersonalInfoState>(
          cubit,
          controller.stream,
          initialState: const PersonalInfoInitial(),
        );
        when(() => cubit.skip()).thenAnswer((_) async {
          controller
            ..add(const PersonalInfoSaving())
            ..add(const PersonalInfoSuccess());
        });

        await tester.pumpWidget(_wrap(cubit, authBloc, country: 'SN'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Passer pour l\'instant'));
        await tester.pumpAndSettle();

        verify(() => cubit.skip()).called(1);
        verify(
          () => authBloc.add(const AuthProfileRefreshRequested()),
        ).called(1);
        expect(find.text('Parrainage extra=SN'), findsOneWidget);
      },
    );
  });
}
