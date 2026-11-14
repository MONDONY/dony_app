import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockFirestore extends Mock implements FirestoreChatRepository {}

class _MockConversations extends Mock implements ConversationRepository {}

const _conv = 'conv_inq';
const _me = 'uid-asker';

InquiryParentSnapshot _parent(String? asker, {bool lifted = false}) =>
    (askerId: asker, quotaLifted: lifted, exists: true, fromCache: false);

ChatTextSendRequested _send([String body = 'Bonjour']) => ChatTextSendRequested(
  firestoreConversationId: _conv,
  conversationId: 'api-1',
  senderFirebaseUid: _me,
  body: body,
);

void main() {
  late _MockFirestore fs;
  late _MockConversations conversations;
  late MockAnalyticsBackend backend;
  late StreamController<InquiryParentSnapshot> parentCtrl;
  late StreamController<int> sentCtrl;

  setUp(() {
    fs = _MockFirestore();
    conversations = _MockConversations();
    backend = MockAnalyticsBackend();
    parentCtrl = StreamController<InquiryParentSnapshot>.broadcast();
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
    when(
      () => fs.inquiryParentStream(_conv),
    ).thenAnswer((_) => parentCtrl.stream);
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
    when(
      () => conversations.updateLastMessage(any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await parentCtrl.close();
    await sentCtrl.close();
  });

  ChatBloc makeBloc() {
    final analytics = makeEnabledAnalytics(backend);
    unawaited(analytics.onConfigured());
    return ChatBloc(fs, conversations, analytics);
  }

  /// Demandeur d'un fil de questions limité, [sent] messages déjà envoyés.
  Future<ChatBloc> openAsker(int sent) async {
    final bloc = makeBloc();
    bloc.add(
      const ChatSubscribeRequested(
        _conv,
        currentUserUid: _me,
        conversationId: 'api-1',
        inquiryLimited: true,
        inquiryMessageLimit: 10,
        announcementId: 'ann-1',
        conversationKind: ConversationModel.kindInquiry,
      ),
    );
    await pumpEventQueue();
    parentCtrl.add(_parent(_me));
    await pumpEventQueue();
    sentCtrl.add(sent);
    await pumpEventQueue();
    return bloc;
  }

  test('message_sent d\'un fil de questions : kind INQUIRY', () async {
    final bloc = await openAsker(2);
    bloc.add(_send());
    await pumpEventQueue();
    verify(
      () => backend.capture(AnalyticsEvents.messageSent, {
        'kind': ConversationModel.kindInquiry,
      }),
    ).called(1);
    await bloc.close();
  });

  test(
    'message_sent d\'une conversation ordinaire : kind SENDER_TRAVELER',
    () async {
      final bloc = makeBloc();
      bloc.add(
        const ChatSubscribeRequested(
          _conv,
          currentUserUid: _me,
          conversationId: 'api-1',
        ),
      );
      await pumpEventQueue();
      bloc.add(_send());
      await pumpEventQueue();
      verify(
        () => backend.capture(AnalyticsEvents.messageSent, {
          'kind': ConversationModel.kindSenderTraveler,
        }),
      ).called(1);
      verifyNever(() => fs.inquiryParentStream(any()));
      await bloc.close();
    },
  );

  test('10e message du demandeur : inquiry_limit_reached, une fois', () async {
    final bloc = await openAsker(9);
    bloc.add(_send());
    await pumpEventQueue();
    verify(
      () => backend.capture(AnalyticsEvents.inquiryLimitReached, {'limit': 10}),
    ).called(1);
    // Refus local suivant : la limite n'est pas remesurée.
    bloc.add(_send('encore'));
    await pumpEventQueue();
    verifyNever(
      () => backend.capture(AnalyticsEvents.inquiryLimitReached, any()),
    );
    await bloc.close();
  });

  test('message qui laisse de la place : pas de limite atteinte', () async {
    final bloc = await openAsker(3);
    bloc.add(_send());
    await pumpEventQueue();
    verifyNever(
      () => backend.capture(AnalyticsEvents.inquiryLimitReached, any()),
    );
    await bloc.close();
  });

  test('« Faire une demande » depuis la carte et le verrou', () async {
    final bloc = makeBloc();
    bloc.add(const ChatInquiryBookingTapped(InquiryBookingSource.card));
    bloc.add(const ChatInquiryBookingTapped(InquiryBookingSource.lock));
    await pumpEventQueue();
    verify(
      () => backend.capture(AnalyticsEvents.inquiryBookingTapped, {
        'source': 'card',
      }),
    ).called(1);
    verify(
      () => backend.capture(AnalyticsEvents.inquiryBookingTapped, {
        'source': 'lock',
      }),
    ).called(1);
    await bloc.close();
  });
}
