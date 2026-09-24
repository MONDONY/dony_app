import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/expediteur_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({
  String? senderName,
  int? senderTotalShipments,
  bool senderKycVerified = false,
  bool senderKiloPro = false,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: 'PENDING',
  senderName: senderName,
  senderTotalShipments: senderTotalShipments,
  senderKycVerified: senderKycVerified,
  senderKiloPro: senderKiloPro,
  createdAt: DateTime(2026, 10, 6),
  updatedAt: DateTime(2026, 10, 6),
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: ExpediteurCard(bid: bid)),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets('repli traduit quand l expediteur n a pas de nom', (
    tester,
  ) async {
    await _pump(tester, _bid());

    // Même clé que le repli (bidSenderFallbackName) : le titre de section et
    // le nom affiché sont identiques.
    expect(find.text('Expéditeur'), findsNWidgets(2));
  });

  testWidgets('nombre d envois composé via senderShipmentsCount', (
    tester,
  ) async {
    await _pump(tester, _bid(senderName: 'Aïcha D.', senderTotalShipments: 4));

    expect(find.text('4 envois'), findsOneWidget);
  });

  testWidgets('badges identité et Kilo Pro réutilisent les clés listing', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(
        senderName: 'Aïcha D.',
        senderKycVerified: true,
        senderKiloPro: true,
      ),
    );

    expect(find.text('Identité'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
  });

  testWidgets('date de soumission formatée dd/mm/yyyy en français', (
    tester,
  ) async {
    await _pump(tester, _bid(senderName: 'Aïcha D.'));

    expect(find.text('Soumis le 06/10/2026'), findsOneWidget);
  });

  testWidgets('en anglais : repli et date localisés', (tester) async {
    useEnglish();
    await _pump(tester, _bid());

    expect(find.text('Sender'), findsNWidgets(2));
    expect(find.text('Submitted on 10/6/2026'), findsOneWidget);
  });
}
