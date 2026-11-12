import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({double? weightKg, double? totalWeightKg, ItemSize? itemSize}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      weightKg: weightKg,
      totalWeightKg: totalWeightKg,
      itemSize: itemSize,
    );

Future<void> _pump(WidgetTester tester, BidModel bid, {bool framed = true}) =>
    tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: ColisDestinataireCard(bid: bid, framed: framed),
        ),
      ),
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

  testWidgets('framed false renders same content without card frame', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      weightKg: 5,
      description: 'Vêtements',
      recipientName: 'Awa',
      recipientPhone: '+221770000000',
    );
    await _pump(tester, bid, framed: false);

    expect(find.byType(DetailCard), findsNothing);
    expect(find.text('Colis & destinataire'), findsNothing);
    expect(find.text('5 kg'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('+221770000000'), findsOneWidget);
  });

  testWidgets('framed true keeps the DetailCard and its title', (tester) async {
    await _pump(tester, _bid(weightKg: 5));

    expect(find.byType(DetailCard), findsOneWidget);
    expect(find.text('Colis & destinataire'), findsOneWidget);
  });

  testWidgets('taille du colis renseignée : « 25 kg · taille L »', (
    tester,
  ) async {
    await _pump(tester, _bid(weightKg: 25, itemSize: ItemSize.l));

    expect(find.text('25 kg · taille L'), findsOneWidget);
  });

  testWidgets('1 200 kg groupés, modifié : taille après les kilos en plus', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(weightKg: 1200, totalWeightKg: 1250, itemSize: ItemSize.xl),
    );

    expect(
      find.text('1\u202f250 kg (dont 50 kg en plus) · taille XL'),
      findsOneWidget,
    );
  });
}
