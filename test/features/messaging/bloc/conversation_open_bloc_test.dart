import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late MockConversationRepository repo;
  late _MockAnalytics analytics;

  const participant = ParticipantModel(id: 'uid-1', name: 'Mamadou D');
  const conv = ConversationModel(
    id: 'conv-1',
    bidId: 'bid-abc',
    firestoreConversationId: 'conv_bid-abc',
    otherParticipant: participant,
  );

  setUp(() {
    repo = MockConversationRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('ConversationOpenBloc', () {
    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'emits Loading then Success when getByBidId succeeds',
      build: () {
        when(() => repo.getByBidId('bid-abc')).thenAnswer((_) async => conv);
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) => b.add(const ConversationOpenRequested('bid-abc')),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenSuccess>().having(
          (s) => s.conversation.id,
          'conv id',
          'conv-1',
        ),
      ],
      verify: (_) => verify(() => repo.getByBidId('bid-abc')).called(1),
    );

    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'emits Loading then Error when getByBidId throws',
      build: () {
        when(() => repo.getByBidId(any())).thenThrow(Exception('network'));
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) => b.add(const ConversationOpenRequested('bid-abc')),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenError>(),
      ],
    );

    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'resets to Initial state before each new request',
      build: () {
        when(() => repo.getByBidId(any())).thenAnswer((_) async => conv);
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) async {
        b.add(const ConversationOpenRequested('bid-abc'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const ConversationOpenRequested('bid-xyz'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenSuccess>(),
        const ConversationOpenLoading(),
        isA<ConversationOpenSuccess>(),
      ],
      verify: (_) => verify(() => repo.getByBidId(any())).called(2),
    );
  });

  group('RecipientConversationOpenRequested', () {
    const recipientConv = ConversationModel(
      id: 'conv-r',
      bidId: 'bid-abc',
      firestoreConversationId: 'rconv_bid-abc',
      otherParticipant: ParticipantModel(
        id: 'uid-2',
        name: 'Awa',
        role: 'Destinataire',
      ),
      kind: ConversationModel.kindRecipientTraveler,
    );

    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'ouvre la conversation destinataire et trace le rôle',
      build: () {
        when(
          () => repo.getRecipientConversation('bid-abc'),
        ).thenAnswer((_) async => recipientConv);
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) => b.add(
        const RecipientConversationOpenRequested(
          'bid-abc',
          role: RecipientConversationRole.traveler,
        ),
      ),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenSuccess>().having(
          (s) => s.conversation.isRecipientConversation,
          'isRecipientConversation',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => repo.getRecipientConversation('bid-abc')).called(1);
        verifyNever(() => repo.getByBidId(any()));
        verifyNever(() => repo.restoreConversation(any()));
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientConversationOpened,
            properties: {'role': 'traveler'},
          ),
        ).called(1);
      },
    );

    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'restaure une conversation supprimée de son côté',
      build: () {
        when(() => repo.getRecipientConversation('bid-abc')).thenAnswer(
          (_) async => const ConversationModel(
            id: 'conv-r',
            bidId: 'bid-abc',
            firestoreConversationId: 'rconv_bid-abc',
            otherParticipant: ParticipantModel(id: 'uid-3', name: 'Moussa'),
            kind: ConversationModel.kindRecipientTraveler,
            deletedBySelf: true,
          ),
        );
        when(
          () => repo.restoreConversation('conv-r'),
        ).thenAnswer((_) async => recipientConv);
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) => b.add(
        const RecipientConversationOpenRequested(
          'bid-abc',
          role: RecipientConversationRole.recipient,
        ),
      ),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenSuccess>().having(
          (s) => s.conversation.deletedBySelf,
          'deletedBySelf',
          isFalse,
        ),
      ],
      verify: (_) {
        verify(() => repo.restoreConversation('conv-r')).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.recipientConversationOpened,
            properties: {'role': 'recipient'},
          ),
        ).called(1);
      },
    );

    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'émet une erreur sans tracer sur un refus du serveur',
      build: () {
        when(
          () => repo.getRecipientConversation(any()),
        ).thenThrow(Exception('403'));
        return ConversationOpenBloc(repo, analytics);
      },
      act: (b) => b.add(
        const RecipientConversationOpenRequested(
          'bid-abc',
          role: RecipientConversationRole.recipient,
        ),
      ),
      expect: () => [
        const ConversationOpenLoading(),
        isA<ConversationOpenError>(),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.recipientConversationOpened,
          properties: any(named: 'properties'),
        ),
      ),
    );
  });
}
