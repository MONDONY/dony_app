import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CorridorAlertModel _alert(AlertDirection d) => CorridorAlertModel(
      id: 'a1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      direction: d,
      active: true,
      createdAt: DateTime(2026, 6, 20),
    );

Widget _pump(CorridorAlertModel a) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CorridorAlertTile(alert: a, onTap: () {}, onToggle: (_) {}),
      ),
    );

void main() {
  testWidgets('package direction shows « Colis » pill', (tester) async {
    await tester.pumpWidget(_pump(_alert(AlertDirection.travelerWantsPackages)));
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Trajets'), findsNothing);
  });

  testWidgets('trip direction shows « Trajets » pill', (tester) async {
    await tester.pumpWidget(_pump(_alert(AlertDirection.senderWantsTrips)));
    expect(find.text('Trajets'), findsOneWidget);
    expect(find.text('Colis'), findsNothing);
  });

  testWidgets(
      'senderWantsTrips with no date window shows "Toute date" and never "tout poids"',
      (tester) async {
    // Alert with senderWantsTrips direction and no dateFrom/dateTo — the
    // 'Toute date' fallback must appear and the weight fallback must NOT.
    final alert = CorridorAlertModel(
      id: 'a2',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      direction: AlertDirection.senderWantsTrips,
      active: true,
      createdAt: DateTime(2026, 6, 20),
      // dateFrom and dateTo intentionally omitted (null).
    );
    await tester.pumpWidget(_pump(alert));
    expect(find.textContaining('Toute date'), findsOneWidget);
    expect(find.textContaining('tout poids'), findsNothing);
  });
}
