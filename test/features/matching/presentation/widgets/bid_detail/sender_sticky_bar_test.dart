import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

// ── Fixture helper ────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'PENDING',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  bool senderHasRated = false,
  String? cancellationNoShowStatus,
}) {
  return BidModel(
    id: 'bid-test-1',
    announcementId: 'ann-1',
    senderId: 'sender-1',
    status: status,
    paymentMethod: paymentMethod,
    senderHasRated: senderHasRated,
    cancellationNoShowStatus: cancellationNoShowStatus,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(
  _MockBidBloc bloc,
  BidModel bid, {
  bool paymentLoaded = false,
  PaymentModel? existingPayment,
  _MockRatingBloc? ratingBloc,
}) {
  Widget child = Scaffold(
    bottomNavigationBar: SenderStickyBar(
      bid: bid,
      isLoading: false,
      paymentLoaded: paymentLoaded,
      existingPayment: existingPayment,
    ),
  );

  // Wrap with RatingBloc provider when needed (e.g. for RatingBottomSheet.show).
  if (ratingBloc != null) {
    child = BlocProvider<RatingBloc>.value(value: ratingBloc, child: child);
  }

  return MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<BidBloc>.value(
      value: bloc,
      child: child,
    ),
  );
}

// ── Payment fixture ───────────────────────────────────────────────────────────

PaymentModel _payment({
  PaymentStatus status = PaymentStatus.escrow,
  double amount = 182.0,
}) {
  return PaymentModel(
    id: 'pay-test-1',
    bidId: 'bid-test-1',
    amount: amount,
    commissionAmount: 21.84,
    status: status,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(BidDeleteRequested('bid-test-1'));
  });

  // Test 1: PENDING stripe non payé → 'Payer mon envoi'
  testWidgets(
    '1. PENDING stripe paymentLoaded=true existingPayment=null → "Payer mon envoi"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'PENDING', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsOneWidget);
    },
  );

  // Test 2: PENDING cash → pas de 'Payer mon envoi'
  testWidgets(
    '2. PENDING cash → pas de "Payer mon envoi"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'PENDING', paymentMethod: BidPaymentMethod.cash),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsNothing);
    },
  );

  // Test 3: ACCEPTED cash → 'Afficher le QR de remise'
  testWidgets(
    '3. ACCEPTED cash → "Afficher le QR de remise"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'ACCEPTED', paymentMethod: BidPaymentMethod.cash),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Afficher le QR de remise'), findsOneWidget);
    },
  );

  // Test 4: IN_TRANSIT → 'Suivi du colis'
  testWidgets(
    '4. IN_TRANSIT → "Suivi du colis"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'IN_TRANSIT'),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suivi du colis'), findsOneWidget);
    },
  );

  // Test 5: COMPLETED non noté → 'Noter le voyageur'
  testWidgets(
    '5. COMPLETED senderHasRated=false → "Noter le voyageur"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'COMPLETED', senderHasRated: false),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noter le voyageur'), findsOneWidget);
    },
  );

  // Test 6: COMPLETED noté → aucun DonyButton
  testWidgets(
    '6. COMPLETED senderHasRated=true → aucun bouton visible',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'COMPLETED', senderHasRated: true),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      // No action button text should be present
      expect(find.text('Payer mon envoi'), findsNothing);
      expect(find.text('Afficher le QR de remise'), findsNothing);
      expect(find.text('Suivi du colis'), findsNothing);
      expect(find.text('Noter le voyageur'), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  // Test 8: PENDING stripe paymentLoaded=false → placeholder loading, aucun DonyButton
  testWidgets(
    '8. PENDING stripe paymentLoaded=false → CircularProgressIndicator, aucun DonyButton',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'PENDING', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: false,
        ),
      );
      // Use pump() instead of pumpAndSettle() — CircularProgressIndicator
      // animates indefinitely and would cause pumpAndSettle to time out.
      await tester.pump();

      // Placeholder must be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // No action button should be rendered
      expect(find.text('Payer mon envoi'), findsNothing);
      expect(find.text('Afficher le QR de remise'), findsNothing);
      expect(find.text('Suivi du colis'), findsNothing);
      expect(find.text('Noter le voyageur'), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  // Test 7: CANCELLED → 'Supprimer cette demande', tap → dialog → 'Supprimer' → BidDeleteRequested
  testWidgets(
    '7. CANCELLED → "Supprimer cette demande", tap → dialog → "Supprimer" → BidDeleteRequested dispatched once',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'CANCELLED'),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette demande'), findsOneWidget);

      // Tap the delete button
      await tester.tap(find.text('Supprimer cette demande'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap 'Supprimer' in the dialog
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      // Verify BidDeleteRequested was dispatched exactly once
      verify(() => bloc.add(any(that: isA<BidDeleteRequested>()))).called(1);
    },
  );

  // Test 9: ACCEPTED + stripe + payé → EscrowBadge présent ET bouton QR présent (composition Column)
  testWidgets(
    '9. ACCEPTED stripe paymentLoaded=true existingPayment≠null → EscrowBadge + "Afficher le QR de remise"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'ACCEPTED', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
          existingPayment: _payment(status: PaymentStatus.escrow, amount: 182.0),
        ),
      );
      await tester.pumpAndSettle();

      // EscrowBadge must be present
      expect(find.byType(EscrowBadge), findsOneWidget);
      // QR button must be present (ACCEPTED + paid → Column layout)
      expect(find.text('Afficher le QR de remise'), findsOneWidget);
    },
  );

  // Test 10: PENDING + stripe + payé → EscrowBadge présent, AUCUN DonyButton (badge seul)
  testWidgets(
    '10. PENDING stripe paymentLoaded=true existingPayment≠null → EscrowBadge présent, aucun DonyButton',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'PENDING', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
          existingPayment: _payment(status: PaymentStatus.escrow, amount: 182.0),
        ),
      );
      await tester.pumpAndSettle();

      // EscrowBadge must be present
      expect(find.byType(EscrowBadge), findsOneWidget);

      // No action button should be rendered (badge alone, no _buildAction output for PENDING+paid)
      expect(find.text('Payer mon envoi'), findsNothing);
      expect(find.text('Afficher le QR de remise'), findsNothing);
      expect(find.text('Suivi du colis'), findsNothing);
      expect(find.text('Noter le voyageur'), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  // ── Tests hasAction() static method ──────────────────────────────────────────

  group('hasAction() static', () {
    test(
      'PENDING_CONFIRMATION → false (hero handles it)',
      () {
        final bid = _bid(
          status: 'ACCEPTED',
          cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        );
        expect(SenderStickyBar.hasAction(bid), isFalse);
      },
    );

    test('PENDING stripe → true', () {
      final bid = _bid(
        status: 'PENDING',
        paymentMethod: BidPaymentMethod.stripe,
      );
      expect(SenderStickyBar.hasAction(bid), isTrue);
    });

    test('PENDING cash → false', () {
      final bid = _bid(
        status: 'PENDING',
        paymentMethod: BidPaymentMethod.cash,
      );
      expect(SenderStickyBar.hasAction(bid), isFalse);
    });

    test('ACCEPTED → true', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'ACCEPTED')), isTrue);
    });

    test('HANDED_OVER → true', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'HANDED_OVER')), isTrue);
    });

    test('IN_TRANSIT → true', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'IN_TRANSIT')), isTrue);
    });

    test('COMPLETED senderHasRated=false → true', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(status: 'COMPLETED', senderHasRated: false),
        ),
        isTrue,
      );
    });

    test('COMPLETED senderHasRated=true → false', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(status: 'COMPLETED', senderHasRated: true),
        ),
        isFalse,
      );
    });

    test('DELIVERED senderHasRated=false → true', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(status: 'DELIVERED', senderHasRated: false),
        ),
        isTrue,
      );
    });

    test('REJECTED → true (kEnvoisPasses)', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'REJECTED')), isTrue);
    });

    test('NO_SHOW → true (kEnvoisPasses)', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'NO_SHOW')), isTrue);
    });

    test('EXPIRED → true (kEnvoisPasses)', () {
      expect(SenderStickyBar.hasAction(_bid(status: 'EXPIRED')), isTrue);
    });

    test('PAYMENT_ESCROWED → false (not in any branch)', () {
      expect(
        SenderStickyBar.hasAction(_bid(status: 'PAYMENT_ESCROWED')),
        isFalse,
      );
    });

    test('AWAITING_PAYMENT stripe → true', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.stripe),
        ),
        isTrue,
      );
    });

    test('AWAITING_PAYMENT cash → false', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.cash),
        ),
        isFalse,
      );
    });
  });

  // ── PENDING_CONFIRMATION → SizedBox.shrink (no action) ───────────────────────

  testWidgets(
    '11. PENDING_CONFIRMATION → SizedBox.shrink (bar invisible)',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(
            status: 'ACCEPTED',
            cancellationNoShowStatus: 'PENDING_CONFIRMATION',
          ),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      // Bar must render nothing (SizedBox.shrink)
      expect(find.text('Payer mon envoi'), findsNothing);
      expect(find.text('Afficher le QR de remise'), findsNothing);
      expect(find.text('Suivi du colis'), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  // ── HANDED_OVER → "Suivi du colis" ────────────────────────────────────────────

  testWidgets(
    '12. HANDED_OVER → "Suivi du colis"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'HANDED_OVER'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suivi du colis'), findsOneWidget);
    },
  );

  // ── DELIVERED non noté → 'Noter le voyageur' ──────────────────────────────────

  testWidgets(
    '13. DELIVERED senderHasRated=false → "Noter le voyageur"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'DELIVERED', senderHasRated: false),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Noter le voyageur'), findsOneWidget);
    },
  );

  // ── delete dialog → 'Annuler' → no event dispatched ──────────────────────────

  testWidgets(
    '14. CANCELLED → dialog "Supprimer cette demande ?" → "Annuler" → aucun BidDeleteRequested',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'CANCELLED'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer cette demande'));
      await tester.pumpAndSettle();

      // Dialog visible
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap 'Annuler'
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // BidDeleteRequested must NOT have been dispatched
      verifyNever(() => bloc.add(any(that: isA<BidDeleteRequested>())));
    },
  );

  // ── REJECTED → "Supprimer cette demande" ─────────────────────────────────────

  testWidgets(
    '15. REJECTED → "Supprimer cette demande"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'REJECTED'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette demande'), findsOneWidget);
    },
  );

  // ── NO_SHOW → "Supprimer cette demande" ──────────────────────────────────────

  testWidgets(
    '16. NO_SHOW → "Supprimer cette demande"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(),
          initialState: BidInitial());

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'NO_SHOW'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cette demande'), findsOneWidget);
    },
  );

  // Test 20: AWAITING_PAYMENT stripe → "Payer mon envoi" (reprise paiement)
  testWidgets(
    '20. AWAITING_PAYMENT stripe → "Payer mon envoi"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsOneWidget);
      expect(find.text('Annuler la demande'), findsOneWidget);
    },
  );

  // Test 21: AWAITING_PAYMENT stripe + paiement PENDING obsolète → bouton présent
  // (ne gate pas sur existingPayment ; pas de badge car badge = PENDING/ACCEPTED)
  testWidgets(
    '21. AWAITING_PAYMENT stripe existingPayment(PENDING) → "Payer mon envoi", pas de badge',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
          existingPayment: _payment(status: PaymentStatus.pending, amount: 182.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsOneWidget);
      expect(find.byType(EscrowBadge), findsNothing);
    },
  );

  // Test 22: AWAITING_PAYMENT cash → pas de "Payer mon envoi" (barre vide)
  testWidgets(
    '22. AWAITING_PAYMENT cash → pas de "Payer mon envoi"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.cash),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsNothing);
    },
  );

  // Test 23: AWAITING_PAYMENT stripe → tap "Annuler la demande" → dialog →
  // "Oui, annuler" → BidDeleteRequested dispatché une fois
  testWidgets(
    '23. AWAITING_PAYMENT → "Annuler la demande" → dialog → "Oui, annuler" → BidDeleteRequested',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(bloc, const Stream.empty(), initialState: BidInitial());

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.stripe),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler la demande de transport ?'), findsOneWidget);

      await tester.tap(find.text('Oui, annuler'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<BidDeleteRequested>()))).called(1);
    },
  );

  // ── Tap tests that open bottom sheets (requires GetIt mocks) ─────────────────
  //
  // These tests tap buttons whose onPressed closures open bottom sheets that
  // resolve blocs via GetIt. We register mock instances before each test and
  // unregister them after to keep the suite isolated.

  group('onPressed tap coverage (opens bottom sheets)', () {
    late _MockTrackingBloc mockTrackingBloc;
    late _MockRatingBloc mockRatingBloc;

    setUp(() {
      mockTrackingBloc = _MockTrackingBloc();
      mockRatingBloc = _MockRatingBloc();
      whenListen<TrackingState>(mockTrackingBloc, const Stream.empty(),
          initialState: TrackingInitial());
      whenListen<RatingState>(mockRatingBloc, const Stream.empty(),
          initialState: const RatingInitial());

      // Register mocks in GetIt so the sheets can resolve them.
      if (!getIt.isRegistered<TrackingBloc>()) {
        getIt.registerFactory<TrackingBloc>(() => mockTrackingBloc);
      }
      if (!getIt.isRegistered<RatingBloc>()) {
        getIt.registerFactory<RatingBloc>(() => mockRatingBloc);
      }
    });

    tearDown(() async {
      if (getIt.isRegistered<TrackingBloc>()) {
        await getIt.unregister<TrackingBloc>();
      }
      if (getIt.isRegistered<RatingBloc>()) {
        await getIt.unregister<RatingBloc>();
      }
    });

    // ── ACCEPTED → tap "Afficher le QR de remise" → onPressed called (lines 181-183)

    testWidgets(
      '17. ACCEPTED cash → tap "Afficher le QR de remise" → onPressed executed',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(bloc, const Stream.empty(),
            initialState: BidInitial());

        await tester.pumpWidget(
          _host(
            bloc,
            _bid(status: 'ACCEPTED', paymentMethod: BidPaymentMethod.cash),
            paymentLoaded: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Afficher le QR de remise'), findsOneWidget);
        await tester.tap(find.text('Afficher le QR de remise'));
        await tester.pump();
      },
    );

    // ── HANDED_OVER → tap "Suivi du colis" → onPressed called (lines 196-200)

    testWidgets(
      '18. HANDED_OVER → tap "Suivi du colis" → onPressed executed',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(bloc, const Stream.empty(),
            initialState: BidInitial());

        await tester.pumpWidget(
          _host(bloc, _bid(status: 'HANDED_OVER'), paymentLoaded: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('Suivi du colis'), findsOneWidget);
        await tester.tap(find.text('Suivi du colis'));
        await tester.pump();
      },
    );

    // ── COMPLETED non noté → tap "Noter le voyageur" → onPressed called (lines 214-218)

    testWidgets(
      '19. COMPLETED senderHasRated=false → tap "Noter le voyageur" → onPressed executed',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(bloc, const Stream.empty(),
            initialState: BidInitial());

        await tester.pumpWidget(
          _host(
            bloc,
            _bid(status: 'COMPLETED', senderHasRated: false),
            paymentLoaded: true,
            // Provide RatingBloc in the widget tree so RatingBottomSheet.show
            // can resolve it via context.read<RatingBloc>().
            ratingBloc: mockRatingBloc,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Noter le voyageur'), findsOneWidget);
        await tester.tap(find.text('Noter le voyageur'));
        await tester.pump();
      },
    );
  });
}
