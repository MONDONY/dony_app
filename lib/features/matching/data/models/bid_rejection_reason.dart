/// Motifs qu'un voyageur peut donner en refusant une demande (FLUTTER-AF).
///
/// Liste fermée, alignée sur `BidRejectionReason` côté back : l'expéditeur
/// comprend le refus sans qu'un champ libre serve à échanger un numéro hors de
/// l'app. Le code part dans `PUT /bids/{id}/reject` et revient dans
/// `BidModel.rejectionReason`.
enum BidRejectionReason {
  noCapacity('NO_CAPACITY'),
  contentNotAccepted('CONTENT_NOT_ACCEPTED'),
  handoverNotPossible('HANDOVER_NOT_POSSIBLE'),
  tripChanged('TRIP_CHANGED'),
  other('OTHER');

  const BidRejectionReason(this.code);

  final String code;

  /// Le motif reconnu, ou `null` (refus automatique, ancienne version, absent).
  static BidRejectionReason? fromCode(String? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// Marqueurs posés par yadony-back dans `BidModel.rejectionReason` quand
/// l'équipe Yadony annule un colis depuis l'admin (FLUTTER-R4, yadony-back
/// #567). Volontairement hors de [BidRejectionReason] : ses valeurs alimentent
/// le choix du voyageur au refus, où ces motifs n'ont rien à faire.
///
/// Seul « voyageur injoignable » est montré tel quel ; les autres motifs de
/// l'équipe restent internes et arrivent sous [cancelled]. Un colis annulé par
/// l'équipe avant ce marqueur garde un `rejectionReason` nul : l'app affiche
/// alors le message terminal habituel.
enum TeamCancellationReason {
  travelerUnavailable('TEAM_TRAVELER_UNAVAILABLE'),
  cancelled('TEAM_CANCELLED');

  const TeamCancellationReason(this.code);

  final String code;

  /// Le marqueur reconnu, ou `null` (autre motif, ancien back, absent).
  static TeamCancellationReason? fromCode(String? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}
