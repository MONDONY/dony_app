import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/firestore_chat_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

class _MockFirestoreChatRepository extends Mock
    implements FirestoreChatRepository {}

ConversationModel _c(String id, {int minutesAgo = 0}) => ConversationModel(
  id: id,
  bidId: 'bid-$id',
  firestoreConversationId: 'conv_$id',
  otherParticipant: ParticipantModel(id: 'u-$id', name: id),
  lastMessageAt: DateTime(
    2026,
    10,
    11,
    12,
  ).subtract(Duration(minutes: minutesAgo)),
);

final _a = _c('a');
final _b = _c('b', minutesAgo: 10);
final _c1 = _c('c', minutesAgo: 20);
final _z = _c('z', minutesAgo: 5); // archivée

List<String> _ids(List<ConversationModel> l) => [for (final c in l) c.id];

Matcher _lists(
  List<String> active,
  List<String> archived, {
  Matcher feedback = isNull,
}) => isA<ConversationListLoaded>()
    .having((s) => _ids(s.conversations), 'active', active)
    .having((s) => _ids(s.archivedConversations), 'archived', archived)
    .having((s) => s.batchFeedback, 'batchFeedback', feedback);

Matcher _feedback(
  ConversationBatchAction action, {
  List<String> succeeded = const [],
  int failed = 0,
  bool hasError = false,
  bool isUndo = false,
}) => isA<ConversationBatchFeedback>()
    .having((f) => f.action, 'action', action)
    .having((f) => f.succeededIds, 'succeededIds', succeeded)
    .having((f) => f.failedCount, 'failedCount', failed)
    .having((f) => f.error, 'error', hasError ? isNotNull : isNull)
    .having((f) => f.isUndo, 'isUndo', isUndo);

