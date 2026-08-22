import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.identity,
    OnboardingStep.address,
    OnboardingStep.payouts,
  ],
  done: {OnboardingStep.consent, OnboardingStep.country},
  current: OnboardingStep.address,
);

Widget _wrap(ResidenceAddressCubit cubit) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<ResidenceAddressCubit>.value(
            value: cubit,
            child: const ResidenceAddressScreen(progress: _progress),
          ),
        ),
        GoRoute(
          path: '/auth/referral-code',
          builder: (_, _) => const Scaffold(body: Text('Parrainage')),
        ),
      ],
    ),
  );
}

void main() {
  late _MockCubit cubit;

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.state).thenReturn(const ResidenceAddressInitial());
    whenListen(
      cubit,
      const Stream<ResidenceAddressState>.empty(),
      initialState: const ResidenceAddressInitial(),
    );
  });

  testWidgets(
    'le bouton Continuer est désactivé tant que le formulaire est vide',
    (tester) async {
      await tester.pumpWidget(_wrap(cubit));
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

    await tester.pumpWidget(_wrap(cubit));
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

    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Passer pour l\'instant'));
    await tester.pump();

    verify(() => cubit.skip()).called(1);
  });

  testWidgets('la jauge remplace le compteur en dur du tunnel', (tester) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DonyOnboardingGauge), findsOneWidget);
    expect(find.byType(DonyStepPill), findsNothing);
    expect(find.text('2 / 5 · Adresse'), findsOneWidget);
  });
}
