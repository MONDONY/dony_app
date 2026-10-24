import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidAmendmentRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _proposed = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'CASH',
  grossAmount: 26.8,
  netAmount: 23.5,
  commissionAmount: 3.3,
);

const _cardProposed = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'STRIPE',
  grossAmount: 26.8,
);

const _accepted = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.accepted,
  rail: 'CASH',
  grossAmount: 26.8,
  netAmount: 23.5,
  commissionAmount: 3.3,
  commissionStatus: 'CHARGED',
);

void main() {
  late _MockRepository repository;
  late _MockAnalytics analytics;
  late List<String> threeDsSecrets;
  late AmendmentAcceptCubit cubit;

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalytics();
    threeDsSecrets = [];
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    final flow = AmendmentCommissionFlow(
      repository,
      analytics,
      nextAction: (secret) async => threeDsSecrets.add(secret),
    );
    cubit = AmendmentAcceptCubit(repository, analytics, flow);
  });

  tearDown(() => cubit.close());

  Future<void> settleMicrotasks() => Future<void>.delayed(Duration.zero);

  List<AmendmentAcceptStatus> record() {
    final seen = <AmendmentAcceptStatus>[];
    cubit.stream.listen((s) => seen.add(s.status));
    return seen;
  }

  group('accept', () {
    test('accept_cashWallet_emitsAccepted_logsAccepted', () async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
        ),
      ).thenAnswer((_) async => _accepted);
      final seen = record();

      await cubit.accept(
        _bid,
        _proposed,
        source: SupplementCommissionSource.wallet,
      );
      await settleMicrotasks();

      expect(seen, [
        AmendmentAcceptStatus.accepting,
        AmendmentAcceptStatus.accepted,
      ]);
      expect(cubit.state.amendment, _accepted);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentAccepted,
          properties: {'method': 'cash', 'commission_source': 'wallet'},
        ),
      ).called(1);
    });

    test('accept_card_logsAcceptedWithoutCommissionSource', () async {
      const card = BidAmendment(
        id: 'am-1',
        status: BidAmendmentStatus.proposed,
        rail: 'STRIPE',
        grossAmount: 26.8,
      );
      when(() => repository.accept('bid-1', 'am-1')).thenAnswer(
        (_) async => const BidAmendment(
          id: 'am-1',
          status: BidAmendmentStatus.accepted,
          rail: 'STRIPE',
          grossAmount: 26.8,
        ),
      );

      await cubit.accept(_bid, card);

      expect(cubit.state.status, AmendmentAcceptStatus.accepted);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentAccepted,
          properties: {'method': 'card'},
        ),
      ).called(1);
    });

    test('accept_unfunded_emitsUnfunded', () async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
        ),
      ).thenThrow(
        const ValidationException(
          'solde',
          code: 'amendment-commission-unfunded',
          extensions: {
            'availableBalance': 1.0,
            'requiredCommission': 3.3,
            'shortfall': 2.3,
            'hasCard': true,
            'currency': 'EUR',
          },
        ),
      );

      await cubit.accept(
        _bid,
        _proposed,
        source: SupplementCommissionSource.wallet,
      );

      expect(cubit.state.status, AmendmentAcceptStatus.unfunded);
      expect(cubit.state.unfunded?.shortfall, 2.3);
      expect(cubit.state.unfunded?.hasCard, isTrue);
    });

    test('accept_fundingCurrency_logsChosen', () async {
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.wallet,
          fundingCurrency: 'XOF',
        ),
      ).thenAnswer((_) async => _accepted);

      await cubit.accept(
        _bid,
        _proposed,
        source: SupplementCommissionSource.wallet,
        fundingCurrency: 'XOF',
      );

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.commissionFundingCurrencyChosen,
          properties: {'currency': 'XOF', 'context': 'bid_amendment'},
        ),
      ).called(1);
    });

    test('accept_card3ds_runsCommissionFlow', () async {
      final needs3ds = _proposed.withCommissionClientSecret('pi_9_secret');
      const pendingWith3ds = BidAmendment(
        id: 'am-1',
        status: BidAmendmentStatus.commissionPending,
        rail: 'CASH',
        grossAmount: 26.8,
        netAmount: 23.5,
        commissionAmount: 3.3,
        commissionClientSecret: 'pi_9_secret',
      );
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.card,
        ),
      ).thenAnswer((_) async => pendingWith3ds);
      when(
        () => repository.confirmCommission('bid-1', 'am-1'),
      ).thenAnswer((_) async => _accepted);
      final seen = record();

      await cubit.accept(
        _bid,
        needs3ds,
        source: SupplementCommissionSource.card,
      );
      await settleMicrotasks();

      expect(threeDsSecrets, ['pi_9_secret']);
      expect(seen, [
        AmendmentAcceptStatus.accepting,
        AmendmentAcceptStatus.commissionAuth,
        AmendmentAcceptStatus.accepted,
      ]);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentSucceeded,
          properties: any(named: 'properties'),
        ),
      ).called(1);
    });

    test('accept_3dsAbandoned_emitsFailureWithoutError', () async {
      final cubit2 = AmendmentAcceptCubit(
        repository,
        analytics,
        AmendmentCommissionFlow(
          repository,
          analytics,
          nextAction: (_) async => throw Exception('canceled'),
        ),
      );
      addTearDown(cubit2.close);
      when(
        () => repository.accept(
          'bid-1',
          'am-1',
          commissionSource: SupplementCommissionSource.card,
        ),
      ).thenAnswer(
        (_) async => const BidAmendment(
          id: 'am-1',
          status: BidAmendmentStatus.commissionPending,
          rail: 'CASH',
          grossAmount: 26.8,
          commissionClientSecret: 'pi_9_secret',
        ),
      );

      await cubit2.accept(
        _bid,
        _proposed,
        source: SupplementCommissionSource.card,
      );

      expect(cubit2.state.status, AmendmentAcceptStatus.failure);
      expect(cubit2.state.error, isNull);
    });

    test('accept_captureFailed409_emitsFailure_errorCode', () async {
      when(() => repository.accept('bid-1', 'am-1')).thenThrow(
        const ConflictException('capture', code: 'amendment-capture-failed'),
      );

      await cubit.accept(_bid, _cardProposed);

      expect(cubit.state.status, AmendmentAcceptStatus.failure);
      expect(cubit.state.error?.code, 'amendment-capture-failed');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentActionFailed,
          properties: {
            'action': 'accept',
            'error_code': 'amendment-capture-failed',
          },
        ),
      ).called(1);
    });

    test('accept_whileBusy_ignored', () async {
      when(() => repository.accept('bid-1', 'am-1')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _accepted;
      });

      final first = cubit.accept(_bid, _cardProposed);
      await cubit.accept(_bid, _cardProposed);
      await first;

      verify(() => repository.accept('bid-1', 'am-1')).called(1);
    });

    test(
      'accept_serverStillCommissionPending_emitsPending_noAcceptedLog',
      () async {
        when(
          () => repository.accept(
            'bid-1',
            'am-1',
            commissionSource: SupplementCommissionSource.wallet,
            fundingCurrency: any(named: 'fundingCurrency'),
          ),
        ).thenAnswer(
          (_) async => const BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.commissionPending,
            rail: 'CASH',
            grossAmount: 26.8,
          ),
        );

        await cubit.accept(_bid, _proposed);

        expect(cubit.state.status, AmendmentAcceptStatus.pending);
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.bidAmendmentAccepted,
            properties: any(named: 'properties'),
          ),
        );
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.paymentSucceeded,
            properties: any(named: 'properties'),
          ),
        );
      },
    );
  });

  group('resume', () {
    const pending = BidAmendment(
      id: 'am-1',
      status: BidAmendmentStatus.commissionPending,
      rail: 'CASH',
      grossAmount: 26.8,
      commissionAmount: 3.3,
    );

    test('resume_confirmsCommission_thenAccepted', () async {
      when(
        () => repository.confirmCommission('bid-1', 'am-1'),
      ).thenAnswer((_) async => _accepted);

      await cubit.resume(_bid, pending);

      expect(cubit.state.status, AmendmentAcceptStatus.accepted);
      verifyNever(() => repository.accept(any(), any()));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentAccepted,
          properties: {'method': 'cash', 'commission_source': 'card'},
        ),
      ).called(1);
    });

    test('resume_3dsRequired_runsFlow', () async {
      when(() => repository.confirmCommission('bid-1', 'am-1')).thenAnswer(
        (_) async => const BidAmendment(
          id: 'am-1',
          status: BidAmendmentStatus.commissionPending,
          rail: 'CASH',
          grossAmount: 26.8,
          commissionClientSecret: 'pi_7_secret',
        ),
      );
      var calls = 0;
      when(() => repository.confirmCommission('bid-1', 'am-1')).thenAnswer((
        _,
      ) async {
        calls++;
        return calls == 1
            ? const BidAmendment(
                id: 'am-1',
                status: BidAmendmentStatus.commissionPending,
                rail: 'CASH',
                grossAmount: 26.8,
                commissionClientSecret: 'pi_7_secret',
              )
            : _accepted;
      });

      await cubit.resume(_bid, pending);

      expect(threeDsSecrets, ['pi_7_secret']);
      expect(cubit.state.status, AmendmentAcceptStatus.accepted);
    });

    test('resume_failure_emitsFailure_logsConfirmCommission', () async {
      when(() => repository.confirmCommission('bid-1', 'am-1')).thenThrow(
        const ConflictException('x', code: 'amendment-commission-declined'),
      );

      await cubit.resume(_bid, pending);

      expect(cubit.state.status, AmendmentAcceptStatus.failure);
      expect(cubit.state.error?.code, 'amendment-commission-declined');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentActionFailed,
          properties: {
            'action': 'confirm_commission',
            'error_code': 'amendment-commission-declined',
          },
        ),
      ).called(1);
    });
  });
}
