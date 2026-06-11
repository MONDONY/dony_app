import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

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
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<BidBloc>.value(
      value: bloc,
      child: Scaffold(
        bottomNavigationBar: SenderStickyBar(
          bid: bid,
          isLoading: false,
          paymentLoaded: paymentLoaded,
          existingPayment: existingPayment,
        ),
      ),
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
}
