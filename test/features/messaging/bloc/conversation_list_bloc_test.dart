import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationRepository extends Mock implements ConversationRepository {}

class MockFirestoreChatRepository extends Mock implements FirestoreChatRepository {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Bob D');
final _conv = ConversationModel(
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
        when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
        when(() => firestoreRepo.perConversationUnreadStream(any()))
            .thenAnswer((_) => const Stream.empty());
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
        when(() => firestoreRepo.perConversationUnreadStream(any()))
            .thenAnswer((_) => const Stream.empty());
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
        when(() => convRepo.getConversations()).thenAnswer((_) async => [_conv]);
        when(() => firestoreRepo.perConversationUnreadStream(any()))
            .thenAnswer((_) => const Stream.empty());
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
      'ConversationsUnreadUpdated does nothing when no conversations loaded',
      build: () {
        when(() => convRepo.getConversations()).thenAnswer((_) async => []);
        when(() => firestoreRepo.perConversationUnreadStream(any()))
            .thenAnswer((_) => const Stream.empty());
        return ConversationListBloc(convRepo, firestoreRepo);
      },
      act: (b) => b.add(const ConversationsUnreadUpdated({'conv_bid-1': 2})),
      expect: () => <ConversationListState>[],
    );
  });
}
