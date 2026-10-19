import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_pricing.dart';

/// Bornes de saisie d'une demande d'envoi.
///
/// Miroir des annotations de validation de `PackageRequestCreateRequest` côté
/// backend (`@DecimalMin` / `@DecimalMax`). Ces valeurs sont compilées dans le
/// jar, elles ne transitent par aucun endpoint de configuration : la source
/// unique côté Flutter est donc ce fichier, et non chaque écran.
///
/// Le plafond du budget était figé à 500 dans le formulaire alors que le
/// backend en acceptait 560, précisément parce que la valeur vivait dans un
/// `State` de widget où personne n'allait la relire.
abstract final class PackageRequestLimits {
  static const double minWeightKg = 0.5;
  static const double maxWeightKg = 32.0;

  /// Budget brut de référence, **en euros**. Le backend descend à 0, on
  /// relève le plancher : un budget nul ne rémunère personne et affichait
  /// « Le voyageur touchera 0,00 € ».
  ///
  /// Ne jamais comparer un montant saisi directement à ces constantes : une
  /// demande se publie désormais dans la devise choisie par l'expéditeur
  /// (Tâche 13), pas nécessairement en euros. Passer par [minBudgetFor] /
  /// [maxBudgetFor] / [isBudgetValid], qui mettent ces bornes à l'échelle de
  /// la devise DE LA DEMANDE.
  static const double minBudgetEur = 1.0;
  static const double maxBudgetEur = 560.0;

  static bool isWeightValid(double? kg) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  /// Plancher du budget dans [currency].
  ///
  /// Même défaut que côté trajet (`maxUnitPriceFor`, `dony_pricing.dart`) :
  /// une borne figée en euros bloquait toute saisie réaliste dès qu'une
  /// demande se publiait en franc CFA — 1..560 XOF valent environ
  /// 0,0015 à 0,85 €, aucun budget de colis ne rentre dans cette fourchette.
  static double minBudgetFor(SupportedCurrency currency) =>
      _scale(minBudgetEur, currency);

  /// Plafond du budget dans [currency]. Voir [minBudgetFor].
  static double maxBudgetFor(SupportedCurrency currency) =>
      _scale(maxBudgetEur, currency);

  /// Même formule que `maxUnitPriceFor` : mise à l'échelle par
  /// `unitsPerEur`, puis arrondie à l'unité pour les devises sans
  /// sous-unité (XOF, XAF n'ont pas de centime).
  static double _scale(double eurValue, SupportedCurrency currency) {
    final scaled = eurValue * currency.unitsPerEur;
    return currency.minorUnit == 0 ? scaled.floorToDouble() : scaled;
  }

  /// [currency] : la devise DE LA DEMANDE (celle choisie dans le
  /// sélecteur de l'étape budget), jamais une devise de repli implicite —
  /// c'est exactement ce qui manquait avant ce fix : un budget saisi en XOF
  /// était comparé aux bornes euros et rendu invalide en silence.
  ///
  /// Sous grille de commission ([grid], sinon la grille en vigueur), le
  /// budget doit en plus couvrir les frais de service minimum : le back
  /// refuse sinon la demande (422 `budget-below-commission-minimum`).
  static bool isBudgetValid(
    double? amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
  }) =>
      _withinBounds(amount, currency) &&
      netForBudget(amount!, currency, grid: grid) != null;

  /// Le budget tient dans les bornes de [currency] mais ne couvre pas les
  /// frais de service minimum de la grille : message dédié, distinct de
  /// celui des bornes.
  static bool isBelowCommissionMinimum(
    double? amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
  }) =>
      _withinBounds(amount, currency) &&
      netForBudget(amount!, currency, grid: grid) == null;

  /// Net du voyageur contenu dans le budget public [amount], tel que le back
  /// le stockera ; `null` quand [amount] ne couvre pas les frais de service
  /// minimum de la grille (ou n'est pas un montant positif).
  static double? netForBudget(
    double amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
  }) {
    if (!amount.isFinite || amount <= 0) return null;
    try {
      final net = netForSenderGross(amount, currency.code, grid: grid);
      return net > 0 ? net : null;
    } on BudgetBelowCommissionMinimumException {
      return null;
    }
  }

  static bool _withinBounds(double? amount, SupportedCurrency currency) =>
      amount != null &&
      amount >= minBudgetFor(currency) &&
      amount <= maxBudgetFor(currency);
}
