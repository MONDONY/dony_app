import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/residence_address_cubit.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/residence_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<ResidenceAddressState>
    implements ResidenceAddressCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.address,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {OnboardingStep.consent, OnboardingStep.country},
  current: OnboardingStep.address,
);

Widget _wrap(
  ResidenceAddressCubit cubit,
  AuthBloc authBloc, {
  String? country,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<ResidenceAddressCubit>.value(value: cubit),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: ResidenceAddressScreen(
              country: country,
              progress: _progress,
            ),
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
    when(() => cubit.state).thenReturn(const ResidenceAddressInitial());
    whenListen(
      cubit,
      const Stream<ResidenceAddressState>.empty(),
      initialState: const ResidenceAddressInitial(),
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

  testWidgets('un formulaire rempli active le bouton et appelle submit', (
    tester,
  ) async {
    when(
      () => cubit.submit(
        street: any(named: 'street'),
        line2: any(named: 'line2'),
        postalCode: any(named: 'postalCode'),
        city: any(named: 'city'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(cubit, authBloc));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.byKey(const Key('residence-street')),
      '12 rue des Lilas',
    );
    await tester.enterText(find.byKey(const Key('residence-postal')), '75011');
    await tester.enterText(find.byKey(const Key('residence-city')), 'Paris');
    await tester.pump();

    await tester.tap(find.widgetWithText(DonyButton, 'Continuer'));
    await tester.pump();

    verify(
      () => cubit.submit(
        street: '12 rue des Lilas',
        postalCode: '75011',
        city: 'Paris',
      ),
    ).called(1);
  });

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
    // Position : l'adresse est le 3e écran du parcours, donc « 3 / 5 ».
    expect(find.text('3 / 5 · Adresse'), findsOneWidget);
  });

  group(
    'ResidenceAddressSuccess (correction 1 de la revue finale du lot 2)',
    () {
      testWidgets(
        'rafraîchit le profil et propage le pays en extra vers le parrainage — '
        'sans ce double repli, l\'étape « pays » ET l\'étape « adresse » '
        'regressaient sur /auth/referral-code (0/5 → 1/5 → 2/5 → 1/5)',
        (tester) async {
          whenListen<ResidenceAddressState>(
            cubit,
            Stream.fromIterable([
              const ResidenceAddressSaving(),
              const ResidenceAddressSuccess(),
            ]),
            initialState: const ResidenceAddressInitial(),
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
        'skip() aboutit au même state que submit() (ResidenceAddressSuccess) '
        'et déclenche donc le même refresh + le même repli extra — skip() ne '
        'pose PAS onboarding_seen_at, il reste identité et paiements',
        (tester) async {
          // `StreamController` plutôt que `Stream.fromIterable` : ce dernier
          // émet ses valeurs dès le premier pump, avant même le tap — le
          // widget aurait déjà navigué au moment d'appuyer sur le bouton. Ici,
          // c'est `skip()` lui-même qui pilote la transition d'état, comme le
          // ferait le vrai cubit.
          final controller = StreamController<ResidenceAddressState>();
          addTearDown(controller.close);
          whenListen<ResidenceAddressState>(
            cubit,
            controller.stream,
            initialState: const ResidenceAddressInitial(),
          );
          when(() => cubit.skip()).thenAnswer((_) async {
            controller
              ..add(const ResidenceAddressSaving())
              ..add(const ResidenceAddressSuccess());
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
    },
  );
}
