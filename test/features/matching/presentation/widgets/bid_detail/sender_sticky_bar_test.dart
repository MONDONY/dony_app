import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_money_breakdown.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_pay_button.dart';
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

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockSupplementRepository extends Mock
    implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

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
  BidMoneyBreakdown? moneyBreakdown,
  List<BidAmendment> amendments = const [],
  AddressData? handoverAddress,
  AddressData? deliveryAddress,
}) {
  return BidModel(
    handoverAddress: handoverAddress,
    deliveryAddress: deliveryAddress,
    moneyBreakdown: moneyBreakdown,
    amendments: amendments,
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
    home: BlocProvider<BidBloc>.value(value: bloc, child: child),
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
    registerFallbackValue(
      BidCancelBeforePaymentRequested('bid-test-1', paymentMethod: 'stripe'),
    );
  });

  // Test 1: PENDING stripe non payé → 'Payer mon envoi'
  testWidgets(
    '1. PENDING stripe paymentLoaded=true existingPayment=null → "Payer mon envoi"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_host(bloc, _bid(), paymentLoaded: true));
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsOneWidget);
    },
  );

  testWidgets('modification à payer en mobile money → bouton « Payer » de la '
      'modification, avant l\'action du colis', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
    final bid = _bid(
      amendments: const [
        BidAmendment(
          id: 'am-1',
          status: BidAmendmentStatus.paymentPending,
          rail: BidAmendment.railPawapay,
          grossAmount: 26.8,
        ),
      ],
    );

    await tester.pumpWidget(_host(bloc, bid, paymentLoaded: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('amendment-pay-btn')), findsOneWidget);
    expect(find.text('Payer mon envoi'), findsNothing);
  });

  // Test 2: PENDING cash → pas de 'Payer mon envoi'
  testWidgets('2. PENDING cash → pas de "Payer mon envoi"', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(paymentMethod: BidPaymentMethod.cash),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payer mon envoi'), findsNothing);
  });

  // Test 3: ACCEPTED cash → 'Afficher le QR de remise'
  testWidgets('3. ACCEPTED cash → "Afficher le QR de remise"', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(status: 'ACCEPTED', paymentMethod: BidPaymentMethod.cash),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Afficher le QR de remise'), findsOneWidget);
  });

  // Test 4: IN_TRANSIT → 'Suivi du colis'
  testWidgets('4. IN_TRANSIT → "Suivi du colis"', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'IN_TRANSIT'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suivi du colis'), findsOneWidget);
  });

  // Test 5: COMPLETED non noté → 'Noter le voyageur'
  testWidgets('5. COMPLETED senderHasRated=false → "Noter le voyageur"', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'COMPLETED'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noter le voyageur'), findsOneWidget);
  });

  // Test 6: COMPLETED noté → aucun DonyButton
  testWidgets('6. COMPLETED senderHasRated=true → aucun bouton visible', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

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
  });

  // Test 8: PENDING stripe paymentLoaded=false → « Payer mon envoi » désactivé
  // en chargement (même hauteur que le bouton réel : aucun saut de mise en page)
  testWidgets(
    '8. PENDING stripe paymentLoaded=false → DonyButton désactivé en chargement, 52 px',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_host(bloc, _bid()));
      // pump() : le spinner du bouton anime en boucle.
      await tester.pump();

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.label, 'Payer mon envoi');
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
      expect(tester.getSize(find.byType(DonyButton)).height, 52);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Aucun autre bouton d'action
      expect(find.text('Afficher le QR de remise'), findsNothing);
      expect(find.text('Suivi du colis'), findsNothing);
      expect(find.text('Noter le voyageur'), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  // Test 7 : « Supprimer cette demande » a quitté le footer (entrée du menu ⋮)
  for (final status in [
    'REJECTED',
    'CANCELLED',
    'NO_SHOW',
    'EXPIRED',
    'PARCEL_REFUSED',
  ]) {
    testWidgets(
      '7. $status → aucun footer, aucun bouton « Supprimer cette demande »',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(
          bloc,
          const Stream.empty(),
          initialState: BidInitial(),
        );

        await tester.pumpWidget(
          _host(bloc, _bid(status: status), paymentLoaded: true),
        );
        await tester.pumpAndSettle();

        expect(SenderStickyBar.hasAction(_bid(status: status)), isFalse);
        expect(find.text('Supprimer cette demande'), findsNothing);
        expect(find.byType(DonyButton), findsNothing);
        expect(tester.getSize(find.byType(SenderStickyBar)).height, 0);
      },
    );
  }

  // Test 9: ACCEPTED + stripe + payé → pas de badge, bouton QR seul
  testWidgets(
    '9. ACCEPTED stripe paymentLoaded=true existingPayment≠null → pas de badge, "Afficher le QR de remise"',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'ACCEPTED'),
          paymentLoaded: true,
          existingPayment: _payment(),
        ),
      );
      await tester.pumpAndSettle();

      // Le badge « Paiement sécurisé » a quitté le footer (la carte Paiement du
      // corps dit déjà l'état) : seul le bouton reste.
      expect(find.textContaining('Paiement sécurisé'), findsNothing);
      expect(find.text('Afficher le QR de remise'), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);
    },
  );

  // Test 10: PENDING + stripe + payé → rien à faire : aucun badge, aucun footer
  testWidgets(
    '10. PENDING stripe paymentLoaded=true existingPayment≠null → aucun footer',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(bloc, _bid(), paymentLoaded: true, existingPayment: _payment()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Paiement sécurisé'), findsNothing);
      expect(find.byType(DonyButton), findsNothing);
      expect(tester.getSize(find.byType(SenderStickyBar)).height, 0);
    },
  );

  // ── Tests hasAction() static method ──────────────────────────────────────────

  group('hasAction() static', () {
    test('modification acceptée à payer en mobile money → true', () {
      final bid = _bid(
        status: 'COMPLETED',
        senderHasRated: true,
        amendments: const [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.paymentPending,
            rail: BidAmendment.railPawapay,
            grossAmount: 26.8,
          ),
        ],
      );
      expect(SenderStickyBar.hasAction(bid), isTrue);
    });

    test('modification en espèces ou close → pas d\'action de paiement', () {
      final bid = _bid(
        status: 'COMPLETED',
        senderHasRated: true,
        amendments: const [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.paymentPending,
            rail: BidAmendment.railCash,
            grossAmount: 26.8,
          ),
        ],
      );
      expect(SenderStickyBar.hasAction(bid), isFalse);
    });

    test('PENDING_CONFIRMATION → false (hero handles it)', () {
      final bid = _bid(
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
      );
      expect(SenderStickyBar.hasAction(bid), isFalse);
    });

    test('PENDING stripe → true', () {
      final bid = _bid();
      expect(SenderStickyBar.hasAction(bid), isTrue);
    });

    test('PENDING cash → false', () {
      final bid = _bid(paymentMethod: BidPaymentMethod.cash);
      expect(SenderStickyBar.hasAction(bid), isFalse);
    });

    // PENDING reste inchangé pour le mobile money : une offre mobile money
    // en attente d'acceptation n'a pas d'action, comme les espèces (arbitrage
    // task 11 — seul AWAITING_PAYMENT gagne le mobile money).
    test('PENDING mobile money → false', () {
      final bid = _bid(paymentMethod: BidPaymentMethod.mobileMoney);
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
      expect(SenderStickyBar.hasAction(_bid(status: 'COMPLETED')), isTrue);
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
      expect(SenderStickyBar.hasAction(_bid(status: 'DELIVERED')), isTrue);
    });

    // « Supprimer cette demande » vit dans le menu ⋮ : plus de footer.
    for (final status in [
      'REJECTED',
      'CANCELLED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
    ]) {
      test('$status → false (suppression dans le menu ⋮)', () {
        expect(SenderStickyBar.hasAction(_bid(status: status)), isFalse);
      });
    }

    test('PAYMENT_ESCROWED → false (not in any branch)', () {
      expect(
        SenderStickyBar.hasAction(_bid(status: 'PAYMENT_ESCROWED')),
        isFalse,
      );
    });

    test('AWAITING_PAYMENT stripe → true', () {
      expect(
        SenderStickyBar.hasAction(_bid(status: 'AWAITING_PAYMENT')),
        isTrue,
      );
    });

    test('AWAITING_PAYMENT cash → false', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.cash,
          ),
        ),
        isFalse,
      );
    });

    test('AWAITING_PAYMENT mobile money → true', () {
      expect(
        SenderStickyBar.hasAction(
          _bid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        isTrue,
      );
    });
  });

  // ── PENDING_CONFIRMATION → SizedBox.shrink (no action) ───────────────────────

  testWidgets('11. PENDING_CONFIRMATION → SizedBox.shrink (bar invisible)', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

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
  });

  // ── HANDED_OVER → "Suivi du colis" ────────────────────────────────────────────

  testWidgets('12. HANDED_OVER → "Suivi du colis"', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'HANDED_OVER'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suivi du colis'), findsOneWidget);
  });

  // ── DELIVERED non noté → 'Noter le voyageur' ──────────────────────────────────

  testWidgets('13. DELIVERED senderHasRated=false → "Noter le voyageur"', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'DELIVERED'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noter le voyageur'), findsOneWidget);
  });

  // Test 20: AWAITING_PAYMENT stripe → "Payer mon envoi" (reprise paiement)
  testWidgets('20. AWAITING_PAYMENT stripe → "Payer mon envoi"', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'AWAITING_PAYMENT'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payer mon envoi'), findsOneWidget);
    expect(
      find.byKey(const Key('sender-cancel-before-payment')),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);
  });

  // Test 21: AWAITING_PAYMENT stripe + paiement PENDING obsolète → bouton présent
  // (ne gate pas sur existingPayment ; pas de badge car badge = PENDING/ACCEPTED)
  testWidgets(
    '21. AWAITING_PAYMENT stripe existingPayment(PENDING) → "Payer mon envoi", pas de badge',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(status: 'AWAITING_PAYMENT'),
          paymentLoaded: true,
          existingPayment: _payment(status: PaymentStatus.pending),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payer mon envoi'), findsOneWidget);
      expect(find.textContaining('Paiement sécurisé'), findsNothing);
    },
  );

  // Test 22: AWAITING_PAYMENT cash → pas de "Payer mon envoi" (barre vide)
  testWidgets('22. AWAITING_PAYMENT cash → pas de "Payer mon envoi"', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(status: 'AWAITING_PAYMENT', paymentMethod: BidPaymentMethod.cash),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payer mon envoi'), findsNothing);
  });

  // Test 23: AWAITING_PAYMENT stripe → « Annuler la demande » → feuille de
  // confirmation → « Oui, annuler la demande » → vraie annulation (jamais le
  // masquage BidDeleteRequested, qui reste le repli du BLoC).
  testWidgets(
    '23. AWAITING_PAYMENT stripe → feuille → confirmer → BidCancelBeforePaymentRequested',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'AWAITING_PAYMENT'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sender-cancel-before-payment')));
      await tester.pumpAndSettle();

      expect(find.text('Annuler la demande ?'), findsOneWidget);
      expect(
        find.text(
          'La carte ne sera pas débitée. Si le voyageur avait vu votre demande, il sera prévenu.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Votre conversation avec le voyageur reste disponible.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Oui, annuler la demande'));
      await tester.pumpAndSettle();

      final captured = verify(
        () =>
            bloc.add(captureAny(that: isA<BidCancelBeforePaymentRequested>())),
      ).captured;
      expect(captured, hasLength(1));
      final event = captured.single as BidCancelBeforePaymentRequested;
      expect(event.bidId, 'bid-test-1');
      expect(event.paymentMethod, 'stripe');
      verifyNever(() => bloc.add(any(that: isA<BidDeleteRequested>())));
      expect(find.text('Annuler la demande ?'), findsNothing);
    },
  );

  testWidgets('23 bis. feuille → « Garder la demande » → aucun événement', (
    tester,
  ) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(bloc, _bid(status: 'AWAITING_PAYMENT'), paymentLoaded: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sender-cancel-before-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garder la demande'));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any()));
    expect(find.text('Annuler la demande ?'), findsNothing);
  });

  testWidgets(
    '23 ter. AWAITING_PAYMENT mobile money → conséquence mobile money, rail mobile_money',
    (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          _bid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sender-cancel-before-payment')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Aucun paiement ne sera prélevé, le voyageur sera prévenu et ses kilos libérés.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Oui, annuler la demande'));
      await tester.pumpAndSettle();

      final event =
          verify(
                () => bloc.add(
                  captureAny(that: isA<BidCancelBeforePaymentRequested>()),
                ),
              ).captured.single
              as BidCancelBeforePaymentRequested;
      expect(event.paymentMethod, 'mobile_money');
    },
  );

  // Test 24: AWAITING_PAYMENT mobile money → boutons "Payer par mobile
  // money" et "Annuler" (jamais le bloc stripe en parallèle)
  testWidgets('24. AWAITING_PAYMENT mobile money → "Payer par mobile money" et '
      '"Annuler"', (tester) async {
    final bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );

    await tester.pumpWidget(
      _host(
        bloc,
        _bid(
          status: 'AWAITING_PAYMENT',
          paymentMethod: BidPaymentMethod.mobileMoney,
        ),
        paymentLoaded: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payer par mobile money'), findsOneWidget);
    expect(
      find.byKey(const Key('sender-cancel-before-payment')),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Payer mon envoi'), findsNothing);
  });

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
      whenListen<TrackingState>(
        mockTrackingBloc,
        const Stream.empty(),
        initialState: TrackingInitial(),
      );
      whenListen<RatingState>(
        mockRatingBloc,
        const Stream.empty(),
        initialState: const RatingInitial(),
      );

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
        whenListen<BidState>(
          bloc,
          const Stream.empty(),
          initialState: BidInitial(),
        );

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

    testWidgets('18. HANDED_OVER → tap "Suivi du colis" → onPressed executed', (
      tester,
    ) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(bloc, _bid(status: 'HANDED_OVER'), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suivi du colis'), findsOneWidget);
      await tester.tap(find.text('Suivi du colis'));
      await tester.pump();
    });

    // Le bouton du bas fait le même geste que la tuile « Suivi » de « Votre
    // envoi » : la fenêtre du suivi, pas la frise seule.
    testWidgets(
      '18 bis. HANDED_OVER avec adresses → "Suivi du colis" ouvre la fenêtre '
      '« Suivi » (comme la tuile)',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(
          bloc,
          const Stream.empty(),
          initialState: BidInitial(),
        );

        await tester.pumpWidget(
          _host(
            bloc,
            _bid(
              status: 'HANDED_OVER',
              handoverAddress: const AddressData(
                label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
                lat: 48.7667,
                lng: 2.3508,
              ),
              deliveryAddress: const AddressData(
                label: 'ACI 2000, Bamako, Mali',
                lat: 12.6362,
                lng: -8.0121,
              ),
            ),
            paymentLoaded: true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Suivi du colis'));
        await tester.pumpAndSettle();

        // Contenu propre à la fenêtre : son bouton de pied et ses adresses.
        expect(find.text('Voir toutes les étapes et photos'), findsOneWidget);
        expect(find.textContaining('Chevilly-Larue'), findsWidgets);
      },
    );

    // ── COMPLETED non noté → tap "Noter le voyageur" → onPressed called (lines 214-218)

    testWidgets(
      '19. COMPLETED senderHasRated=false → tap "Noter le voyageur" → onPressed executed',
      (tester) async {
        final bloc = _MockBidBloc();
        whenListen<BidState>(
          bloc,
          const Stream.empty(),
          initialState: BidInitial(),
        );

        await tester.pumpWidget(
          _host(
            bloc,
            _bid(status: 'COMPLETED'),
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

    // ── Régression ARRIVED ────────────────────────────────────────────────────
    // Avant le fix, ARRIVED n'était pas listé : hasAction retombait sur
    // kEnvoisPasses (false) et le CTA « Suivi du colis » disparaissait.

    testWidgets('20. ARRIVED → hasAction true et CTA "Suivi du colis"', (
      tester,
    ) async {
      final bid = _bid(status: 'ARRIVED');
      expect(SenderStickyBar.hasAction(bid), isTrue);

      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(_host(bloc, bid, paymentLoaded: true));
      await tester.pumpAndSettle();

      expect(find.text('Suivi du colis'), findsOneWidget);
    });

    testWidgets('anglais — ACCEPTED : "Show the drop-off QR" traduit', (
      tester,
    ) async {
      final bid = _bid(
        status: 'ACCEPTED',
        paymentMethod: BidPaymentMethod.cash,
      );
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      useEnglish();
      await tester.pumpWidget(_host(bloc, bid, paymentLoaded: true));
      await tester.pumpAndSettle();

      expect(find.text('Show the drop-off QR'), findsOneWidget);
    });
  });

  // ── Supplément de prix à payer par carte (PR A2) ────────────────────────────

  group('supplément de prix', () {
    BidModel withSupplement({
      String status = 'ACCEPTED',
      String rail = 'STRIPE',
      BidSupplementStatus supplementStatus = BidSupplementStatus.proposed,
      BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
    }) => BidModel(
      id: 'bid-test-1',
      announcementId: 'ann-1',
      senderId: 'sender-1',
      status: status,
      paymentMethod: paymentMethod,
      supplement: BidSupplement(
        id: 'sup-1',
        status: supplementStatus,
        rail: rail,
        grossAmount: 16.8,
      ),
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    setUp(() {
      getIt.registerFactory<SupplementPaymentCubit>(
        () => SupplementPaymentCubit(
          _MockSupplementRepository(),
          _MockAnalyticsService(),
        ),
      );
    });

    tearDown(() async => getIt.unregister<SupplementPaymentCubit>());

    test('hasAction vrai pour un supplément carte, mobile money ou espèces, '
        'même hors statut habituel (espèces : PR A4)', () {
      expect(
        SenderStickyBar.hasAction(withSupplement(status: 'PAYMENT_ESCROWED')),
        isTrue,
      );
      expect(
        SenderStickyBar.hasAction(
          withSupplement(
            status: 'PAYMENT_ESCROWED',
            rail: 'PAWAPAY',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
        ),
        isTrue,
      );
      expect(
        SenderStickyBar.hasAction(
          withSupplement(
            status: 'PAYMENT_ESCROWED',
            rail: 'CASH',
            paymentMethod: BidPaymentMethod.cash,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('carte, supplément en attente : « Payer » remplace le QR', (
      tester,
    ) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(bloc, withSupplement(), paymentLoaded: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SupplementPayButton), findsOneWidget);
      expect(find.text('Afficher le QR de remise'), findsNothing);
    });

    testWidgets('carte, paiement interrompu (PAYMENT_PENDING) : « Payer » '
        'reste', (tester) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          withSupplement(supplementStatus: BidSupplementStatus.paymentPending),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SupplementPayButton), findsOneWidget);
    });

    testWidgets('mobile money : « Payer » remplace le QR (PR A3)', (
      tester,
    ) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          withSupplement(
            rail: 'PAWAPAY',
            paymentMethod: BidPaymentMethod.mobileMoney,
          ),
          paymentLoaded: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SupplementPayButton), findsOneWidget);
      expect(find.text('Afficher le QR de remise'), findsNothing);
    });

    testWidgets('supplément payé : retour à l\'action du statut', (
      tester,
    ) async {
      final bloc = _MockBidBloc();
      whenListen<BidState>(
        bloc,
        const Stream.empty(),
        initialState: BidInitial(),
      );

      await tester.pumpWidget(
        _host(
          bloc,
          withSupplement(supplementStatus: BidSupplementStatus.paid),
          paymentLoaded: true,
          existingPayment: _payment(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SupplementPayButton), findsNothing);
    });
  });

  // Décision du propriétaire : colis ACCEPTED, le QR du colis reste au talon
  // quand le footer ne propose pas « Afficher le QR de remise » (paiement
  // carte introuvable, déclaration d'absence en attente). Partout ailleurs,
  // pas de QR au talon avant la remise.
  group('leavesQrToTalon', () {
    const methods = BidPaymentMethod.values;
    const absences = <String?>[null, 'PENDING_CONFIRMATION', 'CONTESTED'];
    // (paiement lu, paiement trouvé)
    const payments = <(bool, bool)>[
      (false, false),
      (true, false),
      (true, true),
    ];

    for (final method in methods) {
      for (final absence in absences) {
        for (final (loaded, found) in payments) {
          final expected =
              absence == 'PENDING_CONFIRMATION' ||
              (method == BidPaymentMethod.stripe && loaded && !found);
          testWidgets(
            'ACCEPTED ${method.name}, absence ${absence ?? 'aucune'}, '
            'paiement ${loaded ? (found ? 'trouvé' : 'introuvable') : 'en lecture'}'
            ' → ${expected ? 'QR au talon' : 'pas de QR au talon'}',
            (tester) async {
              final bid = _bid(
                status: 'ACCEPTED',
                paymentMethod: method,
                cancellationNoShowStatus: absence,
              );
              final payment = found ? _payment() : null;
              expect(
                SenderStickyBar.leavesQrToTalon(
                  bid,
                  paymentLoaded: loaded,
                  existingPayment: payment,
                ),
                expected,
              );

              // Le footer et le talon ne proposent jamais le QR tous les deux,
              // et l'un des deux le propose dès que le paiement est lu.
              final bloc = _MockBidBloc();
              whenListen<BidState>(
                bloc,
                const Stream.empty(),
                initialState: BidInitial(),
              );
              await tester.pumpWidget(
                _host(
                  bloc,
                  bid,
                  paymentLoaded: loaded,
                  existingPayment: payment,
                ),
              );
              await tester.pump();
              final footerQr = find
                  .text('Afficher le QR de remise')
                  .evaluate()
                  .isNotEmpty;
              expect(footerQr && expected, isFalse);
              if (loaded) expect(footerQr || expected, isTrue);
            },
          );
        }
      }
    }

    test('supplément ou modification à payer : pas de QR au talon', () {
      final supplement = BidModel(
        id: 'bid-test-1',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        status: 'ACCEPTED',
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.proposed,
          rail: 'STRIPE',
          grossAmount: 16.8,
        ),
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(SupplementPayButton.canPay(supplement), isTrue);
      expect(
        SenderStickyBar.leavesQrToTalon(
          supplement,
          paymentLoaded: true,
          existingPayment: _payment(),
        ),
        isFalse,
      );
    });

    for (final status in [
      'PENDING',
      'AWAITING_PAYMENT',
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'DELIVERED',
      'COMPLETED',
      'CANCELLED',
    ]) {
      test('$status : jamais (le talon garde son comportement)', () {
        for (final absence in absences) {
          expect(
            SenderStickyBar.leavesQrToTalon(
              _bid(status: status, cancellationNoShowStatus: absence),
              paymentLoaded: true,
            ),
            isFalse,
            reason: absence,
          );
        }
      });
    }
  });
}
