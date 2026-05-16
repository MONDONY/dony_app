import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  String? trackingNumber,
  String? confirmationCode,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  trackingNumber: trackingNumber,
  confirmationCode: confirmationCode,
);

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BilletTalon(bid: bid, isSender: isSender),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('voyageur + ACCEPTED → action de scan', (tester) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      false,
    );
    expect(find.byType(TalonTravelerActionView), findsOneWidget);
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets('sender + PENDING → placeholder, pas de bande de suivi', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });

  testWidgets('trackingNumber présent → bande de suivi affichée', (
    tester,
  ) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      false,
    );
    expect(find.text('N° DE SUIVI'), findsOneWidget);
    expect(find.text('DON-1'), findsOneWidget);
  });

  testWidgets(
    'sender + HANDED_OVER sans confirmationCode → placeholder en transit',
    (tester) async {
      await _pump(tester, _bid(status: 'HANDED_OVER'), true);
      expect(find.text('Colis en route'), findsOneWidget);
    },
  );
}
