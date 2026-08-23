import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/country_onboarding_cubit.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/country_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockCountryOnboardingCubit extends MockCubit<CountryOnboardingState>
    implements CountryOnboardingCubit {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

const _progress = OnboardingProgress(
  steps: [
    OnboardingStep.consent,
    OnboardingStep.country,
    OnboardingStep.address,
    OnboardingStep.identity,
    OnboardingStep.payouts,
  ],
  done: {OnboardingStep.consent},
  current: OnboardingStep.country,
);

Future<void> _wrap(
  WidgetTester tester,
  CountryOnboardingCubit cubit, {
  AuthBloc? authBloc,
}) async {
  final auth = authBloc ?? MockAuthBloc();
  when(() => auth.state).thenReturn(const AuthInitial());
  when(() => auth.stream).thenAnswer((_) => const Stream.empty());
  when(() => auth.add(any())).thenReturn(null);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<CountryOnboardingCubit>.value(value: cubit),
            BlocProvider<AuthBloc>.value(value: auth),
          ],
          child: const CountrySelectionScreen(progress: _progress),
        ),
      ),
      GoRoute(
        path: '/auth/residence-address',
        builder: (_, state) =>
            Scaffold(body: Text('Residence route extra=${state.extra}')),
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
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late MockCountryOnboardingCubit cubit;

  setUpAll(() {
    registerFallbackValue(const CountryOnboardingInitial());
    registerFallbackValue(FakeAuthEvent());
  });

  setUp(() {
    cubit = MockCountryOnboardingCubit();
    when(() => cubit.state).thenReturn(const CountryOnboardingInitial());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.select(any())).thenAnswer((_) async {});
    when(() => cubit.skip()).thenAnswer((_) async {});
    when(() => cubit.continueAsSenderOnly()).thenAnswer((_) async {});
  });

  testWidgets('affiche les suggestions avec nom, zone et devise', (
    tester,
  ) async {
    await _wrap(tester, cubit);

    await tester.enterText(find.byType(TextField), 'can');
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('Amérique du Nord · CAD · CA\$'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();

    expect(find.text('Sénégal'), findsOneWidget);
    expect(find.text('Afrique de l\'Ouest · XOF · F CFA'), findsOneWidget);
  });

  testWidgets('les suggestions affichent la zone du pays choisi', (
    tester,
  ) async {
    await _wrap(tester, cubit);

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();

    expect(find.text('Afrique de l\'Ouest · XOF · F CFA'), findsOneWidget);
    expect(find.text('Europe · EUR · €'), findsNothing);
  });

  testWidgets('la recherche filtre la liste des pays', (tester) async {
    await _wrap(tester, cubit);

    await tester.enterText(find.byType(TextField), 'can');
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsNothing);
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets(
    'une recherche sans résultat explique que Yadony est indisponible',
    (tester) async {
      await _wrap(tester, cubit);

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(
        find.text('Yadony n’est pas encore disponible dans ce pays'),
        findsOneWidget,
      );
      expect(
        find.text('Je souhaite continuer et envoyer des colis'),
        findsOneWidget,
      );
      expect(find.text('Supprimer mon compte'), findsOneWidget);
      expect(find.text('Canada'), findsNothing);
      expect(find.text('Sénégal'), findsNothing);
    },
  );

  testWidgets('continuer depuis un pays indisponible appelle le cubit dédié', (
    tester,
  ) async {
    await _wrap(tester, cubit);

    await tester.enterText(find.byType(TextField), 'zzzzzzz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je souhaite continuer et envoyer des colis'));
    await tester.pump();

    verify(() => cubit.continueAsSenderOnly()).called(1);
  });

  testWidgets(
    'supprimer mon compte demande confirmation puis dispatch delete',
    (tester) async {
      final authBloc = MockAuthBloc();
      when(() => authBloc.add(any())).thenReturn(null);

      await _wrap(tester, cubit, authBloc: authBloc);

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer définitivement le compte ?'), findsOneWidget);

      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pump();

      verify(() => authBloc.add(const AuthDeleteAccountRequested())).called(1);
    },
  );

  testWidgets('choisir un pays appelle le cubit avec son code', (tester) async {
    await _wrap(tester, cubit);

    await tester.enterText(find.byType(TextField), 'can');
    await tester.pumpAndSettle();
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

      expect(find.text('Enregistrement du pays...'), findsOneWidget);
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

  testWidgets(
    'état Success navigue vers l\'étape adresse de résidence en passant le '
    'code pays fraîchement choisi en extra, et rafraîchit le profil '
    '(correction 1 de la revue finale du lot 2 : sans ce refresh, l\'étape '
    '« pays » regressait sur /auth/referral-code, plusieurs écrans plus loin)',
    (tester) async {
      whenListen<CountryOnboardingState>(
        cubit,
        Stream.fromIterable([
          const CountryOnboardingSaving('CA'),
          const CountryOnboardingSuccess(),
        ]),
        initialState: const CountryOnboardingInitial(),
      );

      final authBloc = MockAuthBloc();
      await _wrap(tester, cubit, authBloc: authBloc);
      await tester.pumpAndSettle();

      // `extra` porte le code choisi par l'utilisateur, la valeur la plus
      // fraîche possible — plus fraîche qu'une relecture de
      // `BusinessPrefsBloc`, dont le singleton app-wide ne se resynchronise
      // pas automatiquement quand ce cubit écrit directement dans Hive.
      expect(find.text('Residence route extra=CA'), findsOneWidget);
      verify(() => authBloc.add(const AuthProfileRefreshRequested())).called(1);
    },
  );

  testWidgets(
    'passer la sélection de pays (skip) navigue directement vers le parrainage, '
    'pas vers l\'adresse de résidence, et ne rafraîchit pas le profil '
    '(skip() n\'écrit rien côté serveur, rien à rafraîchir)',
    (tester) async {
      // `skip()` émet `CountryOnboardingSaving(null)` : aucun code pays, donc
      // rien à préparer sur l'étape adresse (compte de paiement voyageur).
      whenListen<CountryOnboardingState>(
        cubit,
        Stream.fromIterable([
          const CountryOnboardingSaving(null),
          const CountryOnboardingSuccess(),
        ]),
        initialState: const CountryOnboardingInitial(),
      );

      final authBloc = MockAuthBloc();
      await _wrap(tester, cubit, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(find.text('Referral route'), findsOneWidget);
      expect(find.text('Residence route'), findsNothing);
      verifyNever(() => authBloc.add(const AuthProfileRefreshRequested()));
    },
  );

  testWidgets(
    'continuer sans pays disponible (continueAsSenderOnly) navigue directement '
    'vers le parrainage, pas vers l\'adresse de résidence, et ne rafraîchit '
    'pas le profil (rien n\'est écrit côté serveur non plus)',
    (tester) async {
      // `continueAsSenderOnly()` émet lui aussi `CountryOnboardingSaving(null)` :
      // même contrat de navigation que `skip()`.
      whenListen<CountryOnboardingState>(
        cubit,
        Stream.fromIterable([
          const CountryOnboardingSaving(null),
          const CountryOnboardingSuccess(),
        ]),
        initialState: const CountryOnboardingInitial(),
      );

      final authBloc = MockAuthBloc();
      await _wrap(tester, cubit, authBloc: authBloc);
      await tester.pumpAndSettle();

      expect(find.text('Referral route'), findsOneWidget);
      expect(find.text('Residence route'), findsNothing);
      verifyNever(() => authBloc.add(const AuthProfileRefreshRequested()));
    },
  );
}
