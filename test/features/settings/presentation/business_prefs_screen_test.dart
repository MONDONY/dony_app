import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

  setUpAll(() {});

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

  testWidgets('la tuile Pays affiche la devise derivee en lecture seule', (
    tester,
  ) async {
    mockPrefsBloc = stubBusinessPrefsBloc(
      state: const BusinessPrefsState(country: 'CA', currencyCode: 'CAD'),
    );
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Canada'), findsOneWidget);
    expect(find.textContaining('CAD'), findsOneWidget);
    expect(find.textContaining('Définie par votre pays'), findsOneWidget);
  });

  testWidgets('la tuile Pays est grisee quand le pays est verrouille', (
    tester,
  ) async {
    mockPrefsBloc = stubBusinessPrefsBloc(
      state: const BusinessPrefsState(
        country: 'CA',
        currencyCode: 'CAD',
        countryLocked: true,
      ),
    );
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final tile = tester.widget<DonyListTile>(
      find.ancestor(
        of: find.text('Canada'),
        matching: find.byType(DonyListTile),
      ),
    );
    expect(tile.enabled, isFalse);
    // Griser sans expliquer laisse l'utilisateur croire à un bug : le
    // sous-titre doit dire pourquoi le pays est figé.
    expect(tile.subtitle, isNotNull);
    expect(
      find.textContaining(
        'Verrouillé : un envoi est en cours ou votre compte de paiement est créé',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sans pays renseigne, la tuile invite a le choisir', (
    tester,
  ) async {
    // État par défaut (setUp) : ni pays ni devise renseignés côté serveur.
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Choisir mon pays'), findsOneWidget);
  });

  testWidgets('tap sur la tuile Pays ouvre le sélecteur avec recherche', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir mon pays'));
    await tester.pumpAndSettle();

    expect(find.text('Rechercher un pays'), findsOneWidget);
    // Les 38 pays sont groupés par zone, pas listés à plat.
    expect(find.text('EUROPE'), findsOneWidget);
    expect(find.text('AFRIQUE DE L\'OUEST'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets('choisir un pays dans le sélecteur envoie CountryChanged', (
    tester,
  ) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir mon pays'));
    await tester.pumpAndSettle();
    // Filtrer d'abord : la liste complète (38 entrées) dépasse la hauteur de
    // la feuille, un tap direct sur une entrée lointaine ne serait pas fiable.
    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sénégal'));
    await tester.pumpAndSettle();

    verify(() => mockPrefsBloc.add(const CountryChanged('SN'))).called(1);
  });

  testWidgets('la recherche filtre le sélecteur de pays', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir mon pays'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pumpAndSettle();

    expect(find.text('France'), findsNothing);
    expect(find.text('Sénégal'), findsOneWidget);
  });

  testWidgets(
    'une recherche sans résultat dans le sélecteur de pays affiche un état '
    'vide sobre',
    (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choisir mon pays'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();

      expect(find.text('Aucun pays trouvé'), findsOneWidget);
    },
  );

  testWidgets('pays verrouillé : le tap n\'ouvre pas le sélecteur', (
    tester,
  ) async {
    mockPrefsBloc = stubBusinessPrefsBloc(
      state: const BusinessPrefsState(
        country: 'CA',
        currencyCode: 'CAD',
        countryLocked: true,
      ),
    );
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Canada'));
    await tester.pumpAndSettle();

    expect(find.text('Rechercher un pays'), findsNothing);
  });
}
