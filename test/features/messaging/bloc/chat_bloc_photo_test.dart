import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestore extends Mock implements FirestoreChatRepository {}

class _MockConvRepo extends Mock implements ConversationRepository {}

/// Photos dans la messagerie (FLUTTER-B4) : bulle locale, envoi par le back,
/// échecs (403 / 422 / 429 / réseau), nouvel essai et suppression.
void main() {
  late _MockFirestore firestore;
  late _MockConvRepo convRepo;
  late MockAnalyticsBackend backend;

  final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    firestore = _MockFirestore();
    convRepo = _MockConvRepo();
    backend = MockAnalyticsBackend();
    when(
      () => firestore.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => firestore.markConversationRead(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => firestore.markMessagesRead(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        currentUserUid: any(named: 'currentUserUid'),
      ),
    ).thenAnswer((_) async {});
  });

  ChatBloc makeBloc({bool analytics = false}) {
    final a = analytics
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return ChatBloc(firestore, convRepo, a);
  }

  MessageModel msg(String id, {MessageType type = MessageType.text}) =>
      MessageModel(
        id: id,
        senderId: 'uid-me',
        type: type,
        sentAt: DateTime.utc(2026, 10, 7),
      );

  void stubSend(Future<String> Function() answer) => when(
    () => convRepo.sendImage(any(), any(), replyToId: any(named: 'replyToId')),
  ).thenAnswer((_) => answer());

  ChatImageSendRequested send() =>
      ChatImageSendRequested(conversationId: 'conv-1', bytes: bytes);

  ConversationModel conversation({required bool mediaAllowed}) =>
      ConversationModel(
        id: 'conv-1',
        bidId: 'bid-1',
        firestoreConversationId: 'conv_bid-1',
        otherParticipant: const ParticipantModel(id: 'u2', name: 'Awa'),
        mediaAllowed: mediaAllowed,
      );

  group('abonnement', () {
    test('mediaAllowed de la conversation repris dans ChatLoaded, puis la '
        'bulle locale disparaît quand le message du back arrive', () async {
      final messages = StreamController<List<MessageModel>>();
      when(
        () => firestore.messagesStream(any()),
      ).thenAnswer((_) => messages.stream);
      stubSend(() async => 'srv1');
      final bloc = makeBloc();
      addTearDown(() async {
        await bloc.close();
        await messages.close();
      });

      bloc.add(
        const ChatSubscribeRequested(
          'conv_bid-1',
          conversationId: 'conv-1',
          mediaAllowed: true,
        ),
      );
      messages.add([msg('m1')]);
      await pumpEventQueue();
      expect(bloc.state, isA<ChatLoaded>());
      expect((bloc.state as ChatLoaded).mediaAllowed, isTrue);

      bloc.add(send());
      await pumpEventQueue();
      final pending = (bloc.state as ChatLoaded).pendingImages;
      expect(pending.single.messageId, 'srv1');
      expect(pending.single.status, PendingChatImageStatus.sending);
      verify(() => convRepo.sendImage('conv-1', bytes)).called(1);

      messages.add([msg('srv1', type: MessageType.image), msg('m1')]);
      await pumpEventQueue();
      expect((bloc.state as ChatLoaded).pendingImages, isEmpty);
    });
  });

  blocTest<ChatBloc, ChatState>(
    'succès : bulle « envoi » puis id du message retenu, analytics',
    build: () {
      stubSend(() async => 'srv1');
      return makeBloc(analytics: true);
    },
    seed: () => ChatLoaded([msg('m1')], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.status,
        'status',
        PendingChatImageStatus.sending,
      ),
      isA<ChatLoaded>()
          .having((s) => s.pendingImages.single.messageId, 'id', 'srv1')
          .having((s) => s.mediaAllowed, 'mediaAllowed', isTrue),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.chatPhotoSent, any()),
      ).called(1);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'succès alors que le message est déjà dans le fil : bulle retirée',
    build: () {
      stubSend(() async => 'm1');
      return makeBloc();
    },
    seed: () => ChatLoaded([msg('m1')], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>().having((s) => s.pendingImages, 'p', hasLength(1)),
      isA<ChatLoaded>().having((s) => s.pendingImages, 'p', isEmpty),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'fil en lecture seule : rien n’est envoyé',
    build: makeBloc,
    seed: () => ChatReadOnly([msg('m1')]),
    act: (b) => b.add(send()),
    expect: () => <ChatState>[],
    verify: (_) => verifyNever(
      () =>
          convRepo.sendImage(any(), any(), replyToId: any(named: 'replyToId')),
    ),
  );

  blocTest<ChatBloc, ChatState>(
    'échec réseau : signal « other », bulle « non envoyée », puis Réessayer '
    'la renvoie',
    build: () {
      var calls = 0;
      stubSend(() async {
        calls++;
        if (calls == 1) throw const OfflineException();
        return 'srv2';
      });
      return makeBloc(analytics: true);
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) async {
      b.add(send());
      await pumpEventQueue();
      final id = (b.state as ChatLoaded).pendingImages.single.localId;
      b.add(ChatImageRetryRequested(id));
      // Second essai sur une bulle déjà en cours : sans effet.
      b.add(ChatImageRetryRequested(id));
    },
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>().having(
        (s) => s.failure,
        'failure',
        ChatImageFailure.other,
      ),
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.isFailed,
        'failed',
        isTrue,
      ),
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.status,
        'status',
        PendingChatImageStatus.sending,
      ),
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.messageId,
        'id',
        'srv2',
      ),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.chatPhotoFailed, {
          'reason': 'other',
        }),
      ).called(1);
    },
  );

  blocTest<ChatBloc, ChatState>(
    '429 : signal « rateLimited », bulle gardée pour un nouvel essai, puis '
    'Supprimer la retire',
    build: () {
      stubSend(() async => throw const RateLimitException());
      return makeBloc();
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) async {
      b.add(send());
      await pumpEventQueue();
      final id = (b.state as ChatLoaded).pendingImages.single.localId;
      b.add(ChatImageDiscardRequested(id));
    },
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>().having(
        (s) => s.failure,
        'failure',
        ChatImageFailure.rateLimited,
      ),
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.isFailed,
        'failed',
        isTrue,
      ),
      isA<ChatLoaded>().having((s) => s.pendingImages, 'p', isEmpty),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    '422 : signal « invalid », bulle retirée (inutile de réessayer)',
    build: () {
      stubSend(
        () async =>
            throw const ValidationException('x', code: 'INVALID_FILE_TYPE'),
      );
      return makeBloc();
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>().having(
        (s) => s.failure,
        'failure',
        ChatImageFailure.invalid,
      ),
      isA<ChatLoaded>().having((s) => s.pendingImages, 'p', isEmpty),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    '403 media-not-allowed : bulle retirée, trombone grisé, conversation '
    'relue auprès du back',
    build: () {
      stubSend(
        () async => throw const ForbiddenException('no', 'media-not-allowed'),
      );
      when(
        () => convRepo.getConversation('conv-1'),
      ).thenAnswer((_) async => conversation(mediaAllowed: false));
      return makeBloc();
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>().having(
        (s) => s.failure,
        'failure',
        ChatImageFailure.notAllowed,
      ),
      isA<ChatLoaded>()
          .having((s) => s.pendingImages, 'p', isEmpty)
          .having((s) => s.mediaAllowed, 'mediaAllowed', isFalse),
      isA<ChatLoaded>().having((s) => s.mediaAllowed, 'mediaAllowed', isFalse),
    ],
    verify: (_) => verify(() => convRepo.getConversation('conv-1')).called(1),
  );

  blocTest<ChatBloc, ChatState>(
    '403 sans code (non participant) : simple échec réessayable',
    build: () {
      stubSend(() async => throw const ForbiddenException());
      return makeBloc();
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>().having(
        (s) => s.failure,
        'failure',
        ChatImageFailure.other,
      ),
      isA<ChatLoaded>().having(
        (s) => s.pendingImages.single.isFailed,
        'failed',
        isTrue,
      ),
    ],
    verify: (_) => verifyNever(() => convRepo.getConversation(any())),
  );

  blocTest<ChatBloc, ChatState>(
    '403 media-not-allowed, relecture en échec : trombone reste grisé',
    build: () {
      stubSend(
        () async => throw const ForbiddenException('no', 'media-not-allowed'),
      );
      when(
        () => convRepo.getConversation(any()),
      ).thenThrow(const OfflineException());
      return makeBloc();
    },
    seed: () => const ChatLoaded([], mediaAllowed: true),
    act: (b) => b.add(send()),
    expect: () => [
      isA<ChatLoaded>(),
      isA<ChatImageSendFailed>(),
      isA<ChatLoaded>().having((s) => s.mediaAllowed, 'mediaAllowed', isFalse),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'Réessayer / Supprimer inconnus ou hors fil : sans effet',
    build: makeBloc,
    seed: () => const ChatLoaded([]),
    act: (b) {
      b.add(const ChatImageRetryRequested('nope'));
    },
    expect: () => <ChatState>[],
  );

  blocTest<ChatBloc, ChatState>(
    'Supprimer hors fil chargé : sans effet',
    build: makeBloc,
    act: (b) => b.add(const ChatImageDiscardRequested('nope')),
    expect: () => <ChatState>[],
  );
}
