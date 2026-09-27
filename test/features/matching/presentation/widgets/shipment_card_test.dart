import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({String status = 'ARRIVED', DateTime? departureDate}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
  departureDate: departureDate,
);

void main() {
  test(
    'shipmentStepFor : HANDED_OVER et IN_TRANSIT partagent « En route »',
    () {
      expect(shipmentStepFor('ACCEPTED'), 1);
      expect(shipmentStepFor('HANDED_OVER'), 2);
      expect(shipmentStepFor('IN_TRANSIT'), 2);
      expect(shipmentStepFor('ARRIVED'), 3);
      expect(shipmentStepFor('COMPLETED'), 4);
      expect(shipmentStepFor('PENDING'), isNull);
    },
  );

  testWidgets('ShipmentStepper affiche 4 pastilles, sans étape transit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShipmentStepper(currentStep: 3))),
    );
    expect(find.text('Remis'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    expect(find.text('Arrivé'), findsOneWidget);
    expect(find.text('Livraison'), findsOneWidget);
    expect(find.text('Embarqué'), findsNothing);
    expect(find.text('En vol'), findsNothing);
  });

  Future<void> pumpCard(WidgetTester tester, BidModel bid) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ShipmentCard(bid: bid, onTap: () {}, index: 0),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('HANDED_OVER avant le départ : « Colis remis au voyageur »', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _bid(
        status: 'HANDED_OVER',
        departureDate: DateTime.now().add(const Duration(days: 3)),
      ),
    );
    expect(find.text('Colis remis au voyageur'), findsOneWidget);
  });

  testWidgets('HANDED_OVER après le départ, sans scan Transit : en route', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _bid(
        status: 'HANDED_OVER',
        departureDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );
    expect(find.text('En route vers Abidjan'), findsOneWidget);
    expect(find.text('Colis remis au voyageur'), findsNothing);
  });

  testWidgets('ShipmentCard affiche le badge ARRIVÉ pour un colis arrivé', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ShipmentCard(bid: _bid(), onTap: () {}, index: 0),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('ARRIVÉ'), findsOneWidget);
    expect(find.text('Arrivé, prêt à être récupéré'), findsOneWidget);
    expect(find.text('Suivre le colis →'), findsOneWidget);
  });
}
