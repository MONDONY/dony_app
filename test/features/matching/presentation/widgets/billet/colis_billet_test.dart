import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({
  String status = 'ACCEPTED',
  DateTime? departureDate,
  String? departureTime,
}) => BidModel(
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
  departureDate: departureDate,
  departureTime: departureTime,
);

Future<void> _pump(WidgetTester tester, BidModel bid, bool isSender) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
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

  // Régression staging : le rôle (isSender, déjà porté par ColisBillet)
  // atteint bien BilletStatusStamp de bout en bout — pas seulement testé en
  // isolation dans billet_status_stamp_test.dart.
  testWidgets(
    'voyageur + AWAITING_PAYMENT → tampon "Paiement en attente", jamais '
    '"À payer"',
    (tester) async {
      await _pump(tester, _bid(status: 'AWAITING_PAYMENT'), false);
      expect(find.text('Paiement en attente'), findsOneWidget);
      expect(find.text('À payer'), findsNothing);
    },
  );

  testWidgets('expéditeur + AWAITING_PAYMENT → tampon "À payer" (inchangé)', (
    tester,
  ) async {
    await _pump(tester, _bid(status: 'AWAITING_PAYMENT'), true);
    expect(find.text('À payer'), findsOneWidget);
  });

  group('date de départ — non-régression du motif (DateFormat.MMMd)', () {
    setUpAll(() async {
      await initializeDateFormatting('fr');
      await initializeDateFormatting('en');
    });

    testWidgets(
      'fr : le 5 mars (zéro de tête) rend "5 mars", comme l\'ancien motif fixe',
      (tester) async {
        await _pump(
          tester,
          _bid(departureDate: DateTime(2026, 3, 5), departureTime: '09:05:00'),
          false,
        );
        expect(find.textContaining('5 mars · 09:05'), findsOneWidget);
      },
    );

    testWidgets('en : le 5 mars rend "Mar 5" (squelette MMMd anglais)', (
      tester,
    ) async {
      useEnglish();
      await _pump(
        tester,
        _bid(departureDate: DateTime(2026, 3, 5), departureTime: '09:05:00'),
        false,
      );
      expect(find.textContaining('Mar 5 · 09:05'), findsOneWidget);
    });
  });

  group('traductions', () {
    testWidgets(
      'en anglais : en-tête, labels Departure/Arrival, statut Delivered',
      (tester) async {
        useEnglish();
        await _pump(tester, _bid(status: 'COMPLETED'), false);
        expect(find.text('YADONY · PARCEL TRANSPORT'), findsOneWidget);
        expect(find.text('Departure'), findsOneWidget);
        expect(find.text('Arrival'), findsOneWidget);
        expect(find.text('Delivered'), findsOneWidget);
        expect(find.text('TRACKING NUMBER'), findsOneWidget);
      },
    );
  });
}
