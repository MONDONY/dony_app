import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

CorridorAlertModel _alert(AlertDirection d) => CorridorAlertModel(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  direction: d,
  active: true,
  createdAt: DateTime(2026, 6, 20),
);

Widget _pump(CorridorAlertModel a) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: CorridorAlertTile(alert: a, onTap: () {}, onToggle: (_) {}),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('renders corridor, summary and toggle (flat, no border)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pump(_alert(AlertDirection.travelerWantsPackages)),
    );

    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Flat WhatsApp style: the tile itself draws no bordered Container.
    expect(find.byType(Card), findsNothing);
    // Direction pill removed — each screen is mono-direction.
    expect(find.text('Colis'), findsNothing);
    expect(find.text('Trajets'), findsNothing);
  });

  testWidgets('paused alert renders with toggle off', (tester) async {
    final paused = CorridorAlertModel(
      id: 'p1',
      departureCity: 'Lyon',
      arrivalCity: 'Bamako',
      direction: AlertDirection.travelerWantsPackages,
      active: false,
      createdAt: DateTime(2026, 6, 20),
    );
    await tester.pumpWidget(_pump(paused));

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
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
    },
  );

  testWidgets('zone alert shows the pickup-zone chip', (tester) async {
    final zoneAlert = CorridorAlertModel(
      id: 'z1',
      departureCity: 'Paris',
      arrivalCity: 'Abidjan',
      direction: AlertDirection.senderWantsTrips,
      active: true,
      createdAt: DateTime(2026, 6, 20),
      centerLat: 48.8566,
      centerLng: 2.3522,
      radiusKm: 20,
      centerLabel: 'Châtelet',
    );
    await tester.pumpWidget(_pump(zoneAlert));
    expect(find.textContaining('≤ 20 km · Châtelet'), findsOneWidget);
  });

  testWidgets('non-zone alert shows no pickup-zone chip', (tester) async {
    await tester.pumpWidget(
      _pump(_alert(AlertDirection.travelerWantsPackages)),
    );
    expect(find.textContaining('≤'), findsNothing);
  });
}
