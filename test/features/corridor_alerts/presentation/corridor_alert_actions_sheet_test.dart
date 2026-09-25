import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

CorridorAlertModel _alert({bool active = true}) => CorridorAlertModel(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  active: active,
  createdAt: DateTime(2026, 6, 20),
);

Future<CorridorAlertAction?> _open(
  WidgetTester tester, {
  bool active = true,
}) async {
  CorridorAlertAction? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await CorridorAlertActionsSheet.show(
                  ctx,
                  alert: _alert(active: active),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets(
    'alerte active : Modifier, Dupliquer, Mettre en pause, Supprimer',
    (tester) async {
      await _open(tester);

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Corridor, dates et filtres'), findsOneWidget);
      expect(find.text('Dupliquer'), findsOneWidget);
      expect(
        find.text('Repartir de cette alerte pour en créer une autre'),
        findsOneWidget,
      );
      expect(find.text('Mettre en pause'), findsOneWidget);
      expect(
        find.text('Plus de notification, l\'alerte reste là'),
        findsOneWidget,
      );
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.byKey(const Key('alert-action-resume')), findsNothing);
    },
  );

  testWidgets('alerte en pause : Reprendre remplace Mettre en pause', (
    tester,
  ) async {
    await _open(tester, active: false);

    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Les notifications repartent'), findsOneWidget);
    expect(find.byKey(const Key('alert-action-pause')), findsNothing);
  });

  testWidgets('tap sur une action referme la feuille avec ce choix', (
    tester,
  ) async {
    CorridorAlertAction? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await CorridorAlertActionsSheet.show(
                    ctx,
                    alert: _alert(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alert-action-duplicate')));
    await tester.pumpAndSettle();

    expect(result, CorridorAlertAction.duplicate);
  });

  testWidgets('anglais : libellés traduits', (tester) async {
    useEnglish();
    await _open(tester);

    expect(find.text('Route, dates and filters'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('No more notifications, the alert stays'), findsOneWidget);
  });
}
