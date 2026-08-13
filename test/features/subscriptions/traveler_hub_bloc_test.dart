import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_hub_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements SubscriptionsRepository {}

TravelerAnnouncement _ann() => TravelerAnnouncement(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 6),
  pricePerKg: 8,
  availableKg: 5,
  status: 'ACTIVE',
);

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  blocTest<TravelerHubBloc, TravelerHubState>(
    'LoadTravelerHub charge statut + annonces et markSeen si abonné',
    build: () {
      when(() => repo.getStatus('t1')).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: false),
      );
      when(
        () => repo.getTravelerAnnouncements('t1'),
      ).thenAnswer((_) async => [_ann()]);
      when(() => repo.markSeen('t1')).thenAnswer((_) async {});
      return TravelerHubBloc(repo);
    },
    act: (b) => b.add(const LoadTravelerHub('t1')),
    expect: () => [
      isA<TravelerHubState>().having(
        (s) => s.status,
        'status',
        TravelerHubStatus.loading,
      ),
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.success)
          .having((s) => s.subscribed, 'subscribed', true)
          .having((s) => s.announcements.length, 'anns', 1),
    ],
    verify: (_) => verify(() => repo.markSeen('t1')).called(1),
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    'HubSubscribePressed passe subscribed=true',
    build: () {
      when(() => repo.subscribe('t1')).thenAnswer((_) async {});
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(status: TravelerHubStatus.success),
    act: (b) => b.add(const HubSubscribePressed()),
    expect: () => [
      isA<TravelerHubState>().having((s) => s.subscribed, 'subscribed', true),
    ],
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    'HubTogglePush met pushEnabled',
    build: () {
      when(() => repo.setPush('t1', true)).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: true),
      );
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(
      status: TravelerHubStatus.success,
      subscribed: true,
    ),
    act: (b) => b.add(const HubTogglePush(true)),
    expect: () => [
      isA<TravelerHubState>().having((s) => s.pushEnabled, 'push', true),
    ],
  );

  // ─── Error paths ─────────────────────────────────────────────────────────────

  blocTest<TravelerHubBloc, TravelerHubState>(
    '_onLoad catch branch → error when getStatus throws',
    build: () {
      when(() => repo.getStatus('t1')).thenThrow(Exception('network'));
      when(
        () => repo.getTravelerAnnouncements('t1'),
      ).thenAnswer((_) async => []);
      return TravelerHubBloc(repo);
    },
    act: (b) => b.add(const LoadTravelerHub('t1')),
    expect: () => [
      isA<TravelerHubState>().having(
        (s) => s.status,
        'status',
        TravelerHubStatus.loading,
      ),
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    '_onLoad → markSeen NOT called when not subscribed',
    build: () {
      when(() => repo.getStatus('t1')).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: false, pushEnabled: false),
      );
      when(
        () => repo.getTravelerAnnouncements('t1'),
      ).thenAnswer((_) async => []);
      return TravelerHubBloc(repo);
    },
    act: (b) => b.add(const LoadTravelerHub('t1')),
    expect: () => [
      isA<TravelerHubState>().having(
        (s) => s.status,
        'status',
        TravelerHubStatus.loading,
      ),
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.success)
          .having((s) => s.subscribed, 'subscribed', false),
    ],
    verify: (_) => verifyNever(() => repo.markSeen(any())),
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    'HubUnsubscribePressed → subscribed false, pushEnabled false',
    build: () {
      when(() => repo.unsubscribe('t1')).thenAnswer((_) async {});
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(
      status: TravelerHubStatus.success,
      subscribed: true,
      pushEnabled: true,
    ),
    act: (b) => b.add(const HubUnsubscribePressed()),
    expect: () => [
      isA<TravelerHubState>()
          .having((s) => s.subscribed, 'subscribed', false)
          .having((s) => s.pushEnabled, 'pushEnabled', false),
    ],
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    '_onSubscribe catch branch → error when subscribe throws',
    build: () {
      when(() => repo.subscribe('t1')).thenThrow(Exception('subscribe error'));
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(status: TravelerHubStatus.success),
    act: (b) => b.add(const HubSubscribePressed()),
    expect: () => [
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    '_onUnsubscribe catch branch → error when unsubscribe throws',
    build: () {
      when(
        () => repo.unsubscribe('t1'),
      ).thenThrow(Exception('unsubscribe error'));
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(
      status: TravelerHubStatus.success,
      subscribed: true,
    ),
    act: (b) => b.add(const HubUnsubscribePressed()),
    expect: () => [
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<TravelerHubBloc, TravelerHubState>(
    '_onTogglePush catch branch → error when setPush throws',
    build: () {
      when(() => repo.setPush('t1', true)).thenThrow(Exception('push error'));
      return TravelerHubBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerHubState(
      status: TravelerHubStatus.success,
      subscribed: true,
    ),
    act: (b) => b.add(const HubTogglePush(true)),
    expect: () => [
      isA<TravelerHubState>()
          .having((s) => s.status, 'status', TravelerHubStatus.error)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
