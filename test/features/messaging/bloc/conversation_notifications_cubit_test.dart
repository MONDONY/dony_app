import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/messaging/bloc/conversation_notifications/conversation_notifications_cubit.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockConversationRepository extends Mock
    implements ConversationRepository {}

const _conversation = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: ParticipantModel(id: 'uid-2', name: 'Awa'),
);

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/conversations/conv-1/mute'),
  response: Response(
    statusCode: code,
    requestOptions: RequestOptions(path: '/conversations/conv-1/mute'),
  ),
  type: DioExceptionType.badResponse,
);

Matcher _state({
  required bool muted,
  bool inFlight = false,
  ConversationNotificationsOutcome? outcome,
  bool hasError = false,
}) => isA<ConversationNotificationsState>()
    .having((s) => s.muted, 'muted', muted)
    .having((s) => s.inFlight, 'inFlight', inFlight)
    .having((s) => s.outcome, 'outcome', outcome)
    .having((s) => s.error != null, 'error', hasError);

void main() {
  late _MockConversationRepository repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockConversationRepository();
    backend = MockAnalyticsBackend();
  });

  ConversationNotificationsCubit build({bool muted = false}) =>
      ConversationNotificationsCubit(
        repo,
        makeEnabledAnalytics(backend)..onConfigured(),
        conversation: muted
            ? _conversation.copyWith(notificationsMuted: true)
            : _conversation,
      );

  test('état initial repris de la conversation', () {
    expect(build().state.muted, isFalse);
    expect(build(muted: true).state.muted, isTrue);
  });

  blocTest<ConversationNotificationsCubit, ConversationNotificationsState>(
    'sourdine : optimiste puis confirmée, analytics source chat',
    build: () {
      when(
        () => repo.muteConversationNotifications('conv-1'),
      ).thenAnswer((_) async {});
      return build();
    },
    act: (c) => c.toggle(),
    expect: () => [
      _state(muted: true, inFlight: true),
      _state(muted: true, outcome: ConversationNotificationsOutcome.muted),
    ],
    verify: (_) {
      verify(() => repo.muteConversationNotifications('conv-1')).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.conversationNotificationsMuted, {
          'source': 'chat',
        }),
      ).called(1);
    },
  );

  blocTest<ConversationNotificationsCubit, ConversationNotificationsState>(
    'réactivation : appelle unmute',
    build: () {
      when(
        () => repo.unmuteConversationNotifications('conv-1'),
      ).thenAnswer((_) async {});
      return build(muted: true);
    },
    act: (c) => c.toggle(),
    expect: () => [
      _state(muted: false, inFlight: true),
      _state(muted: false, outcome: ConversationNotificationsOutcome.unmuted),
    ],
    verify: (_) {
      verify(() => repo.unmuteConversationNotifications('conv-1')).called(1);
      verify(
        () => backend.capture(
          AnalyticsEvents.conversationNotificationsUnmuted,
          {'source': 'chat'},
        ),
      ).called(1);
    },
  );

  for (final code in [403, 404, 405]) {
    blocTest<ConversationNotificationsCubit, ConversationNotificationsState>(
      'échec $code : retour arrière + erreur, sans analytics',
      build: () {
        when(
          () => repo.muteConversationNotifications('conv-1'),
        ).thenThrow(_status(code));
        return build();
      },
      act: (c) => c.toggle(),
      expect: () => [
        _state(muted: true, inFlight: true),
        _state(
          muted: false,
          outcome: ConversationNotificationsOutcome.failed,
          hasError: true,
        ),
      ],
      verify: (c) {
        expect(c.state.error, isA<AppException>());
        verifyNever(() => backend.capture(any(), any()));
      },
    );
  }

  test('double tap pendant l appel : une seule requête', () async {
    final completer = Completer<void>();
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenAnswer((_) => completer.future);
    final cubit = build();

    final first = cubit.toggle();
    await cubit.toggle();
    completer.complete();
    await first;

    verify(() => repo.muteConversationNotifications('conv-1')).called(1);
    verifyNever(() => repo.unmuteConversationNotifications(any()));
    expect(cubit.state.muted, isTrue);
    await cubit.close();
  });

  test('fermé pendant l appel : aucune émission, pas de crash', () async {
    final completer = Completer<void>();
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenAnswer((_) => completer.future);
    final cubit = build();
    final pending = cubit.toggle();
    await cubit.close();
    completer.completeError(_status(500));
    await pending;
    expect(cubit.isClosed, isTrue);
  });

  test('fermé pendant un appel réussi : aucune émission', () async {
    final completer = Completer<void>();
    when(
      () => repo.muteConversationNotifications('conv-1'),
    ).thenAnswer((_) => completer.future);
    final cubit = build();
    final pending = cubit.toggle();
    await cubit.close();
    completer.complete();
    await pending;
    expect(cubit.state.outcome, isNull);
  });
}
