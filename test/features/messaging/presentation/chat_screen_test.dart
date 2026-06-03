import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:dony/features/messaging/presentation/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockChatBloc extends MockBloc<ChatEvent, ChatState> implements ChatBloc {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');
final _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

MessageModel _makeMsg({
  required String id,
  required String body,
  String senderId = 'uid-1',
  MessageType type = MessageType.text,
}) =>
    MessageModel(
      id: id,
      senderId: senderId,
      body: body,
      type: type,
      sentAt: DateTime(2026, 4, 29, 10, 0),
    );

Future<void> _pump(WidgetTester tester, ChatBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<ChatBloc>.value(
        value: bloc,
        child: ChatScreen(conversation: _conversation),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockChatBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    bloc = MockChatBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => bloc.close());

  group('ChatScreen', () {
    testWidgets('shows loading indicator when state is ChatLoading', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoading());
      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty prompt when conversation has no messages', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Démarrez la conversation !'), findsOneWidget);
    });

    testWidgets('renders message bubbles when messages present', (tester) async {
      when(() => bloc.state).thenReturn(
        ChatLoaded([
          _makeMsg(id: 'm1', body: 'Bonjour, colis reçu !'),
        ]),
      );
      await _pump(tester, bloc);

      expect(find.text('Bonjour, colis reçu !'), findsOneWidget);
    });

    testWidgets('shows participant name in app bar', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Modibo Coulibaly'), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      when(() => bloc.state)
          .thenReturn(ChatError(NetworkException('Erreur de connexion')));
      await _pump(tester, bloc);

      expect(find.text('Connexion interrompue'), findsOneWidget);
    });

    testWidgets('input bar renders with image and send buttons', (tester) async {
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      await _pump(tester, bloc);

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
