import 'dart:math' as math;
import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/foundation.dart';

/// Source unique de vérité, côté app, pour le passage **prix net voyageur →
/// prix affiché expéditeur** (commission Yadony incluse).
///
/// Modèle métier (vérifié backend, `PaymentService` / `PriceGridService`) :
/// - `pricePerKg` (mode KG) et `unitPriceNet` (mode MIXED) = **NET** = ce que
///   le voyageur touche réellement.
/// - L'expéditeur paie ce net **+ la commission** : `display = net × (1 + taux)`. Le backend
///   expose déjà ce prix via `unitPriceDisplay` (MIXED) et `pricePerKgDisplay`
///   (KG). Ce helper centralise le multiplicateur pour les rares cas sans champ
///   display fourni (ex. suggestions de re-match, montant dérivé d'un bid).
///
/// SOURCE UNIQUE du taux : `dony.commission.rate` côté backend. Le front le
/// charge une fois au démarrage (`GET /config/commission-rate` → [setDonyCommissionRate])
/// et retombe sur [kDonyCommissionRateDefault] tant qu'il n'est pas chargé /
/// en cas d'erreur. Changer la valeur backend suffit donc à ajuster la
/// commission partout.
const double kDonyCommissionRateDefault = 0.05;

double _donyCommissionRate = kDonyCommissionRateDefault;

/// Taux de commission Yadony courant (ex. 0,05 = 5 %).
double get donyCommissionRate => _donyCommissionRate;

/// Libellé du taux courant en pourcentage, virgule française si décimal
/// (ex. « 5 », « 12,5 »). À interpoler dans les textes UI :
/// `'$donyCommissionPercentLabel %'`.
String get donyCommissionPercentLabel {
  final pct = _donyCommissionRate * 100;
  return pct % 1 == 0
      ? pct.toStringAsFixed(0)
      : pct.toStringAsFixed(1).replaceFirst('.', ',');
}

/// Multiplicateur net → prix affiché à l'expéditeur (= 1 + commission).
double get donyCommissionMultiplier => 1 + _donyCommissionRate;

/// Met à jour le taux au démarrage avec la valeur backend. Ignore les valeurs
/// aberrantes (hors ]0,1[) pour rester sur le repli [kDonyCommissionRateDefault].
void setDonyCommissionRate(double rate) {
  if (rate > 0 && rate < 1) {
    _donyCommissionRate = rate;
  }
}

/// Convertit un prix **net** (ce que touche le voyageur) en prix **affiché à
/// l'expéditeur** (commission Yadony incluse). À n'utiliser que faute de champ
/// `*Display` fourni par le backend.
double netToSenderPrice(double net) => net * donyCommissionMultiplier;

