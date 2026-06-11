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
    '8 · IN_TRANSIT avec confirmationCode → "Colis en vol" + "code retrait"',
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
      expect(find.textContaining('code retrait'), findsOneWidget);
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
}
