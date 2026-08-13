import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements SubscriptionsRepository {}

SubscriptionItem _item(String id, {bool push = false}) => SubscriptionItem(
  travelerId: id,
  travelerName: 'T $id',
  isProAccount: false,
  averageRating: 4.5,
  ongoingTripsCount: 1,
  pushEnabled: push,
  hasNew: false,
  lastAnnouncement: null,
);

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'LoadSubscriptions → success avec items',
    build: () {
      when(
        () => repo.getMySubscriptions(),
      ).thenAnswer((_) async => [_item('t1')]);
      return SubscriptionsBloc(repo);
    },
    act: (b) => b.add(const LoadSubscriptions()),
    expect: () => [
      isA<SubscriptionsState>().having(
        (s) => s.status,
        'status',
        SubscriptionsStatus.loading,
      ),
      isA<SubscriptionsState>()
          .having((s) => s.status, 'status', SubscriptionsStatus.success)
          .having((s) => s.items.length, 'len', 1),
    ],
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'UnsubscribeTraveler retire l\'item',
    build: () {
      when(() => repo.unsubscribe('t1')).thenAnswer((_) async {});
      return SubscriptionsBloc(repo);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1'), _item('t2')],
    ),
    act: (b) => b.add(const UnsubscribeTraveler('t1')),
    expect: () => [
      isA<SubscriptionsState>().having(
        (s) => s.items.map((e) => e.travelerId),
        'ids',
        ['t2'],
      ),
    ],
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'ToggleSubscriptionPush met à jour pushEnabled',
    build: () {
      when(() => repo.setPush('t1', true)).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: true),
      );
      return SubscriptionsBloc(repo);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1')],
    ),
    act: (b) => b.add(const ToggleSubscriptionPush('t1', true)),
    expect: () => [
      isA<SubscriptionsState>().having(
        (s) => s.items.first.pushEnabled,
        'push',
        true,
      ),
    ],
  );

  // ─── Error paths ─────────────────────────────────────────────────────────────

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    '_onLoad catch branch → status error when getMySubscriptions throws',
    build: () {
      when(
        () => repo.getMySubscriptions(),
      ).thenThrow(Exception('network error'));
      return SubscriptionsBloc(repo);
    },
    act: (b) => b.add(const LoadSubscriptions()),
    expect: () => [
      isA<SubscriptionsState>().having(
        (s) => s.status,
        'status',
        SubscriptionsStatus.loading,
      ),
      isA<SubscriptionsState>()
          .having((s) => s.status, 'status', SubscriptionsStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    '_onUnsubscribe catch branch → status error when unsubscribe throws',
    build: () {
      when(() => repo.unsubscribe('t1')).thenThrow(Exception('server error'));
      return SubscriptionsBloc(repo);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1')],
    ),
    act: (b) => b.add(const UnsubscribeTraveler('t1')),
    expect: () => [
      isA<SubscriptionsState>()
          .having((s) => s.status, 'status', SubscriptionsStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    '_onTogglePush catch branch → status error when setPush throws',
    build: () {
      when(() => repo.setPush('t1', true)).thenThrow(Exception('toggle error'));
      return SubscriptionsBloc(repo);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1')],
    ),
    act: (b) => b.add(const ToggleSubscriptionPush('t1', true)),
    expect: () => [
      isA<SubscriptionsState>()
          .having((s) => s.status, 'status', SubscriptionsStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
