import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/gp_pro_badge.dart';
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
  bool senderGpPro = false,
  bool senderIsProAccount = false,
  int? senderIncidentCount,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: 'PENDING',
  senderName: senderName,
  senderTotalShipments: senderTotalShipments,
  senderKycVerified: senderKycVerified,
  senderGpPro: senderGpPro,
  senderIsProAccount: senderIsProAccount,
  senderIncidentCount: senderIncidentCount,
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

  testWidgets('sans senderGpPro : pas de badge GP Pro', (tester) async {
    await _pump(tester, _bid(senderName: 'Aïcha D.'));

    expect(find.byType(GpProBadge), findsNothing);
  });

  testWidgets('badges identité et GP Pro', (tester) async {
    await _pump(
      tester,
      _bid(senderName: 'Aïcha D.', senderKycVerified: true, senderGpPro: true),
    );

    expect(find.text('Identité'), findsOneWidget);
    expect(find.byType(GpProBadge), findsOneWidget);
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

  testWidgets(
    'fiabilité : annulations ou absences de l expediteur (FLUTTER-E0/E6)',
    (tester) async {
      await _pump(tester, _bid(senderName: 'Aïcha D.', senderIncidentCount: 2));
      expect(find.text('2 annulations ou absences'), findsOneWidget);
    },
  );

  testWidgets('fiabilité masquée à zéro et sur un back antérieur', (
    tester,
  ) async {
    await _pump(tester, _bid(senderName: 'Aïcha D.'));
    expect(find.byKey(const Key('sender-reliability-label')), findsNothing);
    await _pump(tester, _bid(senderName: 'Aïcha D.', senderIncidentCount: 0));
    expect(find.byKey(const Key('sender-reliability-label')), findsNothing);
  });

  testWidgets('coche de l\'avatar : niveau GP Pro et PRO transmis', (
    tester,
  ) async {
    DonyAvatar avatar() => tester.widget<DonyAvatar>(find.byType(DonyAvatar));

    await _pump(tester, _bid(senderName: 'Aïcha D.', senderKycVerified: true));
    expect(avatar().gpPro, isFalse);
    expect(avatar().pro, isFalse);

    await _pump(
      tester,
      _bid(senderName: 'Aïcha D.', senderKycVerified: true, senderGpPro: true),
    );
    expect(avatar().gpPro, isTrue);
    expect(avatar().pro, isFalse);

    await _pump(
      tester,
      _bid(
        senderName: 'Aïcha D.',
        senderKycVerified: true,
        senderGpPro: true,
        senderIsProAccount: true,
      ),
    );
    expect(avatar().pro, isTrue);
  });
}
