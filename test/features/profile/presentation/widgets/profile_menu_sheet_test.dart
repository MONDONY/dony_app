import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/widgets/profile_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Monte un écran minimal dont le seul bouton ouvre la feuille, et retient
  /// l'action rendue. La feuille n'agit jamais elle-même : c'est ce contrat
  /// que ces tests vérifient.
  Future<void> pumpSheet(
    WidgetTester tester, {
    bool canDeleteAccount = true,
    required void Function(ProfileMenuAction?) onClosed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  onClosed(
                    await ProfileMenuSheet.show(
                      context,
                      canDeleteAccount: canDeleteAccount,
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  for (final entry in [
    ('profile-menu-edit', ProfileMenuAction.editProfile),
    ('profile-menu-settings', ProfileMenuAction.settings),
    ('profile-menu-export', ProfileMenuAction.exportData),
    ('profile-menu-logout', ProfileMenuAction.logout),
    ('profile-menu-delete', ProfileMenuAction.deleteAccount),
  ]) {
    testWidgets('« ${entry.$1} » rend ${entry.$2.name} à l\'appelant', (
      tester,
    ) async {
      ProfileMenuAction? action;
      await pumpSheet(tester, onClosed: (value) => action = value);

      await tester.tap(find.byKey(Key(entry.$1)));
      await tester.pumpAndSettle();

      expect(action, entry.$2);
    });
  }

  testWidgets('fermée sans choisir, elle ne rend rien', (tester) async {
    ProfileMenuAction? action;
    var closed = false;
    await pumpSheet(
      tester,
      onClosed: (value) {
        closed = true;
        action = value;
      },
    );

    // Tap sur le voile : la feuille se referme sans action.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(action, isNull);
  });

  testWidgets('porte les libellés du compte, du plus anodin au plus grave', (
    tester,
  ) async {
    await pumpSheet(tester, onClosed: (_) {});

    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Mon compte'), findsOneWidget);
    expect(find.text('Télécharger mes données'), findsOneWidget);
    expect(find.text('Export RGPD au format JSON'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
    expect(find.text('Délai de rétractation de 30 jours'), findsOneWidget);
  });

  // Suppression déjà demandée : la bannière de l'écran propose la
  // réactivation, redemander la suppression n'aurait pas de sens.
  testWidgets('sans droit de suppression, l\'entrée disparaît', (tester) async {
    await pumpSheet(tester, canDeleteAccount: false, onClosed: (_) {});

    expect(find.byKey(const Key('profile-menu-delete')), findsNothing);
    expect(find.text('Supprimer mon compte'), findsNothing);
    expect(find.byKey(const Key('profile-menu-logout')), findsOneWidget);
  });

  // La règle de contenu : le menu ne redit aucune tuile de l'écran Moi.
  testWidgets('ne redit aucune tuile de l\'écran Moi', (tester) async {
    await pumpSheet(tester, onClosed: (_) {});

    expect(find.text('Mon profil public'), findsNothing);
    expect(find.text('Mes avis reçus'), findsNothing);
    expect(find.text('Mes litiges'), findsNothing);
    expect(find.text('FAQ & aide'), findsNothing);
    expect(find.text('Parrainages'), findsNothing);
  });
}
