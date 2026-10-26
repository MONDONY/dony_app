import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({double? weightKg, double? totalWeightKg}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  weightKg: weightKg,
  totalWeightKg: totalWeightKg,
);

Future<void> _pump(WidgetTester tester, BidModel bid) => tester.pumpWidget(
  localizedApp(Scaffold(body: ColisDestinataireCard(bid: bid))),
);

void main() {
  testWidgets('colis sans modification : poids du colis avec son unité', (
    tester,
  ) async {
    await _pump(tester, _bid(weightKg: 5));

    expect(find.text('5 kg'), findsOneWidget);
  });

  testWidgets('colis modifié : le poids final et les kilos en plus', (
    tester,
  ) async {
    await _pump(tester, _bid(weightKg: 15, totalWeightKg: 17));

    expect(find.text('17 kg (dont 2 kg en plus)'), findsOneWidget);
    expect(find.textContaining('15 kg'), findsNothing);
  });
}
