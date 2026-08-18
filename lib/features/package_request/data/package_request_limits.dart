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

  /// Budget brut. Le backend descend à 0, on relève le plancher : un budget
  /// nul ne rémunère personne et affichait « Le voyageur touchera 0,00 € ».
  static const double minBudget = 1.0;
  static const double maxBudget = 560.0;

  static bool isWeightValid(double? kg) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  static bool isBudgetValid(double? amount) =>
      amount != null && amount >= minBudget && amount <= maxBudget;

  /// Dérivé des bornes plutôt que retapé : le libellé était écrit en clair à
  /// deux endroits, qu'un changement de borne aurait laissés faux en silence.
  static String get weightRangeLabel =>
      'Entre ${_fr(minWeightKg)} et ${_fr(maxWeightKg)} kg';

  static String _fr(double v) => (v.truncateToDouble() == v
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceFirst('.', ','));
}
