import 'package:dony/features/messaging/data/models/conversation_model.dart';

abstract class ConversationListState {
  const ConversationListState();
}

class ConversationListInitial extends ConversationListState {
  const ConversationListInitial();
}

class ConversationListLoading extends ConversationListState {
  const ConversationListLoading();
}

class ConversationListLoaded extends ConversationListState {
  final List<ConversationModel> conversations;
  const ConversationListLoaded(this.conversations);
}

class ConversationListError extends ConversationListState {
  final String message;
  const ConversationListError(this.message);
}
