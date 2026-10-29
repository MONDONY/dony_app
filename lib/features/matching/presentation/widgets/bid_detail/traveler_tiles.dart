import 'package:dony/features/matching/data/models/bid_model.dart';

/// Tuiles de la grille « Votre transport » de la fiche colis (vue voyageur).
enum TravelerTile { lieux, colis, details }

/// Statuts d'un colis clos : plus de lieu de dépôt ni de récupération à
/// montrer, même si les adresses sont encore connues.
const _closedStatuses = <String>{
  'REJECTED',
  'CANCELLED',
  'NO_SHOW',
  'EXPIRED',
  'PARCEL_REFUSED',
};

bool _hasText(String? text) => (text ?? '').trim().isNotEmpty;

/// Tuiles à afficher pour [bid], dans l'ordre de la grille. Fonction pure : la
/// fiche la rappelle à chaque rafraîchissement du colis.
///
/// - `lieux` : colis non clos (ni REJECTED, CANCELLED, NO_SHOW, EXPIRED, ni
///   PARCEL_REFUSED) ET au moins un lieu à montrer, celui que le sheet affiche :
///   adresse de dépôt (`handoverAddress`) ou, pour un ancien colis, son texte
///   (`handoverLocation`), adresse de récupération (`deliveryAddress`) ou
///   consignes de retrait (`arrivalInstructions`) non vides. Un texte blanc ne
///   compte pas ;
/// - `colis` et `details` : toujours.
List<TravelerTile> travelerTilesFor(BidModel bid) {
  final hasPlaces =
      !_closedStatuses.contains(bid.status) &&
      (bid.handoverAddress != null ||
          _hasText(bid.handoverLocation) ||
          bid.deliveryAddress != null ||
          _hasText(bid.arrivalInstructions));
  return [
    if (hasPlaces) TravelerTile.lieux,
    TravelerTile.colis,
    TravelerTile.details,
  ];
}
