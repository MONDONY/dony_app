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
  final String message;
  const ChatError(this.message);
}
