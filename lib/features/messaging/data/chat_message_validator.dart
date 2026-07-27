/// Validation du contenu des messages texte du chat yadony.
///
/// Règles (cf. spec 2026-06-20-chat-redesign) — bloque + avertit :
/// 1. Longueur 1–500, trim, pas de vide.
/// 2. Anti-contournement : téléphone, email, apps de messagerie externes.
/// 3. Anti-spam : 5 msg / 15 s glissant + anti-doublon (même texte < 30 s).
/// 4. Contenu interdit : IBAN / carte bancaire / liens externes / insultes.
///
/// Pur et déterministe (injecte [now]) → testable sans I/O.
library;

/// Un envoi récent de l'utilisateur (pour débit + anti-doublon).
class SentRecord {
  final DateTime at;
  final String body;
  const SentRecord(this.at, this.body);
}

/// Résultat de validation.
sealed class ChatValidation {
  const ChatValidation();
}

class ChatValidationOk extends ChatValidation {
  const ChatValidationOk(this.text);

  /// Le texte normalisé (trim) prêt à envoyer.
  final String text;
}

class ChatValidationBlocked extends ChatValidation {
  const ChatValidationBlocked(this.reason, this.message);

  /// Famille de la règle (analytics / debug) : empty, length, rate, duplicate,
  /// contact, url, banking, profanity.
  final String reason;

  /// Message utilisateur (snackbar). Vide pour `empty` (envoi silencieusement ignoré).
  final String message;
}

abstract final class ChatMessageRules {
  static const int maxLength = 500;
  static const int rateMax = 5;
  static const Duration rateWindow = Duration(seconds: 15);
  static const Duration dedupWindow = Duration(seconds: 30);

  static const String contactMsg =
      'Pour ta sécurité, garde les échanges et le paiement sur yadony. '
      'Le partage de coordonnées est interdit.';

  // ── Détecteurs (anti-contournement / contenu interdit) ──────────────────────

  /// 8+ chiffres, séparateurs ` .-()/` tolérés entre eux (téléphone / CB).
  // 8+ chiffres séparés par espace/point/parenthèses uniquement (pas `/`
  // ni `-` → évite les faux positifs sur les dates type 22/06/2026).
  static final RegExp _phone = RegExp(r'\d(?:[\s.()]*\d){7,}');
  static final RegExp _email =
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+', caseSensitive: false);
  static final RegExp _apps = RegExp(
    r'(whats?app|wa\.me|t\.me|telegram|signal|snap(chat)?|insta(gram)?|viber|messenger|imo\b)',
    caseSensitive: false,
  );
  static final RegExp _url = RegExp(
    r'(https?://|www\.|\b[\w-]+\.(com|fr|net|org|io|me|app|co|ci|sn|ml|cm))',
    caseSensitive: false,
  );
  static final RegExp _iban =
      RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b', caseSensitive: false);

  /// Liste FR minimale (évite les faux positifs ; bornée par limites de mot).
  static final RegExp _profanity = RegExp(
    r'\b(connard|connasse|encul[ée]s?|salop[e]?|put[ea]in|t[a]?barnak|nique? ta|fdp|ntm|batard|bâtard)\b',
    caseSensitive: false,
  );
}

class ChatMessageValidator {
  /// Valide [raw] pour envoi. [recent] = envois récents de l'utilisateur
  /// (ordre quelconque). [now] injectable pour les tests.
  ChatValidation validate(
    String raw, {
    List<SentRecord> recent = const [],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final text = raw.trim();

    // 1. Vide
    if (text.isEmpty) {
      return const ChatValidationBlocked('empty', '');
    }
    // 1. Longueur
    if (text.length > ChatMessageRules.maxLength) {
      return const ChatValidationBlocked(
        'length',
        'Message trop long (500 caractères max).',
      );
    }
    // 3. Anti-doublon (même texte trim < 30 s)
    final dupCutoff = clock.subtract(ChatMessageRules.dedupWindow);
    final isDup = recent.any(
      (r) => r.body.trim() == text && r.at.isAfter(dupCutoff),
    );
    if (isDup) {
      return const ChatValidationBlocked(
        'duplicate',
        'Tu viens d\'envoyer ce message.',
      );
    }
    // 3. Débit (5 / 15 s glissant)
    final rateCutoff = clock.subtract(ChatMessageRules.rateWindow);
    final inWindow = recent.where((r) => r.at.isAfter(rateCutoff)).length;
    if (inWindow >= ChatMessageRules.rateMax) {
      return const ChatValidationBlocked(
        'rate',
        'Tu envoies trop de messages, patiente un instant.',
      );
    }
    // 4. IBAN (avant le téléphone : un IBAN est plein de chiffres et serait
    // sinon capté comme « contact »). Message bancaire plus précis.
    if (ChatMessageRules._iban.hasMatch(text)) {
      return const ChatValidationBlocked(
        'banking',
        'Le partage de coordonnées bancaires est interdit.',
      );
    }
    // 2. Anti-contournement
    if (ChatMessageRules._phone.hasMatch(text) ||
        ChatMessageRules._email.hasMatch(text) ||
        ChatMessageRules._apps.hasMatch(text)) {
      return const ChatValidationBlocked('contact', ChatMessageRules.contactMsg);
    }
    // 4. Contenu interdit
    if (ChatMessageRules._url.hasMatch(text)) {
      return const ChatValidationBlocked(
        'url',
        'Les liens externes ne sont pas autorisés dans la messagerie.',
      );
    }
    if (ChatMessageRules._profanity.hasMatch(text)) {
      return const ChatValidationBlocked(
        'profanity',
        'Reste courtois : ce message contient des termes interdits.',
      );
    }

    return ChatValidationOk(text);
  }
}
