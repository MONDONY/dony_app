import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';

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

  /// Poids maximum d'une demande route ou bateau, en kilos (miroir de
  /// `WeightLimits` côté back : 999 999,99).
  static const double heavyMaxWeightKg = 999999.99;

  /// Garde-fou technique du budget d'une demande route ou bateau, dans la
  /// devise de la demande : Yadony n'y pose aucun plafond métier (miroir du
  /// back).
  static const double technicalMaxBudget = 1000000;

  /// Poids maximum d'une demande selon son [mode] : 32 kg pour l'avion, le
  /// train, « peu importe » (`null`) et les autres, 999 999,99 kg en route et
  /// en bateau.
  static double maxWeightFor(TransportMode? mode) =>
      mode != null && mode.isHeavy ? heavyMaxWeightKg : maxWeightKg;

  /// Poids valide pour [mode] : au moins [minWeightKg], au plus
  /// [maxWeightFor].
  static bool isWeightValidFor(double? kg, TransportMode? mode) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightFor(mode);

  /// Brouillon IA (« Créer avec l'IA ») : garde les 32 kg, le mode n'y est pas
  /// encore connu. Pour une saisie dans le formulaire, voir [isWeightValidFor].
  static bool isWeightValid(double? kg) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  /// Vrai quand Yadony plafonne le budget (avion, « peu importe », autres) ;
  /// faux en route et en bateau, où seul [technicalMaxBudget] s'applique.
  static bool budgetHasBusinessCap(TransportMode? mode) =>
      !(mode != null && mode.isHeavy);

  /// Plancher du budget dans [currency].
  ///
  /// Même défaut que côté trajet (`maxUnitPriceFor`, `dony_pricing.dart`) :
  /// une borne figée en euros bloquait toute saisie réaliste dès qu'une
  /// demande se publiait en franc CFA — 1..560 XOF valent environ
  /// 0,0015 à 0,85 €, aucun budget de colis ne rentre dans cette fourchette.
  static double minBudgetFor(SupportedCurrency currency) =>
      _scale(minBudgetEur, currency);

  /// Plafond du budget dans [currency]. Voir [minBudgetFor]. En route et en
  /// bateau ([mode]), le plafond est le garde-fou technique, sans mise à
  /// l'échelle : il est exprimé dans la devise de la demande.
  static double maxBudgetFor(
    SupportedCurrency currency, {
    TransportMode? mode,
  }) => budgetHasBusinessCap(mode)
      ? _scale(maxBudgetEur, currency)
      : technicalMaxBudget;

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
  /// [legacy] : demande existante créée avant les paliers, recalculée par le
  /// back au taux unique (aucun minimum).
  ///
  /// [mode] : mode de la demande ; en route et en bateau le budget n'a pas de
  /// plafond métier (voir [maxBudgetFor]).
  static bool isBudgetValid(
    double? amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
    bool legacy = false,
    TransportMode? mode,
  }) =>
      _withinBounds(amount, currency, mode) &&
      netForBudget(amount!, currency, grid: grid, legacy: legacy) != null;

  /// Le budget tient dans les bornes de [currency] mais ne couvre pas les
  /// frais de service minimum de la grille : message dédié, distinct de
  /// celui des bornes.
  static bool isBelowCommissionMinimum(
    double? amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
    bool legacy = false,
    TransportMode? mode,
  }) =>
      _withinBounds(amount, currency, mode) &&
      netForBudget(amount!, currency, grid: grid, legacy: legacy) == null;

  /// Net du voyageur contenu dans le budget public [amount], tel que le back
  /// le stockera ; `null` quand [amount] ne couvre pas les frais de service
  /// minimum de la grille (ou n'est pas un montant positif).
  static double? netForBudget(
    double amount,
    SupportedCurrency currency, {
    CommissionGrid? grid,
    bool legacy = false,
  }) {
    if (!amount.isFinite || amount <= 0) return null;
    try {
      final net = netForSenderGross(
        amount,
        currency.code,
        grid: grid,
        legacy: legacy,
      );
      return net > 0 ? net : null;
    } on BudgetBelowCommissionMinimumException {
      return null;
    }
  }

  static bool _withinBounds(
    double? amount,
    SupportedCurrency currency,
    TransportMode? mode,
  ) =>
      amount != null &&
      amount >= minBudgetFor(currency) &&
      amount <= maxBudgetFor(currency, mode: mode);
}
