import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({String status = 'ARRIVED'}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
);

void main() {
  test('shipmentStepFor maps ARRIVED to step 4 and COMPLETED to step 5', () {
    expect(shipmentStepFor('IN_TRANSIT'), 3);
    expect(shipmentStepFor('ARRIVED'), 4);
    expect(shipmentStepFor('COMPLETED'), 5);
  });

  testWidgets('ShipmentStepper renders 5 pastilles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShipmentStepper(currentStep: 4))),
    );
    expect(find.text('Arrivé'), findsOneWidget);
    expect(find.text('Remis'), findsOneWidget);
    expect(find.text('Embarqué'), findsOneWidget);
    expect(find.text('En vol'), findsOneWidget);
    expect(find.text('Livraison'), findsOneWidget);
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
