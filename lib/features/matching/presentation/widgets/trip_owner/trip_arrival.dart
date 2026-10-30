import 'package:dony/features/matching/data/models/bid_model.dart';

// Règles d'arrivée de l'écran du trajet vu par son voyageur : pied collant
// et annulation.

/// Colis entre les mains du voyageur : à restituer si le trajet est annulé.
const _handedOverStatuses = <String>{'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED'};

/// Le voyageur peut-il marquer son trajet arrivé ? Oui dès qu'un colis lui a
/// été remis (`HANDED_OVER`, avec ou sans scan Transit) ou voyage
/// (`IN_TRANSIT`).
///
/// Le scan Transit est facultatif (yadony-back #336) : un colis récupéré au
/// départ suffit à marquer le trajet arrivé. Un colis pas encore récupéré
/// (`ACCEPTED`) ne bloque pas le trajet, il reste simplement en attente ; un
/// colis déjà arrivé non plus (un autre, passé en transit plus tard, se
/// marque encore). Une fois l'arrivée marquée, les instructions de retrait
/// se modifient depuis la tuile « Arrivée » (`TripTile.arrival`).
bool tripCanMarkArrived(List<BidModel> bids) =>
    bids.any((b) => b.status == 'HANDED_OVER' || b.status == 'IN_TRANSIT');

/// Colis du trajet déjà remis au voyageur (remis, en transit, arrivés) : leur
/// retour s'ouvre à l'annulation, la feuille d'annulation le signale.
/// Colis pas encore chargés ([bids] `null`) : 0.
int tripHandedOverParcelCount(List<BidModel>? bids) =>
    bids?.where((b) => _handedOverStatuses.contains(b.status)).length ?? 0;
