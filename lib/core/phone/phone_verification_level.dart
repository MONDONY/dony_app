/// Niveau de confiance d'un numéro de téléphone affiché dans l'app.
///
/// Un numéro vérifié par SMS prouve la possession de la ligne. Un numéro
/// déclaré (pays où le SMS n'arrive pas) ne prouve rien : il sert à être
/// appelé ou retrouvé, jamais à se connecter ni à payer. L'équipe peut le
/// vérifier à la main ([yadony]).
enum PhoneVerificationLevel {
  /// Déclaré, vérifié par personne.
  none,

  /// Déclaré, vérifié par l'équipe Yadony.
  yadony,

  /// Vérifié par un code reçu par SMS.
  sms;

  /// Champ `verification` de la révélation de contact (`SMS`, `YADONY`,
  /// `NONE`). Absent : un back antérieur, qui ne renvoyait que des numéros
  /// vérifiés par SMS. Valeur inconnue : jamais présentée comme vérifiée.
  static PhoneVerificationLevel parseContact(String? raw) => switch (raw) {
    null || 'SMS' => PhoneVerificationLevel.sms,
    'YADONY' => PhoneVerificationLevel.yadony,
    _ => PhoneVerificationLevel.none,
  };

  /// Champ `declaredPhoneLevel` du profil du propriétaire (`DECLARED`,
  /// `YADONY_VERIFIED`). `null` : pas de numéro déclaré.
  static PhoneVerificationLevel? parseDeclared(String? raw) => switch (raw) {
    null => null,
    'YADONY_VERIFIED' => PhoneVerificationLevel.yadony,
    _ => PhoneVerificationLevel.none,
  };
}
