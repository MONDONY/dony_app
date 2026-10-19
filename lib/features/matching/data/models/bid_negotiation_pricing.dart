import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';

/// Brut que paiera l'expéditeur pour un net voyageur [net] sur le fil [n] :
/// l'aperçu de la contre-offre du voyageur. Le serveur recalcule et fait foi.
///
/// - Fil à grille (`commissionGridId`) : grille FIGÉE du bid (chargée par
///   [CommissionGridStore.ensure] avant l'affichage du fil, sinon la grille en
///   vigueur faute de mieux) et réductions figées du bid (taux spécial, bon de
///   parrainage), comme `CommissionCalculator.compute(net, …).gross` du back.
/// - Fil d'avant les grilles : taux figé du fil ([grossForNet]), inchangé.
double grossForNegotiationNet(BidNegotiation n, double net) {
  final gridId = n.commissionGridId;
  if (gridId == null) {
    return grossForNet(net, n.commissionRate ?? donyCommissionRate, n.currency);
  }
  return senderPriceForNet(
    net,
    n.currency,
    grid: CommissionGridStore.byId(gridId) ?? activeCommissionGrid,
    legacyRate: n.commissionRate,
    reductions: CommissionReductions(
      overrideRate: n.commissionOverrideRate,
      voucherFactor: n.commissionVoucherFactor,
    ),
  ).gross;
}

/// Brut que paiera l'expéditeur pour un net voyageur donné, au taux figé du
/// fil (FLUTTER-NS). Réplique exacte de `BidNegotiationPricing.grossForNet`
/// côté serveur (yadony-back #516) : ce n'est qu'un APERÇU, le serveur
/// recalcule et fait foi.
///
/// `brut = arrondi_supérieur(net × (1 + taux), d)` avec `d` les décimales de
/// la devise (2 pour l'euro, 0 pour le franc CFA), puis une unité mineure de
/// moins tant que `arrondi_demi_haut(brut / (1 + taux), 2)` atteint encore le
/// net (au plus un pas).
///
/// Calcul en entiers (centimes, taux en millionièmes) : un `double` ferait
/// basculer un arrondi supérieur d'une unité sur un produit comme
/// `35 × 1,12 = 39,2000000001`.
double grossForNet(double netEur, double rate, String currencyCode) {
  if (netEur <= 0) return 0;
  final decimals = SupportedCurrency.fromCodeOrDefault(currencyCode).minorUnit;
  final safeRate = rate < 0 ? 0.0 : rate;
  const scale = 1000000;
  final rateMicro = (safeRate * scale).round();
  final factor = scale + rateMicro; // (1 + taux) en millionièmes

  // Net cible en centimes, arrondi demi-haut comme `setScale(2, HALF_UP)`.
  final target = (netEur * 100 + 1e-9).round();
  // Une unité mineure de la devise, en centimes (1 pour l'euro, 100 pour XOF).
  final step = _pow10(2 - decimals);

  // Plafond de target × factor / scale à l'unité mineure, en entiers.
  final denom = scale * step;
  final units = (target * factor + denom - 1) ~/ denom;
  var gross = units * step;

  int netOf(int grossCents) =>
      // arrondi demi-haut de grossCents × scale / factor
      (2 * grossCents * scale + factor) ~/ (2 * factor);

  while (gross - step > 0 && netOf(gross - step) >= target) {
    gross -= step;
  }
  return gross / 100;
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
