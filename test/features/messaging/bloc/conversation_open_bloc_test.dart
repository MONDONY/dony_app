import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationRepository extends Mock
    implements ConversationRepository {}

void main() {
  late MockConversationRepository repo;

  final participant = ParticipantModel(id: 'uid-1', name: 'Mamadou D');
  final conv = ConversationModel(
    id: 'conv-1',
    bidId: 'bid-abc',
    firestoreConversationId: 'conv_bid-abc',
    otherParticipant: participant,
  );

  setUp(() {
    repo = MockConversationRepository();
  });

  group('ConversationOpenBloc', () {
    blocTest<ConversationOpenBloc, ConversationOpenState>(
      'emits Loading then Success when getByBidId succeeds',
      build: () {
        when(() => repo.getByBidId('bid-abc')).thenAnswer((_) async => conv);
        return ConversationOpenBloc(repo);
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
        return ConversationOpenBloc(repo);
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
        return ConversationOpenBloc(repo);
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
}
