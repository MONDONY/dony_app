import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/conversation_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  hasUnread: true,
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
          .thenReturn(const ConversationListError('Erreur réseau'));
      await _pump(tester, bloc);

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('retry button dispatches ConversationsLoadRequested', (tester) async {
      when(() => bloc.state)
          .thenReturn(const ConversationListError('Erreur réseau'));
      await _pump(tester, bloc);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(() => bloc.add(const ConversationsLoadRequested())).called(greaterThanOrEqualTo(1));
    });
  });
}
