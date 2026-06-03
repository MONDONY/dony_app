import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockFirestore extends Mock implements FirestoreChatRepository {}
class _MockConvRepo extends Mock implements ConversationRepository {}

void main() {
  late _MockFirestore firestore;
  late _MockConvRepo convRepo;
  late MockAnalyticsBackend backend;

  setUp(() {
    firestore = _MockFirestore();
    convRepo = _MockConvRepo();
    backend = MockAnalyticsBackend();
  });

  ChatBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return ChatBloc(firestore, convRepo, a);
  }

  test('message_sent fires on ChatTextSendRequested', () async {
    when(() => firestore.sendTextMessage(
      firestoreConversationId: any(named: 'firestoreConversationId'),
      senderFirebaseUid: any(named: 'senderFirebaseUid'),
      body: any(named: 'body'),
    )).thenAnswer((_) async {});
    when(() => convRepo.updateLastMessage(any(), any())).thenAnswer((_) async {});

    final bloc = makeBloc();
    bloc.add(const ChatTextSendRequested(
      firestoreConversationId: 'fs_conv1',
      senderFirebaseUid: 'user1',
      body: 'Bonjour',
      conversationId: 'conv1',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verify(() => backend.capture(AnalyticsEvents.messageSent, any())).called(1);
  });

  test('no event when disabled', () async {
    when(() => firestore.sendTextMessage(
      firestoreConversationId: any(named: 'firestoreConversationId'),
      senderFirebaseUid: any(named: 'senderFirebaseUid'),
      body: any(named: 'body'),
    )).thenAnswer((_) async {});
    when(() => convRepo.updateLastMessage(any(), any())).thenAnswer((_) async {});

    final bloc = makeBloc(enabled: false);
    bloc.add(const ChatTextSendRequested(
      firestoreConversationId: 'fs_conv1',
      senderFirebaseUid: 'user1',
      body: 'Bonjour',
      conversationId: 'conv1',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    verifyNever(() => backend.capture(any(), any()));
  });
}
