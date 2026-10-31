import 'package:dony/features/matching/data/models/bid_model.dart';

// Règles d'arrivée de l'écran du trajet vu par son voyageur : pied collant,
// carte de statut et annulation.

/// Colis entre les mains du voyageur : à restituer si le trajet est annulé.
const _handedOverStatuses = <String>{'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED'};

/// Un colis est-il à bord, pas encore marqué arrivé ? Remis au voyageur
/// (`HANDED_OVER`, avec ou sans scan Transit) ou en transit (`IN_TRANSIT`).
/// Un colis pas encore récupéré (`ACCEPTED`) ou déjà arrivé (`ARRIVED`) ne
/// compte pas.
bool tripHasParcelsOnBoard(List<BidModel> bids) =>
    bids.any((b) => b.status == 'HANDED_OVER' || b.status == 'IN_TRANSIT');

/// Le voyageur peut-il marquer son trajet arrivé ? Seulement une fois le
/// trajet parti (`IN_PROGRESS`, [tripStatus]) avec un colis à bord
/// ([tripHasParcelsOnBoard]).
///
/// Un colis se remet avant le départ : sur un trajet encore `ACTIVE` ou
/// `FULL`, un colis `HANDED_OVER` veut dire que la remise est faite, pas que
/// le voyageur est parti, et « Arrivé à destination » n'a pas de sens. Le
/// back passe le trajet `IN_PROGRESS` à l'heure de départ (relevé horaire,
/// ou ouverture de « Mes trajets ») ou dès qu'un colis est scanné en
/// transit (`AnnouncementService.markUnderway`).
///
/// Le scan Transit est facultatif (yadony-back #336) : un colis récupéré au
/// départ suffit, une fois le trajet parti. Un colis pas encore récupéré
/// (`ACCEPTED`) ne bloque pas le trajet, il reste simplement en attente ; un
/// colis déjà arrivé non plus (un autre, passé en transit plus tard, se
/// marque encore). Une fois l'arrivée marquée, les instructions de retrait
/// se modifient depuis la tuile « Arrivée » (`TripTile.arrival`).
bool tripCanMarkArrived(String tripStatus, List<BidModel> bids) =>
    tripStatus == 'IN_PROGRESS' && tripHasParcelsOnBoard(bids);

/// Colis du trajet déjà remis au voyageur (remis, en transit, arrivés) : leur
/// retour s'ouvre à l'annulation, la feuille d'annulation le signale.
/// Colis pas encore chargés ([bids] `null`) : 0.
int tripHandedOverParcelCount(List<BidModel>? bids) =>
    bids?.where((b) => _handedOverStatuses.contains(b.status)).length ?? 0;
