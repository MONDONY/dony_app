/// Statut légal déclaré par un voyageur : particulier ou professionnel.
///
/// Distinct de `isProAccount` (l'abonnement PRO) et de `gpPro` (le badge
/// accordé par l'équipe Yadony) : c'est la réponse du voyageur lui-même à
/// « Comment voyagez-vous ? ».
enum TravelerStatus {
  individual('INDIVIDUAL'),
  professional('PROFESSIONAL');

  const TravelerStatus(this.wire);

  /// Valeur échangée avec le back.
  final String wire;

  /// Lit la valeur du back. `null` (statut non déclaré, ancien back) et toute
  /// valeur inconnue (futur statut) donnent `null` : aucune pastille, aucune
  /// erreur de lecture.
  static TravelerStatus? parse(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// Valeur envoyée au back, pour `@JsonKey(toJson: ...)`.
String? travelerStatusToJson(TravelerStatus? status) => status?.wire;
