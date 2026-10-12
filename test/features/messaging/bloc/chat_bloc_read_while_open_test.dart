import 'dart:async';

import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

/// Messages reçus pendant que le fil est ouvert : ils sont marqués lus, le
/// compteur de la liste retombe à 0 (FLUTTER-NX, FLUTTER-NY).
void main() {
  const conv = 'conv_1';
  const uid = 'uid-me';
  const delay = Duration(milliseconds: 20);

  late _MockFirestoreChatRepository repo;
  late StreamController<Map<String, int>> unread;

  setUp(() {
    repo = _MockFirestoreChatRepository();
    unread = StreamController<Map<String, int>>.broadcast();
    when(
      () => repo.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.messagesStream(any()),
    ).thenAnswer((_) => const Stream<List<MessageModel>>.empty());
    when(
      () => repo.perConversationUnreadStream(uid),
    ).thenAnswer((_) => unread.stream);
    when(
      () => repo.markConversationRead(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repo.markMessagesRead(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        currentUserUid: any(named: 'currentUserUid'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() => unread.close());

  ChatBloc makeBloc() => ChatBloc(
    repo,
    _MockConversationRepository(),
    makeEnabledAnalytics(MockAnalyticsBackend()),
    markReadDelay: delay,
  );

  Future<void> open(ChatBloc bloc) async {
    bloc.add(const ChatSubscribeRequested(conv, currentUserUid: uid));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> settle() => Future<void>.delayed(delay * 3);

  void verifyMarkedRead(int times) {
    verify(() => repo.markConversationRead(conv, uid)).called(times);
    verify(
      () => repo.markMessagesRead(
        firestoreConversationId: conv,
        currentUserUid: uid,
      ),
    ).called(times);
  }

  test('ouverture : le fil est marqué lu une fois', () async {
    final bloc = makeBloc();
    await open(bloc);
    verifyMarkedRead(1);
    await bloc.close();
  });

  test('message reçu fil ouvert : compteur remis à zéro', () async {
    final bloc = makeBloc();
    await open(bloc);
    verifyMarkedRead(1);

    unread.add({conv: 1});
    await settle();

    verifyMarkedRead(1);
    await bloc.close();
  });

  test('messages rapprochés : une seule remise à zéro', () async {
    final bloc = makeBloc();
    await open(bloc);
    verifyMarkedRead(1);

    unread
      ..add({conv: 1})
      ..add({conv: 2})
      ..add({conv: 3});
    await settle();

    verifyMarkedRead(1);
    await bloc.close();
  });

  test('compteur d\'une autre conversation : rien ne part', () async {
    final bloc = makeBloc();
    await open(bloc);
    verifyMarkedRead(1);

    unread.add({'autre': 4});
    await settle();

    verifyNever(() => repo.markConversationRead(any(), any()));
    await bloc.close();
  });

  test('app en arrière-plan : rien n\'est marqué, '
      'puis marqué au retour au premier plan', () async {
    final bloc = makeBloc();
    await open(bloc);
    verifyMarkedRead(1);

    bloc.add(const ChatAppVisibilityChanged(visible: false));
    await Future<void>.delayed(Duration.zero);
    unread.add({conv: 2});
    await settle();
    verifyNever(() => repo.markConversationRead(any(), any()));

    bloc.add(const ChatAppVisibilityChanged(visible: true));
    await Future<void>.delayed(Duration.zero);
    verifyMarkedRead(1);
    await bloc.close();
  });

  test('sortie du fil pendant le délai : dernière remise à zéro', () async {
    final bloc = ChatBloc(
      repo,
      _MockConversationRepository(),
      makeEnabledAnalytics(MockAnalyticsBackend()),
      markReadDelay: const Duration(seconds: 5),
    );
    await open(bloc);
    verifyMarkedRead(1);

    unread.add({conv: 1});
    await Future<void>.delayed(Duration.zero);
    await bloc.close();

    verifyMarkedRead(1);
  });

  test('flux de non-lus en erreur : le fil reste utilisable', () async {
    when(
      () => repo.perConversationUnreadStream(uid),
    ).thenAnswer((_) => Stream.error(Exception('permission-denied')));
    final bloc = makeBloc();
    await open(bloc);
    await settle();
    expect(bloc.isClosed, isFalse);
    await bloc.close();
  });

  test('sans utilisateur : ni marquage ni écoute', () async {
    final bloc = makeBloc();
    bloc.add(const ChatSubscribeRequested(conv));
    await settle();
    verifyNever(() => repo.markConversationRead(any(), any()));
    verifyNever(() => repo.perConversationUnreadStream(any()));
    await bloc.close();
  });
}
