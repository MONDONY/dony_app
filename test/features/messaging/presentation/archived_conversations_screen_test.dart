import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'dart:async';

import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/bloc/conversation_selection/conversation_selection_cubit.dart';
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
    if (getIt.isRegistered<ConversationSelectionCubit>()) {
      getIt.unregister<ConversationSelectionCubit>();
    }
    getIt.registerFactoryParam<
      ConversationSelectionCubit,
      ConversationSelectionSource,
      void
    >((source, _) => ConversationSelectionCubit(source: source));
  });

  tearDown(() async {
    await bloc.close();
    if (getIt.isRegistered<ConversationSelectionCubit>()) {
      getIt.unregister<ConversationSelectionCubit>();
    }
  });

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

  group('sélection multiple (FLUTTER-M4)', () {
    const second = ConversationModel(
      id: 'conv-2',
      bidId: 'bid-2',
      firestoreConversationId: 'conv_bid-2',
      otherParticipant: ParticipantModel(id: 'uid-2', name: 'Moussa'),
      bidStatus: 'DELIVERY_CONFIRMED',
    );

    testWidgets('appui long, « Désarchiver » envoie le lot et ferme le mode', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationListLoaded(
          [],
          archivedConversations: [_archived, second],
        ),
      );
      await _pump(tester, bloc);

      await tester.longPress(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();
      expect(find.text('1 sélectionnée'), findsOneWidget);
      expect(find.text('Archives'), findsNothing);

      await tester.tap(find.byKey(const Key('conversation-select-finished')));
      await tester.pumpAndSettle();
      expect(find.text('2 sélectionnées'), findsOneWidget);

      await tester.tap(find.byKey(const Key('conversation-batch-unarchive')));
      await tester.pumpAndSettle();

      final event =
          verify(
                () => bloc.add(
                  captureAny(that: isA<ConversationsBatchUnarchiveRequested>()),
                ),
              ).captured.single
              as ConversationsBatchUnarchiveRequested;
      expect(event.conversationIds.toSet(), {'conv-1', 'conv-2'});
      expect(event.isUndo, isFalse);
      expect(find.text('Archives'), findsOneWidget);
    });

    testWidgets('fermeture par la croix et tap qui coche', (tester) async {
      when(() => bloc.state).thenReturn(
        const ConversationListLoaded(
          [],
          archivedConversations: [_archived, second],
        ),
      );
      await _pump(tester, bloc);

      await tester.longPress(find.text('Aïcha Bah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moussa'));
      await tester.pumpAndSettle();
      expect(find.text('2 sélectionnées'), findsOneWidget);

      await tester.tap(find.byKey(const Key('conversation-selection-close')));
      await tester.pumpAndSettle();
      expect(find.text('Archives'), findsOneWidget);
    });

    testWidgets('retour du désarchivage groupé : snackbar avec le nombre', (
      tester,
    ) async {
      final states = StreamController<ConversationListState>.broadcast();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: const ConversationListLoaded(
          [],
          archivedConversations: [_archived, second],
        ),
      );
      await _pump(tester, bloc);

      states.add(
        const ConversationListLoaded(
          [_archived, second],
          batchFeedback: ConversationBatchFeedback(
            action: ConversationBatchAction.unarchive,
            succeededIds: ['conv-1', 'conv-2'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2 conversations désarchivées'), findsOneWidget);
      // Laisse la snackbar se refermer : aucun minuteur en attente.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });
  });
}
