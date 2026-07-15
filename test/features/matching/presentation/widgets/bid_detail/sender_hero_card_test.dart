import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'PENDING',
  String? cancellationNoShowStatus,
  DateTime? contestationDeadline,
  DateTime? handoverWindowStart,
  DateTime? handoverWindowEnd,
  String? handoverLocation,
  String? travelerName,
  String? recipientName,
  String? arrivalCity,
  String? arrivalTime,
  String? confirmationCode,
  double? totalAmountEur,
  DateTime? departureDate,
  String? deliveryNoShowStatus,
  bool? deliveryNoShowReportedByTraveler,
}) =>
    BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      cancellationNoShowStatus: cancellationNoShowStatus,
      contestationDeadline: contestationDeadline,
      handoverWindowStart: handoverWindowStart,
      handoverWindowEnd: handoverWindowEnd,
      handoverLocation: handoverLocation,
      travelerName: travelerName,
      recipientName: recipientName,
      arrivalCity: arrivalCity,
      arrivalTime: arrivalTime,
      confirmationCode: confirmationCode,
      totalAmountEur: totalAmountEur,
      departureDate: departureDate,
      deliveryNoShowStatus: deliveryNoShowStatus,
      deliveryNoShowReportedByTraveler: deliveryNoShowReportedByTraveler,
    );

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(BidModel bid, _MockCancellationBloc cancellationBloc) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: BlocProvider<CancellationBloc>.value(
        value: cancellationBloc,
        child: SenderHeroCard(bid: bid),
      ),
    ),
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(TravelerNoShowReportRequested('bid-001'));
    registerFallbackValue(NoShowContestRequested('bid-001'));
    registerFallbackValue(DeliveryNoShowContestRequested('bid-001'));
  });

  late _MockCancellationBloc cancellationBloc;

  setUp(() {
    cancellationBloc = _MockCancellationBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
  });

  // ── Test 1: PENDING ──────────────────────────────────────────────────────────

  testWidgets('1 · PENDING → "En attente du voyageur" + "notifié"', (
    tester,
  ) async {
    final bid = _bid(status: 'PENDING');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente du voyageur'), findsOneWidget);
    expect(find.textContaining('notifié'), findsOneWidget);
  });

  // ── Test 2: PAYMENT_ESCROWED ─────────────────────────────────────────────────

  testWidgets('2 · PAYMENT_ESCROWED → "Paiement sécurisé"', (tester) async {
    final bid = _bid(status: 'PAYMENT_ESCROWED', totalAmountEur: 45.0);
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Paiement sécurisé'), findsOneWidget);
  });

  // ── Test 3: ACCEPTED fenêtre future ─────────────────────────────────────────

  testWidgets(
    '3 · ACCEPTED fenêtre future → "Remise du colis" + location',
    (tester) async {
      final now = DateTime.now();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverWindowStart: now.add(const Duration(days: 1)),
        handoverWindowEnd: now.add(const Duration(days: 1, hours: 2)),
        handoverLocation: 'Gare de Lyon, Paris',
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Remise du colis'), findsOneWidget);
      expect(find.textContaining('Gare de Lyon'), findsOneWidget);
    },
  );

  // ── Test 4: ACCEPTED fenêtre passée ─────────────────────────────────────────

  testWidgets(
    '4 · ACCEPTED fenêtre passée → "Fenêtre de remise dépassée" + bouton signalement',
    (tester) async {
      final now = DateTime.now();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverWindowStart: now.subtract(const Duration(hours: 4)),
        handoverWindowEnd: now.subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Fenêtre de remise dépassée'), findsOneWidget);
      expect(
        find.textContaining("Signaler l'absence du voyageur"),
        findsOneWidget,
      );
    },
  );

  // ── Test 5: tap "Signaler" → sheet → confirmation → event dispatched ─────────

  testWidgets(
    '5 · tap "Signaler l\'absence du voyageur" → sheet → bouton → TravelerNoShowReportRequested dispatched',
    (tester) async {
      final now = DateTime.now();
      final bid = _bid(
        status: 'ACCEPTED',
        handoverWindowStart: now.subtract(const Duration(hours: 4)),
        handoverWindowEnd: now.subtract(const Duration(hours: 2)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      // Tap the "Signaler l'absence du voyageur" button in the hero
      await tester.tap(find.textContaining("Signaler l'absence du voyageur"));
      await tester.pumpAndSettle();

      // The confirmation sheet should be visible
      expect(find.textContaining("Signaler l'absence"), findsWidgets);

      // Tap the confirmation button in stickyBottom (the DonyButton in the sheet)
      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining("Signaler l'absence"),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      // Verify the event was dispatched exactly once
      verify(
        () => cancellationBloc.add(
          any(that: isA<TravelerNoShowReportRequested>()),
        ),
      ).called(1);
    },
  );

  // ── Test 6: PENDING_CONFIRMATION → contestation hero ────────────────────────

  testWidgets(
    '6 · cancellationNoShowStatus PENDING_CONFIRMATION → "Absence signalée" + "Je conteste" + "Je confirme"',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(
          const Duration(hours: 46, minutes: 12),
        ),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(find.textContaining('Je conteste'), findsOneWidget);
      expect(find.textContaining('Je confirme'), findsOneWidget);

      // Kill the timer by replacing the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 7: HANDED_OVER ──────────────────────────────────────────────────────

  testWidgets('7 · HANDED_OVER → "Colis remis"', (tester) async {
    final bid = _bid(
      status: 'HANDED_OVER',
      travelerName: 'Mamadou',
      departureDate: DateTime.now().add(const Duration(days: 2)),
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Colis remis'), findsOneWidget);
  });

  // ── Test 8: IN_TRANSIT with confirmationCode ─────────────────────────────────

  testWidgets(
    '8 · IN_TRANSIT avec confirmationCode → "Colis en vol" + renvoi au billet',
    (tester) async {
      final bid = _bid(
        status: 'IN_TRANSIT',
        confirmationCode: '4829',
        arrivalTime: '14:30',
        arrivalCity: 'Dakar',
        recipientName: 'Fatou',
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Colis en vol'), findsOneWidget);
      // La hero renvoie au talon (« CODE DE RETRAIT ») sans dire « à qui » —
      // l'instruction de transmission fait autorité sur le talon.
      expect(find.textContaining('code de retrait'), findsOneWidget);
      expect(find.textContaining('billet'), findsOneWidget);
    },
  );

  // ── Test 9: COMPLETED with recipientName ────────────────────────────────────

  testWidgets(
    '9 · COMPLETED (recipientName "Drissa") → "Livré à Drissa" + "libéré"',
    (tester) async {
      final bid = _bid(status: 'COMPLETED', recipientName: 'Drissa');
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Livré à Drissa'), findsOneWidget);
      expect(find.textContaining('libéré'), findsOneWidget);
    },
  );

  // ── Test 10: CANCELLED → SizedBox.shrink (no hero text) ─────────────────────

  testWidgets('10 · CANCELLED → aucun texte de hero (widget shrink)', (
    tester,
  ) async {
    final bid = _bid(status: 'CANCELLED');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    // None of the hero titles should appear
    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
    expect(find.textContaining('Absence signalée'), findsNothing);
    expect(find.textContaining('Fenêtre de remise'), findsNothing);
  });

  // ── Test 11: AWAITING_PAYMENT ────────────────────────────────────────────────

  testWidgets('11 · AWAITING_PAYMENT → "Payez pour confirmer" + amount', (
    tester,
  ) async {
    final bid = _bid(status: 'AWAITING_PAYMENT', totalAmountEur: 120.50);
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining("Payez pour confirmer"), findsOneWidget);
    expect(find.textContaining("120.50"), findsOneWidget);
  });

  // ── Test 12: IN_TRANSIT sans confirmationCode ─────────────────────────────────

  testWidgets('12 · IN_TRANSIT sans confirmationCode → "En route vers"', (
    tester,
  ) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      arrivalCity: 'Dakar',
      arrivalTime: '',
      confirmationCode: null,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Colis en vol'), findsOneWidget);
    expect(find.textContaining('En route vers Dakar'), findsOneWidget);
  });

  // ── Test 13: HANDED_OVER departureDate null → "Colis remis." ──────────────────

  testWidgets('13 · HANDED_OVER departureDate=null → "Colis remis."', (
    tester,
  ) async {
    final bid = _bid(
      status: 'HANDED_OVER',
      travelerName: 'Amadou',
      departureDate: null,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Colis remis.'), findsOneWidget);
  });

  // ── Test 14: DELIVERED → "Livré à" ───────────────────────────────────────────

  testWidgets('14 · DELIVERED → "Livré à"', (tester) async {
    final bid = _bid(status: 'DELIVERED', recipientName: 'Karim');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Livré à Karim'), findsOneWidget);
  });

  // ── Test 15a: REJECTED → shrink (no hero text) ───────────────────────────────

  testWidgets('15a · REJECTED → shrink (no hero text)', (tester) async {
    final bid = _bid(status: 'REJECTED');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
  });

  // ── Test 15b: NO_SHOW → shrink (no hero text) ────────────────────────────────

  testWidgets('15b · NO_SHOW → shrink (no hero text)', (tester) async {
    final bid = _bid(status: 'NO_SHOW');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
  });

  // ── Test 15c: EXPIRED → shrink (no hero text) ────────────────────────────────

  testWidgets('15c · EXPIRED → shrink (no hero text)', (tester) async {
    final bid = _bid(status: 'EXPIRED');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
  });

  // ── Test 15d: PARCEL_REFUSED → shrink (no hero text) ─────────────────────────

  testWidgets('15d · PARCEL_REFUSED → shrink (no hero text)', (tester) async {
    final bid = _bid(status: 'PARCEL_REFUSED');
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('En attente'), findsNothing);
    expect(find.textContaining('Paiement'), findsNothing);
    expect(find.textContaining('Remise'), findsNothing);
    expect(find.textContaining('Colis'), findsNothing);
    expect(find.textContaining('Livré'), findsNothing);
  });

  // ── Test 16: PENDING_CONFIRMATION deadline null → pas de countdown ────────────

  testWidgets(
    '16 · PENDING_CONFIRMATION deadline=null → "Absence signalée" sans "Temps pour contester"',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: null,
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Absence signalée'), findsOneWidget);
      expect(find.textContaining('Temps pour contester'), findsNothing);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 17: PENDING_CONFIRMATION deadline passée → "Délai expiré" ───────────

  testWidgets(
    '17 · PENDING_CONFIRMATION deadline passée → "Délai expiré" affiché',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      expect(find.textContaining('Délai expiré'), findsOneWidget);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 17b: bannière absence livraison — je suis l'auteur (sender) ───────

  testWidgets(
      'bannière "Absence signalée" si deliveryNoShowReportedByTraveler=false (je suis l\'auteur, expéditeur)',
      (tester) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      deliveryNoShowStatus: 'PENDING_CONFIRMATION',
      deliveryNoShowReportedByTraveler: false,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Absence signalée'), findsOneWidget);
  });

  // ── Test 17c: bannière absence livraison — je suis l'adversaire (sender) ───

  testWidgets(
      'bannière "Une absence est signalée" + Contester si deliveryNoShowReportedByTraveler=true (je suis l\'adversaire, expéditeur)',
      (tester) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      deliveryNoShowStatus: 'PENDING_CONFIRMATION',
      deliveryNoShowReportedByTraveler: true,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Une absence est signalée'), findsOneWidget);
    expect(find.text('Contester ce signalement'), findsOneWidget);
  });

  // ── Test 17d: bannière absence livraison contestée (sender, auteur) ────────

  testWidgets(
      'bannière deliveryNoShowStatus=CONTESTED (auteur, expéditeur) → "Absence contestée"',
      (tester) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      deliveryNoShowStatus: 'CONTESTED',
      deliveryNoShowReportedByTraveler: false,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    expect(find.textContaining('Absence contestée'), findsOneWidget);
  });

  // ── Test 17e: tap "Contester ce signalement" (sender) → dispatch ───────────

  testWidgets(
      'tap "Contester ce signalement" (expéditeur) → DeliveryNoShowContestRequested émis',
      (tester) async {
    final bid = _bid(
      status: 'IN_TRANSIT',
      deliveryNoShowStatus: 'PENDING_CONFIRMATION',
      deliveryNoShowReportedByTraveler: true,
    );
    await tester.pumpWidget(_host(bid, cancellationBloc));
    await tester.pump();

    await tester.tap(find.text('Contester ce signalement'));
    await tester.pump();

    verify(
      () => cancellationBloc.add(
        any(that: isA<DeliveryNoShowContestRequested>()),
      ),
    ).called(1);
  });

  // ── Test 18: tap "Je conteste" → sheet → annuler (no dispatch) ───────────────

  testWidgets(
    '18 · tap "Je conteste" → sheet s\'ouvre → appuyer barrière → aucun dispatch',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je conteste'));
      await tester.pumpAndSettle();

      // Sheet is open — close by tapping outside
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      // NoShowContestRequested must NOT have been dispatched
      verifyNever(
        () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
      );

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 19: tap "Je conteste" → confirmer → NoShowContestRequested ──────────

  testWidgets(
    '19 · tap "Je conteste" → "Confirmer la contestation" → NoShowContestRequested dispatched',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je conteste'));
      await tester.pumpAndSettle();

      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining('Confirmer la contestation'),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      verify(
        () => cancellationBloc.add(any(that: isA<NoShowContestRequested>())),
      ).called(1);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );

  // ── Test 20: tap "Je confirme" → confirmer → NoShowConfirmRequested ──────────

  testWidgets(
    '20 · tap "Je confirme" → "Confirmer mon absence" → NoShowConfirmRequested dispatched',
    (tester) async {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 47)),
      );
      await tester.pumpWidget(_host(bid, cancellationBloc));
      await tester.pump();

      await tester.tap(find.textContaining('Je confirme'));
      await tester.pumpAndSettle();

      final confirmBtn = find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.textContaining('Confirmer mon absence'),
      );
      await tester.tap(confirmBtn.last);
      await tester.pumpAndSettle();

      verify(
        () => cancellationBloc.add(any(that: isA<NoShowConfirmRequested>())),
      ).called(1);

      // Kill timer
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    },
  );
}
