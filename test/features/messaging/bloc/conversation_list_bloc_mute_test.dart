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

const _active = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-1', name: 'Bob'),
);
const _archived = ConversationModel(
  id: 'conv-9',
  bidId: 'bid-9',
  firestoreConversationId: 'conv_bid-9',
  otherParticipant: ParticipantModel(id: 'uid-9', name: 'Awa'),
  notificationsMuted: true,
);

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/conversations/x/mute'),
  response: Response(
    statusCode: code,
    requestOptions: RequestOptions(path: '/conversations/x/mute'),
  ),
  type: DioExceptionType.badResponse,
);

bool _mutedIn(List<ConversationModel> list, String id) =>
    list.firstWhere((c) => c.id == id).notificationsMuted;

Matcher _loaded({
  required bool activeMuted,
  bool archivedMuted = true,
  Matcher feedback = isNull,
}) => isA<ConversationListLoaded>()
    .having(
      (s) => _mutedIn(s.conversations, 'conv-1'),
      'conv-1 muted',
      activeMuted,
    )
    .having(
      (s) => _mutedIn(s.archivedConversations, 'conv-9'),
      'conv-9 muted',
      archivedMuted,
    )
    .having((s) => s.muteFeedback, 'muteFeedback', feedback);

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
    ).thenAnswer((_) async => const ConversationPage([_active]));
    when(
      () => repo.getArchivedConversations(),
    ).thenAnswer((_) async => [_archived]);
    when(
      () => firestore.perConversationUnreadStream(any()),
    ).thenAnswer((_) => const Stream.empty());
  });

  ConversationListBloc build() => ConversationListBloc(
    repo,
    firestore,
    currentUid: () => '',
    analytics: makeEnabledAnalytics(backend)..onConfigured(),
  );

  Future<void> load(ConversationListBloc b) async {
    b.add(const ConversationsLoadRequested());
    await Future<void>.delayed(Duration.zero);
  }

  group('ConversationNotificationsMuteToggled (FLUTTER-CM)', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'succès : optimiste, puis confirmation et analytics source list',
      build: () {
        when(
          () => repo.muteConversationNotifications('conv-1'),
        ).thenAnswer((_) async {});
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationNotificationsMuteToggled('conv-1'));
      },
      skip: 2,
      expect: () => [
        _loaded(activeMuted: true),
        _loaded(
          activeMuted: true,
          feedback: isA<ConversationMuteFeedback>()
              .having((f) => f.muted, 'muted', true)
              .having((f) => f.error, 'error', isNull),
        ),
      ],
      verify: (_) {
        verify(() => repo.muteConversationNotifications('conv-1')).called(1);
        verify(
          () => backend.capture(
            AnalyticsEvents.conversationNotificationsMuted,
            {'source': 'list'},
          ),
        ).called(1);
      },
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'archivée en sourdine : réactivée via unmute',
      build: () {
        when(
          () => repo.unmuteConversationNotifications('conv-9'),
        ).thenAnswer((_) async {});
        return build();
      },
      act: (b) async {
        await load(b);
        b.add(const ConversationNotificationsMuteToggled('conv-9'));
      },
      skip: 2,
      expect: () => [
        _loaded(activeMuted: false, archivedMuted: false),
        _loaded(
          activeMuted: false,
          archivedMuted: false,
          feedback: isA<ConversationMuteFeedback>().having(
            (f) => f.muted,
            'muted',
            false,
          ),
        ),
      ],
      verify: (_) {
        verify(() => repo.unmuteConversationNotifications('conv-9')).called(1);
      },
    );

    for (final code in [404, 405, 403]) {
      blocTest<ConversationListBloc, ConversationListState>(
        'échec $code : retour arrière + erreur, sans analytics',
        build: () {
          when(
            () => repo.muteConversationNotifications('conv-1'),
          ).thenThrow(_status(code));
          return build();
        },
        act: (b) async {
          await load(b);
          b.add(const ConversationNotificationsMuteToggled('conv-1'));
        },
        skip: 2,
        expect: () => [
          _loaded(activeMuted: true),
          _loaded(
            activeMuted: false,
            feedback: isA<ConversationMuteFeedback>()
                .having((f) => f.muted, 'muted', true)
                .having((f) => f.error, 'error', isNotNull),
          ),
        ],
        verify: (_) => verifyNever(() => backend.capture(any(), any())),
      );
    }

    blocTest<ConversationListBloc, ConversationListState>(
      'fil inconnu : rien',
      build: build,
      act: (b) async {
        await load(b);
        b.add(const ConversationNotificationsMuteToggled('absent'));
      },
      skip: 2,
      expect: () => <ConversationListState>[],
      verify: (_) =>
          verifyNever(() => repo.muteConversationNotifications(any())),
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'avant chargement : rien',
      build: build,
      act: (b) => b.add(const ConversationNotificationsMuteToggled('conv-1')),
      expect: () => <ConversationListState>[],
    );
  });

  group('ConversationNotificationsMuteSynced', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'reflète la bascule faite dans le chat, sans appel API',
      build: build,
      act: (b) async {
        await load(b);
        b
          ..add(
            const ConversationNotificationsMuteSynced('conv-1', muted: true),
          )
          // Même valeur : ignorée.
          ..add(
            const ConversationNotificationsMuteSynced('conv-1', muted: true),
          )
          ..add(
            const ConversationNotificationsMuteSynced('absent', muted: true),
          );
      },
      skip: 2,
      expect: () => [_loaded(activeMuted: true)],
      verify: (_) {
        verifyNever(() => repo.muteConversationNotifications(any()));
        verifyNever(() => repo.unmuteConversationNotifications(any()));
      },
    );
  });
}
