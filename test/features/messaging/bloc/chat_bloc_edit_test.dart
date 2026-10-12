import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

class _MockMessageEditRepository extends Mock
    implements MessageEditRepository {}

/// Modification / suppression de ses messages texte (FLUTTER-MG).
void main() {
  late _MockFirestoreChatRepository firestoreRepo;
  late _MockConversationRepository convRepo;
  late _MockMessageEditRepository editRepo;
  late MockAnalyticsBackend backend;
  late StreamController<List<MessageModel>> messages;

  final m1 = MessageModel(
    id: 'm1',
    senderId: 'uid-1',
    body: 'Bonjour',
    type: MessageType.text,
    sentAt: DateTime.utc(2026, 10, 11),
  );

  setUp(() {
    firestoreRepo = _MockFirestoreChatRepository();
    convRepo = _MockConversationRepository();
    editRepo = _MockMessageEditRepository();
    backend = MockAnalyticsBackend();
    messages = StreamController<List<MessageModel>>.broadcast();
    when(
      () => firestoreRepo.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => firestoreRepo.messagesStream(any()),
    ).thenAnswer((_) => messages.stream);
  });

  tearDown(() => messages.close());

  ChatBloc makeBloc({bool withRepo = true}) {
    final analytics = makeEnabledAnalytics(backend);
    analytics.onConfigured();
    return ChatBloc(
      firestoreRepo,
      convRepo,
      analytics,
      editRepository: withRepo ? editRepo : null,
    );
  }

  Future<void> subscribe(ChatBloc bloc, {bool readOnly = false}) async {
    bloc.add(ChatSubscribeRequested('conv_1', isReadOnly: readOnly));
    await Future<void>.delayed(Duration.zero);
    messages.add([m1]);
    await Future<void>.delayed(Duration.zero);
  }

  void stubEdit({Object? error}) {
    final stub = when(
      () => editRepo.editMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        messageId: any(named: 'messageId'),
        text: any(named: 'text'),
      ),
    );
    error == null ? stub.thenAnswer((_) async {}) : stub.thenThrow(error);
  }

  void stubDelete({Object? error}) {
    final stub = when(
      () => editRepo.deleteMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        messageId: any(named: 'messageId'),
      ),
    );
    error == null ? stub.thenAnswer((_) async {}) : stub.thenThrow(error);
  }

  blocTest<ChatBloc, ChatState>(
    'modification réussie : appelle la callable, aucun signal, event analytics',
    build: () {
      stubEdit();
      return makeBloc();
    },
    act: (bloc) async {
      await subscribe(bloc);
      bloc.add(const ChatMessageEditRequested(messageId: 'm1', text: 'Salut'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => <Matcher>[],
    verify: (_) {
      verify(
        () => editRepo.editMessage(
          firestoreConversationId: 'conv_1',
          messageId: 'm1',
          text: 'Salut',
        ),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.messageEdited, any()),
      ).called(1);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'suppression réussie : appelle deleteMessage',
    build: () {
      stubDelete();
      return makeBloc();
    },
    act: (bloc) async {
      await subscribe(bloc);
      bloc.add(const ChatMessageDeleteRequested('m1'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => <Matcher>[],
    verify: (_) {
      verify(
        () => editRepo.deleteMessage(
          firestoreConversationId: 'conv_1',
          messageId: 'm1',
        ),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.messageDeleted, any()),
      ).called(1);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'suppression du message cité : la barre « Réponse à » tombe',
    build: () {
      stubDelete();
      return makeBloc();
    },
    act: (bloc) async {
      await subscribe(bloc);
      bloc.add(ChatReplyStarted(m1));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChatMessageDeleteRequested('m1'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 3,
    expect: () => [
      isA<ChatLoaded>().having((s) => s.replyingTo, 'replyingTo', isNull),
    ],
  );

  for (final failure in MessageEditFailure.values) {
    blocTest<ChatBloc, ChatState>(
      'échec ${failure.name} : signal ChatMessageEditFailed puis le fil',
      build: () {
        stubEdit(error: MessageEditException(failure));
        return makeBloc();
      },
      act: (bloc) async {
        await subscribe(bloc);
        bloc.add(const ChatMessageEditRequested(messageId: 'm1', text: 'x'));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2,
      expect: () => [
        isA<ChatMessageEditFailed>()
            .having((s) => s.failure, 'failure', failure)
            .having((s) => s.action, 'action', ChatMessageEditAction.edit),
        isA<ChatLoaded>().having((s) => s.messages, 'messages', [m1]),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.messageEditFailed, {
          'action': 'edit',
          'reason': failure.name,
        }),
      ).called(1),
    );
  }

  blocTest<ChatBloc, ChatState>(
    'erreur inattendue → other, sans plantage',
    build: () {
      stubDelete(error: StateError('boom'));
      return makeBloc();
    },
    act: (bloc) async {
      await subscribe(bloc);
      bloc.add(const ChatMessageDeleteRequested('m1'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => [
      isA<ChatMessageEditFailed>()
          .having((s) => s.failure, 'failure', MessageEditFailure.other)
          .having((s) => s.action, 'action', ChatMessageEditAction.delete),
      isA<ChatLoaded>(),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'sans dépôt injecté → unavailable, aucun appel',
    build: () => makeBloc(withRepo: false),
    act: (bloc) async {
      await subscribe(bloc);
      bloc.add(const ChatMessageEditRequested(messageId: 'm1', text: 'x'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => [
      isA<ChatMessageEditFailed>().having(
        (s) => s.failure,
        'failure',
        MessageEditFailure.unavailable,
      ),
      isA<ChatLoaded>(),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'fil en lecture seule : rien n’est appelé',
    build: () {
      stubEdit();
      return makeBloc();
    },
    act: (bloc) async {
      await subscribe(bloc, readOnly: true);
      bloc.add(const ChatMessageEditRequested(messageId: 'm1', text: 'x'));
      await Future<void>.delayed(Duration.zero);
    },
    skip: 2,
    expect: () => <Matcher>[],
    verify: (_) => verifyNever(
      () => editRepo.editMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        messageId: any(named: 'messageId'),
        text: any(named: 'text'),
      ),
    ),
  );

  blocTest<ChatBloc, ChatState>(
    'avant tout fil chargé : ignoré',
    build: () {
      stubEdit();
      return makeBloc();
    },
    act: (bloc) =>
        bloc.add(const ChatMessageEditRequested(messageId: 'm1', text: 'x')),
    expect: () => <Matcher>[],
  );
}
