import 'package:cloud_functions/cloud_functions.dart';

/// Pourquoi une modification ou une suppression de message a échoué.
enum MessageEditFailure {
  /// Les 15 minutes après l'envoi sont passées.
  windowExpired,

  /// Conversation fermée, supprimée par l'interlocuteur ou verrouillée.
  locked,

  /// Litige en cours sur le colis de la conversation.
  disputed,

  /// Messagerie coupée par la modération.
  muted,

  /// Texte refusé par le serveur (coordonnées, longueur…).
  invalidContent,

  /// Message introuvable, déjà supprimé, d'un autre type ou d'un autre
  /// auteur : plus rien à modifier.
  notEditable,

  /// Fonction absente (pas encore déployée) ou service indisponible.
  unavailable,

  /// Réseau, délai dépassé ou erreur serveur : on peut réessayer.
  other,
}

class MessageEditException implements Exception {
  const MessageEditException(this.failure);
  final MessageEditFailure failure;

  @override
  String toString() => 'MessageEditException(${failure.name})';
}

/// Modification et suppression de ses propres messages texte (FLUTTER-MG),
/// par les callables `editMessage` / `deleteMessage` de dony-functions.
///
/// Jamais d'écriture Firestore directe : les règles la refusent, et c'est le
/// serveur qui conserve l'original dans l'historique avant d'y toucher.
class MessageEditRepository {
  MessageEditRepository(this._functions);
  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 20);

  Future<void> editMessage({
    required String firestoreConversationId,
    required String messageId,
    required String text,
  }) => _call('editMessage', {
    'conversationId': firestoreConversationId,
    'messageId': messageId,
    'text': text,
  });

  Future<void> deleteMessage({
    required String firestoreConversationId,
    required String messageId,
  }) => _call('deleteMessage', {
    'conversationId': firestoreConversationId,
    'messageId': messageId,
  });

  Future<void> _call(String name, Map<String, Object> data) async {
    try {
      await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: _timeout))
          .call<Object?>(data);
    } on FirebaseFunctionsException catch (e) {
      throw MessageEditException(classify(e.code, e.details));
    } catch (_) {
      // Plugin absent ou plateforme non prise en charge : jamais de plantage.
      throw const MessageEditException(MessageEditFailure.other);
    }
  }

  /// Traduit le code de l'erreur callable et sa raison (`details.reason`,
  /// cf. dony-functions src/messageEdits.ts).
  static MessageEditFailure classify(String code, Object? details) {
    final reason = details is Map ? details['reason'] : null;
    switch (reason) {
      case 'window-expired':
        return MessageEditFailure.windowExpired;
      case 'conversation-locked':
      case 'not-participant':
        return MessageEditFailure.locked;
      case 'conversation-disputed':
        return MessageEditFailure.disputed;
      case 'messaging-muted':
        return MessageEditFailure.muted;
      case 'invalid-content':
        return MessageEditFailure.invalidContent;
      case 'message-not-found':
      case 'not-author':
      case 'not-editable-type':
      case 'already-deleted':
        return MessageEditFailure.notEditable;
    }
    // Sans raison connue : `not-found` sans `details` est la réponse d'une
    // fonction qui n'existe pas (pas encore déployée), `unimplemented` celle
    // d'une plateforme sans le plugin.
    return switch (code) {
      'not-found' ||
      'unimplemented' ||
      'unavailable' => MessageEditFailure.unavailable,
      'permission-denied' ||
      'failed-precondition' => MessageEditFailure.notEditable,
      'invalid-argument' => MessageEditFailure.invalidContent,
      _ => MessageEditFailure.other,
    };
  }
}
