import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirestoreChatRepository extends Mock implements FirestoreChatRepository {}
class MockConversationRepository extends Mock implements ConversationRepository {}

void main() {
  late MockFirestoreChatRepository firestoreRepo;
  late MockConversationRepository convRepo;

  setUp(() {
    firestoreRepo = MockFirestoreChatRepository();
    convRepo = MockConversationRepository();
  });

  final msg = MessageModel(
    id: 'msg1',
    senderId: 'uid-1',
    body: 'Hello',
    type: MessageType.text,
    sentAt: DateTime(2026, 4, 29),
  );

  group('ChatBloc', () {
    blocTest<ChatBloc, ChatState>(
      'emits Loading then Loaded when subscription fires',
      build: () {
        when(() => firestoreRepo.messagesStream('conv_bid1'))
            .thenAnswer((_) => Stream.value([msg]));
        return ChatBloc(firestoreRepo, convRepo);
      },
      act: (b) => b.add(const ChatSubscribeRequested('conv_bid1')),
      expect: () => [
        const ChatLoading(),
        isA<ChatLoaded>().having((s) => s.messages.length, 'count', 1),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'calls markConversationRead when subscribing with a non-empty uid',
      build: () {
        when(() => firestoreRepo.messagesStream(any()))
            .thenAnswer((_) => Stream.value([]));
        when(() => firestoreRepo.markConversationRead(any(), any()))
            .thenAnswer((_) async {});
        return ChatBloc(firestoreRepo, convRepo);
      },
      act: (b) => b.add(
        const ChatSubscribeRequested('conv_bid1', currentUserUid: 'uid-me'),
      ),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>(),
      ],
      verify: (_) {
        verify(() => firestoreRepo.markConversationRead('conv_bid1', 'uid-me'))
            .called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'does NOT call markConversationRead when uid is empty',
      build: () {
        when(() => firestoreRepo.messagesStream(any()))
            .thenAnswer((_) => Stream.value([]));
        return ChatBloc(firestoreRepo, convRepo);
      },
      act: (b) => b.add(
        const ChatSubscribeRequested('conv_bid1'),
      ),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>(),
      ],
      verify: (_) {
        verifyNever(() => firestoreRepo.markConversationRead(any(), any()));
      },
    );

    blocTest<ChatBloc, ChatState>(
      'sendText calls firestoreRepo and updates lastMessage',
      build: () {
        when(() => firestoreRepo.sendTextMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              body: any(named: 'body'),
            )).thenAnswer((_) async {});
        when(() => convRepo.updateLastMessage(any(), any()))
            .thenAnswer((_) async {});
        return ChatBloc(firestoreRepo, convRepo);
      },
      act: (b) => b.add(const ChatTextSendRequested(
        firestoreConversationId: 'conv_bid1',
        conversationId: 'conv-id-1',
        senderFirebaseUid: 'uid-1',
        body: 'Hello world',
      )),
      expect: () => [],
      verify: (_) {
        verify(() => firestoreRepo.sendTextMessage(
              firestoreConversationId: 'conv_bid1',
              senderFirebaseUid: 'uid-1',
              body: 'Hello world',
            )).called(1);
        verify(() => convRepo.updateLastMessage('conv-id-1', 'Hello world'))
            .called(1);
      },
    );
  });
}
