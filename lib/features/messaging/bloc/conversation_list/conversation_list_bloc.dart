import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/conversation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  final ConversationRepository _repository;

  ConversationListBloc(this._repository)
      : super(const ConversationListInitial()) {
    on<ConversationsLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    ConversationsLoadRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(const ConversationListLoading());
    try {
      final conversations = await _repository.getConversations();
      emit(ConversationListLoaded(conversations));
    } catch (_) {
      emit(const ConversationListError('Impossible de charger les conversations'));
    }
  }
}
