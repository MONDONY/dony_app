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

/// Lit un prix saisi à la main dans un champ de formulaire.
///
/// Le clavier décimal d'un téléphone français produit une virgule, que
/// `double.tryParse` refuse : sans cette normalisation, un montant parfaitement
/// valide passe pour vide. Renvoie `null` dès que la saisie ne donne pas un
/// montant strictement positif, un prix nul n'étant pas un prix.
double? parsePriceInput(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return value;
}

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

/// Bornes du filtre « prix maximum par kilo », exprimées dans la devise active.
///
/// Le backend interprète désormais `maxPricePerKg` dans la devise ACTIVE du
/// lecteur (converti vers le pivot EUR côté serveur) : les bornes du curseur
/// doivent donc suivre cette devise. Figées à 3–25, elles étaient justes en
/// euro mais absurdes en franc CFA — tout prix XOF dépasse 25, le filtre
/// éliminait 100 % des annonces.
///
/// Arrondi « lisible » : pas de 500 pour les devises sans sous-unité (XOF/XAF),
/// pas de 1 pour les autres. En EUR, rend exactement les bornes historiques
/// (3, 25, pas de 1) : aucun changement de comportement pour la zone euro.
({double min, double max, double step}) priceFilterBoundsActive() =>
    priceFilterBoundsFor(ActiveCurrency.current ?? SupportedCurrency.eur);

/// Variante à devise explicite de [priceFilterBoundsActive] — même pattern que
/// [maxUnitPriceFor] : la logique se teste sans conteneur d'injection.
({double min, double max, double step}) priceFilterBoundsFor(
  SupportedCurrency currency,
) {
  if (currency.minorUnit == 0) {
    double round500(double v) => (v / 500).round() * 500.0;
    return (
      min: round500(3 * currency.unitsPerEur),
      max: round500(25 * currency.unitsPerEur),
      step: 500,
    );
  }
  return (
    min: (3 * currency.unitsPerEur).roundToDouble(),
    max: (25 * currency.unitsPerEur).roundToDouble(),
    step: 1,
  );
}

/// Montants des réponses rapides « Jusqu'à X /kg » du composeur de recherche,
/// scalés de leurs valeurs de référence (6 et 9 EUR/kg) vers la devise active.
///
/// Même contrat que [priceFilterBoundsActive] : la valeur part au backend dans
/// la devise active du lecteur. L'arrondi vise un montant qu'un humain
/// proposerait (4 000 F CFA, 6,5 $), pas une conversion au centime.
List<double> quickPriceFilterOptionsActive() =>
    quickPriceFilterOptionsFor(ActiveCurrency.current ?? SupportedCurrency.eur);

/// Variante à devise explicite de [quickPriceFilterOptionsActive].
List<double> quickPriceFilterOptionsFor(SupportedCurrency currency) {
  double nice(double eur) {
    final scaled = eur * currency.unitsPerEur;
    if (currency.minorUnit == 0) return (scaled / 500).round() * 500.0;
    return (scaled * 2).round() / 2.0;
  }

  return [nice(6), nice(9)];
}

/// Plafond de référence, en euros, d'un prix unitaire ou au kilo. Aligné sur
/// `CurrencyBounds.MAX_PRICE_PER_KG_EUR` côté backend.
const double kMaxUnitPriceEur = 500;

/// Plafond d'un prix unitaire dans la devise active.
///
/// Une limite figée à 500 était juste en euro mais absurde ailleurs : en franc
/// CFA elle plafonnait la saisie à 0,76 €, si bien qu'aucun tarif réaliste ne
/// passait le formulaire. La borne suit donc le taux de la devise.
///
/// Les taux sont les mêmes des deux côtés (`SupportedCurrency.unitsPerEur`,
/// ici et dans `CurrencyBounds` côté serveur) : le formulaire accepte donc
/// exactement ce que l'API accepte. Les faire diverger rouvrirait l'écart entre
/// ce que l'écran promet et ce que le serveur autorise.
double get maxUnitPriceActive =>
    maxUnitPriceFor(ActiveCurrency.current ?? SupportedCurrency.eur);

