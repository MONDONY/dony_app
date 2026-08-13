import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BidModel _bid(String status) => BidModel.fromJson({
  'id': 'b1',
  'announcementId': 'a1',
  'senderId': 's1',
  'status': status,
  'weightKg': 4.5,
  'recipientName': 'Mariama D.',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'travelerName': 'Ibrahima Diallo',
  'departureDate': DateTime.now()
      .add(const Duration(days: 3))
      .toIso8601String(),
  // Required fields discovered in BidModel constructor:
  'createdAt': DateTime.now().toIso8601String(),
  'updatedAt': DateTime.now().toIso8601String(),
});

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  testWidgets('affiche la date du trajet (Départ dans 3 jours)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ShipmentCard(bid: _bid('ACCEPTED'), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // La date du départ, absente auparavant, doit désormais figurer sur la carte.
    expect(find.textContaining('Départ dans 3 jours'), findsOneWidget);
  });

  testWidgets('IN_TRANSIT : stepper étape 3, badge transit', (tester) async {
    await tester.pumpWidget(
      _wrap(ShipmentCard(bid: _bid('IN_TRANSIT'), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('EN TRANSIT'), findsOneWidget);
    expect(find.byType(ShipmentStepper), findsOneWidget);
    expect(find.textContaining('4,5 kg'), findsOneWidget);
    expect(find.textContaining('Mariama'), findsOneWidget);
    expect(find.textContaining('Ibrahima'), findsOneWidget);
  });

  testWidgets('PENDING : pas de stepper (pré-acceptation)', (tester) async {
    await tester.pumpWidget(
      _wrap(ShipmentCard(bid: _bid('PENDING'), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShipmentStepper), findsNothing);
    expect(find.textContaining('EN ATTENTE'), findsOneWidget);
  });

  test('shipmentStepFor mappe les statuts vers les étapes', () {
    expect(shipmentStepFor('ACCEPTED'), 1);
    expect(shipmentStepFor('HANDED_OVER'), 2);
    expect(shipmentStepFor('IN_TRANSIT'), 3);
    expect(shipmentStepFor('COMPLETED'), 4);
    expect(shipmentStepFor('PENDING'), isNull);
    expect(shipmentStepFor('AWAITING_PAYMENT'), isNull);
  });
}
