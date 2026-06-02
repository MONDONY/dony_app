import 'package:dony/features/matching/data/models/announcement_model.dart';

/// Source unique de vérité, côté app, pour le passage **prix net voyageur →
/// prix affiché expéditeur** (commission Dony incluse).
///
/// Modèle métier (vérifié backend, `PaymentService` / `PriceGridService`) :
/// - `pricePerKg` (mode KG) et `unitPriceNet` (mode MIXED) = **NET** = ce que
///   le voyageur touche réellement.
/// - L'expéditeur paie ce net **+ 12 %** : `display = net × 1,12`. Le backend
///   expose déjà ce prix via `unitPriceDisplay` (MIXED) et `pricePerKgDisplay`
///   (KG). Ce helper centralise le multiplicateur pour les rares cas sans champ
///   display fourni (ex. suggestions de re-match, montant dérivé d'un bid).
///
/// SOURCE UNIQUE du taux : `dony.commission.rate` côté backend. Le front le
/// charge une fois au démarrage (`GET /config/commission-rate` → [setDonyCommissionRate])
/// et retombe sur 12 % tant qu'il n'est pas chargé / en cas d'erreur. Changer la
/// valeur backend suffit donc à ajuster la commission partout.
const double kDonyCommissionRateDefault = 0.12;

double _donyCommissionRate = kDonyCommissionRateDefault;

/// Taux de commission Dony courant (ex. 0,12 = 12 %).
double get donyCommissionRate => _donyCommissionRate;

/// Multiplicateur net → prix affiché à l'expéditeur (= 1 + commission).
double get donyCommissionMultiplier => 1 + _donyCommissionRate;

/// Met à jour le taux au démarrage avec la valeur backend. Ignore les valeurs
/// aberrantes (hors ]0,1[) pour rester sur le repli 12 %.
void setDonyCommissionRate(double rate) {
  if (rate > 0 && rate < 1) _donyCommissionRate = rate;
}

/// Convertit un prix **net** (ce que touche le voyageur) en prix **affiché à
/// l'expéditeur** (commission Dony incluse). À n'utiliser que faute de champ
/// `*Display` fourni par le backend.
double netToSenderPrice(double net) => net * donyCommissionMultiplier;

/// Formate un prix au kilo : entier si rond, 2 décimales sinon
/// (ex. 6 → « 6 », 5,6 → « 5.60 »). Aligné sur l'affichage du mode MIXED.
/// Pratique car le prix expéditeur (net × 1,12) est rarement entier.
String formatKgPrice(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

extension AnnouncementSenderPricing on AnnouncementModel {
  /// Prix au kilo **affiché à l'expéditeur** (net + commission). Préfère le
  /// champ backend [AnnouncementModel.pricePerKgDisplay] s'il est présent, sinon
  /// recalcule via [donyCommissionMultiplier]. À utiliser sur toutes les
  /// surfaces vues par l'expéditeur ; les surfaces voyageur gardent `pricePerKg`.
  double get senderPricePerKg =>
      pricePerKgDisplay ?? netToSenderPrice(pricePerKg);
}
