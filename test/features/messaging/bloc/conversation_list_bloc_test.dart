import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConversationRepository extends Mock implements ConversationRepository {}

final _participant = ParticipantModel(id: 'uid-1', name: 'Bob D');
final _conv = ConversationModel(
  id: 'conv-1',
  bidId: 'bid-1',
  firestoreConversationId: 'conv_bid-1',
  otherParticipant: _participant,
);

void main() {
  late MockConversationRepository repo;

  setUp(() {
    repo = MockConversationRepository();
  });

  group('ConversationListBloc', () {
    blocTest<ConversationListBloc, ConversationListState>(
      'emits Loading then Loaded on success',
      build: () {
        when(() => repo.getConversations()).thenAnswer((_) async => [_conv]);
        return ConversationListBloc(repo);
      },
      act: (b) => b.add(const ConversationsLoadRequested()),
      expect: () => [
        const ConversationListLoading(),
        isA<ConversationListLoaded>()
            .having((s) => s.conversations.length, 'count', 1),
      ],
    );

    blocTest<ConversationListBloc, ConversationListState>(
      'emits Loading then Error on failure',
      build: () {
        when(() => repo.getConversations()).thenThrow(Exception('net'));
        return ConversationListBloc(repo);
      },
      act: (b) => b.add(const ConversationsLoadRequested()),
      expect: () => [
        const ConversationListLoading(),
        isA<ConversationListError>(),
      ],
    );
  });
}
