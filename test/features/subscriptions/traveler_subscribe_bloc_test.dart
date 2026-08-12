import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements SubscriptionsRepository {}

void main() {
  late MockRepo repo;
  setUp(() => repo = MockRepo());

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'LoadSubscribeStatus charge le statut (abonné + push)',
    build: () {
      when(() => repo.getStatus('t1')).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: true),
      );
      return TravelerSubscribeBloc(repo);
    },
    act: (b) => b.add(const LoadSubscribeStatus('t1')),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.loading),
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.ready)
          .having((s) => s.subscribed, 'subscribed', true)
          .having((s) => s.pushEnabled, 'pushEnabled', true),
    ],
    verify: (b) => expect(b.travelerId, 't1'),
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'LoadSubscribeStatus passe en erreur si le repo échoue',
    build: () {
      when(() => repo.getStatus('t1')).thenThrow(Exception('boom'));
      return TravelerSubscribeBloc(repo);
    },
    act: (b) => b.add(const LoadSubscribeStatus('t1')),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.loading),
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.error),
    ],
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'SubscribePressed passe subscribed=true',
    build: () {
      when(() => repo.subscribe('t1')).thenAnswer((_) async {});
      return TravelerSubscribeBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
    ),
    act: (b) => b.add(const SubscribePressed()),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.subscribed, 'subscribed', true),
    ],
    verify: (_) => verify(() => repo.subscribe('t1')).called(1),
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'SubscribePressed émet une erreur si le repo échoue',
    build: () {
      when(() => repo.subscribe('t1')).thenThrow(Exception('boom'));
      return TravelerSubscribeBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
    ),
    act: (b) => b.add(const SubscribePressed()),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.error),
    ],
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'UnsubscribePressed remet subscribed et pushEnabled à false',
    build: () {
      when(() => repo.unsubscribe('t1')).thenAnswer((_) async {});
      return TravelerSubscribeBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    ),
    act: (b) => b.add(const UnsubscribePressed()),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.subscribed, 'subscribed', false)
          .having((s) => s.pushEnabled, 'pushEnabled', false),
    ],
    verify: (_) => verify(() => repo.unsubscribe('t1')).called(1),
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'TogglePushPressed met à jour pushEnabled depuis la réponse repo',
    build: () {
      when(() => repo.setPush('t1', true)).thenAnswer(
        (_) async =>
            const SubscriptionStatus(subscribed: true, pushEnabled: true),
      );
      return TravelerSubscribeBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
    ),
    act: (b) => b.add(const TogglePushPressed(true)),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.pushEnabled, 'pushEnabled', true),
    ],
    verify: (_) => verify(() => repo.setPush('t1', true)).called(1),
  );

  blocTest<TravelerSubscribeBloc, TravelerSubscribeState>(
    'TogglePushPressed émet une erreur si le repo échoue',
    build: () {
      when(() => repo.setPush('t1', false)).thenThrow(Exception('boom'));
      return TravelerSubscribeBloc(repo)..travelerId = 't1';
    },
    seed: () => const TravelerSubscribeState(
      status: TravelerSubscribeStatus.ready,
      subscribed: true,
      pushEnabled: true,
    ),
    act: (b) => b.add(const TogglePushPressed(false)),
    expect: () => [
      isA<TravelerSubscribeState>()
          .having((s) => s.status, 'status', TravelerSubscribeStatus.error),
    ],
  );
}
