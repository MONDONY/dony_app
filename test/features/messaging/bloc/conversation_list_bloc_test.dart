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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
        when(
          () => convRepo.getConversationPage(),
        ).thenThrow(Exception('network'));
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
        when(
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([]));
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
            filter: ConversationFilter.done,
            searchQuery: 'test',
          ),
        );
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>()
            // « En cours » par défaut (YADONY-FLUTTER-PROD-W).
            .having((s) => s.filter, 'filter', ConversationFilter.active)
            .having((s) => s.searchQuery, 'searchQuery', ''),
        isA<ConversationListLoaded>()
            .having((s) => s.filter, 'filter', ConversationFilter.done)
            .having((s) => s.searchQuery, 'searchQuery', 'test'),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationArchiveRequested retire la conversation localement et appelle l\'API',
      build: () {
        when(
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
            filter: ConversationFilter.done,
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
          ConversationFilter.done,
        ),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.done,
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationFilter.active ne montre que les conversations en cours',
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => ConversationPage([convActive, convDone]));
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
        // « En cours » par défaut : le fil livré et lu est déjà rangé.
        isA<ConversationListLoaded>().having(
          (s) => s.displayed.length,
          'en cours par défaut',
          1,
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
      'ConversationFilter.active garde un colis remis, en route, arrivé ou une '
      'offre en attente',
      build: () {
        when(
          () => convRepo.getArchivedConversations(),
        ).thenAnswer((_) async => []);
        ConversationModel withStatus(String id, String? status) =>
            ConversationModel(
              id: id,
              bidId: 'bid-$id',
              firestoreConversationId: 'conv_$id',
              otherParticipant: _participant,
              bidStatus: status,
            );
        when(() => convRepo.getConversationPage()).thenAnswer(
          (_) async => ConversationPage([
            withStatus('accepted', 'BID_ACCEPTED'),
            withStatus('transit', 'IN_TRANSIT'),
            withStatus('arrived', 'TRIP_ARRIVED'),
            withStatus('done', 'DELIVERY_CONFIRMED'),
            withStatus('cancelled', 'TRIP_CANCELLED'),
            withStatus('pending', null),
          ]),
        );
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
      skip: 2,
      expect: () => [
        isA<ConversationListLoaded>().having(
          (s) => s.displayed.map((c) => c.id).toList(),
          'en cours',
          // Offre en attente sans bidStatus : pas terminée, donc en cours.
          ['accepted', 'transit', 'arrived', 'pending'],
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'ConversationFilter.done ne montre que les conversations terminées et lues',
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => ConversationPage([convDone, convActive]));
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
          (s) => s.displayed.single.bidStatus,
          'en cours par défaut',
          'BID_ACCEPTED',
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
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
            filter: ConversationFilter.done,
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
          ConversationFilter.done,
        ),
        isA<ConversationListLoaded>().having(
          (s) => s.filter,
          'filter',
          ConversationFilter.done,
        ),
      ],
    );
  });

  // ── Compteurs de non-lus orphelins ───────────────────────────────────────
  group('ConversationListBloc — nettoyage des non-lus', () {
    setUp(() {
      when(
        () => convRepo.getArchivedConversations(),
      ).thenAnswer((_) async => []);
      when(
        () => firestoreRepo.perConversationUnreadStream(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestoreRepo.cleanupOrphanUnreadCounters(
          currentUserUid: any(named: 'currentUserUid'),
          validFirestoreIds: any(named: 'validFirestoreIds'),
        ),
      ).thenAnswer((_) async {});
    });

    test('liste complète : les fils absents sont nettoyés', () async {
      when(
        () => convRepo.getConversationPage(),
      ).thenAnswer((_) async => const ConversationPage([_conv]));
      final bloc = ConversationListBloc(
        convRepo,
        firestoreRepo,
        currentUid: () => 'me',
      );

      bloc.add(const ConversationsLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(
        () => firestoreRepo.cleanupOrphanUnreadCounters(
          currentUserUid: 'me',
          validFirestoreIds: {'conv_bid-1'},
        ),
      ).called(1);
      verify(() => firestoreRepo.perConversationUnreadStream('me')).called(1);
      await bloc.close();
    });

    test(
      'liste incomplète : aucun compteur remis à zéro, non-lus toujours suivis',
      () async {
        // Une seule page chargée : les fils des pages suivantes ne sont pas
        // supprimés, leurs non-lus doivent survivre.
        when(() => convRepo.getConversationPage()).thenAnswer(
          (_) async => const ConversationPage([_conv], isComplete: false),
        );
        final bloc = ConversationListBloc(
          convRepo,
          firestoreRepo,
          currentUid: () => 'me',
        );

        bloc.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => firestoreRepo.cleanupOrphanUnreadCounters(
            currentUserUid: any(named: 'currentUserUid'),
            validFirestoreIds: any(named: 'validFirestoreIds'),
          ),
        );
        verify(() => firestoreRepo.perConversationUnreadStream('me')).called(1);
        await bloc.close();
      },
    );

    test(
      'échec du nettoyage (hors ligne) : rattrapé, liste chargée (FLUTTER-KW)',
      () async {
        when(
          () => convRepo.getConversationPage(),
        ).thenAnswer((_) async => const ConversationPage([_conv]));
        when(
          () => firestoreRepo.cleanupOrphanUnreadCounters(
            currentUserUid: any(named: 'currentUserUid'),
            validFirestoreIds: any(named: 'validFirestoreIds'),
          ),
        ).thenAnswer((_) => Future.error(StateError('unavailable')));
        final bloc = ConversationListBloc(
          convRepo,
          firestoreRepo,
          currentUid: () => 'me',
        );

        bloc.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state, isA<ConversationListLoaded>());
        verify(() => firestoreRepo.perConversationUnreadStream('me')).called(1);
        await bloc.close();
      },
    );
  });

  // ── Réaction aux blocages ────────────────────────────────────────────────
  group('ConversationListBloc — blocages', () {
    late BlockEventsService blockEvents;

    setUp(() {
      blockEvents = BlockEventsService();
      when(
        () => convRepo.getConversationPage(),
      ).thenAnswer((_) async => const ConversationPage([_conv]));
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
      // Le rechargement est silencieux (FLUTTER-PF) : pas de second Loading.
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>(),
      ],
      verify: (_) => verify(() => convRepo.getConversationPage()).called(2),
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'FLUTTER-PF : un rechargement après une liste chargée n\'émet pas Loading',
      build: () => ConversationListBloc(convRepo, firestoreRepo),
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        when(() => convRepo.getConversationPage()).thenAnswer(
          (_) async => ConversationPage([
            _conv,
            _conv.copyWith(lastMessagePreview: 'Nouveau message'),
          ]),
        );
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<ConversationListLoading>(),
        isA<ConversationListLoaded>(),
        isA<ConversationListLoaded>().having(
          (s) => s.conversations.last.lastMessagePreview,
          'dernier aperçu',
          'Nouveau message',
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'FLUTTER-PF : un rechargement raté garde la liste affichée',
      build: () => ConversationListBloc(convRepo, firestoreRepo),
      act: (b) async {
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        when(
          () => convRepo.getConversationPage(),
        ).thenThrow(Exception('hors ligne'));
        b.add(const ConversationsLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
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

      verifyNever(() => convRepo.getConversationPage());
    });

    test('sans service injecté, la construction reste possible', () {
      // GetIt n'est pas initialisé dans ce test : la résolution doit échouer en
      // silence plutôt que de faire tomber le bloc.
      final bloc = ConversationListBloc(convRepo, firestoreRepo);
      expect(bloc.state, isA<ConversationListInitial>());
      bloc.close();
    });
  });

  // YADONY-FLUTTER-PROD-W : deux filtres, « En cours » et « Terminés ».
  group('ConversationFilter — En cours / Terminés', () {
    ConversationModel conv({
      String? bidStatus,
      String? parcelStatus,
      bool unread = false,
      bool returnPending = false,
    }) => ConversationModel(
      id: 'c',
      bidId: 'b',
      firestoreConversationId: 'conv_b',
      otherParticipant: _participant,
      bidStatus: bidStatus,
      parcelStatus: parcelStatus,
      hasUnread: unread,
      unreadCount: unread ? 1 : 0,
      returnPending: returnPending,
    );

    void expectIn(ConversationModel c, ConversationFilter filter) {
      expect(filter.matches(c), isTrue, reason: '${filter.name} attendu');
      final other = ConversationFilter.values.firstWhere((f) => f != filter);
      expect(other.matches(c), isFalse, reason: 'jamais dans les deux');
    }

    test('annulé et lu → Terminés', () {
      expectIn(conv(bidStatus: 'TRIP_CANCELLED'), ConversationFilter.done);
    });

    test('livré et lu → Terminés', () {
      expectIn(conv(bidStatus: 'DELIVERY_CONFIRMED'), ConversationFilter.done);
    });

    test('livré mais non lu → En cours', () {
      expectIn(
        conv(bidStatus: 'DELIVERY_CONFIRMED', unread: true),
        ConversationFilter.active,
      );
    });

    test('offre en attente sans bidStatus → En cours', () {
      expectIn(conv(), ConversationFilter.active);
    });

    test('colis en route, même lu → En cours', () {
      expectIn(conv(bidStatus: 'IN_TRANSIT'), ConversationFilter.active);
    });

    test('retour de colis en cours → En cours', () {
      expectIn(
        conv(bidStatus: 'TRIP_CANCELLED', returnPending: true),
        ConversationFilter.active,
      );
    });

    test('repli sur parcelStatus → Terminés', () {
      expectIn(conv(parcelStatus: 'COMPLETED'), ConversationFilter.done);
    });

    test('« En cours » est le filtre par défaut', () {
      expect(
        const ConversationListLoaded([]).filter,
        ConversationFilter.active,
      );
    });
  });
}
