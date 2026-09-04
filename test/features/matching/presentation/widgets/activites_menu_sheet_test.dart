import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/activites_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Monte un écran minimal dont le seul bouton ouvre la feuille, et retient
  /// le choix rendu. La feuille ne navigue pas elle-même : c'est ce contrat
  /// que ces tests vérifient.
  Future<void> pumpSheet(
    WidgetTester tester, {
    required ToolsCompletionModel? tools,
    required void Function(ActivitesMenuChoice?) onClosed,
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
                    await ActivitesMenuSheet.show(context, tools: tools),
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

  const complete = ToolsCompletionModel(
    tools: [
      ToolStatus(key: ToolKey.addresses, count: 3),
      ToolStatus(key: ToolKey.recipients, count: 1),
      ToolStatus(key: ToolKey.alerts, count: 2),
      ToolStatus(key: ToolKey.tripTemplates, count: 1),
      ToolStatus(key: ToolKey.priceGrid, count: 4),
    ],
  );

  testWidgets('rend son choix à l\'appelant plutôt que de naviguer', (
    tester,
  ) async {
    ActivitesMenuChoice? choice;
    await pumpSheet(
      tester,
      tools: complete,
      onClosed: (value) => choice = value,
    );

    await tester.tap(find.byKey(const Key('menu-quick-scan')));
    await tester.pumpAndSettle();

    expect(choice?.route, '/tracking/scan-hub');
    expect(choice?.event, AnalyticsEvents.activitesHubScanOpened);
  });

  testWidgets('fermée sans choisir, elle ne rend rien', (tester) async {
    ActivitesMenuChoice? choice;
    var closed = false;
    await pumpSheet(
      tester,
      tools: complete,
      onClosed: (value) {
        closed = true;
        choice = value;
      },
    );

    // Tap sur le voile : la feuille se referme sans destination.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(choice, isNull);
  });

  // Le hub ouvre son menu dès le premier tap, sans attendre la réponse de
  // `GET /users/me/tools-completion`. Sans complétion, la feuille reste
  // utilisable : elle perd ses pastilles, jamais ses entrées.
  testWidgets('complétion pas encore chargée : ni pastille ni décompte', (
    tester,
  ) async {
    await pumpSheet(tester, tools: null, onClosed: (_) {});

    expect(find.textContaining('prêts'), findsNothing);
    expect(find.byKey(const Key('tool-status-badge')), findsNothing);
    expect(find.text('Mes alertes'), findsOneWidget);
    expect(find.text('Portefeuille'), findsOneWidget);
  });

  testWidgets('complétion chargée : décompte global et pastilles', (
    tester,
  ) async {
    await pumpSheet(tester, tools: complete, onClosed: (_) {});

    expect(find.text('5/5 prêts'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('menu-tool-price-grid')),
        matching: find.text('Configurée'),
      ),
      findsOneWidget,
    );
  });

  // La règle de contenu du menu : les quatre domaines du hub restent l'affaire
  // de la grille, avec leurs compteurs et leur pastille de non-lus.
  testWidgets('n\'expose aucune des tuiles « En ce moment »', (tester) async {
    await pumpSheet(tester, tools: complete, onClosed: (_) {});

    expect(find.text('Trajets actifs'), findsNothing);
    expect(find.text('Mes colis'), findsNothing);
    expect(find.text('Demandes reçues'), findsNothing);
    expect(find.text('Discussions de prix'), findsNothing);
  });
}
