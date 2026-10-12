import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:dony/features/messaging/data/message_edit_repository.dart';
import 'package:dony/l10n/l10n.dart';

/// Aperçus de dernier message écrits par `ChatBloc.updateLastMessage` (envoi
/// d'une photo ou d'une position). Valeurs de donnée : stockées côté serveur
/// et lues par l'autre participant quelle que soit sa langue — elles restent
/// en français, et seul leur affichage (via [chatPreviewLabel]) est traduit.
const kChatPreviewPhoto = '📷 Photo'; // i18n-ignore
const kChatPreviewLocation = '📍 Localisation partagée'; // i18n-ignore

/// Aperçu écrit par la callable `deleteMessage` (dony-functions,
/// `DELETED_PREVIEW`) quand le dernier message est supprimé par son auteur.
const kChatPreviewDeleted = '🚫 Message supprimé'; // i18n-ignore

/// Traduit un aperçu de conversation pour l'affichage. Reconnaît les deux
/// marqueurs écrits par [ChatBloc] quelle que soit la langue de l'expéditeur
/// et rend tout autre aperçu tel quel (texte libre d'un utilisateur).
String chatPreviewLabel(AppLocalizations l, String preview) {
  return switch (preview) {
    kChatPreviewPhoto => l.chatPreviewPhoto,
    kChatPreviewLocation => l.chatPreviewLocation,
    kChatPreviewDeleted => l.chatPreviewDeleted,
    _ => preview,
  };
}

/// Message affiché quand `ChatMessageValidator` bloque un envoi, à partir du
/// code renvoyé par [ChatValidationBlocked.reason] (aussi la propriété
/// `reason` de l'événement analytics `message_blocked`, jamais traduite).
/// `empty` (et tout code inconnu) rend `''` : l'envoi est ignoré en silence.
/// [term] (cf. [ChatValidationBlocked.term]) précise, pour `contact`, ce qui a
/// déclenché le blocage.
String chatBlockedMessage(AppLocalizations l, String reason, {String? term}) {
  return switch (reason) {
    'length' => l.chatBlockedLength(ChatMessageRules.maxLength),
    'duplicate' => l.chatBlockedDuplicate,
    'rate' => l.chatBlockedRate,
    'contact' when term != null && term.isNotEmpty => l.chatBlockedContactTerm(
      term,
    ),
    'contact' => l.chatBlockedContact,
    'banking' => l.chatBlockedBanking,
    'url' => l.chatBlockedUrl,
    'profanity' => l.chatBlockedProfanity,
    _ => '',
  };
}

/// Message affiché quand la modification ou la suppression d'un message
/// échoue (FLUTTER-MG), selon [ChatMessageEditFailed.failure].
String chatMessageEditFailureMessage(
  AppLocalizations l,
  ChatMessageEditAction action,
  MessageEditFailure failure,
) {
  return switch (failure) {
    MessageEditFailure.windowExpired => l.chatEditWindowExpired,
    MessageEditFailure.locked => l.chatEditConversationLocked,
    MessageEditFailure.disputed => l.chatEditConversationDisputed,
    MessageEditFailure.muted => l.chatEditMuted,
    MessageEditFailure.invalidContent => l.chatEditInvalidContent,
    MessageEditFailure.notEditable => l.chatEditNotEditable,
    MessageEditFailure.unavailable => l.chatEditUnavailable,
    MessageEditFailure.other =>
      action == ChatMessageEditAction.edit
          ? l.chatEditFailed
          : l.chatDeleteFailed,
  };
}
