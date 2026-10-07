import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:hive_flutter/hive_flutter.dart';

/// Brouillon de message non envoyé, un par conversation (FLUTTER-CY).
///
/// Quitter le chat avant d'envoyer perdait le texte tapé. Le brouillon vit
/// dans la boîte `user_prefs`, que la déconnexion et le changement de compte
/// vident déjà en entier (`AuthBloc._clearHiveAccountData`) : aucun texte ne
/// survit au compte qui l'a écrit, sans nettoyage dédié.
///
/// Le brouillon n'est jamais filtré : seul l'envoi passe par
/// `ChatMessageValidator` (anti-contournement, débit, doublons). Le stockage
/// est local à l'appareil et ne quitte jamais le téléphone.
class ChatDraftStore {
  ChatDraftStore(this._prefs);

  final Box<dynamic> _prefs;

  static const keyPrefix = 'chat_draft_';

  /// Borne de sécurité, au-dessus de la limite de saisie du chat : un
  /// brouillon ne doit jamais faire grossir la boîte sans fin.
  static const maxLength = 2000;

  String _key(String conversationId) => '$keyPrefix$conversationId';

  /// Brouillon de la conversation, chaîne vide s'il n'y en a pas ou si le
  /// stockage est illisible (le chat s'ouvre alors simplement vide).
  String read(String conversationId) {
    if (conversationId.isEmpty) return '';
    try {
      final value = _prefs.get(_key(conversationId));
      return value is String ? value : '';
    } catch (_) {
      return '';
    }
  }

  /// Enregistre [text] ; un texte vide ou fait d'espaces efface le brouillon.
  /// Meilleur effort : une écriture ratée ne doit jamais gêner la sortie de
  /// l'écran.
  Future<void> save(String conversationId, String text) async {
    if (conversationId.isEmpty) return;
    if (text.trim().isEmpty) return clear(conversationId);
    // Coupé en caractères visibles : jamais un emoji tranché en deux.
    final chars = text.characters;
    final bounded = chars.length > maxLength
        ? chars.take(maxLength).toString()
        : text;
    try {
      await _prefs.put(_key(conversationId), bounded);
    } catch (_) {
      // Brouillon perdu : sans conséquence au-delà du confort.
    }
  }

  Future<void> clear(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      await _prefs.delete(_key(conversationId));
    } catch (_) {
      // Idem : meilleur effort.
    }
  }
}