/// Formate un prix au kilo : entier si rond, 2 décimales sinon
/// (ex. 6 → « 6 », 5,6 → « 5.60 »). Aligné sur l'affichage du mode MIXED.
/// Pratique car le prix expéditeur (net × multiplicateur) est rarement entier.
String formatKgPrice(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

/// Formate un prix dans sa devise réelle (symbole et position corrects),
/// sans décimales superflues (ex. « 8 € », « CA\$8.40 »). À utiliser partout
/// où la devise du trajet/bid/annonce est connue, à la place de
/// [formatKgPrice] + un « € » codé en dur. Repli EUR si absente/inconnue.
String formatPriceIn(double value, String? currencyCode) {
  return CurrencyFormatter.format(
    value,
    SupportedCurrency.fromCodeOrDefault(currencyCode),
    compact: true,
  );
}

/// Formate un prix dans la **devise active de l'utilisateur**, pour les montants
/// qui ne se rattachent à aucun objet portant sa propre devise : soldes, revenus,
/// bornes de filtres, champs de saisie.
///
/// Ne jamais écrire `'${formatKgPrice(v)} €'` à la place : le symbole serait faux
/// dès qu'un utilisateur passe en XOF ou en CAD. Quand un objet porte une devise
/// (annonce, offre, fil de négociation), utiliser [formatPriceIn] avec la devise
/// de cet objet, car elle est figée à la création et ne suit pas les réglages.
String formatPriceActive(double value) =>
    formatPriceIn(value, ActiveCurrency.current?.code);

/// Symbole de la devise active, pour les rares surfaces qui affichent l'unité
/// séparément du montant (suffixe de champ, en-tête de colonne).
String get activeCurrencySymbol =>
    (ActiveCurrency.current ?? SupportedCurrency.eur).symbol;

/// Formate un montant reçu en **unités mineures** (ce que renvoie Stripe et ce
/// que stockent les montants en centimes côté backend).
///
/// Diviser par 100 en dur serait faux : le franc CFA n'a pas de sous-unité, si
/// bien qu'un montant de 5000 XOF y deviendrait « 50 ». Le diviseur suit donc la
/// sous-unité déclarée par la devise (100 pour l'euro, 1 pour le XOF).
String formatMinorAmount(int minorAmount, String? currencyCode) {
  final currency = SupportedCurrency.fromCodeOrDefault(currencyCode);
  final divisor = math.pow(10, currency.minorUnit);
  return CurrencyFormatter.format(minorAmount / divisor, currency);
}

/// Plafond de référence, en euros, d'un prix unitaire ou au kilo. Aligné sur
/// `CurrencyBounds.MAX_PRICE_PER_KG_EUR` côté backend.
const double kMaxUnitPriceEur = 500;

/// Plafond d'un prix unitaire dans la devise active.
///
/// Une limite figée à 500 était juste en euro mais absurde ailleurs : en franc
/// CFA elle plafonnait la saisie à 0,76 €, si bien qu'aucun tarif réaliste ne
/// passait le formulaire. La borne suit donc l'ordre de grandeur de la devise.
/// Elle reste un peu plus stricte que celle du backend, ce qui est le bon sens :
/// le formulaire ne doit jamais accepter ce que l'API refusera.
double get maxUnitPriceActive {
  final currency = ActiveCurrency.current ?? SupportedCurrency.eur;
  final scaled = kMaxUnitPriceEur * currency.unitsPerEur;
  return currency.minorUnit == 0 ? scaled.floorToDouble() : scaled;
}

/// Plafond de remboursement Yadony en cas de perte de colis (€), source unique
/// backend `dony.reimbursement.max-amount-eur`. Chargé une fois au démarrage
/// via `GET /config/reimbursement-cap` → [setDonyReimbursementCap], repli sur
/// [kDonyReimbursementCapDefault] tant qu'il n'est pas chargé / en cas d'erreur.
const double kDonyReimbursementCapDefault = 50;

final ValueNotifier<double> _donyReimbursementCapNotifier = ValueNotifier(
  kDonyReimbursementCapDefault,
);

/// Plafond de remboursement courant en euros.
double get donyReimbursementCapEur => _donyReimbursementCapNotifier.value;

/// Écoute les changements du plafond chargé depuis le backend.
ValueListenable<double> get donyReimbursementCapListenable =>
    _donyReimbursementCapNotifier;

/// Libellé du plafond (entier si rond, sinon 2 décimales max, virgule FR).
/// À interpoler dans les textes UI : `'$donyReimbursementCapLabel €'`.
String get donyReimbursementCapLabel {
  final v = donyReimbursementCapEur;
  return v % 1 == 0
      ? v.toStringAsFixed(0)
      : v
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst('.', ',');
}

/// Met à jour le plafond au démarrage avec la valeur backend. Ignore les
/// valeurs non strictement positives (repli sur le défaut).
void setDonyReimbursementCap(double amount) {
  if (amount > 0) {
    _donyReimbursementCapNotifier.value = amount;
  }
}

extension AnnouncementSenderPricing on AnnouncementModel {
  /// Prix au kilo **affiché à l'expéditeur** (net + commission). Préfère le
  /// champ backend [AnnouncementModel.pricePerKgDisplay] s'il est présent, sinon
  /// recalcule via [donyCommissionMultiplier]. À utiliser sur toutes les
  /// surfaces vues par l'expéditeur ; les surfaces voyageur gardent `pricePerKg`.
  double get senderPricePerKg =>
      pricePerKgDisplay ?? netToSenderPrice(pricePerKg);
}
