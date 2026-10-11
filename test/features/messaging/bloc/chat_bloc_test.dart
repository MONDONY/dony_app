import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

void main() {
  late MockFirestoreChatRepository firestoreRepo;
  late MockConversationRepository convRepo;

  setUp(() {
    firestoreRepo = MockFirestoreChatRepository();
    convRepo = MockConversationRepository();
  });

  ChatBloc makeBloc() {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return ChatBloc(firestoreRepo, convRepo, analytics);
  }

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
        when(
          () => firestoreRepo.messagesStream('conv_bid1'),
        ).thenAnswer((_) => Stream.value([msg]));
        when(
          () => firestoreRepo.conversationDeletedStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return makeBloc();
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
        when(
          () => firestoreRepo.messagesStream(any()),
        ).thenAnswer((_) => Stream.value([]));
        when(
          () => firestoreRepo.markConversationRead(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.markMessagesRead(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            currentUserUid: any(named: 'currentUserUid'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.conversationDeletedStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return makeBloc();
      },
      act: (b) => b.add(
        const ChatSubscribeRequested('conv_bid1', currentUserUid: 'uid-me'),
      ),
      expect: () => [isA<ChatLoading>(), isA<ChatLoaded>()],
      verify: (_) {
        verify(
          () => firestoreRepo.markConversationRead('conv_bid1', 'uid-me'),
        ).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'calls markConversationRead even in read-only '
      '(sinon le unread_* d\'une conv à interlocuteur supprimé ne redescend jamais)',
      build: () {
        when(
          () => firestoreRepo.messagesStream(any()),
        ).thenAnswer((_) => Stream.value([]));
        when(
          () => firestoreRepo.markConversationRead(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => firestoreRepo.markMessagesRead(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            currentUserUid: any(named: 'currentUserUid'),
          ),
        ).thenAnswer((_) async {});
        return makeBloc();
      },
      act: (b) => b.add(
        const ChatSubscribeRequested(
          'conv_bid1',
          currentUserUid: 'uid-me',
          isReadOnly: true,
        ),
      ),
      expect: () => [isA<ChatLoading>(), isA<ChatReadOnly>()],
      verify: (_) {
        verify(
          () => firestoreRepo.markConversationRead('conv_bid1', 'uid-me'),
        ).called(1);
        verify(
          () => firestoreRepo.markMessagesRead(
            firestoreConversationId: 'conv_bid1',
            currentUserUid: 'uid-me',
          ),
        ).called(1);
        // en read-only, pas d'abonnement au stream de suppression
        verifyNever(() => firestoreRepo.conversationDeletedStream(any()));
      },
    );

    blocTest<ChatBloc, ChatState>(
      'does NOT call markConversationRead when uid is empty',
      build: () {
        when(
          () => firestoreRepo.messagesStream(any()),
        ).thenAnswer((_) => Stream.value([]));
        when(
          () => firestoreRepo.conversationDeletedStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return makeBloc();
      },
      act: (b) => b.add(const ChatSubscribeRequested('conv_bid1')),
      expect: () => [isA<ChatLoading>(), isA<ChatLoaded>()],
      verify: (_) {
        verifyNever(() => firestoreRepo.markConversationRead(any(), any()));
      },
    );

    blocTest<ChatBloc, ChatState>(
      'sendText calls firestoreRepo and updates lastMessage',
      build: () {
        when(
          () => firestoreRepo.sendTextMessage(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            senderFirebaseUid: any(named: 'senderFirebaseUid'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => convRepo.updateLastMessage(any(), any()),
        ).thenAnswer((_) async {});
        return makeBloc();
      },
      act: (b) => b.add(
        const ChatTextSendRequested(
          firestoreConversationId: 'conv_bid1',
          conversationId: 'conv-id-1',
          senderFirebaseUid: 'uid-1',
          body: 'Hello world',
        ),
      ),
      expect: () => [],
      verify: (_) {
        verify(
          () => firestoreRepo.sendTextMessage(
            firestoreConversationId: 'conv_bid1',
            senderFirebaseUid: 'uid-1',
            body: 'Hello world',
          ),
        ).called(1);
        verify(
          () => convRepo.updateLastMessage('conv-id-1', 'Hello world'),
        ).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'sendText truncates preview to 77 chars when body exceeds 80 characters',
      build: () {
        when(
          () => firestoreRepo.sendTextMessage(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            senderFirebaseUid: any(named: 'senderFirebaseUid'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => convRepo.updateLastMessage(any(), any()),
        ).thenAnswer((_) async {});
        return makeBloc();
      },
      act: (b) => b.add(
        const ChatTextSendRequested(
          firestoreConversationId: 'conv_bid1',
          conversationId: 'conv-id-1',
          senderFirebaseUid: 'uid-1',
          // 81-char body so body.length > 80 triggers the truncation branch
          body:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ),
      expect: () => [],
      verify: (_) {
        verify(
          () => convRepo.updateLastMessage('conv-id-1', '${'a' * 77}...'),
        ).called(1);
      },
    );

    group('envoi refusé par Firestore (FLUTTER-CT/CV)', () {
      FirebaseException denied() => FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      blocTest<ChatBloc, ChatState>(
        'permission-denied : signal ChatSendRejected avec le texte, puis '
        "l'état précédent ; aucun aperçu ni analytics",
        build: () {
          when(
            () => firestoreRepo.sendTextMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              body: any(named: 'body'),
            ),
          ).thenThrow(denied());
          return makeBloc();
        },
        seed: () => ChatLoaded([msg]),
        act: (b) => b.add(
          const ChatTextSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            body: 'Bonjour',
          ),
        ),
        expect: () => [
          isA<ChatSendRejected>()
              .having((s) => s.text, 'text', 'Bonjour')
              .having((s) => s.previous, 'previous', isA<ChatLoaded>()),
          isA<ChatLoaded>().having((s) => s.messages.length, 'count', 1),
        ],
        verify: (_) {
          verifyNever(() => convRepo.updateLastMessage(any(), any()));
        },
      );

      blocTest<ChatBloc, ChatState>(
        'permission-denied sur une position : signal sans texte',
        build: () {
          when(
            () => firestoreRepo.sendLocationMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
            ),
          ).thenThrow(denied());
          return makeBloc();
        },
        seed: () => const ChatLoaded([]),
        act: (b) => b.add(
          const ChatLocationSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            latitude: 1,
            longitude: 2,
          ),
        ),
        expect: () => [
          isA<ChatSendRejected>().having((s) => s.text, 'text', isNull),
          isA<ChatLoaded>(),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'autre erreur Firestore : signal ChatSendFailed avec le texte et '
        "l'envoi à rejouer, puis l'état précédent ; aucune erreur levée",
        build: () {
          when(
            () => firestoreRepo.sendTextMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              body: any(named: 'body'),
            ),
          ).thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );
          return makeBloc();
        },
        seed: () => ChatLoaded([msg]),
        act: (b) => b.add(
          const ChatTextSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            body: 'Bonjour',
          ),
        ),
        expect: () => [
          isA<ChatSendFailed>()
              .having((s) => s.text, 'text', 'Bonjour')
              .having((s) => s.previous, 'previous', isA<ChatLoaded>())
              .having(
                (s) => s.retry,
                'retry',
                isA<ChatTextSendRequested>().having(
                  (e) => e.body,
                  'body',
                  'Bonjour',
                ),
              ),
          isA<ChatLoaded>().having((s) => s.messages.length, 'count', 1),
        ],
        errors: () => <Object>[],
        verify: (_) {
          verifyNever(() => convRepo.updateLastMessage(any(), any()));
        },
      );

      blocTest<ChatBloc, ChatState>(
        "échec quelconque d'une position : ChatSendFailed sans texte",
        build: () {
          when(
            () => firestoreRepo.sendLocationMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
            ),
          ).thenThrow(StateError('boom'));
          return makeBloc();
        },
        seed: () => const ChatLoaded([]),
        act: (b) => b.add(
          const ChatLocationSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            latitude: 1,
            longitude: 2,
          ),
        ),
        expect: () => [
          isA<ChatSendFailed>()
              .having((s) => s.text, 'text', isNull)
              .having(
                (s) => s.retry,
                'retry',
                isA<ChatLocationSendRequested>(),
              ),
          isA<ChatLoaded>(),
        ],
        errors: () => <Object>[],
      );
    });

    group('aperçu « dernier message » en échec (FLUTTER-KW)', () {
      DioException timeout() => DioException(
        requestOptions: RequestOptions(
          path: '/conversations/conv-1/last-message',
        ),
        type: DioExceptionType.connectionTimeout,
        error: const TimeoutException(),
      );

      blocTest<ChatBloc, ChatState>(
        'délai dépassé sur updateLastMessage : message envoyé, aucun état '
        "d'erreur, aucune erreur levée",
        build: () {
          when(
            () => firestoreRepo.sendTextMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => convRepo.updateLastMessage(any(), any()),
          ).thenThrow(timeout());
          return makeBloc();
        },
        seed: () => ChatLoaded([msg]),
        act: (b) => b.add(
          const ChatTextSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            body: 'Bonjour',
          ),
        ),
        expect: () => <ChatState>[],
        errors: () => <Object>[],
        verify: (_) {
          verify(
            () => firestoreRepo.sendTextMessage(
              firestoreConversationId: 'conv_bid1',
              senderFirebaseUid: 'uid-1',
              body: 'Bonjour',
            ),
          ).called(1);
          verify(
            () => convRepo.updateLastMessage('conv-1', 'Bonjour'),
          ).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'réponse : la barre « Réponse à » disparaît malgré le délai dépassé',
        build: () {
          when(
            () => firestoreRepo.sendTextMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              body: any(named: 'body'),
              replyToId: any(named: 'replyToId'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => convRepo.updateLastMessage(any(), any()),
          ).thenAnswer((_) => Future.error(timeout()));
          return makeBloc();
        },
        seed: () => ChatLoaded([msg], replyingTo: msg),
        act: (b) => b.add(
          const ChatTextSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            body: 'Bonjour',
            replyToId: 'msg1',
          ),
        ),
        expect: () => [
          isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
        ],
        errors: () => <Object>[],
      );

      blocTest<ChatBloc, ChatState>(
        'position : échec de updateLastMessage rattrapé',
        build: () {
          when(
            () => firestoreRepo.sendLocationMessage(
              firestoreConversationId: any(named: 'firestoreConversationId'),
              senderFirebaseUid: any(named: 'senderFirebaseUid'),
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => convRepo.updateLastMessage(any(), any()),
          ).thenThrow(StateError('boom'));
          return makeBloc();
        },
        seed: () => const ChatLoaded([]),
        act: (b) => b.add(
          const ChatLocationSendRequested(
            firestoreConversationId: 'conv_bid1',
            conversationId: 'conv-1',
            senderFirebaseUid: 'uid-1',
            latitude: 1,
            longitude: 2,
          ),
        ),
        expect: () => <ChatState>[],
        errors: () => <Object>[],
        verify: (_) {
          verify(() => convRepo.updateLastMessage('conv-1', any())).called(1);
        },
      );
    });

    blocTest<ChatBloc, ChatState>(
      'ouverture : échec de markConversationRead / markMessagesRead rattrapé',
      build: () {
        when(
          () => firestoreRepo.messagesStream(any()),
        ).thenAnswer((_) => Stream.value([msg]));
        when(() => firestoreRepo.markConversationRead(any(), any())).thenAnswer(
          (_) => Future.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ),
        );
        when(
          () => firestoreRepo.markMessagesRead(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            currentUserUid: any(named: 'currentUserUid'),
          ),
        ).thenAnswer((_) => Future.error(StateError('boom')));
        when(
          () => firestoreRepo.conversationDeletedStream(any()),
        ).thenAnswer((_) => const Stream.empty());
        return makeBloc();
      },
      act: (b) => b.add(
        const ChatSubscribeRequested('conv_bid1', currentUserUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [isA<ChatLoading>(), isA<ChatLoaded>()],
      errors: () => <Object>[],
    );
  });
}
