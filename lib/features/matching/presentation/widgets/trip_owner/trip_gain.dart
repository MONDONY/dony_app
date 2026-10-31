import 'dart:math' as math;

import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';

/// Statuts d'un colis que le voyageur a récupéré : remis, en transit,
/// arrivé, livré (`DELIVERED` est l'ancien nom de `COMPLETED`, comme dans la
/// carte de gain de la fiche colis). Un colis accepté ou en attente de
/// paiement n'est pas encore récupéré ; un colis clos sans livraison
/// (annulé, refusé, absent, expiré, colis refusé) ne rapporte rien.
const kTripGainRecoveredStatuses = {
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

/// Écart sous lequel un montant compte pour zéro (arrondis du back), comme
/// la carte de gain de la fiche colis.
const _kEpsilon = 0.004;

/// Gain estimé du voyageur sur un trajet, dans la devise [currency] du
/// trajet : nets des colis récupérés, séparés entre ceux payés dans l'app
/// ([online] : carte, mobile money) et ceux payés en espèces ([cash]).
class TripGain {
  const TripGain({
    required this.currency,
    this.online = 0,
    this.cash = 0,
    this.cashGross = 0,
  });

  final String currency;

  /// Net des colis payés dans l'app, versé après la livraison de chacun.
  final double online;

  /// Net des colis payés en espèces : ce que le voyageur garde.
  final double cash;

  /// Argent remis en main propre par les expéditeurs des colis en espèces
  /// ([travelerCashGrossAmount]) : la commission n'en est pas déduite, elle
  /// est avancée à part sur le solde du voyageur (FLUTTER-R8).
  final double cashGross;

  /// Total estimé : [online] + [cash].
  double get total => online + cash;

  /// Frais de service compris dans [cashGross], déjà avancés par le voyageur.
  double get cashCommission => math.max(0, cashGross - cash);

  bool get hasOnline => online > _kEpsilon;
  bool get hasCash => cash > _kEpsilon;
  bool get hasCashCommission => cashCommission > _kEpsilon;

  /// Le trajet rapporte-t-il quelque chose ? Sinon la case Gain n'est pas
  /// affichée.
  bool get hasGain => total > _kEpsilon;
}

/// Gain des colis récupérés parmi [bids] ([kTripGainRecoveredStatuses]),
/// dans la devise [currency] du trajet. Fonction pure.
///
/// - net de chaque colis : [travelerNetAmount] (commission déduite,
///   supplément payé compris) ; un colis sans net connu est ignoré ;
/// - espèces ([BidPaymentMethod.cash]) d'un côté, tous les autres moyens
///   (carte, mobile money) de l'autre ;
/// - un colis dans une autre devise que le trajet est ignoré : l'app n'a
///   pas de taux pour le convertir, et additionner des francs CFA à des
///   euros donnerait un total faux. Un colis hérite de la devise de son
///   trajet : le cas ne vient que d'une donnée incohérente.
TripGain tripGainFor(List<BidModel> bids, String currency) {
  var online = 0.0, cash = 0.0, cashGross = 0.0;
  final code = currency.toUpperCase();
  for (final bid in bids) {
    if (!kTripGainRecoveredStatuses.contains(bid.status)) continue;
    if (bid.currency.toUpperCase() != code) continue;
    final net = travelerNetAmount(bid);
    if (net == null) continue;
    if (bid.paymentMethod == BidPaymentMethod.cash) {
      cash += net;
      cashGross += travelerCashGrossAmount(bid) ?? net;
    } else {
      online += net;
    }
  }
  return TripGain(
    currency: currency,
    online: online,
    cash: cash,
    cashGross: cashGross,
  );
}

/// Gain du trajet [trip] affiché par la case Gain et son sheet : le calcul
/// de l'app sur les colis chargés ([tripGainFor]), rapproché du résumé servi
/// par le détail (`parcelsSummary.netAmount`).
///
/// Le résumé ne compte que les colis remis, en transit ou arrivés payés
/// dans l'app, d'après les paiements enregistrés : il ignore les espèces et
/// les colis livrés. Il sert donc :
/// - liste pas encore chargée ([bids] `null`) : seule source, pour la part
///   en ligne ; les espèces restent inconnues (0) ;
/// - liste chargée : plancher de la part en ligne (le plus grand des deux),
///   pour un colis payé en ligne dont le net manque dans la liste (cas qui
///   ne devrait pas arriver : le net retombe sur prix au kilo × poids).
///   Les deux sources comptent le même net, jamais l'une en plus de l'autre.
///
/// Un résumé dans une autre devise que le trajet est ignoré.
TripGain tripGainOf(AnnouncementModel trip, List<BidModel>? bids) {
  final summary = trip.parcelsSummary;
  final summaryOnline =
      summary != null &&
          summary.currency.toUpperCase() == trip.currency.toUpperCase()
      ? summary.netAmount
      : 0.0;
  final computed = tripGainFor(bids ?? const [], trip.currency);
  return TripGain(
    currency: trip.currency,
    online: math.max(computed.online, summaryOnline),
    cash: computed.cash,
    cashGross: computed.cashGross,
  );
}
