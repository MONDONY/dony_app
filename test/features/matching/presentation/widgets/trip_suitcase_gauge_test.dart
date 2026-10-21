import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/trip_suitcase_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripCapacity _capacity({required double total, required double available}) =>
    TripCapacity.fromAnnouncement(
      AnnouncementModel(
        id: 'a1',
        travelerId: 't1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 6, 15),
        availableKg: available,
        totalKg: total,
        capacityUnit: 'SUITCASE_23KG',
        pricePerKg: 12,
        status: 'ACTIVE',
        createdAt: DateTime(2026, 5),
        updatedAt: DateTime(2026, 5),
      ),
    )!;

void main() {
  Future<void> pump(WidgetTester tester, TripCapacity capacity) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripSuitcaseGauge(capacity: capacity)),
        ),
      );

  testWidgets('une ligne par valise avec ses kilos restants', (tester) async {
    await pump(tester, _capacity(total: 46, available: 32));
    await tester.pumpAndSettle();

    expect(find.text('V1'), findsOneWidget);
    expect(find.text('V2'), findsOneWidget);
    expect(find.text('9 / 23 kg'), findsOneWidget);
    expect(find.text('23 / 23 kg'), findsOneWidget);
    expect(find.text('Restant'), findsOneWidget);
    expect(find.text('Réservé'), findsOneWidget);
  });

  testWidgets('une valise sans kilo libre est « pleine »', (tester) async {
    await pump(tester, _capacity(total: 46, available: 16));
    await tester.pumpAndSettle();

    expect(find.text('pleine'), findsOneWidget);
    expect(find.text('16 / 23 kg'), findsOneWidget);
  });
}
