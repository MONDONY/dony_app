import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

final _bid = BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: BidPaymentMethod.cash,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _pending = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.commissionPending,
  rail: 'CASH',
  grossAmount: 16.8,
  commissionAmount: 1.8,
);

const _proposed = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  rail: 'CASH',
  grossAmount: 16.8,
  commissionAmount: 1.8,
  commissionStatus: SupplementCommissionStatus.charged,
);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;
  late bool failAuth;

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    failAuth = false;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SupplementCommissionCubit build() => SupplementCommissionCubit(
    SupplementCommissionFlow(
      repository,
      analytics,
      nextAction: (_) async {
        if (failAuth) throw StateError('canceled');
      },
    ),
    analytics,
  );

  test('beginAuthorization bloque le double tap ; refus : retour au repos', () {
    final cubit = build();
    expect(cubit.beginAuthorization(), isTrue);
    expect(cubit.state.isBusy, isTrue);
    expect(cubit.beginAuthorization(), isFalse);
    cubit.authorizationDenied();
    expect(cubit.state.status, SupplementCommissionResumeStatus.idle);
    cubit.authorizationDenied();
    expect(cubit.state.status, SupplementCommissionResumeStatus.idle);
  });

  blocTest<SupplementCommissionCubit, SupplementCommissionResumeState>(
    'reprise réussie : demande envoyée, payment_succeeded carte',
    setUp: () => when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _proposed),
    build: build,
    act: (c) => c.resume(_bid, _pending),
    expect: () => [
      isA<SupplementCommissionResumeState>().having(
        (s) => s.status,
        'status',
        SupplementCommissionResumeStatus.busy,
      ),
      isA<SupplementCommissionResumeState>().having(
        (s) => s.status,
        'status',
        SupplementCommissionResumeStatus.proposed,
      ),
    ],
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.paymentSucceeded,
          properties: any(
            named: 'properties',
            that: containsPair('method', 'card'),
          ),
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidSupplementCommissionResumed,
          properties: {'outcome': 'proposed'},
        ),
      ).called(1);
    },
  );

  blocTest<SupplementCommissionCubit, SupplementCommissionResumeState>(
    'Stripe traite encore : en attente, pas de payment_succeeded',
    setUp: () => when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _pending),
    build: build,
    act: (c) => c.resume(_bid, _pending),
    skip: 1,
    expect: () => [
      isA<SupplementCommissionResumeState>().having(
        (s) => s.status,
        'status',
        SupplementCommissionResumeStatus.pending,
      ),
    ],
    verify: (_) => verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.paymentSucceeded,
        properties: any(named: 'properties'),
      ),
    ),
  );

  blocTest<SupplementCommissionCubit, SupplementCommissionResumeState>(
    '3DS abandonnée : échec sans erreur serveur',
    setUp: () {
      failAuth = true;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.commissionPending,
          rail: 'CASH',
          grossAmount: 16.8,
          commissionClientSecret: 'pi_secret',
        ),
      );
    },
    build: build,
    act: (c) => c.resume(_bid, _pending),
    skip: 1,
    expect: () => [
      isA<SupplementCommissionResumeState>()
          .having(
            (s) => s.status,
            'status',
            SupplementCommissionResumeStatus.failure,
          )
          .having((s) => s.error, 'error', isNull),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.paymentFailed,
        properties: any(
          named: 'properties',
          that: containsPair('reason', 'authentication_failed'),
        ),
      ),
    ).called(1),
  );

  blocTest<SupplementCommissionCubit, SupplementCommissionResumeState>(
    'carte refusée : échec avec l\'erreur, payment_failed declined',
    setUp: () =>
        when(() => repository.confirmCommission('bid-1', 'sup-1')).thenThrow(
          const ValidationException(
            'd',
            code: 'supplement-commission-card-declined',
          ),
        ),
    build: build,
    act: (c) => c.resume(_bid, _pending),
    skip: 1,
    expect: () => [
      isA<SupplementCommissionResumeState>().having(
        (s) => s.error?.code,
        'code',
        'supplement-commission-card-declined',
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.paymentFailed,
        properties: any(
          named: 'properties',
          that: containsPair('reason', 'declined'),
        ),
      ),
    ).called(1),
  );

  blocTest<SupplementCommissionCubit, SupplementCommissionResumeState>(
    'réseau : échec générique',
    setUp: () => when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenThrow(const OfflineException()),
    build: build,
    act: (c) => c.resume(_bid, _pending),
    skip: 1,
    expect: () => [
      isA<SupplementCommissionResumeState>().having(
        (s) => s.error,
        'error',
        isA<OfflineException>(),
      ),
    ],
  );

  test('un second resume pendant le premier est ignoré', () async {
    when(
      () => repository.confirmCommission('bid-1', 'sup-1'),
    ).thenAnswer((_) async => _proposed);
    final cubit = build();
    final first = cubit.resume(_bid, _pending);
    await cubit.resume(_bid, _pending);
    await first;
    verify(() => repository.confirmCommission('bid-1', 'sup-1')).called(1);
    await cubit.close();
    await cubit.resume(_bid, _pending);
    expect(cubit.beginAuthorization(), isFalse);
  });
}
