import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tracking_card.dart';

/// Tuiles de la grille « Votre envoi » de la fiche colis (vue expéditeur).
enum SenderTile { prevenir, suivi, lieux, colis, details }

/// Statuts où le colis est chez le voyageur ou livré : la tuile Suivi existe.
const _trackedStatuses = <String>{
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

/// Tuiles à afficher pour [bid], dans l'ordre de la grille. Fonction pure :
/// la fiche la rappelle à chaque rafraîchissement du colis (ACCEPTED →
/// HANDED_OVER fait passer « Lieux » à « Suivi »).
///
/// - `prevenir` : le message au destinataire peut partir (lien de suivi, colis
///   pas encore remis, destinataire n'ayant pas refusé) ;
/// - `suivi` : colis chez le voyageur ou livré, avec la carte du voyageur ou
///   les adresses à montrer ;
/// - `lieux` : colis accepté mais pas encore remis, avec une adresse ;
/// - `colis` et `details` : toujours.
List<SenderTile> senderTilesFor(BidModel bid) {
  final hasLocations = ParcelLocationsCard.shouldShow(bid);
  return [
    if (PrevenirDestinataire.canNotify(bid)) SenderTile.prevenir,
    if (_trackedStatuses.contains(bid.status) &&
        (TravelerTrackingCard.shouldShow(bid) || hasLocations))
      SenderTile.suivi,
    if (bid.status == 'ACCEPTED' && hasLocations) SenderTile.lieux,
    SenderTile.colis,
    SenderTile.details,
  ];
}