void main() {
  late _MockConversationRepository repo;
  late _MockFirestoreChatRepository firestore;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockConversationRepository();
    firestore = _MockFirestoreChatRepository();
    backend = MockAnalyticsBackend();
    when(
      () => repo.getConversationPage(),
    ).thenAnswer((_) async => ConversationPage([_a, _b, _c1]));
    when(() => repo.getArchivedConversations()).thenAnswer((_) async => [_z]);
    when(
      () => firestore.perConversationUnreadStream(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => firestore.markConversationRead(any(), any()),
    ).thenAnswer((_) async {});
  });

  ConversationListBloc build({String uid = ''}) => ConversationListBloc(
    repo,
    firestore,
    currentUid: () => uid,
    analytics: makeEnabledAnalytics(backend)..onConfigured(),
  );

  Future<void> load(ConversationListBloc b) async {
    b.add(const ConversationsLoadRequested());
    await Future<void>.delayed(Duration.zero);
  }

  final networkError = DioException(
    requestOptions: RequestOptions(path: '/conversations/batch/archive'),
    type: DioExceptionType.connectionError,
  );

  group('ConversationsBatchArchiveRequested (FLUTTER-M4)', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'retrait optimiste, puis confirmation et analytics',
      build: () {
        when(() => repo.archiveConversations(any())).thenAnswer(
          (_) async => const BatchConversationResult(succeeded: ['a', 'c']),
        );
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchArchiveRequested(['a', 'c', 'inconnu']));
      },
      skip: 2,
      expect: () => [
        _lists(['b'], ['z', 'a', 'c']),
        _lists(
          ['b'],
          ['z', 'a', 'c'],
          feedback: _feedback(
            ConversationBatchAction.archive,
            succeeded: ['a', 'c'],
          ),
        ),
      ],
      verify: (_) {
        final sent =
            verify(
                  () => repo.archiveConversations(captureAny()),
                ).captured.single
                as List<String>;
        expect(sent.toSet(), {'a', 'c'});
        verify(
          () => backend.capture(AnalyticsEvents.conversationsBatchArchived, {
            'count': 2,
            'failed': 0,
          }),
        ).called(1);
      },
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'échec partiel : les fils refusés reviennent à leur place',
      build: () {
        when(() => repo.archiveConversations(any())).thenAnswer(
          (_) async =>
              const BatchConversationResult(succeeded: ['a'], failed: ['c']),
        );
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchArchiveRequested(['a', 'c']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['b', 'c'],
          ['z', 'a'],
          feedback: _feedback(
            ConversationBatchAction.archive,
            succeeded: ['a'],
            failed: 1,
          ),
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'erreur réseau : tout est remis, triés par dernier message',
      build: () {
        when(
          () => repo.archiveConversations(any()),
        ).thenAnswer((_) async => throw networkError);
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchArchiveRequested(['a', 'c']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['a', 'b', 'c'],
          ['z'],
          feedback: _feedback(
            ConversationBatchAction.archive,
            failed: 2,
            hasError: true,
          ),
        ),
      ],
      verify: (_) => verifyNever(
        () =>
            backend.capture(AnalyticsEvents.conversationsBatchArchived, any()),
      ),
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'aucun id connu ou liste non chargée : rien ne se passe',
      build: build,
      act: (b) async {
        b.add(const ConversationsBatchArchiveRequested(['a']));
        await load(b);
        b
          ..add(const ConversationsBatchArchiveRequested([]))
          ..add(const ConversationsBatchArchiveRequested(['inconnu']));
      },
      skip: 2,
      expect: () => <Matcher>[],
      verify: (_) => verifyNever(() => repo.archiveConversations(any())),
    );
  });

  group('ConversationsBatchUnarchiveRequested', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'les fils reviennent dans la liste active, triés',
      build: () {
        when(() => repo.unarchiveConversations(any())).thenAnswer(
          (_) async => const BatchConversationResult(succeeded: ['z']),
        );
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchUnarchiveRequested(['z']));
      },
      skip: 2,
      expect: () => [
        _lists(['a', 'z', 'b', 'c'], []),
        _lists(
          ['a', 'z', 'b', 'c'],
          [],
          feedback: _feedback(
            ConversationBatchAction.unarchive,
            succeeded: ['z'],
          ),
        ),
      ],
      verify: (_) => verify(
        () => backend.capture(AnalyticsEvents.conversationsBatchUnarchived, {
          'count': 1,
          'failed': 0,
          'undo': false,
        }),
      ).called(1),
    );

    blocTest<ConversationListBloc, ConversationListState>(
      '« Annuler » d\'un archivage groupé : tout le lot revient',
      build: () {
        when(() => repo.archiveConversations(any())).thenAnswer(
          (_) async => const BatchConversationResult(succeeded: ['a', 'b']),
        );
        when(() => repo.unarchiveConversations(any())).thenAnswer(
          (_) async => const BatchConversationResult(succeeded: ['a', 'b']),
        );
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchArchiveRequested(['a', 'b']));
        await Future<void>.delayed(Duration.zero);
        b.add(
          const ConversationsBatchUnarchiveRequested(['a', 'b'], isUndo: true),
        );
      },
      skip: 4,
      expect: () => [
        _lists(['a', 'b', 'c'], ['z']),
        _lists(
          ['a', 'b', 'c'],
          ['z'],
          feedback: _feedback(
            ConversationBatchAction.unarchive,
            succeeded: ['a', 'b'],
            isUndo: true,
          ),
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'refus ou erreur : les fils restent aux archives',
      build: () {
        when(
          () => repo.unarchiveConversations(any()),
        ).thenAnswer((_) async => throw networkError);
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchUnarchiveRequested(['z']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['a', 'b', 'c'],
          ['z'],
          feedback: _feedback(
            ConversationBatchAction.unarchive,
            failed: 1,
            hasError: true,
          ),
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'échec partiel du désarchivage',
      build: () {
        when(
          () => repo.unarchiveConversations(any()),
        ).thenAnswer((_) async => const BatchConversationResult(failed: ['z']));
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchUnarchiveRequested(['z', 'absent']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['a', 'b', 'c'],
          ['z'],
          feedback: _feedback(ConversationBatchAction.unarchive, failed: 1),
        ),
      ],
    );
  });

  group('ConversationsBatchDeleteRequested', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'supprime actifs et archivés, remet les non-lus à zéro',
      build: () {
        when(() => repo.deleteConversations(any())).thenAnswer(
          (_) async => const BatchConversationResult(succeeded: ['a', 'z']),
        );
        return build(uid: 'me');
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchDeleteRequested(['a', 'z']));
      },
      skip: 2,
      expect: () => [
        _lists(['b', 'c'], []),
        _lists(
          ['b', 'c'],
          [],
          feedback: _feedback(
            ConversationBatchAction.delete,
            succeeded: ['a', 'z'],
          ),
        ),
      ],
      verify: (_) {
        verify(() => firestore.markConversationRead('conv_a', 'me')).called(1);
        verify(() => firestore.markConversationRead('conv_z', 'me')).called(1);
        verify(
          () => backend.capture(AnalyticsEvents.conversationsBatchDeleted, {
            'count': 2,
            'failed': 0,
          }),
        ).called(1);
      },
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'échec partiel : le fil refusé revient dans sa liste',
      build: () {
        when(() => repo.deleteConversations(any())).thenAnswer(
          (_) async =>
              const BatchConversationResult(succeeded: ['a'], failed: ['z']),
        );
        when(
          () => firestore.markConversationRead(any(), any()),
        ).thenThrow(Exception('offline'));
        return build(uid: 'me');
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchDeleteRequested(['a', 'z']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['b', 'c'],
          ['z'],
          feedback: _feedback(
            ConversationBatchAction.delete,
            succeeded: ['a'],
            failed: 1,
          ),
        ),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'erreur réseau : tout est remis',
      build: () {
        when(
          () => repo.deleteConversations(any()),
        ).thenAnswer((_) async => throw networkError);
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationsBatchDeleteRequested(['b', 'z']));
      },
      skip: 3,
      expect: () => [
        _lists(
          ['a', 'b', 'c'],
          ['z'],
          feedback: _feedback(
            ConversationBatchAction.delete,
            failed: 2,
            hasError: true,
          ),
        ),
      ],
      verify: (_) =>
          verifyNever(() => firestore.markConversationRead(any(), any())),
    );
  });
}
