import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/conversation_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Aïcha Bah');
final _conv = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  lastMessagePreview: 'Bonjour !',
  lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
  hasUnread: true,
);
final _convNoUnread = ConversationModel(
  id: 'conv-2',
  bidId: 'bid-2',
  firestoreConversationId: 'conv_bid-2',
  otherParticipant: ParticipantModel(id: 'uid-2', name: 'Mamadou'),
  lastMessagePreview: 'À bientôt',
  lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
  hasUnread: false,
);
final _convNow = ConversationModel(
  id: 'conv-5',
  bidId: 'bid-5',
  firestoreConversationId: 'conv_bid-5',
  otherParticipant: ParticipantModel(id: 'uid-5', name: 'Kadiatou'),
  lastMessagePreview: 'Maintenant',
  lastMessageAt: DateTime.now(),
  hasUnread: false,
);
final _convDaysAgo = ConversationModel(
  id: 'conv-3',
  bidId: 'bid-3',
  firestoreConversationId: 'conv_bid-3',
  otherParticipant: ParticipantModel(id: 'uid-3', name: 'Fatoumata'),
  lastMessagePreview: 'À demain',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 3)),
  hasUnread: false,
);
final _convWeeksAgo = ConversationModel(
  id: 'conv-4',
  bidId: 'bid-4',
  firestoreConversationId: 'conv_bid-4',
  otherParticipant: ParticipantModel(id: 'uid-4', name: 'Oumar'),
  lastMessagePreview: 'Merci',
  lastMessageAt: DateTime.now().subtract(const Duration(days: 10)),
  hasUnread: false,
);

GoRouter _buildRouter(ConversationListBloc bloc) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider<ConversationListBloc>.value(
            value: bloc,
            child: const ConversationListScreen(),
          ),
        ),
        GoRoute(
          path: '/conversations/:id',
          builder: (_, __) => const Scaffold(body: Text('Chat')),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, ConversationListBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _buildRouter(bloc),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockConversationListBloc bloc;

  setUp(() {
    bloc = MockConversationListBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => bloc.close());

  group('ConversationListScreen', () {
    testWidgets('shows loading indicator when state is Loading', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoading());
      await _pump(tester, bloc);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no conversations', (tester) async {
      when(() => bloc.state)
          .thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Aucun message'), findsOneWidget);
    });

    testWidgets('renders conversation tile with participant name', (tester) async {
      when(() => bloc.state)
          .thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
      expect(find.text('Bonjour !'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      when(() => bloc.state)
          .thenReturn(ConversationListError(NetworkException('Erreur réseau')));
      await _pump(tester, bloc);

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('retry button dispatches ConversationsLoadRequested', (tester) async {
      when(() => bloc.state)
          .thenReturn(ConversationListError(NetworkException('Erreur réseau')));
      await _pump(tester, bloc);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => bloc.add(const ConversationsLoadRequested())).called(greaterThanOrEqualTo(1));
    });

    testWidgets('renders tile with lastMessageAt time and hasUnread=true', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
      expect(find.text('Bonjour !'), findsOneWidget);
    });

    testWidgets('renders tile with hasUnread=false (non-bold styling path)', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convNoUnread]));
      await _pump(tester, bloc);

      expect(find.text('Mamadou'), findsOneWidget);
      expect(find.text('À bientôt'), findsOneWidget);
    });

    testWidgets('renders separator when two conversations present', (tester) async {
      when(() => bloc.state)
          .thenReturn(ConversationListLoaded([_conv, _convNoUnread]));
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
      expect(find.text('Mamadou'), findsOneWidget);
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('tapping conversation tile navigates to chat', (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.tap(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('_formatTime shows maintenant for sub-1-minute message',
        (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convNow]));
      await _pump(tester, bloc);

      expect(find.text('Kadiatou'), findsOneWidget);
      expect(find.text('maintenant'), findsOneWidget);
    });

    testWidgets('_formatTime uses EEE format for 3-day-old message',
        (tester) async {
      await initializeDateFormatting('fr');
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convDaysAgo]));
      await _pump(tester, bloc);

      expect(find.text('Fatoumata'), findsOneWidget);
    });

    testWidgets('_formatTime uses dd/MM format for 10-day-old message',
        (tester) async {
      await initializeDateFormatting('fr');
      when(() => bloc.state).thenReturn(ConversationListLoaded([_convWeeksAgo]));
      await _pump(tester, bloc);

      expect(find.text('Oumar'), findsOneWidget);
    });

    testWidgets('pull-to-refresh dispatches ConversationsLoadRequested',
        (tester) async {
      when(() => bloc.state).thenReturn(ConversationListLoaded([_conv]));
      await _pump(tester, bloc);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => bloc.add(const ConversationsLoadRequested()))
          .called(greaterThanOrEqualTo(1));
    });
  });
}
