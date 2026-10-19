/// Taux unique historique de la commission Yadony, appliqué tant qu'aucune
/// grille de commission par paliers n'est en vigueur (voir
/// `commission_pricing.dart`), et aux offres antérieures aux paliers.
///
/// SOURCE UNIQUE du taux : `dony.commission.rate` côté backend. Le front le
/// charge une fois au démarrage (`GET /config/commission-rate` →
/// [setDonyCommissionRate]) et retombe sur [kDonyCommissionRateDefault] tant
/// qu'il n'est pas chargé ou en cas d'erreur.
///
/// Fichier à part pour que `dony_pricing.dart` (formatage, bornes) et
/// `commission_pricing.dart` (façade de prix) n'aient pas à s'importer l'un
/// l'autre.
const double kDonyCommissionRateDefault = 0.05;

double _donyCommissionRate = kDonyCommissionRateDefault;

/// Taux de commission Yadony courant (ex. 0,05 = 5 %).
double get donyCommissionRate => _donyCommissionRate;

/// Met à jour le taux au démarrage avec la valeur backend. Ignore les valeurs
/// aberrantes (hors ]0,1[) pour rester sur le repli [kDonyCommissionRateDefault].
void setDonyCommissionRate(double rate) {
  if (rate > 0 && rate < 1) {
    _donyCommissionRate = rate;
  }
}
