import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/payment_release_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  String? travelerName,
  double? pricePerKg,
  double weightKg = 5,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: weightKg,
  status: 'COMPLETED',
  createdAt: DateTime(2026, 5, 10),
  updatedAt: DateTime(2026, 5, 10),
  travelerName: travelerName,
  pricePerKg: pricePerKg,
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: PaymentReleaseCard(bid: bid)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('affiche "Fonds libérés à" avec le nom du voyageur', (
    tester,
  ) async {
    await _pump(tester, _bid(travelerName: 'Kofi Mensah'));
    expect(find.textContaining('Fonds libérés à Kofi Mensah'), findsOneWidget);
    expect(find.text('Reçu'), findsOneWidget);
  });

  testWidgets(
    'sans nom de voyageur → fallback "le voyageur" (plus de hardcode "Ibrahima")',
    (tester) async {
      await _pump(tester, _bid(travelerName: null));
      expect(
        find.textContaining('Fonds libérés à le voyageur'),
        findsOneWidget,
      );
      // Ensure the old hardcoded name is gone
      expect(find.textContaining('Ibrahima'), findsNothing);
    },
  );

  testWidgets('pricePerKg renseigné → le voyageur touche le net entier (pas de décote)', (
    tester,
  ) async {
    // Le voyageur reçoit l'intégralité du net : 10 €/kg × 5 kg = 50.00 €.
    // (La commission Dony est payée EN SUS par l'expéditeur, jamais déduite ici.)
    await _pump(tester, _bid(pricePerKg: 10, weightKg: 5));
    expect(find.textContaining('50.00'), findsOneWidget);
  });

  testWidgets('pricePerKg null → "—" affiché', (tester) async {
    await _pump(tester, _bid(pricePerKg: null));
    expect(find.textContaining('—'), findsOneWidget);
    // Should not show a numeric amount
    expect(find.textContaining('50'), findsNothing);
  });
}
