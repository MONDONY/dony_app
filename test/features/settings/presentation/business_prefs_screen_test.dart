import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/screens/business_prefs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/currency_test_doubles.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// Helper to create UserModel with specific roles
UserModel _makeUser({List<String> roles = const ['SENDER']}) => UserModel(
  id: 'test-user-id',
  roles: roles,
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

void main() {
  late MockBusinessPrefsBloc mockPrefsBloc;
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const CurrencyChanged('EUR'));
  });

  setUp(() {
    mockPrefsBloc = MockBusinessPrefsBloc();
    mockAuthBloc = MockAuthBloc();
    mockPrefsBloc = stubBusinessPrefsBloc();
  });

  Widget buildScreen() => MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<BusinessPrefsBloc>.value(value: mockPrefsBloc),
              BlocProvider<AuthBloc>.value(value: mockAuthBloc),
            ],
            child: const BusinessPrefsScreen(),
          ),
        ),
      ],
    ),
  );

  testWidgets('section MES TRAJETS masquée si rôle SENDER uniquement', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsNothing);
    expect(find.text('Poids par défaut'), findsNothing);
  });

  testWidgets('section MES TRAJETS visible si rôle TRAVELER présent', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(
      AuthAuthenticated(_makeUser(roles: const ['SENDER', 'TRAVELER'])),
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsOneWidget);
    expect(find.text('Poids par défaut'), findsOneWidget);
    expect(find.text('Prix minimum'), findsOneWidget);
    expect(find.text('Mode de contact'), findsOneWidget);
    expect(find.text('Délai de réponse'), findsOneWidget);
  });

  testWidgets('section MES TRAJETS visible si rôle TRAVELER-only', (
    tester,
  ) async {
    when(
      () => mockAuthBloc.state,
    ).thenReturn(AuthAuthenticated(_makeUser(roles: const ['TRAVELER'])));
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsOneWidget);
  });

  testWidgets('section MES TRAJETS masquée si non authentifié', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('MES TRAJETS'), findsNothing);
  });

  testWidgets('banner erreur affiché si errorMessage non null', (tester) async {
    when(() => mockPrefsBloc.state).thenReturn(
      const BusinessPrefsState(
        errorMessage: 'Impossible de synchroniser. Réessayez.',
      ),
    );
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Impossible de synchroniser. Réessayez.'), findsOneWidget);
  });

  testWidgets(
    'sélecteur devise affiche toutes les devises du catalogue et leur taux EUR',
    (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();

      expect(find.text('Franc CFA Ouest (XOF)'), findsOneWidget);
      expect(find.text('Franc CFA Centre (XAF)'), findsOneWidget);
      expect(find.textContaining('1 EUR ≈ 655,957 XOF'), findsOneWidget);
      expect(find.textContaining('1 EUR ≈ 655,957 XAF'), findsOneWidget);
    },
  );

  testWidgets(
    'taper une devise différente affiche un dialogue de confirmation sans '
    'envoyer CurrencyChanged avant validation',
    (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Franc CFA Centre (XAF)'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de devise'), findsOneWidget);
      verifyNever(() => mockPrefsBloc.changeCurrency(any()));
    },
  );

  testWidgets(
    'confirmer le dialogue envoie CurrencyChanged avec la devise choisie',
    (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Franc CFA Centre (XAF)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer pour XAF'));
      await tester.pumpAndSettle();

      verify(() => mockPrefsBloc.changeCurrency('XAF')).called(1);
    },
  );

  testWidgets('annuler le dialogue n\'envoie jamais CurrencyChanged', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Franc CFA Centre (XAF)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    verifyNever(() => mockPrefsBloc.changeCurrency(any()));
  });

  testWidgets('taper la devise déjà active ferme le picker sans dialogue', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro (EUR)'));
    await tester.pumpAndSettle();

    expect(find.text('Changer de devise'), findsNothing);
    verifyNever(() => mockPrefsBloc.changeCurrency(any()));
  });

  testWidgets(
    'devise verrouillée : la tuile est grisée avec une explication et ne '
    'répond plus au tap',
    (tester) async {
      mockPrefsBloc = stubBusinessPrefsBloc(
        state: const BusinessPrefsState(currencyLocked: true),
      );
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Verrouillée'),
        findsOneWidget,
      );

      await tester.tap(find.text('EUR'));
      await tester.pumpAndSettle();

      expect(find.text('Devise d\'affichage'), findsOneWidget);
      verifyNever(() => mockPrefsBloc.changeCurrency(any()));
    },
  );
}
