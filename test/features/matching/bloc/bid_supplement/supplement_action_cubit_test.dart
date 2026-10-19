import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
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
  paymentMethod: BidPaymentMethod.mobileMoney,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _supplement = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  grossAmount: 16.8,
);

BidSupplement _with(BidSupplementStatus status) =>
    BidSupplement(id: 'sup-1', status: status, grossAmount: 16.8);

void main() {
  late _MockRepository repository;
  late _MockAnalyticsService analytics;

  setUp(() {
    repository = _MockRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  SupplementActionCubit build() => SupplementActionCubit(repository, analytics);

  test('viewed : une seule fois par encart', () async {
    final cubit = build();
    cubit.viewed(isSender: true, status: BidSupplementStatus.proposed);
    cubit.viewed(isSender: true, status: BidSupplementStatus.declined);

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementViewed,
        properties: {'role': 'sender', 'status': 'proposed'},
      ),
    ).called(1);
    verifyNoMoreInteractions(analytics);
    await cubit.close();
  });

  test('viewed côté voyageur', () async {
    final cubit = build();
    cubit.viewed(isSender: false, status: BidSupplementStatus.paid);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementViewed,
        properties: {'role': 'traveler', 'status': 'paid'},
      ),
    ).called(1);
    await cubit.close();
  });

  blocTest<SupplementActionCubit, SupplementActionState>(
    'withdraw : busy puis done, tracé',
    setUp: () => when(
      () => repository.withdraw(any(), any()),
    ).thenAnswer((_) async => _with(BidSupplementStatus.withdrawn)),
    build: build,
    act: (c) => c.withdraw(_bid, _supplement),
    expect: () => [
      isA<SupplementActionState>().having((s) => s.isBusy, 'busy', isTrue),
      isA<SupplementActionState>().having(
        (s) => s.status,
        'status',
        SupplementActionStatus.done,
      ),
    ],
    verify: (_) {
      verify(() => repository.withdraw('bid-1', 'sup-1')).called(1);
      verify(
        () => analytics.logEvent(AnalyticsEvents.bidSupplementWithdrawn),
      ).called(1);
    },
  );

  blocTest<SupplementActionCubit, SupplementActionState>(
    'decline : done, tracé avec le moyen de paiement',
    setUp: () => when(
      () => repository.decline(any(), any()),
    ).thenAnswer((_) async => _with(BidSupplementStatus.declined)),
    build: build,
    act: (c) => c.decline(_bid, _supplement),
    skip: 1,
    expect: () => [
      isA<SupplementActionState>().having(
        (s) => s.status,
        'status',
        SupplementActionStatus.done,
      ),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementDeclined,
        properties: {'payment_method': 'mobileMoney'},
      ),
    ).called(1),
  );

  blocTest<SupplementActionCubit, SupplementActionState>(
    'échec : failure avec l\'erreur, tracé',
    setUp: () => when(
      () => repository.decline(any(), any()),
    ).thenThrow(const ConflictException('x', code: 'supplement-not-pending')),
    build: build,
    act: (c) => c.decline(_bid, _supplement),
    skip: 1,
    expect: () => [
      isA<SupplementActionState>()
          .having((s) => s.status, 'status', SupplementActionStatus.failure)
          .having((s) => s.error?.code, 'code', 'supplement-not-pending'),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.bidSupplementActionFailed,
        properties: {
          'action': 'decline',
          'error_code': 'supplement-not-pending',
        },
      ),
    ).called(1),
  );

  blocTest<SupplementActionCubit, SupplementActionState>(
    'une action en cours ignore le second tap',
    setUp: () => when(
      () => repository.withdraw(any(), any()),
    ).thenAnswer((_) async => _with(BidSupplementStatus.withdrawn)),
    build: build,
    seed: () =>
        const SupplementActionState(status: SupplementActionStatus.busy),
    act: (c) => c.withdraw(_bid, _supplement),
    expect: () => const <SupplementActionState>[],
    verify: (_) => verifyNever(() => repository.withdraw(any(), any())),
  );
}
