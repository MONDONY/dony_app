import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
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

class _MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

/// Réponse à un message précis (FLUTTER-86) : seul `replyToId` voyage,
/// la citation est reconstituée (fil chargé, sinon lecture à l'unité).
void main() {
  late _MockFirestoreChatRepository firestoreRepo;
  late _MockConversationRepository convRepo;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    firestoreRepo = _MockFirestoreChatRepository();
    convRepo = _MockConversationRepository();
    when(
      () => firestoreRepo.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => convRepo.updateLastMessage(any(), any()),
    ).thenAnswer((_) async {});
  });

  ChatBloc makeBloc() {
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    analytics.onConfigured();
    return ChatBloc(firestoreRepo, convRepo, analytics);
  }

  MessageModel message(
    String id, {
    String? replyToId,
    String? deletedAt,
    MessageType type = MessageType.text,
  }) => MessageModel(
    id: id,
    senderId: 'uid-1',
    body: 'corps $id',
    type: type,
    sentAt: DateTime.utc(2026, 10, 7),
    deletedAt: deletedAt,
    replyToId: replyToId,
  );

  final m1 = message('m1');
  final m2 = message('m2');

  void stubSendText({Object? error}) {
    final stub = when(
      () => firestoreRepo.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
      ),
    );
    if (error != null) {
      stub.thenThrow(error);
    } else {
      stub.thenAnswer((_) async {});
    }
  }

  ChatTextSendRequested send({String? replyToId}) => ChatTextSendRequested(
    firestoreConversationId: 'conv_bid1',
    conversationId: 'conv-1',
    senderFirebaseUid: 'uid-me',
    body: 'Bien reçu',
    replyToId: replyToId,
  );

  group('début / annulation de la réponse', () {
    blocTest<ChatBloc, ChatState>(
      'ChatReplyStarted : le message devient la réponse en cours',
      build: makeBloc,
      seed: () => ChatLoaded([m1, m2]),
      act: (b) => b.add(ChatReplyStarted(m1)),
      expect: () => [
        isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', m1).having(
          (s) => s.messages,
          'messages',
          [m1, m2],
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ChatReplyCancelled : la réponse en cours disparaît',
      build: makeBloc,
      seed: () => ChatLoaded([m1, m2], replyingTo: m1),
      act: (b) => b.add(const ChatReplyCancelled()),
      expect: () => [
        isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ChatReplyCancelled sans réponse en cours : rien',
      build: makeBloc,
      seed: () => ChatLoaded([m1]),
      act: (b) => b.add(const ChatReplyCancelled()),
      expect: () => <ChatState>[],
    );

    blocTest<ChatBloc, ChatState>(
      'fil en lecture seule : impossible de répondre',
      build: makeBloc,
      seed: () => ChatReadOnly([m1]),
      act: (b) => b
        ..add(ChatReplyStarted(m1))
        ..add(const ChatReplyCancelled()),
      expect: () => <ChatState>[],
    );

    blocTest<ChatBloc, ChatState>(
      'message supprimé ou système : impossible de le citer',
      build: makeBloc,
      seed: () => ChatLoaded([m1]),
      act: (b) => b
        ..add(ChatReplyStarted(message('d', deletedAt: '2026-10-07')))
        ..add(ChatReplyStarted(message('s', type: MessageType.system))),
      expect: () => <ChatState>[],
    );

    blocTest<ChatBloc, ChatState>(
      'pas de fil affiché (chargement) : ignoré',
      build: makeBloc,
      seed: () => const ChatLoading(),
      act: (b) => b.add(ChatReplyStarted(m1)),
      expect: () => <ChatState>[],
    );
  });

  group('envoi d’une réponse', () {
    blocTest<ChatBloc, ChatState>(
      'replyToId transmis au dépôt, puis réponse remise à null',
      build: () {
        stubSendText();
        return makeBloc();
      },
      seed: () => ChatLoaded([m1, m2], replyingTo: m2),
      act: (b) => b.add(send(replyToId: 'm2')),
      expect: () => [
        isA<ChatLoaded>()
            .having((s) => s.replyingTo, 'replyingTo', isNull)
            .having((s) => s.messages.length, 'messages', 2),
      ],
      verify: (_) {
        verify(
          () => firestoreRepo.sendTextMessage(
            firestoreConversationId: 'conv_bid1',
            senderFirebaseUid: 'uid-me',
            body: 'Bien reçu',
            replyToId: 'm2',
          ),
        ).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'autre message choisi entre-temps : la nouvelle réponse reste',
      build: () {
        stubSendText();
        return makeBloc();
      },
      seed: () => ChatLoaded([m1, m2], replyingTo: m1),
      act: (b) => b.add(send(replyToId: 'm2')),
      expect: () => <ChatState>[],
    );

    blocTest<ChatBloc, ChatState>(
      'message ordinaire : replyToId null, aucun changement d’état',
      build: () {
        stubSendText();
        return makeBloc();
      },
      seed: () => ChatLoaded([m1]),
      act: (b) => b.add(send()),
      expect: () => <ChatState>[],
      verify: (_) {
        verify(
          () => firestoreRepo.sendTextMessage(
            firestoreConversationId: 'conv_bid1',
            senderFirebaseUid: 'uid-me',
            body: 'Bien reçu',
          ),
        ).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'envoi refusé (permission-denied) : la réponse en cours est gardée',
      build: () {
        stubSendText(
          error: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
        return makeBloc();
      },
      seed: () => ChatLoaded([m1], replyingTo: m1),
      act: (b) => b.add(send(replyToId: 'm1')),
      expect: () => [
        isA<ChatSendRejected>(),
        isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', m1),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'photo en réponse : replyToId transmis au back, réponse remise à null',
      build: () {
        when(
          () => convRepo.sendImage(
            any(),
            any(),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer((_) async => 'srv1');
        return makeBloc();
      },
      seed: () => ChatLoaded([m1], replyingTo: m1, mediaAllowed: true),
      act: (b) => b.add(
        ChatImageSendRequested(
          conversationId: 'conv-1',
          bytes: Uint8List.fromList([1]),
          replyToId: 'm1',
        ),
      ),
      expect: () => [
        isA<ChatLoaded>().having(
          (s) => s.pendingImages,
          'pending',
          hasLength(1),
        ),
        isA<ChatLoaded>()
            .having(
              (s) => s.pendingImages.single.messageId,
              'messageId',
              'srv1',
            )
            .having((s) => s.replyingTo, 'replyingTo', m1),
        isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
      ],
      verify: (_) {
        verify(
          () => convRepo.sendImage('conv-1', any(), replyToId: 'm1'),
        ).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'position en réponse : replyToId transmis au dépôt',
      build: () {
        when(
          () => firestoreRepo.sendLocationMessage(
            firestoreConversationId: any(named: 'firestoreConversationId'),
            senderFirebaseUid: any(named: 'senderFirebaseUid'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            replyToId: any(named: 'replyToId'),
          ),
        ).thenAnswer((_) async {});
        return makeBloc();
      },
      seed: () => ChatLoaded([m1], replyingTo: m1),
      act: (b) => b.add(
        const ChatLocationSendRequested(
          firestoreConversationId: 'conv_bid1',
          conversationId: 'conv-1',
          senderFirebaseUid: 'uid-me',
          latitude: 14.7,
          longitude: -17.4,
          replyToId: 'm1',
        ),
      ),
      expect: () => [
        isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
      ],
      verify: (_) {
        verify(
          () => firestoreRepo.sendLocationMessage(
            firestoreConversationId: 'conv_bid1',
            senderFirebaseUid: 'uid-me',
            latitude: 14.7,
            longitude: -17.4,
            replyToId: 'm1',
          ),
        ).called(1);
      },
    );
  });

  group('cache des messages cités hors du fil chargé', () {
    final reply = message('r1', replyToId: 'old1');
    final old = message('old1');

    blocTest<ChatBloc, ChatState>(
      'citation absente du fil : relue une seule fois puis mise en cache',
      build: () {
        when(() => firestoreRepo.messagesStream('conv_bid1')).thenAnswer(
          (_) => Stream.fromIterable([
            [reply],
            [message('r2', replyToId: 'old1'), reply],
          ]),
        );
        when(
          () => firestoreRepo.getMessage('conv_bid1', 'old1'),
        ).thenAnswer((_) async => old);
        return makeBloc();
      },
      act: (b) => b.add(const ChatSubscribeRequested('conv_bid1')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        final state = b.state as ChatLoaded;
        expect(state.messages, hasLength(2));
        expect(state.quotedMessages, {'old1': old});
        verify(() => firestoreRepo.getMessage('conv_bid1', 'old1')).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'citation introuvable ou lecture en erreur : null en cache',
      build: () {
        when(() => firestoreRepo.messagesStream('conv_bid1')).thenAnswer(
          (_) => Stream.value([
            message('r1', replyToId: 'gone'),
            message('r2', replyToId: 'boom'),
          ]),
        );
        when(
          () => firestoreRepo.getMessage('conv_bid1', 'gone'),
        ).thenAnswer((_) async => null);
        when(
          () => firestoreRepo.getMessage('conv_bid1', 'boom'),
        ).thenAnswer((_) => Future.error(Exception('unavailable')));
        return makeBloc();
      },
      act: (b) => b.add(const ChatSubscribeRequested('conv_bid1')),
      wait: const Duration(milliseconds: 20),
      verify: (b) {
        final state = b.state as ChatLoaded;
        expect(state.quotedMessages, {'gone': null, 'boom': null});
      },
    );

    blocTest<ChatBloc, ChatState>(
      'citation présente dans le fil : aucune lecture à l’unité',
      build: () {
        when(
          () => firestoreRepo.messagesStream('conv_bid1'),
        ).thenAnswer((_) => Stream.value([message('r1', replyToId: 'm1'), m1]));
        return makeBloc();
      },
      act: (b) => b.add(const ChatSubscribeRequested('conv_bid1')),
      expect: () => [isA<ChatLoading>(), isA<ChatLoaded>()],
      verify: (_) {
        verifyNever(() => firestoreRepo.getMessage(any(), any()));
      },
    );

    blocTest<ChatBloc, ChatState>(
      'fil en lecture seule : les citations restent résolues',
      build: () {
        when(
          () => firestoreRepo.messagesStream('conv_bid1'),
        ).thenAnswer((_) => Stream.value([reply]));
        when(
          () => firestoreRepo.getMessage('conv_bid1', 'old1'),
        ).thenAnswer((_) async => old);
        return makeBloc();
      },
      act: (b) =>
          b.add(const ChatSubscribeRequested('conv_bid1', isReadOnly: true)),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatReadOnly>(),
        isA<ChatReadOnly>().having(
          (s) => s.quotedMessages['old1'],
          'old1',
          old,
        ),
      ],
    );
  });

  blocTest<ChatBloc, ChatState>(
    'conversation supprimée par l’autre partie : lecture seule, réponse '
    'abandonnée',
    build: () {
      final deleted = StreamController<bool>();
      addTearDown(deleted.close);
      when(
        () => firestoreRepo.conversationDeletedStream('conv_bid1'),
      ).thenAnswer((_) => deleted.stream);
      final messages = StreamController<List<MessageModel>>();
      addTearDown(messages.close);
      when(
        () => firestoreRepo.messagesStream('conv_bid1'),
      ).thenAnswer((_) => messages.stream);
      final bloc = makeBloc();
      bloc.stream.listen((s) {
        if (s is ChatLoading) messages.add([m1]);
        if (s is ChatLoaded && s.replyingTo != null) deleted.add(true);
      });
      return bloc;
    },
    act: (b) async {
      b.add(const ChatSubscribeRequested('conv_bid1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(ChatReplyStarted(m1));
    },
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<ChatLoading>(),
      isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
      isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', m1),
      isA<ChatReadOnly>().having((s) => s.messages, 'messages', [m1]),
    ],
  );
}
