import 'dart:async';

import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

const _conv = 'conv_inq';
const _me = 'uid-asker';

ChatSubscribeRequested _subscribe({bool limited = true, int? limit = 10}) =>
    ChatSubscribeRequested(
      _conv,
      currentUserUid: _me,
      conversationId: 'api-1',
      inquiryLimited: limited,
      inquiryMessageLimit: limit,
      announcementId: 'ann-1',
    );

ChatTextSendRequested _send([String body = 'Bonjour']) => ChatTextSendRequested(
  firestoreConversationId: _conv,
  conversationId: 'api-1',
  senderFirebaseUid: _me,
  body: body,
);

ConversationModel _conversation({bool lifted = false}) => ConversationModel(
  id: 'api-1',
  firestoreConversationId: _conv,
  otherParticipant: const ParticipantModel(id: 'o', name: 'Owner'),
  kind: ConversationModel.kindInquiry,
  announcementId: 'ann-1',
  inquiryMessageLimit: lifted ? null : 10,
  inquiryQuotaLifted: lifted,
);

void main() {
  late MockFirestoreChatRepository fs;
  late MockConversationRepository conv;
  late StreamController<int> sentCtrl;

  setUpAll(() {
    registerFallbackValue(_send());
  });

  setUp(() {
    fs = MockFirestoreChatRepository();
    conv = MockConversationRepository();
    sentCtrl = StreamController<int>.broadcast();
    when(() => fs.messagesStream(any())).thenAnswer((_) => Stream.value([]));
    when(
      () => fs.conversationDeletedStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(() => fs.markConversationRead(any(), any())).thenAnswer((_) async {});
    when(
      () => fs.markMessagesRead(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        currentUserUid: any(named: 'currentUserUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => fs.perConversationUnreadStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(() => fs.inquiryAskerId(_conv)).thenAnswer((_) async => _me);
    when(() => fs.inquirySentStream(_conv)).thenAnswer((_) => sentCtrl.stream);
    when(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    ).thenAnswer((_) async {});
    when(() => conv.updateLastMessage(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() => sentCtrl.close());

  /// Premier appel : flux vivant du test ; ensuite : valeur relue au recalage.
  void freshSent(int value) {
    var calls = 0;
    when(
      () => fs.inquirySentStream(_conv),
    ).thenAnswer((_) => calls++ == 0 ? sentCtrl.stream : Stream.value(value));
  }

  ChatBloc makeBloc() {
    final backend = MockAnalyticsBackend();
    final analytics = makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return ChatBloc(fs, conv, analytics);
  }

  Future<ChatBloc> open(ChatSubscribeRequested event, {int? sent}) async {
    final bloc = makeBloc();
    bloc.add(event);
    await pumpEventQueue();
    if (sent != null) {
      sentCtrl.add(sent);
      await pumpEventQueue();
    }
    return bloc;
  }

  ChatLoaded loaded(ChatBloc b) => b.state as ChatLoaded;

  void verifySentBefore(int? n) => verify(
    () => fs.sendTextMessage(
      firestoreConversationId: _conv,
      senderFirebaseUid: _me,
      body: any(named: 'body'),
      replyToId: any(named: 'replyToId'),
      inquirySentBefore: n,
    ),
  );

  test('abonnement : inquiryRemaining = 10 - sent', () async {
    final bloc = await open(_subscribe(), sent: 3);
    expect(loaded(bloc).inquiryRemaining, 7);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    await bloc.close();
  });

  test('compteur absent du flux : 10 restants', () async {
    final bloc = await open(_subscribe());
    expect(loaded(bloc).inquiryRemaining, 10);
    await bloc.close();
  });

  test('limite nulle : repli sur 10', () async {
    final bloc = await open(_subscribe(limit: null), sent: 4);
    expect(loaded(bloc).inquiryRemaining, 6);
    await bloc.close();
  });

  test(
    'envoi passe inquirySentBefore = sent, le 10e laisse 0 et verrouille',
    () async {
      final bloc = await open(_subscribe(), sent: 9);
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(9);
      expect(loaded(bloc).inquiryRemaining, 0);
      expect(loaded(bloc).inquiryLimitReached, isTrue);
      await bloc.close();
    },
  );

  test('envoi à 0 restant : refusé sans appel au dépôt, texte gardé', () async {
    final bloc = await open(_subscribe(), sent: 10);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('mon texte'));
    await pumpEventQueue();
    verifyNever(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    );
    final rejected = emitted.whereType<ChatSendRejected>().single;
    expect(rejected.text, 'mon texte');
    expect(rejected.inquiryLimit, isTrue);
    verifyNever(() => conv.openInquiry(any()));
    await sub.cancel();
    await bloc.close();
  });

  test(
    'InquiryLimitReachedException : recalage puis un seul nouvel essai',
    () async {
      var calls = 0;
      when(
        () => fs.sendTextMessage(
          firestoreConversationId: any(named: 'firestoreConversationId'),
          senderFirebaseUid: any(named: 'senderFirebaseUid'),
          body: any(named: 'body'),
          replyToId: any(named: 'replyToId'),
          inquirySentBefore: any(named: 'inquirySentBefore'),
        ),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw InquiryLimitReachedException();
      });
      when(
        () => conv.openInquiry('ann-1'),
      ).thenAnswer((_) async => _conversation());
      freshSent(4);
      final bloc = await open(_subscribe(), sent: 2);
      final emitted = <ChatState>[];
      final sub = bloc.stream.listen(emitted.add);
      bloc.add(_send());
      await pumpEventQueue();
      verify(() => conv.openInquiry('ann-1')).called(1);
      verifySentBefore(2); // premier essai
      verifySentBefore(4); // essai recalé
      expect(emitted.whereType<ChatSendRejected>(), isEmpty);
      expect(emitted.whereType<ChatSendFailed>(), isEmpty);
      expect(loaded(bloc).inquiryRemaining, 5);
      await sub.cancel();
      await bloc.close();
    },
  );

  test('second refus : rejeté, texte gardé, pas de 3e essai', () async {
    when(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    ).thenAnswer((_) async => throw InquiryLimitReachedException());
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation());
    freshSent(6);
    final bloc = await open(_subscribe(), sent: 6);
    final emitted = <ChatState>[];
    final sub = bloc.stream.listen(emitted.add);
    bloc.add(_send('garde-moi'));
    await pumpEventQueue();
    final rejected = emitted.whereType<ChatSendRejected>().single;
    expect(rejected.text, 'garde-moi');
    expect(rejected.inquiryLimit, isTrue);
    verify(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    ).called(2);
    expect(loaded(bloc).inquiryRemaining, 4);
    await sub.cancel();
    await bloc.close();
  });

  test('recalage : quota levé côté back, renvoi ordinaire', () async {
    var calls = 0;
    when(
      () => fs.sendTextMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        body: any(named: 'body'),
        replyToId: any(named: 'replyToId'),
        inquirySentBefore: any(named: 'inquirySentBefore'),
      ),
    ).thenAnswer((_) async {
      if (calls++ == 0) throw InquiryLimitReachedException();
    });
    when(
      () => conv.openInquiry('ann-1'),
    ).thenAnswer((_) async => _conversation(lifted: true));
    final bloc = await open(_subscribe(), sent: 5);
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null);
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    await bloc.close();
  });

  test('ChatInquiryLiftedObserved efface compteur et verrou', () async {
    final bloc = await open(_subscribe(), sent: 10);
    expect(loaded(bloc).inquiryLimitReached, isTrue);
    bloc.add(const ChatInquiryLiftedObserved());
    await pumpEventQueue();
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null);
    await bloc.close();
  });

  test(
    'conversation ordinaire : aucun champ de compteur, envoi simple',
    () async {
      final bloc = await open(_subscribe(limited: false));
      expect(loaded(bloc).inquiryRemaining, isNull);
      expect(loaded(bloc).inquiryLimitReached, isFalse);
      verifyNever(() => fs.inquirySentStream(any()));
      verifyNever(() => fs.inquiryAskerId(any()));
      bloc.add(_send());
      await pumpEventQueue();
      verifySentBefore(null);
      await bloc.close();
    },
  );

  test('créateur de l\'annonce : jamais de compteur ni de limite', () async {
    when(() => fs.inquiryAskerId(_conv)).thenAnswer((_) async => 'autre-uid');
    final bloc = await open(_subscribe(), sent: 10);
    expect(loaded(bloc).inquiryRemaining, isNull);
    expect(loaded(bloc).inquiryLimitReached, isFalse);
    verifyNever(() => fs.inquirySentStream(any()));
    bloc.add(_send());
    await pumpEventQueue();
    verifySentBefore(null);
    await bloc.close();
  });

  test('position et photo non envoyées dans une INQUIRY sous quota', () async {
    final bloc = await open(_subscribe(), sent: 1);
    bloc.add(
      const ChatLocationSendRequested(
        firestoreConversationId: _conv,
        conversationId: 'api-1',
        senderFirebaseUid: _me,
        latitude: 1,
        longitude: 2,
      ),
    );
    await pumpEventQueue();
    verifyNever(
      () => fs.sendLocationMessage(
        firestoreConversationId: any(named: 'firestoreConversationId'),
        senderFirebaseUid: any(named: 'senderFirebaseUid'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        replyToId: any(named: 'replyToId'),
      ),
    );
    await bloc.close();
  });
}
