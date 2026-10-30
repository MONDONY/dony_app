// Tuile « À traiter » partagée par les vues expéditeur et voyageur : clé,
// couleur primaire, pastille ambre et toucher.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_action_tile.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clé <role>-todo-<tile>, pastille news, toucher transmis', (
    tester,
  ) async {
    var taps = 0;
    late Color primary;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              primary = Theme.of(context).colorScheme.primary;
              return todoActionTile(
                context,
                role: 'traveler',
                tile: 'supplement',
                iconName: 'credit-card',
                label: 'Supplément de prix',
                subtitle: 'Frais à valider',
                badge: 'Réponse attendue',
                onTap: () => taps++,
              );
            },
          ),
        ),
      ),
    );

    final finder = find.byKey(const Key('traveler-todo-supplement'));
    final tile = tester.widget<DonyActionTile>(finder);
    expect(tile.color, primary);
    expect(tile.label, 'Supplément de prix');
    expect(tile.subtitle, 'Frais à valider');
    final badge = tile.badge! as ToolStatusBadge;
    expect(badge.tone, ToolStatusTone.news);
    expect(badge.ready, isFalse);
    expect(badge.label, 'Réponse attendue');
    expect(badge.semanticsLabel, 'Réponse attendue');

    await tester.tap(finder);
    expect(taps, 1);
  });
}
