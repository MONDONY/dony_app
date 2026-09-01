import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedUsersRepository extends Mock
    implements BlockedUsersRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockBlockedUsersRepository mockRepo;
  late MockAnalyticsService mockAnalytics;
  late BlockEventsService blockEvents;

  /// Le service d'événements est un vrai (et non un mock) : c'est un simple
  /// StreamController, et les tests d'émission veulent observer le flux réel.
  BlockedUsersBloc makeBloc() =>
      BlockedUsersBloc(mockRepo, mockAnalytics, blockEvents);

  final user1 = BlockedUserModel(
    userId: 'u1',
    displayName: 'Mamadou D.',
    blockedAt: DateTime(2026, 5, 20),
  );
  final user2 = BlockedUserModel(
    userId: 'u2',
    displayName: 'Aïcha K.',
    blockedAt: DateTime(2026, 5, 10),
  );

  setUp(() {
    mockRepo = MockBlockedUsersRepository();
    mockAnalytics = MockAnalyticsService();
    blockEvents = BlockEventsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  tearDown(() => blockEvents.dispose());

  group('BlockedUsersBloc', () {
    // ── état initial ────────────────────────────────────────────────────────
    test('état initial est BlockedUsersInitial', () {
      final bloc = makeBloc();
      expect(bloc.state, isA<BlockedUsersInitial>());
      bloc.close();
    });

    // ── BlockedUsersLoadRequested — liste non vide ──────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUsersLoadRequested émet Loading puis Loaded avec la liste',
      setUp: () {
        when(
          () => mockRepo.fetchBlockedUsers(),
        ).thenAnswer((_) async => [user1, user2]);
      },
      build: () => makeBloc(),
      act: (bloc) => bloc.add(const BlockedUsersLoadRequested()),
      expect: () => [
        isA<BlockedUsersLoading>(),
        isA<BlockedUsersLoaded>()
            .having((s) => s.users.length, 'length', 2)
            .having((s) => s.users.first.userId, 'first.userId', 'u1'),
      ],
    );

    // ── BlockedUsersLoadRequested — liste vide ──────────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUsersLoadRequested émet Loading puis Loaded(vide)',
      setUp: () {
        when(() => mockRepo.fetchBlockedUsers()).thenAnswer((_) async => []);
      },
      build: () => makeBloc(),
      act: (bloc) => bloc.add(const BlockedUsersLoadRequested()),
      expect: () => [
        isA<BlockedUsersLoading>(),
        isA<BlockedUsersLoaded>().having((s) => s.users, 'users', isEmpty),
      ],
    );

    // ── BlockedUsersLoadRequested — erreur ──────────────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUsersLoadRequested émet Error si le repo lève une exception',
      setUp: () {
        when(
          () => mockRepo.fetchBlockedUsers(),
        ).thenThrow(Exception('Network error'));
      },
      build: () => makeBloc(),
      act: (bloc) => bloc.add(const BlockedUsersLoadRequested()),
      expect: () => [
        isA<BlockedUsersLoading>(),
        isA<BlockedUsersError>().having(
          (s) => s.message,
          'message',
          'Impossible de charger les utilisateurs bloqués',
        ),
      ],
    );

    // ── BlockedUserUnblockRequested — succès ────────────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUserUnblockRequested déblocage ok → Unblocking puis Loaded sans user débloqué',
      setUp: () {
        when(() => mockRepo.unblockUser('u1')).thenAnswer((_) async {});
        when(
          () => mockRepo.fetchBlockedUsers(),
        ).thenAnswer((_) async => [user2]);
      },
      build: () => makeBloc(),
      seed: () => BlockedUsersLoaded([user1, user2]),
      act: (bloc) => bloc.add(const BlockedUserUnblockRequested('u1')),
      expect: () => [
        isA<BlockedUsersUnblocking>()
            .having((s) => s.userId, 'userId', 'u1')
            .having((s) => s.currentUsers.length, 'currentUsers.length', 2),
        isA<BlockedUsersLoaded>()
            .having((s) => s.users.length, 'length', 1)
            .having((s) => s.users.first.userId, 'first.userId', 'u2'),
      ],
      verify: (_) {
        verify(() => mockRepo.unblockUser('u1')).called(1);
        verify(() => mockRepo.fetchBlockedUsers()).called(1);
      },
    );

    // ── BlockedUserUnblockRequested — erreur → rollback ─────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUserUnblockRequested rollback vers liste initiale si le backend échoue',
      setUp: () {
        when(
          () => mockRepo.unblockUser('u1'),
        ).thenThrow(Exception('Server error'));
      },
      build: () => makeBloc(),
      seed: () => BlockedUsersLoaded([user1, user2]),
      act: (bloc) => bloc.add(const BlockedUserUnblockRequested('u1')),
      expect: () => [
        isA<BlockedUsersUnblocking>(),
        isA<BlockedUsersLoaded>().having((s) => s.users.length, 'length', 2),
      ],
    );

    // ── BlockedUserBlockRequested — succès ──────────────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUserBlockRequested émet Blocking puis BlockSuccess',
      setUp: () {
        when(() => mockRepo.blockUser('u1')).thenAnswer((_) async {});
      },
      build: () => makeBloc(),
      act: (bloc) => bloc.add(const BlockedUserBlockRequested('u1')),
      expect: () => [
        isA<BlockedUserBlocking>().having((s) => s.userId, 'userId', 'u1'),
        isA<BlockedUserBlockSuccess>().having((s) => s.userId, 'userId', 'u1'),
      ],
      verify: (_) {
        verify(() => mockRepo.blockUser('u1')).called(1);
        verify(
          () => mockAnalytics.logEvent(
            'user_blocked',
            properties: any(named: 'properties'),
          ),
        ).called(1);
      },
    );

    // ── BlockedUserBlockRequested — échec ───────────────────────────────────
    blocTest<BlockedUsersBloc, BlockedUsersState>(
      'BlockedUserBlockRequested émet BlockFailure si le backend refuse',
      setUp: () {
        when(() => mockRepo.blockUser('u1')).thenThrow(Exception('Server'));
      },
      build: () => makeBloc(),
      act: (bloc) => bloc.add(const BlockedUserBlockRequested('u1')),
      expect: () => [
        isA<BlockedUserBlocking>(),
        isA<BlockedUserBlockFailure>().having(
          (s) => s.message,
          'message',
          'Une erreur est survenue. Réessaie plus tard.',
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockAnalytics.logEvent(
            'user_blocked',
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    // ── diffusion aux autres écrans ─────────────────────────────────────────
    test('un blocage réussi est diffusé sur BlockEventsService', () async {
      when(() => mockRepo.blockUser('u1')).thenAnswer((_) async {});
      final bloc = makeBloc();
      final change = blockEvents.changes.first;

      bloc.add(const BlockedUserBlockRequested('u1'));

      final received = await change;
      expect(received.userId, 'u1');
      expect(received.blocked, isTrue);
      await bloc.close();
    });

    test('un déblocage réussi est diffusé avec blocked à false', () async {
      when(() => mockRepo.unblockUser('u1')).thenAnswer((_) async {});
      when(() => mockRepo.fetchBlockedUsers()).thenAnswer((_) async => []);
      final bloc = makeBloc();
      final change = blockEvents.changes.first;

      bloc.add(const BlockedUserUnblockRequested('u1'));

      final received = await change;
      expect(received.userId, 'u1');
      expect(received.blocked, isFalse);
      await bloc.close();
    });

    test('un blocage en échec ne diffuse rien', () async {
      when(() => mockRepo.blockUser('u1')).thenThrow(Exception('Server'));
      final bloc = makeBloc();
      var emitted = false;
      final sub = blockEvents.changes.listen((_) => emitted = true);

      bloc.add(const BlockedUserBlockRequested('u1'));
      await bloc.stream.firstWhere((s) => s is BlockedUserBlockFailure);

      expect(emitted, isFalse);
      await sub.cancel();
      await bloc.close();
    });

    // ── equality ────────────────────────────────────────────────────────────
    test('BlockedUsersLoaded equality est correcte', () {
      final a = BlockedUsersLoaded([user1]);
      final b = BlockedUsersLoaded([user1]);
      final c = BlockedUsersLoaded([user2]);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('BlockedUsersError equality est correcte', () {
      const a = BlockedUsersError('msg');
      const b = BlockedUsersError('msg');
      const c = BlockedUsersError('autre');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
