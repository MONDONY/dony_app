import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/auth/presentation/screens/country_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockCountryOnboardingCubit extends MockCubit<CountryOnboardingState>
    implements CountryOnboardingCubit {}

Future<void> _wrap(WidgetTester tester, CountryOnboardingCubit cubit) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider.value(
          value: cubit,
          child: const CountrySelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/referral-code',
        builder: (_, _) => const Scaffold(body: Text('Referral route')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

void main() {
  late MockCountryOnboardingCubit cubit;

  setUpAll(() {
    registerFallbackValue(const CountryOnboardingInitial());
  });

  setUp(() {
    cubit = MockCountryOnboardingCubit();
    when(() => cubit.state).thenReturn(const CountryOnboardingInitial());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.select(any())).thenAnswer((_) async {});
    when(() => cubit.skip()).thenAnswer((_) async {});
  });

  testWidgets('affiche le catalogue avec nom et devise de chaque pays', (
    tester,
  ) async {
    await _wrap(tester, cubit);

    // La liste virtualise ses 38 entrées : ne construire que ce qui est
    // amené à l'écran, comme la liste dense qu'elle remplace le prescrit.
    await tester.scrollUntilVisible(
      find.text('Canada'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('CAD · CA\$'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Sénégal'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Sénégal'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sélectionner Sénégal, devise XOF'),
      findsOneWidget,
    );
  });

  testWidgets('la recherche filtre la liste des pays', (tester) async {
    await _wrap(tester, cubit);

    await tester.scrollUntilVisible(
      find.text('Canada'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Canada'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsNothing);
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets('choisir un pays appelle le cubit avec son code', (tester) async {
    await _wrap(tester, cubit);

    await tester.scrollUntilVisible(
      find.text('Canada'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Canada'));
    await tester.pump();

    verify(() => cubit.select('CA')).called(1);
  });

  testWidgets('passer appelle le cubit sans imposer de pays', (tester) async {
    await _wrap(tester, cubit);

    await tester.tap(find.text('Passer pour l’instant'));
    await tester.pump();

    verify(() => cubit.skip()).called(1);
  });

  testWidgets(
    'état Saving affiche l\'indicateur d\'enregistrement sur le pays choisi',
    (tester) async {
      when(() => cubit.state).thenReturn(const CountryOnboardingSaving('CA'));

      await _wrap(tester, cubit);
      await tester.scrollUntilVisible(
        find.text('Canada'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Enregistrement'), findsOneWidget);
    },
  );

  testWidgets('état Error affiche un message d\'erreur', (tester) async {
    whenListen<CountryOnboardingState>(
      cubit,
      Stream.fromIterable([
        const CountryOnboardingSaving('CA'),
        const CountryOnboardingError(
          'Impossible d’enregistrer le pays. Réessayez.',
        ),
      ]),
      initialState: const CountryOnboardingInitial(),
    );

    await _wrap(tester, cubit);
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible d’enregistrer le pays. Réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('état Success navigue vers le code de parrainage', (
    tester,
  ) async {
    whenListen<CountryOnboardingState>(
      cubit,
      Stream.fromIterable([
        const CountryOnboardingSaving('CA'),
        const CountryOnboardingSuccess(),
      ]),
      initialState: const CountryOnboardingInitial(),
    );

    await _wrap(tester, cubit);
    await tester.pumpAndSettle();

    expect(find.text('Referral route'), findsOneWidget);
  });
}
