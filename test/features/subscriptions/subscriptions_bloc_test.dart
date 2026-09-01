import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements SubscriptionsRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

SubscriptionItem _item(String id, {bool push = false, bool hasNew = false}) =>
    SubscriptionItem(
      travelerId: id,
      travelerName: 'T $id',
      isProAccount: false,
      averageRating: 4.5,
      ongoingTripsCount: 1,
      pushEnabled: push,
      hasNew: hasNew,
      lastAnnouncement: null,
    );

void main() {
  late MockRepo repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'LoadSubscriptions → success avec items',
    build: () {
      when(
        () => repo.getMySubscriptions(),
      ).thenAnswer((_) async => [_item('t1')]);
      return SubscriptionsBloc(repo, analytics);
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
      return SubscriptionsBloc(repo, analytics);
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
      return SubscriptionsBloc(repo, analytics);
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
      return SubscriptionsBloc(repo, analytics);
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
      return SubscriptionsBloc(repo, analytics);
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
      return SubscriptionsBloc(repo, analytics);
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

  // ─── MarkAllSubscriptionsSeen ───────────────────────────────────────────────

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'MarkAllSubscriptionsSeen → toutes les pastilles retombent',
    build: () {
      when(() => repo.markAllSeen()).thenAnswer((_) async {});
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1', hasNew: true), _item('t2', hasNew: true)],
    ),
    act: (b) => b.add(const MarkAllSubscriptionsSeen()),
    expect: () => [
      isA<SubscriptionsState>().having(
        (s) => s.items.every((i) => !i.hasNew),
        'aucune pastille',
        isTrue,
      ),
    ],
    verify: (_) => verify(() => repo.markAllSeen()).called(1),
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'MarkAllSubscriptionsSeen en échec → les pastilles reviennent',
    build: () {
      when(() => repo.markAllSeen()).thenThrow(Exception('réseau'));
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1', hasNew: true)],
    ),
    act: (b) => b.add(const MarkAllSubscriptionsSeen()),
    expect: () => [
      // Optimiste d'abord…
      isA<SubscriptionsState>().having(
        (s) => s.items.single.hasNew,
        'pastille masquée',
        isFalse,
      ),
      // …puis restaurée, sans passer par un état d'erreur : l'action est sans
      // conséquence, un bandeau rouge serait disproportionné.
      isA<SubscriptionsState>()
          .having((s) => s.items.single.hasNew, 'pastille rendue', isTrue)
          .having((s) => s.status, 'statut', SubscriptionsStatus.success),
    ],
  );

  // ─── Tracking ───────────────────────────────────────────────────────────────

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'la bascule push est tracée avec l\'état rendu par le serveur',
    build: () {
      when(() => repo.setPush('t1', true)).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: true),
      );
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1')],
    ),
    act: (b) => b.add(const ToggleSubscriptionPush('t1', true)),
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.subscriptionPushToggled,
        properties: {'enabled': true},
      ),
    ).called(1),
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'le désabonnement est tracé une fois le serveur confirmé',
    build: () {
      when(() => repo.unsubscribe('t1')).thenAnswer((_) async {});
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1')],
    ),
    act: (b) => b.add(const UnsubscribeTraveler('t1')),
    verify: (_) => verify(
      () => analytics.logEvent(AnalyticsEvents.subscriptionRemoved),
    ).called(1),
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'le marquage global compte les pastilles réellement retirées',
    build: () {
      when(() => repo.markAllSeen()).thenAnswer((_) async {});
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [
        _item('t1', hasNew: true),
        _item('t2', hasNew: true),
        _item('t3'),
      ],
    ),
    act: (b) => b.add(const MarkAllSubscriptionsSeen()),
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.subscriptionsMarkedAllSeen,
        properties: {'count': 2},
      ),
    ).called(1),
  );

  blocTest<SubscriptionsBloc, SubscriptionsState>(
    'un marquage global en échec n\'est pas tracé',
    build: () {
      when(() => repo.markAllSeen()).thenThrow(Exception('réseau'));
      return SubscriptionsBloc(repo, analytics);
    },
    seed: () => SubscriptionsState(
      status: SubscriptionsStatus.success,
      items: [_item('t1', hasNew: true)],
    ),
    act: (b) => b.add(const MarkAllSubscriptionsSeen()),
    verify: (_) => verifyNever(
      () => analytics.logEvent(
        AnalyticsEvents.subscriptionsMarkedAllSeen,
        properties: any(named: 'properties'),
      ),
    ),
  );
}
