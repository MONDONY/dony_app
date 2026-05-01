import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationOpenBloc
    extends Bloc<ConversationOpenEvent, ConversationOpenState> {
  final ConversationRepository _repository;

  ConversationOpenBloc(this._repository) : super(const ConversationOpenInitial()) {
    on<ConversationOpenRequested>(_onOpen);
  }

  Future<void> _onOpen(
    ConversationOpenRequested event,
    Emitter<ConversationOpenState> emit,
  ) async {
    if (state is ConversationOpenLoading) return;
    emit(const ConversationOpenLoading());
    try {
      var conversation = await _repository.getByBidId(event.bidId);
      if (conversation.deletedBySelf) {
        conversation = await _repository.restoreConversation(conversation.id);
      }
      emit(ConversationOpenSuccess(conversation));
    } catch (_) {
      emit(const ConversationOpenError('Impossible d\'ouvrir la conversation'));
    }
  }
}
