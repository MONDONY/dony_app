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
  double? declaredValueEur,
  String? contentCategory,
  double weightKg = 5,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: weightKg,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  trackingNumber: trackingNumber,
  confirmationCode: confirmationCode,
  declaredValueEur: declaredValueEur,
  contentCategory: contentCategory,
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
  // ── Sender dispatch ─────────────────────────────────────────────────────────

  testWidgets('sender + PENDING → placeholder, pas de bande de suivi', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });

  testWidgets(
    'sender + HANDED_OVER → bouton QR du colis',
    (tester) async {
      await _pump(tester, _bid(status: 'HANDED_OVER'), true);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
      expect(find.textContaining('QR du colis'), findsOneWidget);
    },
  );

  testWidgets(
    'sender + IN_TRANSIT sans confirmationCode → bouton QR + placeholder en transit',
    (tester) async {
      await _pump(tester, _bid(status: 'IN_TRANSIT'), true);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
      expect(find.text('Colis en route'), findsOneWidget);
    },
  );

  testWidgets('sender + COMPLETED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'), true);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('sender + DELIVERED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'DELIVERED'), true);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('sender + REJECTED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'), true);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets('sender + CANCELLED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'), true);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  // ── Traveler dispatch ───────────────────────────────────────────────────────

  testWidgets('voyageur + ACCEPTED → action de scan', (tester) async {
    await _pump(
      tester,
      _bid(status: 'ACCEPTED', trackingNumber: 'DON-1'),
      false,
    );
    expect(find.byType(TalonTravelerActionView), findsOneWidget);
    expect(find.text('Scanner le colis'), findsOneWidget);
  });

  testWidgets(
    'voyageur + PENDING → résumé de décision avec poids/valeur/type',
    (tester) async {
      await _pump(
        tester,
        _bid(
          status: 'PENDING',
          declaredValueEur: 150,
          contentCategory: 'Vêtements',
          weightKg: 3.5,
        ),
        false,
      );
      expect(find.text('POIDS'), findsOneWidget);
      expect(find.text('VALEUR'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('3.5 kg'), findsOneWidget);
      expect(find.text('150 €'), findsOneWidget);
      expect(find.text('Vêtements'), findsOneWidget);
    },
  );

  testWidgets('voyageur + PENDING sans valeur déclarée → "—" pour la valeur', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'PENDING'), false);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('voyageur + HANDED_OVER → action de confirmation de livraison', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'HANDED_OVER'), false);
    expect(find.byType(TalonTravelerActionView), findsOneWidget);
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('voyageur + IN_TRANSIT → action de confirmation de livraison', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'IN_TRANSIT'), false);
    expect(find.byType(TalonTravelerActionView), findsOneWidget);
    expect(find.text('Confirmer la livraison'), findsOneWidget);
  });

  testWidgets('voyageur + COMPLETED → bloc vert "Colis livré"', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'), false);
    expect(find.text('Colis livré'), findsOneWidget);
  });

  testWidgets('voyageur + REJECTED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'), false);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  testWidgets('voyageur + CANCELLED → message terminal', (tester) async {
    await _pump(tester, _bid(status: 'CANCELLED'), false);
    expect(find.textContaining('Cette demande est terminée'), findsOneWidget);
  });

  // ── Tracking strip ──────────────────────────────────────────────────────────

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

  testWidgets('sans trackingNumber → pas de bande de suivi', (tester) async {
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.text('N° DE SUIVI'), findsNothing);
  });
}