/// Plafond d'un prix unitaire dans [currency], quelle qu'elle soit — pas
/// nécessairement la devise active du profil.
///
/// Extrait de [maxUnitPriceActive] : une annonce peut désormais se publier
/// dans une devise choisie à la création, distincte de celle du portefeuille.
/// Borner la saisie sur la devise active aurait laissé passer un prix
/// absurde (ou refusé un prix valide) dès que l'annonce et le profil
/// divergent.
double maxUnitPriceFor(SupportedCurrency currency) {
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
  ///
  /// `null` quand ni [pricePerKgDisplay] ni [pricePerKg] ne sont exploitables :
  /// mode `MIXED` sans grille de prix au kilo, ou (net masqué pour un
  /// lecteur anonyme) absence des deux champs. Ne jamais retomber sur `0` :
  /// un net à zéro s'afficherait comme un vrai prix.
  double? get senderPricePerKg {
    final display = pricePerKgDisplay;
    if (display != null) return display;
    final net = pricePerKg;
    return net == null ? null : netToSenderPrice(net);
  }

  /// Équivalent, dans la devise convertie par le serveur
  /// ([AnnouncementModel.convertedCurrency]), du prix affiché à l'expéditeur
  /// ([senderPricePerKg]) — donc majoré de la commission Yadony, pas le net
  /// voyageur brut.
  ///
  /// Le backend (`AnnouncementService`) convertit [pricePerKg] (le NET) vers
  /// [convertedPricePerKg], indépendamment de [pricePerKgDisplay]. Afficher
  /// ce net converti à côté de [senderPricePerKg] (le BRUT, net + commission)
  /// mélangerait deux bases différentes et sous-évaluerait systématiquement
  /// l'estimation d'environ le taux de commission. On réapplique donc ici, au
  /// résultat déjà converti par le serveur, exactement le même ratio net→brut
  /// que celui qui produit [senderPricePerKg] — jamais un nouveau calcul de
  /// taux de change, seulement la majoration commission déjà appliquée au
  /// montant d'origine.
  ///
  /// Pour un lecteur anonyme (net masqué, [pricePerKg] absent), aucun ratio
  /// net→brut n'est calculable ici : on retombe alors sur
  /// [AnnouncementModel.pricePerKgDisplayConverted], que le serveur sert
  /// déjà comme le brut converti (PR #219, compense justement ce trou).
  /// `null` si le serveur n'a rien converti non plus, si [pricePerKg] est nul
  /// pour une autre raison (mode `MIXED` sans tarif au kilo), ou si
  /// [senderPricePerKg] est absent.
  double? get convertedSenderPricePerKg {
    final converted = convertedPricePerKg;
    final net = pricePerKg;
    final sender = senderPricePerKg;
    if (converted == null || net == null || net <= 0 || sender == null) {
      return pricePerKgDisplayConverted;
    }
    final markupRatio = sender / net;
    return converted * markupRatio;
  }

  /// Le trajet porte-t-il un tarif au kilo exploitable **à afficher à
  /// l'expéditeur** ?
  ///
  /// Dérivé de [senderPricePerKg] (pas du net brut [pricePerKg], qui peut être
  /// masqué pour un lecteur anonyme sans que le prix affiché le soit). En mode
  /// `MIXED` le prix au kilo est facultatif : la colonne backend `pricePerKg`
  /// étant `NOT NULL`, le formulaire de création la remplit avec `0.0`, ce que
  /// [senderPricePerKg] répercute à `0.0` plutôt qu'à `null`. C'est donc la
  /// valeur strictement positive de [senderPricePerKg], pas sa seule présence,
  /// qui tranche.
  bool get hasKgPrice {
    final sender = senderPricePerKg;
    return sender != null && sender > 0;
  }

  /// Le trajet est-il vendu à l'article ? Le backend garantit une grille non
  /// vide en mode `MIXED` (422 `price-grid-empty` sinon), mais on vérifie
  /// quand même : une annonce ancienne ou un DTO allégé peut arriver sans.
  bool get usesPriceGrid => pricingMode == 'MIXED' && priceGridItems.isNotEmpty;

  /// Prix expéditeur de l'article le moins cher, pour une accroche « dès X ».
  /// `null` si la grille est absente ou vide.
  double? get cheapestGridPrice => usesPriceGrid
      ? priceGridItems
            .map((i) => i.unitPriceDisplay)
            .reduce((a, b) => a < b ? a : b)
      : null;
}
