import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({String status = 'ACCEPTED'}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  trackingNumber: 'DON-3TSTR9VH',
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
);

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ColisBillet(bid: bid, isSender: isSender),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('le billet montre le tampon de statut et le talon', (
    tester,
  ) async {
    // isSender: false → talon voyageur (TalonTravelerActionView), sans bloc.
    // isSender: true + ACCEPTED rendrait QrCodeCard, qui exige un
    // TrackingBloc ambiant — hors périmètre d'un widget test isolé.
    await _pump(tester, _bid(), false);
    expect(find.byType(BilletStatusStamp), findsOneWidget);
    expect(find.byType(BilletTalon), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.textContaining('Paris'), findsWidgets);
  });

  testWidgets('sender + PENDING → placeholder hourglass visible', (
    tester,
  ) async {
    // isSender: true + PENDING renders _PendingPlaceholder — no BLoC needed.
    await _pump(tester, _bid(status: 'PENDING'), true);
    expect(find.byType(BilletStatusStamp), findsOneWidget);
    expect(find.byType(BilletTalon), findsOneWidget);
    expect(find.textContaining('En attente de confirmation'), findsOneWidget);
  });

  testWidgets('affiche le corridor départ → arrivée', (tester) async {
    await _pump(tester, _bid(), false);
    expect(find.textContaining('Paris'), findsWidgets);
    expect(find.textContaining('Abidjan'), findsWidgets);
    // Boarding-pass codes: CDG for Paris, ABJ for Abidjan
    expect(find.text('CDG'), findsOneWidget);
    expect(find.text('ABJ'), findsOneWidget);
  });

  testWidgets('REJECTED → tampon de statut avec label correct', (tester) async {
    await _pump(tester, _bid(status: 'REJECTED'), false);
    expect(find.byType(BilletStatusStamp), findsOneWidget);
    // Label shown by BilletStatusStamp for REJECTED
    expect(find.text('Refusé'), findsOneWidget);
  });

  testWidgets('COMPLETED → billet livré avec bande de suivi', (tester) async {
    await _pump(tester, _bid(status: 'COMPLETED'), false);
    expect(find.text('Livré'), findsOneWidget);
    expect(find.text('N° DE SUIVI'), findsOneWidget);
    expect(find.text('DON-3TSTR9VH'), findsOneWidget);
  });
}
