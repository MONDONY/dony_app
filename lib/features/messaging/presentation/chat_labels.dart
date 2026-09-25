import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:dony/l10n/l10n.dart';

/// Aperçus de dernier message écrits par `ChatBloc.updateLastMessage` (envoi
/// d'une photo ou d'une position). Valeurs de donnée : stockées côté serveur
/// et lues par l'autre participant quelle que soit sa langue — elles restent
/// en français, et seul leur affichage (via [chatPreviewLabel]) est traduit.
const kChatPreviewPhoto = '📷 Photo'; // i18n-ignore
const kChatPreviewLocation = '📍 Localisation partagée'; // i18n-ignore

/// Traduit un aperçu de conversation pour l'affichage. Reconnaît les deux
/// marqueurs écrits par [ChatBloc] quelle que soit la langue de l'expéditeur
/// et rend tout autre aperçu tel quel (texte libre d'un utilisateur).
String chatPreviewLabel(AppLocalizations l, String preview) {
  return switch (preview) {
    kChatPreviewPhoto => l.chatPreviewPhoto,
    kChatPreviewLocation => l.chatPreviewLocation,
    _ => preview,
  };
}

/// Message affiché quand `ChatMessageValidator` bloque un envoi, à partir du
/// code renvoyé par [ChatValidationBlocked.reason] (aussi la propriété
/// `reason` de l'événement analytics `message_blocked`, jamais traduite).
/// `empty` (et tout code inconnu) rend `''` : l'envoi est ignoré en silence.
String chatBlockedMessage(AppLocalizations l, String reason) {
  return switch (reason) {
    'length' => l.chatBlockedLength(ChatMessageRules.maxLength),
    'duplicate' => l.chatBlockedDuplicate,
    'rate' => l.chatBlockedRate,
    'contact' => l.chatBlockedContact,
    'banking' => l.chatBlockedBanking,
    'url' => l.chatBlockedUrl,
    'profanity' => l.chatBlockedProfanity,
    _ => '',
  };
}
