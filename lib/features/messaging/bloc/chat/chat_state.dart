import 'dart:typed_data';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
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

  /// Photos envoyées par l'utilisateur, pas encore arrivées dans le fil
  /// Firestore (FLUTTER-B4), la plus récente en tête.
  final List<PendingChatImage> pendingImages;

  /// Photos permises dans ce fil : valeur de la conversation à l'ouverture,
  /// relue auprès du back après un refus `media-not-allowed`.
  final bool mediaAllowed;

  /// Messages restants du demandeur dans une conversation de questions sous
  /// quota ; `null` hors de ce cas (conversation ordinaire, créateur de
  /// l'annonce, quota levé).
  final int? inquiryRemaining;

  /// Le demandeur a épuisé son quota : le champ de saisie se verrouille.
  final bool inquiryLimitReached;

  /// Conversation relue après le passage en direct d'un fil de questions
  /// (`bidId`, type ordinaire) ; `null` tant que celle de l'ouverture vaut.
  final ConversationModel? conversation;
  const ChatLoaded(
    this.messages, {
    this.replyingTo,
    this.quotedMessages = const {},
    this.pendingImages = const [],
    this.mediaAllowed = false,
    this.inquiryRemaining,
    this.inquiryLimitReached = false,
    this.conversation,
  });
}

enum PendingChatImageStatus { sending, failed }

/// Photo en cours d'envoi, ou dont l'envoi a échoué (FLUTTER-B4). Les octets
/// restent en mémoire pour l'aperçu de la bulle et un nouvel essai.
class PendingChatImage {
  /// Identifiant local, stable entre les essais.
  final String localId;
  final Uint8List bytes;
  final String? replyToId;
  final PendingChatImageStatus status;

  /// Id du message Firestore rendu par le back : la bulle disparaît quand il
  /// arrive dans le fil. `null` tant que le back n'a pas répondu.
  final String? messageId;

  const PendingChatImage({
    required this.localId,
    required this.bytes,
    this.replyToId,
    this.status = PendingChatImageStatus.sending,
    this.messageId,
  });

  bool get isFailed => status == PendingChatImageStatus.failed;

  PendingChatImage copyWith({
    PendingChatImageStatus? status,
    String? messageId,
  }) => PendingChatImage(
    localId: localId,
    bytes: bytes,
    replyToId: replyToId,
    status: status ?? this.status,
    messageId: messageId ?? this.messageId,
  );
}

/// Cause d'un échec d'envoi de photo, pour le message affiché.
enum ChatImageFailure {
  /// 403 `media-not-allowed` : photos pas ou plus permises dans ce fil.
  notAllowed,

  /// 429 : trop de photos envoyées.
  rateLimited,

  /// 422 : image refusée (format, taille).
  invalid,

  /// Réseau ou serveur : la bulle propose « Réessayer ».
  other,
}

/// Envoi de photo refusé. Signal ponctuel, aussitôt suivi de l'état du fil :
/// l'écran l'écoute sans jamais le dessiner (comme [ChatSendRejected]).
class ChatImageSendFailed extends ChatState {
  final ChatImageFailure failure;
  const ChatImageSendFailed(this.failure);
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

  /// Refus dû au plafond de messages d'une conversation de questions : l'écran
  /// affiche `inquirySendLimitError` plutôt que le message générique.
  final bool inquiryLimit;
  const ChatSendRejected(this.previous, {this.text, this.inquiryLimit = false});
}

/// Envoi d'un texte ou d'une position échoué hors refus des règles (réseau,
/// Firestore indisponible…, FLUTTER-KW). Signal ponctuel, aussitôt suivi de
/// [previous] : l'écran l'écoute sans jamais le dessiner. [text] rend le
/// texte saisi, jamais perdu (`null` pour une position) ; [retry] rejoue
/// l'envoi à l'identique.
class ChatSendFailed extends ChatState {
  final ChatState previous;
  final ChatEvent retry;
  final String? text;
  const ChatSendFailed(this.previous, {required this.retry, this.text});
}

enum ChatMessageEditAction { edit, delete }

/// Modification ou suppression refusée ou échouée (FLUTTER-MG). Signal
/// ponctuel, aussitôt suivi de l'état du fil : l'écran l'écoute sans jamais
/// le dessiner (comme [ChatSendRejected]). En cas de succès, rien à signaler :
/// la bulle change d'elle-même par le flux Firestore.
class ChatMessageEditFailed extends ChatState {
  final ChatMessageEditAction action;
  final MessageEditFailure failure;
  const ChatMessageEditFailed(this.action, this.failure);
}
