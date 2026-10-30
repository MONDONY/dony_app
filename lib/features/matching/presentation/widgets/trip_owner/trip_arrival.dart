import 'package:dony/features/matching/data/models/bid_model.dart';

// Règles d'arrivée de l'écran du trajet vu par son voyageur : pied collant,
// menu ⋮ et annulation.

const _biddableActiveStatuses = <String>{
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
};

/// Colis entre les mains du voyageur : à restituer si le trajet est annulé.
const _handedOverStatuses = <String>{'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED'};

/// Mode du CTA d'arrivée affiché au voyageur propriétaire.
enum TripArrivalCta {
  /// Au moins un colis actif a été récupéré (HANDED_OVER, avec ou sans scan
  /// Transit, facultatif) : le marquer arrivé.
  markArrived,

  /// Trajet déjà marqué arrivé : seule l'édition des instructions reste
  /// possible (le bouton doit rester accessible, sinon les instructions
  /// deviennent définitivement figées).
  editInstructions,
}

/// `null` = aucun CTA (aucun colis récupéré ni arrivé, ou plus aucun colis actif).
///
/// Le scan Transit est facultatif (yadony-back #336) : un colis récupéré au
/// départ suffit à marquer le trajet arrivé. Un colis pas encore récupéré ne
/// bloque pas le trajet, il reste simplement en attente.
TripArrivalCta? tripArrivalCtaFor(List<BidModel> bids) {
  final active = bids
      .where((b) => _biddableActiveStatuses.contains(b.status))
      .toList();
  if (active.any(
    (b) => b.status == 'HANDED_OVER' || b.status == 'IN_TRANSIT',
  )) {
    return TripArrivalCta.markArrived;
  }
  if (active.any((b) => b.status == 'ARRIVED')) {
    return TripArrivalCta.editInstructions;
  }
  return null;
}

/// Colis du trajet déjà remis au voyageur (remis, en transit, arrivés) : leur
/// retour s'ouvre à l'annulation, la feuille d'annulation le signale.
/// Colis pas encore chargés ([bids] `null`) : 0.
int tripHandedOverParcelCount(List<BidModel>? bids) =>
    bids?.where((b) => _handedOverStatuses.contains(b.status)).length ?? 0;
