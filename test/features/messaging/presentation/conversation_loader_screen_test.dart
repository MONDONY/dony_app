import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/conversation_loader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockConversationRepository extends Mock implements ConversationRepository {}
class MockChatBloc extends MockBloc<ChatEvent, ChatState> implements ChatBloc {}
class MockContactRevealBloc extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Modibo Coulibaly');
final _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

Future<void> _pump(WidgetTester tester, String conversationId) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ConversationLoaderScreen(conversationId: conversationId),
    ),
  );
}

void main() {
  late MockConversationRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
  });

  setUp(() {
    repository = MockConversationRepository();
    getIt.registerSingleton<ConversationRepository>(repository);
    getIt.registerFactory<ChatBloc>(() {
      final bloc = MockChatBloc();
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bloc.state).thenReturn(const ChatLoaded([]));
      return bloc;
    });
    getIt.registerFactory<ContactRevealBloc>(() {
      final bloc = MockContactRevealBloc();
      when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bloc.state).thenReturn(const ContactRevealInitial());
      return bloc;
    });
  });

  tearDown(() async {
    await getIt.unregister<ConversationRepository>();
    await getIt.unregister<ChatBloc>();
    await getIt.unregister<ContactRevealBloc>();
  });

  tearDownAll(() => GetIt.instance.reset());

  group('ConversationLoaderScreen', () {
    testWidgets('shows a loading indicator while fetching', (tester) async {
      when(() => repository.getConversation('conv-1'))
          .thenAnswer((_) => Completer<ConversationModel>().future);

      await _pump(tester, 'conv-1');
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('opens the chat screen once the conversation is loaded', (tester) async {
      when(() => repository.getConversation('conv-1'))
          .thenAnswer((_) async => _conversation);

      await _pump(tester, 'conv-1');
      await tester.pumpAndSettle();

      expect(find.text('Modibo Coulibaly'), findsOneWidget);
    });

    testWidgets('shows a retry error state when the fetch fails', (tester) async {
      when(() => repository.getConversation('conv-1'))
          .thenAnswer((_) async => throw Exception('network error'));

      await _pump(tester, 'conv-1');
      await tester.pumpAndSettle();

      expect(find.text('Conversation introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('tapping retry re-fetches the conversation', (tester) async {
      var calls = 0;
      when(() => repository.getConversation('conv-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('network error');
        return _conversation;
      });

      await _pump(tester, 'conv-1');
      await tester.pumpAndSettle();
      expect(find.text('Conversation introuvable'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Modibo Coulibaly'), findsOneWidget);
      expect(calls, 2);
    });
  });
}
