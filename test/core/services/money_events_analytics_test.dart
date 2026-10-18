// Mocktail exige le jeu exact d'arguments nommés des appels réels : certains
// stubs répètent donc une valeur par défaut.
// ignore_for_file: avoid_redundant_argument_values
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_code_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide PaymentMethod;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockWalletRepo extends Mock implements WalletRepository {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockNegotiationRepo extends Mock implements NegotiationRepository {}

class _MockMobileMoneyRepo extends Mock implements MobileMoneyRepository {}

class _MockStripe extends Mock implements Stripe {}

/// Tous les mouvements d'argent lancés depuis l'app tombent dans la famille
/// `payment_succeeded` / `payment_failed`, lue par `method` × `context` :
/// recharges par code et mobile money, commission d'un accord en espèces,
/// mobile money d'un colis.
void main() {
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUpAll(() {
    registerFallbackValue(const MobileMoneyScope.bid('fallback'));
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Map<String, Object> captured(String event) =>
      verify(() => backend.capture(event, captureAny())).captured.single
          as Map<String, Object>;

  group('recharge par code (voucher)', () {
    test('succès : wallet_topup_completed et payment_succeeded', () async {
      final repo = _MockWalletRepo();
      when(() => repo.redeemTopupCode('ABC-123')).thenAnswer(
        (_) async => const WalletTopupCodeRedemptionModel(
          amount: 25,
          currency: 'EUR',
          balance: 25,
        ),
      );
      final cubit = WalletTopupCodeCubit(repo, analytics: analytics);

      await cubit.submit('ABC-123');
      await settle();

      const expected = {
        'method': 'voucher',
        'currency': 'EUR',
        'amount_bracket': '20-50',
      };
      expect(captured(AnalyticsEvents.walletTopupCompleted), expected);
      expect(captured(AnalyticsEvents.paymentSucceeded), {
        ...expected,
        'context': 'wallet_topup',
      });
    });

    test('code refusé : wallet_topup_failed sans le code saisi', () async {
      final repo = _MockWalletRepo();
      when(() => repo.redeemTopupCode('ABC-123')).thenThrow(
        const ValidationException('Code inconnu', code: 'topup-code/invalid'),
      );
      final cubit = WalletTopupCodeCubit(repo, analytics: analytics);

      await cubit.submit('ABC-123');
      await settle();

      final props = captured(AnalyticsEvents.walletTopupFailed);
      expect(props, {
        'method': 'voucher',
        'reason': 'code_rejected',
        'error_code': 'topup-code/invalid',
      });
      expect(props.values, isNot(contains('ABC-123')));
      expect(
        captured(AnalyticsEvents.paymentFailed),
        containsPair('context', 'wallet_topup'),
      );
    });

    test('sans AnalyticsService : le cubit fonctionne', () async {
      final repo = _MockWalletRepo();
      when(() => repo.redeemTopupCode('X')).thenThrow(Exception('réseau'));
      final cubit = WalletTopupCodeCubit(repo);

      await cubit.submit('X');

      expect(cubit.state, isA<WalletTopupCodeFailure>());
    });
  });

  test('recharge mobile money abandonnée : wallet_topup_cancelled', () async {
    final repo = _MockWalletRepo();
    when(
      () => repo.topupMobileMoney(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer(
      (_) async => const WalletTopupModel(
        topupId: 'topup-1',
        currency: 'XOF',
        provider: 'ORANGE_SEN',
        providerLabel: 'Orange Money',
        msisdnMasked: '+221 ** ** 12 34',
      ),
    );
    final cubit = WalletTopupMobileMoneyCubit(repo, analytics);

    await cubit.initiate(amount: 5000, phoneNumber: '+221771234567');
    cubit.reset();
    await settle();

    expect(captured(AnalyticsEvents.walletTopupCancelled), {
      'method': 'mobile_money',
    });
    await cubit.close();
  });

  group('commission d\'une offre en espèces', () {
    late _MockBidRepo repo;

    setUp(() => repo = _MockBidRepo());

    BidAcceptanceBloc makeBloc() =>
        BidAcceptanceBloc(repo, _MockStripe(), analytics);

    test('acceptée par le solde : payment_succeeded commission', () async {
      when(
        () => repo.acceptBidWithCommission('bid1', fundingCurrency: 'XOF'),
      ).thenAnswer(
        (_) async =>
            const AcceptanceResponse(status: AcceptanceStatus.accepted),
      );
      final bloc = makeBloc()
        ..add(BidAcceptRequested('bid1', fundingCurrency: 'XOF'));
      await bloc.stream.firstWhere((s) => s is BidAccepted);
      await settle();

      expect(captured(AnalyticsEvents.paymentSucceeded), {
        'method': 'wallet_balance',
        'context': 'commission',
        'bid_id': 'bid1',
        'currency': 'XOF',
      });
    });

    test('solde insuffisant : bid_accept_failed et payment_failed', () async {
      when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
        (_) async => const AcceptanceResponse(
          status: AcceptanceStatus.insufficientWallet,
          currency: 'EUR',
        ),
      );
      final bloc = makeBloc()..add(BidAcceptRequested('bid1'));
      await bloc.stream.firstWhere((s) => s is BidWalletInsufficient);
      await settle();

      expect(captured(AnalyticsEvents.bidAcceptFailed), {
        'bid_id': 'bid1',
        'method': 'wallet_balance',
        'reason': 'insufficient_balance',
        'error_code': 'commission/insufficient-wallet',
      });
      expect(
        captured(AnalyticsEvents.paymentFailed),
        containsPair('reason', 'insufficient_balance'),
      );
    });

    test(
      'carte refusée par le serveur : method card, server_refused',
      () async {
        when(
          () => repo.acceptBidWithCommission('bid1', commissionSource: 'CARD'),
        ).thenThrow(
          const ValidationException('Refus', code: 'commission/card-declined'),
        );
        final bloc = makeBloc()..add(BidAcceptWithCardRequested('bid1'));
        await bloc.stream.firstWhere((s) => s is BidFailed);
        await settle();

        final props = captured(AnalyticsEvents.paymentFailed);
        expect(props, containsPair('method', 'card'));
        expect(props, containsPair('reason', 'server_refused'));
        expect(props, containsPair('error_code', 'commission/card-declined'));
      },
    );

    test('refus explicite : reason declined', () async {
      when(() => repo.acceptBidWithCommission('bid1')).thenAnswer(
        (_) async => const AcceptanceResponse(status: AcceptanceStatus.failed),
      );
      final bloc = makeBloc()..add(BidAcceptRequested('bid1'));
      await bloc.stream.firstWhere((s) => s is BidFailed);
      await settle();

      expect(
        captured(AnalyticsEvents.bidAcceptFailed),
        containsPair('reason', 'declined'),
      );
    });
  });

  group('commission d\'un accord en espèces (négociation)', () {
    late _MockNegotiationRepo repo;

    final thread = NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: NegotiationThreadStatus.awaitingCommission,
      currentPriceEur: 30,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: const [],
      currency: 'XOF',
    );

    setUp(() => repo = _MockNegotiationRepo());

    blocTest<NegotiationBloc, NegotiationState>(
      'réglée par le solde : settled porte le moyen, payment_succeeded',
      build: () {
        when(
          () => repo.settleCommission(
            't-1',
            commissionSource: 'WALLET_FIRST',
            fundingCurrency: null,
          ),
        ).thenAnswer(
          (_) async =>
              const AcceptanceResponse(status: AcceptanceStatus.accepted),
        );
        return NegotiationBloc(
          repo,
          analytics: analytics,
          stripe: _MockStripe(),
        );
      },
      seed: () => NegotiationLoaded(thread),
      act: (b) => b.add(const NegotiationSettleCommissionRequested('t-1')),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        expect(captured(AnalyticsEvents.negotiationCommissionSettled), {
          'thread_id': 't-1',
          'method': 'wallet_balance',
        });
        expect(captured(AnalyticsEvents.paymentSucceeded), {
          'method': 'wallet_balance',
          'context': 'commission',
          'thread_id': 't-1',
          'currency': 'XOF',
        });
      },
    );

    blocTest<NegotiationBloc, NegotiationState>(
      'refusée par le serveur : negotiation_commission_failed',
      build: () {
        when(
          () => repo.settleCommission(
            't-1',
            commissionSource: 'CARD',
            fundingCurrency: null,
          ),
        ).thenThrow(
          const ConflictException('Pris', code: 'request/already-accepted'),
        );
        when(() => repo.getById('t-1')).thenAnswer((_) async => thread);
        return NegotiationBloc(
          repo,
          analytics: analytics,
          stripe: _MockStripe(),
        );
      },
      seed: () => NegotiationLoaded(thread),
      act: (b) => b.add(
        const NegotiationSettleCommissionRequested('t-1', useCard: true),
      ),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        expect(captured(AnalyticsEvents.negotiationCommissionFailed), {
          'thread_id': 't-1',
          'method': 'card',
          'reason': 'server_refused',
          'error_code': 'request/already-accepted',
        });
        expect(
          captured(AnalyticsEvents.paymentFailed),
          containsPair('context', 'commission'),
        );
      },
    );
  });

  group('mobile money d\'un colis', () {
    const bidId = 'bid-1';
    const scope = MobileMoneyScope.bid(bidId);
    const live = MobileMoneyPaymentStatus(
      subjectId: bidId,
      subjectStatus: 'AWAITING_PAYMENT',
      paymentStatus: 'PENDING',
      amount: 5000,
      currency: 'XOF',
      deposit: MobileMoneyDeposit(
        id: 'd1',
        status: MobileMoneyDepositStatus.accepted,
        providerLabel: 'Wave',
      ),
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'séquestre confirmé : payment_succeeded mobile_money',
      build: () {
        final repo = _MockMobileMoneyRepo();
        when(() => repo.getStatus(scope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'ACCEPTED',
            paymentStatus: 'ESCROW',
            amount: 5000,
            currency: 'XOF',
            deposit: MobileMoneyDeposit(
              id: 'd1',
              status: MobileMoneyDepositStatus.completed,
              providerLabel: 'Wave',
            ),
          ),
        );
        return MobileMoneyPaymentBloc(repo, analytics);
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(live),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        expect(captured(AnalyticsEvents.paymentSucceeded), {
          'method': 'mobile_money',
          'context': 'bid',
          'currency': 'XOF',
          'amount_bracket': analyticsAmountBracket(5000),
          'provider': 'Wave',
        });
      },
    );

    blocTest<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
      'dépôt refusé : payment_failed declined avec le code opérateur',
      build: () {
        final repo = _MockMobileMoneyRepo();
        when(() => repo.getStatus(scope)).thenAnswer(
          (_) async => const MobileMoneyPaymentStatus(
            subjectId: bidId,
            subjectStatus: 'AWAITING_PAYMENT',
            amount: 5000,
            currency: 'XOF',
            deposit: MobileMoneyDeposit(
              id: 'd1',
              status: MobileMoneyDepositStatus.failed,
              failureCode: 'INSUFFICIENT_BALANCE',
            ),
          ),
        );
        return MobileMoneyPaymentBloc(repo, analytics);
      },
      seed: () => const MobileMoneyPaymentAwaitingConfirmation(live),
      act: (b) => b.add(const MobileMoneyStatusPolled(scope: scope)),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        final props = captured(AnalyticsEvents.paymentFailed);
        expect(props, containsPair('method', 'mobile_money'));
        expect(props, containsPair('reason', 'declined'));
        expect(props, containsPair('error_code', 'INSUFFICIENT_BALANCE'));
      },
    );
  });
}
