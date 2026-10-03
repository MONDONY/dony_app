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
