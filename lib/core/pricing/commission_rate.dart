import 'package:flutter/foundation.dart';

/// Taux unique historique de la commission Yadony, appliqué tant qu'aucune
/// grille de commission par paliers n'est en vigueur (voir
/// `commission_pricing.dart`), et aux offres antérieures aux paliers.
///
/// SOURCE UNIQUE du taux : `dony.commission.rate` côté backend. Le front le
/// charge une fois au démarrage (`GET /config/commission-rate` →
/// [setDonyCommissionRate]) et retombe sur [kDonyCommissionRateDefault] tant
/// qu'il n'est pas chargé ou en cas d'erreur.
///
/// Sous grille, `/config/commission-rate` renvoie la première tranche, pas le
/// taux des objets d'avant les paliers : `GET /config/commission-grid` porte
/// alors ce taux dans `legacyRate` ([setLegacyCommissionRate]), qui prime.
///
/// Fichier à part pour que `dony_pricing.dart` (formatage, bornes) et
/// `commission_pricing.dart` (façade de prix) n'aient pas à s'importer l'un
/// l'autre.
const double kDonyCommissionRateDefault = 0.05;

double _donyCommissionRate = kDonyCommissionRateDefault;

/// Vrai dès qu'un `legacyRate` valide a été posé : `/config/commission-rate`,
/// même arrivé après, ne l'écrase plus.
bool _legacyRateSet = false;

/// Taux de commission Yadony courant (ex. 0,05 = 5 %).
double get donyCommissionRate => _donyCommissionRate;

/// Met à jour le taux au démarrage avec la valeur backend. Ignore les valeurs
/// aberrantes (hors ]0,1[) pour rester sur le repli [kDonyCommissionRateDefault].
/// Sans effet une fois un `legacyRate` posé ([setLegacyCommissionRate]).
void setDonyCommissionRate(double rate) {
  if (_legacyRateSet) return;
  if (rate > 0 && rate < 1) {
    _donyCommissionRate = rate;
  }
}

/// Pose le taux des objets sans grille lu dans `GET /config/commission-grid`
/// (`legacyRate`). `null` (back sans le champ) ou hors [0,1[ : sans effet, le
/// taux de `/config/commission-rate` reste.
void setLegacyCommissionRate(double? rate) {
  if (rate == null || rate.isNaN || rate < 0 || rate >= 1) return;
  _legacyRateSet = true;
  _donyCommissionRate = rate;
}

@visibleForTesting
void resetDonyCommissionRate() {
  _legacyRateSet = false;
  _donyCommissionRate = kDonyCommissionRateDefault;
}
