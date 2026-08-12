import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/blocked_users_bloc.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedUsersRepository extends Mock
    implements BlockedUsersRepository {}

void main() {
  late MockBlockedUsersRepository mockRepo;

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
  });

  group('BlockedUsersBloc', () {
    // ── état initial ────────────────────────────────────────────────────────
    test('état initial est BlockedUsersInitial', () {
      final bloc = BlockedUsersBloc(mockRepo);
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
      build: () => BlockedUsersBloc(mockRepo),
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
      build: () => BlockedUsersBloc(mockRepo),
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
      build: () => BlockedUsersBloc(mockRepo),
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
      build: () => BlockedUsersBloc(mockRepo),
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
      build: () => BlockedUsersBloc(mockRepo),
      seed: () => BlockedUsersLoaded([user1, user2]),
      act: (bloc) => bloc.add(const BlockedUserUnblockRequested('u1')),
      expect: () => [
        isA<BlockedUsersUnblocking>(),
        isA<BlockedUsersLoaded>().having((s) => s.users.length, 'length', 2),
      ],
    );

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
