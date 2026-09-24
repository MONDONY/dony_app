import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../helpers/l10n_test_helpers.dart';

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
    expect(shipmentStepFor('ARRIVED'), 4);
    expect(shipmentStepFor('COMPLETED'), 5);
    expect(shipmentStepFor('PENDING'), isNull);
    expect(shipmentStepFor('AWAITING_PAYMENT'), isNull);
  });

  testWidgets('ARRIVED : stepper étape 4, badge arrivé', (tester) async {
    await tester.pumpWidget(
      _wrap(ShipmentCard(bid: _bid('ARRIVED'), onTap: () {}, index: 0)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('ARRIVÉ'), findsOneWidget);
    expect(find.byType(ShipmentStepper), findsOneWidget);
    expect(find.textContaining('Arrivé, prêt à être récupéré'), findsOneWidget);
  });

  group('date de départ lointaine — non-régression du motif (yMMMEd)', () {
    BidModel bidWithDate(DateTime date) => BidModel.fromJson({
      'id': 'b-far',
      'announcementId': 'a1',
      'senderId': 's1',
      'status': 'ACCEPTED',
      'weightKg': 4.5,
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'departureDate': date.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    testWidgets('fr : plus de 6 jours → même rendu que DateFormat.yMMMEd(fr)', (
      tester,
    ) async {
      final farDate = DateTime.now().add(const Duration(days: 20));
      await tester.pumpWidget(
        _wrap(ShipmentCard(bid: bidWithDate(farDate), onTap: () {}, index: 0)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text(DateFormat.yMMMEd('fr').format(farDate)),
        findsOneWidget,
      );
    });

    testWidgets('en : plus de 6 jours → même rendu que DateFormat.yMMMEd(en)', (
      tester,
    ) async {
      useEnglish();
      final farDate = DateTime.now().add(const Duration(days: 20));
      await tester.pumpWidget(
        _wrap(ShipmentCard(bid: bidWithDate(farDate), onTap: () {}, index: 0)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text(DateFormat.yMMMEd('en').format(farDate)),
        findsOneWidget,
      );
    });
  });

  group('traductions', () {
    testWidgets('en anglais : badge, ligne poids/destinataire, CTA, stepper', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(ShipmentCard(bid: _bid('IN_TRANSIT'), onTap: () {}, index: 0)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('IN TRANSIT'), findsOneWidget);
      expect(find.text('Track the parcel →'), findsOneWidget);
      expect(find.textContaining('Parcel 4,5 kg'), findsOneWidget);
      expect(find.textContaining('for Mariama'), findsOneWidget);
      expect(find.text('Handed over'), findsOneWidget);
      expect(find.text('Boarded'), findsOneWidget);
      expect(find.text('In flight'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('en anglais : ACCEPTED → "TO HAND OVER" et "View the QR →"', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(ShipmentCard(bid: _bid('ACCEPTED'), onTap: () {}, index: 0)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('TO HAND OVER'), findsOneWidget);
      expect(find.text('View the QR →'), findsOneWidget);
    });
  });
}
