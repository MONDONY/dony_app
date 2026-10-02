/// Validation du contenu des messages texte du chat Yadony.
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
  const ChatValidationBlocked(this.reason, {this.term});

  /// Famille de la règle (analytics / debug ; propriété `reason` de
  /// l'événement `message_blocked`) : empty, length, rate, duplicate,
  /// contact, url, banking, profanity. Le message affiché à l'utilisateur se
  /// calcule à partir de ce code via `chatBlockedMessage` (chat_labels.dart).
  final String reason;

  /// Extrait du message qui a déclenché le blocage (ex. « insta », un numéro),
  /// pour dire à l'utilisateur ce qui pose problème. Renseigné pour `contact`.
  /// Contenu utilisateur : affiché localement, JAMAIS envoyé en analytics.
  final String? term;
}

abstract final class ChatMessageRules {
  static const int maxLength = 500;
  static const int rateMax = 5;
  static const Duration rateWindow = Duration(seconds: 15);
  static const Duration dedupWindow = Duration(seconds: 30);

  // ── Détecteurs (anti-contournement / contenu interdit) ──────────────────────
  //
  // Les mots-clés se comparent par MOT ENTIER : `(?<![\p{L}\p{N}_])…(?!…)`
  // (lettres Unicode, accents compris). Une recherche par sous-chaîne bloquait
  // « instant » (insta), « signalé » (signal), « snapshot » (snap), « primo »
  // (imo) : retours FLUTTER-80/81/84/85.

  static const String _wb = r'(?<![\p{L}\p{N}_])';
  static const String _we = r'(?![\p{L}\p{N}_])';

  /// Téléphone : 8+ chiffres séparés par espace/point/parenthèses (pas `/`
  /// ni `-` → évite les dates type 22/06/2026). Un code de retrait à 6
  /// chiffres (« 821921 ») reste autorisé.
  static final RegExp _phone = RegExp(r'\+?\d(?:[\s.()]*\d){7,}');

  /// Téléphone au format à tirets par paires : 06-12-34-56-78.
  static final RegExp _phoneDashed = RegExp(
    '$_wb\\d{2}(?:-\\d{2}){4}$_we',
    unicode: true,
  );

  static final RegExp _email = RegExp(
    r'[\w.+-]+@[\w-]+\.[\w.-]+',
    caseSensitive: false,
  );

  /// Pseudo de réseau social : « @kadi_221 » (pas un @ isolé, pas un email).
  static final RegExp _handle = RegExp('$_wb@[A-Za-z0-9_.]{3,}', unicode: true);

  /// Applications de messagerie / réseaux, toujours sans ambiguïté.
  static final RegExp _apps = RegExp(
    '$_wb(wh?ats?app?|wa\\.me|t\\.me|telegram|snap(?:chat)?|insta(?:gram)?'
    '|ig|viber|messenger|facebook|fb)$_we',
    caseSensitive: false,
    unicode: true,
  );

  /// Noms d'apps qui sont aussi des mots courants (« pas de signal »,
  /// « imo » = in my opinion) : bloqués seulement après une préposition ou un
  /// possessif (« sur signal », « via imo », « mon signal »).
  static final RegExp _appsInContext = RegExp(
    '$_wb(?:sur|par|via|on|en|mon|ton|my|your)\\s+(signal|imo)$_we',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _url = RegExp(
    '(https?://|www\\.|$_wb[\\w-]+\\.(?:com|fr|net|org|io|me|app|co|ci|sn|ml|cm)$_we)',
    caseSensitive: false,
    unicode: true,
  );

  /// IBAN compact (FR7630006000011234567890189).
  static final RegExp _iban = RegExp(
    r'\b[A-Z]{2}\d{2}[A-Z0-9]{10,30}\b',
    caseSensitive: false,
  );

  /// IBAN écrit par groupes de 4 (FR76 3000 6000 0112 3456 7890 189),
  /// majuscules seulement pour ne pas capter une phrase ordinaire.
  static final RegExp _ibanSpaced = RegExp(
    r'\b[A-Z]{2}\d{2}(?: [A-Z0-9]{4}){2,7}(?: [A-Z0-9]{1,4})?\b',
  );

  /// Liste FR minimale (évite les faux positifs ; bornée par limites de mot).
  static final RegExp _profanity = RegExp(
    r'\b(connard|connasse|encul[ée]s?|salop[e]?|put[ea]in|t[a]?barnak|nique? ta|fdp|ntm|batard|bâtard)\b', // i18n-ignore
    caseSensitive: false,
  );

  /// Premier extrait « coordonnées » trouvé dans [text], ou `null`.
  static String? contactTerm(String text) {
    for (final re in [_email, _apps, _phone, _phoneDashed, _handle]) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(0)!.trim();
    }
    final ctx = _appsInContext.firstMatch(text);
    return ctx?.group(1);
  }
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
      return const ChatValidationBlocked('empty');
    }
    // 1. Longueur
    if (text.length > ChatMessageRules.maxLength) {
      return const ChatValidationBlocked('length');
    }
    // 3. Anti-doublon (même texte trim < 30 s)
    final dupCutoff = clock.subtract(ChatMessageRules.dedupWindow);
    final isDup = recent.any(
      (r) => r.body.trim() == text && r.at.isAfter(dupCutoff),
    );
    if (isDup) {
      return const ChatValidationBlocked('duplicate');
    }
    // 3. Débit (5 / 15 s glissant)
    final rateCutoff = clock.subtract(ChatMessageRules.rateWindow);
    final inWindow = recent.where((r) => r.at.isAfter(rateCutoff)).length;
    if (inWindow >= ChatMessageRules.rateMax) {
      return const ChatValidationBlocked('rate');
    }
    // 4. IBAN (avant le téléphone : un IBAN est plein de chiffres et serait
    // sinon capté comme « contact »). Message bancaire plus précis.
    if (ChatMessageRules._iban.hasMatch(text) ||
        ChatMessageRules._ibanSpaced.hasMatch(text)) {
      return const ChatValidationBlocked('banking');
    }
    // 2. Anti-contournement
    final term = ChatMessageRules.contactTerm(text);
    if (term != null) {
      return ChatValidationBlocked('contact', term: term);
    }
    // 4. Contenu interdit
    if (ChatMessageRules._url.hasMatch(text)) {
      return const ChatValidationBlocked('url');
    }
    if (ChatMessageRules._profanity.hasMatch(text)) {
      return const ChatValidationBlocked('profanity');
    }

    return ChatValidationOk(text);
  }
}
