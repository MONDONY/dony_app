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

  /// Message auquel l'utilisateur répond, `null` hors réponse (FLUTTER-86).
  final MessageModel? replyingTo;

  /// Messages cités hors des 50 chargés, relus à l'unité : une valeur `null`
  /// signale un message introuvable, une clé absente une lecture en cours.
  final Map<String, MessageModel?> quotedMessages;
  const ChatLoaded(
    this.messages, {
    this.replyingTo,
    this.quotedMessages = const {},
  });
}

class ChatError extends ChatState {
  final AppException error;
  const ChatError(this.error);
}

class ChatReadOnly extends ChatState {
  final List<MessageModel> messages;

  /// Cf. [ChatLoaded.quotedMessages] : les citations restent lisibles.
  final Map<String, MessageModel?> quotedMessages;
  const ChatReadOnly(this.messages, {this.quotedMessages = const {}});
}

class ChatDeletingConversation extends ChatState {
  const ChatDeletingConversation();
}

class ChatConversationDeleted extends ChatState {
  const ChatConversationDeleted();
}

/// Envoi refusé par les règles Firestore (`permission-denied`) : messagerie
/// coupée par un administrateur, ou conversation fermée. Signal ponctuel,
/// aussitôt suivi de [previous] : l'écran l'écoute sans jamais le dessiner
/// (FLUTTER-CT/CV). [text] rend le texte saisi, `null` pour une photo ou
/// une position.
class ChatSendRejected extends ChatState {
  final ChatState previous;
  final String? text;
  const ChatSendRejected(this.previous, {this.text});
}
