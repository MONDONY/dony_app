import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidSupplement _sup(
  BidSupplementStatus status, {
  String? secret,
  String? commissionStatus,
  double? commission = 1.8,
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: 'CASH',
  grossAmount: 16.8,
  commissionAmount: commission,
  commissionStatus: commissionStatus,
  commissionClientSecret: secret,
);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;
  late List<String> secrets;

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    secrets = [];
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SupplementCommissionFlow flow({Object? failWith}) => SupplementCommissionFlow(
    repository,
    analytics,
    nextAction: (secret) async {
      secrets.add(secret);
      if (failWith != null) throw failWith;
    },
  );

  group('settle', () {
    test('sans secret : rendu tel quel, ni 3DS ni confirmation', () async {
      final s = _sup(BidSupplementStatus.proposed);
      expect(await flow().settle('b', s), same(s));
      expect(secrets, isEmpty);
      verifyNever(() => repository.confirmCommission(any(), any()));
    });

    test('3DS puis confirmation : la demande part à l\'expéditeur', () async {
      when(() => repository.confirmCommission('b', 'sup-1')).thenAnswer(
        (_) async => _sup(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
      );

      final settled = await flow().settle(
        'b',
        _sup(BidSupplementStatus.commissionPending, secret: 'pi_1'),
      );

      expect(settled.status, BidSupplementStatus.proposed);
      expect(secrets, ['pi_1']);
    });

    test('3DS redemandée : deux tours au plus, puis en attente', () async {
      when(() => repository.confirmCommission('b', 'sup-1')).thenAnswer(
        (_) async =>
            _sup(BidSupplementStatus.commissionPending, secret: 'pi_again'),
      );

      final settled = await flow().settle(
        'b',
        _sup(BidSupplementStatus.commissionPending, secret: 'pi_1'),
      );

      expect(settled.status, BidSupplementStatus.commissionPending);
      expect(secrets, ['pi_1', 'pi_again']);
      verify(() => repository.confirmCommission('b', 'sup-1')).called(2);
    });

    test('3DS abandonnée : SupplementCommissionAuthInterrupted', () async {
      expect(
        () => flow(failWith: StateError('canceled')).settle(
          'b',
          _sup(BidSupplementStatus.commissionPending, secret: 'pi_1'),
        ),
        throwsA(
          isA<SupplementCommissionAuthInterrupted>().having(
            (e) => e.toString(),
            'toString',
            contains('canceled'),
          ),
        ),
      );
      verifyNever(() => repository.confirmCommission(any(), any()));
    });
  });

  test('resume : confirme d\'abord, puis 3DS si redemandée', () async {
    var calls = 0;
    when(() => repository.confirmCommission('b', 'sup-1')).thenAnswer((
      _,
    ) async {
      calls++;
      return calls == 1
          ? _sup(BidSupplementStatus.commissionPending, secret: 'pi_2')
          : _sup(BidSupplementStatus.proposed);
    });

    final settled = await flow().resume('b', 'sup-1');

    expect(settled.status, BidSupplementStatus.proposed);
    expect(secrets, ['pi_2']);
  });

  group('analytics', () {
    test('logCharged : payment_succeeded, contexte commission du supplément '
        '(solde)', () {
      flow().logCharged(
        _sup(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
        SupplementCommissionSource.wallet,
      );
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentSucceeded,
          properties: {
            'method': 'wallet_balance',
            'context': 'bid_supplement_commission',
            'currency': 'EUR',
            'amount_bracket': '<20',
          },
        ),
      ).called(1);
    });

    test('logCharged sans commission prélevée : rien', () {
      flow().logCharged(
        _sup(BidSupplementStatus.proposed),
        SupplementCommissionSource.card,
      );
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });

    test('logCharged sans montant : pas de tranche', () {
      flow().logCharged(
        _sup(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
          commission: null,
        ),
        SupplementCommissionSource.card,
      );
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentSucceeded,
          properties: {
            'method': 'card',
            'context': 'bid_supplement_commission',
            'currency': 'EUR',
          },
        ),
      ).called(1);
    });

    test('logFailed : payment_failed avec raison et code', () {
      flow().logFailed(
        SupplementCommissionSource.card,
        reason: 'declined',
        errorCode: 'supplement-commission-card-declined',
        currency: 'EUR',
      );
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentFailed,
          properties: {
            'method': 'card',
            'context': 'bid_supplement_commission',
            'reason': 'declined',
            'error_code': 'supplement-commission-card-declined',
            'currency': 'EUR',
          },
        ),
      ).called(1);
    });
  });
}
