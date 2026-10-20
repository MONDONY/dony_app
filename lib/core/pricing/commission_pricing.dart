import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_rate.dart';

/// Façade de prix côté expéditeur : la grille de commission par paliers quand
/// le serveur en publie une, sinon le taux unique historique
/// ([donyCommissionRate]).
///
/// Les écrans passent par ici plutôt que par [computeCommission] : la façade
/// choisit le chemin, retombe sur le taux unique quand la grille ne couvre pas
/// la devise, et ne lève jamais pour un net nul ou une devise inconnue (repli
/// EUR, comme [formatPriceIn]). Le serveur reste la source de vérité : un
/// montant qu'il sert (`totalSenderAmountEur`, `pricePerKgDisplay`) passe
/// toujours avant ce calcul (`formatPriceIn`, dans `dony_pricing.dart`).

/// Prix payé par l'expéditeur pour un net du voyageur.
class SenderPrice {
  const SenderPrice({
    required this.net,
    required this.commission,
    required this.gross,
    required this.minimumApplied,
    required this.fromGrid,
  });

  /// Rien à payer : net nul ou négatif.
  static const zero = SenderPrice(
    net: 0,
    commission: 0,
    gross: 0,
    minimumApplied: false,
    fromGrid: false,
  );

  /// Net du voyageur, à l'unité mineure de la devise.
  final double net;

  /// Frais de service Yadony, à l'unité mineure de la devise.
  final double commission;

  /// Total payé par l'expéditeur, `net + commission`.
  final double gross;

  /// Vrai quand le minimum de la devise a relevé les frais.
  final bool minimumApplied;

  /// Vrai quand le calcul vient d'une grille, faux pour le taux unique.
  final bool fromGrid;
}

/// Une grille de commission est-elle en vigueur ?
bool get commissionGridActive => activeCommissionGrid != null;

/// Prix expéditeur pour [net] dans [currencyCode].
///
/// Grille : [grid], sinon la grille en vigueur ([activeCommissionGrid]). Sans
/// grille, avec [legacy] (offre antérieure aux paliers) ou quand la grille n'a
/// pas de minimum pour la devise, le taux unique s'applique, exactement comme
/// avant les paliers : `net × (legacyRate ?? donyCommissionRate)` arrondi
/// HALF_UP à l'unité mineure, brut = net arrondi + frais.
SenderPrice senderPriceForNet(
  double net,
  String? currencyCode, {
  CommissionGrid? grid,
  bool legacy = false,
  double? legacyRate,
  CommissionReductions reductions = CommissionReductions.none,
}) {
  final currency = SupportedCurrency.fromCodeOrDefault(currencyCode);
  if (!_isPositiveAtMinorUnit(net, currency)) return SenderPrice.zero;

  final usable = legacy ? null : _usableGrid(grid, currency);
  if (usable != null) {
    final result = computeCommission(
      net,
      currency.code,
      usable,
      reductions: reductions,
    );
    return SenderPrice(
      net: result.net,
      commission: result.commission,
      gross: result.gross,
      minimumApplied: result.minimumApplied,
      fromGrid: true,
    );
  }

  // Taux unique, calculé par le même décimal exact que la grille : une seule
  // tranche au taux hérité, minimum nul (la commission n'est jamais relevée).
  final rate = legacyRate ?? donyCommissionRate;
  final result = computeCommission(
    net,
    currency.code,
    _flatRateGrid(rate, currency),
  );
  return SenderPrice(
    net: result.net,
    commission: result.commission,
    gross: result.gross,
    minimumApplied: false,
    fromGrid: false,
  );
}

/// Net du voyageur contenu dans un brut [gross] payé par l'expéditeur (budget
/// TTC d'une demande, brut négocié).
///
/// Grille : plus grand net dont le brut tient dans [gross] ([netForGross]),
/// qui lève [BudgetBelowCommissionMinimumException] quand [gross] ne couvre
/// pas le minimum. Taux unique (sans grille, [legacy], ou minimum absent pour
/// la devise) : `gross / (1 + donyCommissionRate)`.
double netForSenderGross(
  double gross,
  String? currencyCode, {
  CommissionGrid? grid,
  bool legacy = false,
}) {
  final currency = SupportedCurrency.fromCodeOrDefault(currencyCode);
  final usable = legacy ? null : _usableGrid(grid, currency);
  if (usable == null) return gross / (1 + donyCommissionRate);
  return netForGross(gross, currency.code, usable);
}

/// Prix unitaire (au kilo, à l'article) affiché dans les listes à
/// l'expéditeur, faute de champ `*Display` servi par le serveur.
///
/// Sous grille, les frais ne se répartissent plus à l'unité : la liste montre
/// le net et les frais de service s'ajoutent au total. Sans grille, ou quand
/// la grille n'a pas de minimum pour [currencyCode], le prix reste majoré du
/// taux unique, comme avant : même règle que [senderPriceForNet] et que la
/// mention « + frais de service » (`listPriceFeeSuffix`), qui n'apparaît
/// qu'avec ce minimum.
double listUnitPrice(double netUnit, String? currencyCode) =>
    commissionMinimumFor(currencyCode) != null
    ? netUnit
    : flatRateGross(netUnit);

/// Brut au taux unique historique, sans arrondi : `net × (1 +
/// donyCommissionRate)`. Aperçus locaux d'avant les paliers (prix au kilo,
/// total d'une offre sans grille), où l'arrondi HALF_UP de
/// [senderPriceForNet] changerait le montant affiché.
double flatRateGross(double net) => net * (1 + donyCommissionRate);

/// Frais de service minimum de la grille en vigueur dans [currencyCode]
/// (repli EUR), `null` sans grille ou sans minimum pour la devise.
double? commissionMinimumFor(String? currencyCode) => activeCommissionGrid
    ?.minimumFor(SupportedCurrency.fromCodeOrDefault(currencyCode).code);

/// Moitié de l'unité mineure de [currency] (0,005 en euros, 0,5 en franc
/// CFA) : un écart plus petit entre deux montants n'est qu'un reste d'arrondi.
double halfMinorUnit(SupportedCurrency currency) =>
    1 / _minorUnitFactor(currency) / 2;

// ── Interne ────────────────────────────────────────────────────────────────

/// `10^minorUnit` : 100 pour l'euro, 1 pour le franc CFA.
double _minorUnitFactor(SupportedCurrency currency) {
  var factor = 1.0;
  for (var i = 0; i < currency.minorUnit; i++) {
    factor *= 10;
  }
  return factor;
}

/// Grille à utiliser pour [currency], `null` quand il faut retomber sur le
/// taux unique (aucune grille, ou pas de minimum pour la devise).
CommissionGrid? _usableGrid(CommissionGrid? grid, SupportedCurrency currency) {
  final candidate = grid ?? activeCommissionGrid;
  if (candidate == null || candidate.minimumFor(currency.code) == null) {
    return null;
  }
  return candidate;
}

/// Le net arrondi à l'unité mineure reste-t-il strictement positif ? Sinon
/// [computeCommission] lèverait.
bool _isPositiveAtMinorUnit(double net, SupportedCurrency currency) {
  if (!net.isFinite || net <= 0) return false;
  return (net * _minorUnitFactor(currency)).round() > 0;
}

CommissionGrid _flatRateGrid(double rate, SupportedCurrency currency) =>
    CommissionGrid(
      id: 'legacy-flat-rate',
      effectiveFrom: DateTime.utc(1970),
      tiers: [CommissionTier(fromEur: 0, rate: rate)],
      minimums: {currency.code: 0},
    );
