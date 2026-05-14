import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';

abstract class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final List<MessageModel> messages;
  const ChatLoaded(this.messages);
}

class ChatError extends ChatState {
  final AppException error;
  const ChatError(this.error);
}

class ChatReadOnly extends ChatState {
  final List<MessageModel> messages;
  const ChatReadOnly(this.messages);
}

class ChatDeletingConversation extends ChatState {
  const ChatDeletingConversation();
}

class ChatConversationDeleted extends ChatState {
  const ChatConversationDeleted();
}
