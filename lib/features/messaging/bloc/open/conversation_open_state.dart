import 'package:dony/features/messaging/data/models/conversation_model.dart';

abstract class ConversationOpenState {
  const ConversationOpenState();
}

class ConversationOpenInitial extends ConversationOpenState {
  const ConversationOpenInitial();
}

class ConversationOpenLoading extends ConversationOpenState {
  const ConversationOpenLoading();
}

class ConversationOpenSuccess extends ConversationOpenState {
  final ConversationModel conversation;
  const ConversationOpenSuccess(this.conversation);
}

class ConversationOpenError extends ConversationOpenState {
  final String message;
  const ConversationOpenError(this.message);
}
