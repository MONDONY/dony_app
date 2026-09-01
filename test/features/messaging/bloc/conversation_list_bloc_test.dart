import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/block_events_service.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Bob D');
const _conv = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

void main() {
  late MockConversationRepository convRepo;
  late MockFirestoreChatRepository firestoreRepo;

  setUp(() {
    convRepo = MockConversationRepository();
    firestoreRepo = MockFirestoreChatRepository();
  });

  group('ConversationListBloc', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'emits Loading → Loaded when load succeeds',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) => b.add(const ConversationsLoadRequested()),
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'emits Loading → Error when getConversations throws',
      build: () {
        when(() => convRepo.getConversations()).thenThrow(Exception('network'));
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) => b.add(const ConversationsLoadRequested()),
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListError>(),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'emits updated Loaded state with hasUnread=true when unread count > 0',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationsUnreadUpdated({'conv_bid-1': 3}));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>().having(
          (s) => s.conversations.first.hasUnread,
          'hasUnread',
          true,
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationDeleteRequested removes the conversation locally and calls API',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => firestoreRepo.markConversationRead(any(), any()),
        ).thenAnswer((_) async {});
        when(() => convRepo.deleteConversation(any())).thenAnswer((_) async {});
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationDeleteRequested('conv-1'));
      },
      verify: (_) {
        // Backend deletion still happens.
        verify(() => convRepo.deleteConversation('conv-1')).called(1);
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>().having(
          (s) => s.conversations.length,
          'conversations.length',
          0,
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationsUnreadUpdated does nothing when no conversations loaded',
      build: () {
        when(() => convRepo.getConversations()).thenAnswer((_) async => []);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) => b.add(const ConversationsUnreadUpdated({'conv_bid-1': 2})),
      expect: () => <ConversationListState>[],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationFilterChanged met à jour filter et searchQuery dans le state',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.unread,
            searchQuery: 'test',
          ),
        );
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>()
            .having((s) => s.filter, 'filter', ConversationFilter.all)
            .having((s) => s.searchQuery, 'searchQuery', ''),
        isA<ConversationListLoaded>()
            .having((s) => s.filter, 'filter', ConversationFilter.unread)
            .having((s) => s.searchQuery, 'searchQuery', 'test'),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationArchiveRequested retire la conversation localement et appelle l\'API',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => convRepo.archiveConversation(any()),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationArchiveRequested('conv-1'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (_) {
        verify(() => convRepo.archiveConversation('conv-1')).called(1);
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>().having(
          (s) => s.conversations.length,
          'length',
          1,
        ),
        isA<ConversationListLoaded>()
            .having((s) => s.conversations.length, 'conversations', 0)
            .having((s) => s.archivedConversations.length, 'archived', 1),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'filter est préservé après ConversationArchiveRequested',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => convRepo.archiveConversation(any()),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.unread,
            searchQuery: '',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const ConversationArchiveRequested('conv-1'));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.unread,
        ),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.unread,
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationFilter.active ne montre que les conversations BID_ACCEPTED',
      build: () {
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        final convActive = ConversationModel(
          id: _conv.id,
          bidId: _conv.bidId,
          firestoreConversationId: _conv.firestoreConversationId,
          otherParticipant: _conv.otherParticipant,
          bidStatus: 'BID_ACCEPTED',
        );
        const convDone = ConversationModel(
          id: 'conv-done',
          bidId: 'bid-done',
          firestoreConversationId: 'conv_bid-done',
          otherParticipant: _participant,
          bidStatus: 'DELIVERY_CONFIRMED',
        );
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [convActive, convDone]);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.active,
            searchQuery: '',
          ),
        );
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>().having(
          (s) => s.displayed.length,
          'all',
          2,
        ),
        isA<ConversationListLoaded>()
            .having((s) => s.displayed.length, 'active only', 1)
            .having(
              (s) => s.displayed.first.bidStatus,
              'bidStatus',
              'BID_ACCEPTED',
            ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationFilter.done ne montre que les conversations DELIVERY_CONFIRMED',
      build: () {
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        final convDone = ConversationModel(
          id: _conv.id,
          bidId: _conv.bidId,
          firestoreConversationId: _conv.firestoreConversationId,
          otherParticipant: _conv.otherParticipant,
          bidStatus: 'DELIVERY_CONFIRMED',
        );
        const convActive = ConversationModel(
          id: 'conv-active',
          bidId: 'bid-active',
          firestoreConversationId: 'conv_bid-active',
          otherParticipant: _participant,
          bidStatus: 'BID_ACCEPTED',
        );
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [convDone, convActive]);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.done,
            searchQuery: '',
          ),
        );
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>().having(
          (s) => s.displayed.length,
          'all',
          2,
        ),
        isA<ConversationListLoaded>()
            .having((s) => s.displayed.length, 'done only', 1)
            .having(
              (s) => s.displayed.first.bidStatus,
              'bidStatus',
              'DELIVERY_CONFIRMED',
            ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationUnarchiveRequested remet la conversation dans la liste et appelle l\'API',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => convRepo.archiveConversation(any()),
        ).thenAnswer((_) async {});
        when(
          () => convRepo.unarchiveConversation(any()),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationArchiveRequested('conv-1'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationUnarchiveRequested('conv-1'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (_) {
        verify(() => convRepo.unarchiveConversation('conv-1')).called(1);
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>().having(
          (s) => s.conversations.length,
          'initial',
          1,
        ),
        isA<ConversationListLoaded>()
            .having((s) => s.conversations.length, 'après archive', 0)
            .having((s) => s.archivedConversations.length, 'archived', 1),
        isA<ConversationListLoaded>()
            .having((s) => s.conversations.length, 'après désarchive', 1)
            .having((s) => s.archivedConversations.length, 'archived vide', 0),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'filter est préservé après ConversationsUnreadUpdated',
      build: () {
        when(
          () => convRepo.getConversations(),
        ).thenAnswer((_) async => [_conv]);
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        when(
          () => firestoreRepo.perConversationUnreadStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(
          const ConversationFilterChanged(
            filter: ConversationFilter.unread,
            searchQuery: '',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        b.add(const ConversationsUnreadUpdated({'conv_bid-1': 2}));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.unread,
        ),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.unread,
        ),
      ],
    );
  });

  // ── Réaction aux blocages ────────────────────────────────────────────────
  group('ConversationListBloc — blocages', () {
    late BlockEventsService blockEvents;

    setUp(() {
      blockEvents = BlockEventsService();
      when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
      when(
        () => convRepo.getArchivedConversations(),
      ).thenAnswer((_) async => []);
      when(
        () => firestoreRepo.perConversationUnreadStream(any()),
      ).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() => blockEvents.dispose());

    blocTest<ConversationListBloc, ConversationListState>(
      'un blocage relance un chargement de la liste',
      build: () => ConversationListBloc(
        convRepo,
        firestoreRepo,
        blockEvents: blockEvents,
      ),
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        blockEvents.notifyBlocked('uid-1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'un déblocage relance aussi un chargement',
      build: () => ConversationListBloc(
        convRepo,
        firestoreRepo,
        blockEvents: blockEvents,
      ),
      act: (b) async {
        blockEvents.notifyUnblocked('uid-1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
      ],
    );

    test('aucun rechargement après la fermeture du bloc', () async {
      final bloc = ConversationListBloc(
        convRepo,
        firestoreRepo,
        blockEvents: blockEvents,
      );
      await bloc.close();

      blockEvents.notifyBlocked('uid-1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => convRepo.getConversations());
    });

    test('sans service injecté, la construction reste possible', () {
      // GetIt n'est pas initialisé dans ce test : la résolution doit échouer en
      // silence plutôt que de faire tomber le bloc.
      final bloc = ConversationListBloc(convRepo, firestoreRepo);
      expect(bloc.state, isA<ConversationListInitial>());
      bloc.close();
    });
  });
}
