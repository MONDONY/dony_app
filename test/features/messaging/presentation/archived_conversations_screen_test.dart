import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/archived_conversations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/l10n_test_helpers.dart';

class MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _FakeConversationListEvent extends Fake
    implements ConversationListEvent {}

const _participant = ParticipantModel(id: 'uid-1', name: 'Aïcha Bah');
const _archived = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
  lastMessagePreview: 'Bonjour !',
);

Future<void> _pump(WidgetTester tester, ConversationListBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<ConversationListBloc>.value(
        value: bloc,
        child: const ArchivedConversationsScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeConversationListEvent());
  });

  late MockConversationListBloc bloc;

  setUp(() {
    bloc = MockConversationListBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => bloc.close());

  group('ArchivedConversationsScreen', () {
    testWidgets('affiche le titre Archives', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Archives'), findsOneWidget);
    });

    testWidgets('shows skeleton while not loaded', (tester) async {
      when(() => bloc.state).thenReturn(const ConversationListLoading());
      await _pump(tester, bloc);

      expect(find.byType(DonyConversationTileSkeleton), findsWidgets);
    });

    testWidgets('shows empty state when no archived conversation', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
      await _pump(tester, bloc);

      expect(find.text('Aucune archive'), findsOneWidget);
    });

    testWidgets('shows archived tile when conversations are archived', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationListLoaded([], archivedConversations: [_archived]),
      );
      await _pump(tester, bloc);

      expect(find.text('Aïcha Bah'), findsOneWidget);
    });

    testWidgets(
      'en anglais : titre identique (« Archives ») et état vide traduit',
      (tester) async {
        useEnglish();
        when(() => bloc.state).thenReturn(const ConversationListLoaded([]));
        await _pump(tester, bloc);

        expect(find.text('Archives'), findsOneWidget);
        expect(find.text('No archived conversations'), findsOneWidget);
        expect(find.text('Aucune archive'), findsNothing);
      },
    );
  });
}
