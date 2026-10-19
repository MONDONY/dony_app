# Commission par paliers (dony_app) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapter l'app à la commission par grille marginale datée avec minimum par devise (yadony-back #591), sans changer un seul prix tant qu'aucune grille n'est en vigueur.

**Architecture:** Un portage Dart pur du calculateur du back (`commission_calculator.dart`, arithmétique entière `BigInt`, testé sur le fichier de vecteurs recopié du back), une mémoire globale des grilles chargée au démarrage (`CommissionGridStore`), et une façade unique (`commission_pricing.dart`) qui choisit grille ou taux unique. Tous les calculs locaux de l'inventaire passent par cette façade ; les montants servis par le serveur priment toujours. Sans grille (`current: null`, 404, erreur réseau), la façade reproduit au centime le comportement actuel.

**Tech Stack:** Flutter/Dart, flutter_bloc, GoRouter, Dio, GetIt, json_serializable, bloc_test, mocktail.

**Spec:** `yadony-back` origin/main `docs/superpowers/specs/2026-10-18-commission-paliers-design.md` (§4.2, §4.3, §4.6, §7.1 à §7.3) et contrats livrés `docs/stories-done/story-commission-paliers.md`. Lire avec `/usr/bin/git -C ../../dony-back show origin/main:<chemin>`.

## Global Constraints

- PR jumelle du back **#591** (fusionnée, en staging, pas en prod). La description de la PR app la cite ; l'app tolère l'ancien contrat : `/config/commission-grid` absent (404), `current: null`, champs de devis absents.
- Les montants du serveur (`totalEur`, `commissionEur`, `grossPriceEur`, `totalSenderAmountEur`, `pricePerKgDisplay`, `unitPriceDisplay`, `minGridUnitPriceDisplay`, `pricePerKgSenderEur`) priment toujours sur un calcul local.
- Sans grille active, chaque valeur affichée est identique à celle d'aujourd'hui (taux unique `donyCommissionRate`, arrondi au centime comme `PriceDisplay.feeFromNet`, `grossForNet` pour les fils de trajet hérités).
- Bornes de tranche converties avec `SupportedCurrency.unitsPerEur` (constantes 1 ; 1,08 ; 1,47 ; 0,86 ; 0,95 ; 655,957), jamais avec `ActiveRates`. Un seul arrondi HALF_UP à `minorUnit` de la devise, à la fin.
- Aucun pourcentage en dur dans le code ni les ARB. Le minimum affiché vient toujours de la grille chargée, dans la devise affichée.
- Libellé public : « Frais de service Yadony ». Marque « Yadony » uniquement.
- Pas de tiret cadratin dans les textes visibles. Pas de dégradé (couleurs unies).
- BLoC uniquement pour l'état nouveau (pas de `setState`), GoRouter (pas de `Navigator.push`). Tout `DonyButton` d'un bottom sheet reste dans `stickyBottom` (CLAUDE.md racine).
- ARB : toute clé ajoutée l'est en fr ET en en (`lib/l10n/app_fr.arb` est le gabarit), avec `@clé.description`, puis `flutter gen-l10n` (sorties versionnées dans `lib/l10n/generated/`).
- `.g.dart` : `dart run build_runner build --delete-conflicting-outputs` après chaque modèle `@JsonSerializable` touché.
- La grille est un état global : tout test qui en installe une passe par `useTestCommissionGrid()` (tâche 2), qui la retire en `addTearDown`. Les tests sans grille appellent `CommissionGridStore.reset()` en `setUp` s'ils tournent dans un fichier qui en installe une.
- Garde-fou des textes en dur à 0 : `dart run tool/check_hardcoded_strings.dart` (lancé par la CI) doit rester vert ; tout texte passe par une clé ARB et `context.l10n`.
- Code mort interdit (CLAUDE.md de l'app, règle 18) : un widget, bloc ou fonction sans appelant est supprimé avec ses tests, pas laissé « au cas où ».
- Analytics : aucun nouvel événement n'est requis (les montants n'entrent jamais dans les propriétés). Un BLoC dont la signature change garde son `AnalyticsService` et son enregistrement dans `injection.dart` est mis à jour.
- AUCUN build `.ipa`, `.aab`, `.apk`. Pas de `flutter run`.
- Couverture globale ≥ 90 % ; aucun test rouge ; commits sur `feature/commission-paliers`, sans ligne `Co-Authored-By`.
- Mise à jour forcée (spec §7.2) : ne pas toucher à `min_supported_build`. La description de PR documente la valeur à viser (tâche 11).

## Review Focus

1. **Budget au plancher sous grille.** `PackageRequestLimits.minBudgetEur` vaut 1,0 : sous grille, 1,00 € ne couvre pas le minimum et le back répond 422 `budget-below-commission-minimum`. Le formulaire doit refuser ce budget avant l'envoi, avec le minimum dans la devise (test tâche 8).
2. **Grille qui entre en vigueur app ouverte.** Avant la première grille, `/config/commission-grid` renvoie `current: null, next: {…}`. Une session ouverte doit basculer sur `next` dès `effectiveFrom` franchi, sans redémarrage (test tâche 2).
3. **`effectiveFrom` sans fuseau.** Le back sérialise un `LocalDateTime` UTC sans suffixe (`2026-11-20T09:00:00`). `DateTime.parse` le lirait en heure locale : bascule décalée d'une ou deux heures (test tâche 1).
4. **Francs CFA.** Commission en francs entiers, minimum 650, suffixe « min. 650 F CFA » et jamais « 1 € » sur un trajet en XOF (vecteurs tâche 1, test tâche 4).
5. **Serveur sans grille.** 404 sur un back de prod sans #591, `current: null` ou erreur réseau : tous les écrans identiques à aujourd'hui, aucun suffixe « min. » (tests tâches 2 et 3).

---

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `lib/core/pricing/commission_calculator.dart` (créé) | Modèle `CommissionGrid` et calcul pur §4.2/§4.3 (grille, taux spécial, bon, minimum), sans code promo |
| `lib/core/pricing/commission_grid_store.dart` (créé) | Grilles connues (en vigueur, programmée, figées chargées par id), grille active à l'instant t |
| `lib/core/pricing/commission_pricing.dart` (créé) | Façade : grille si active, sinon taux unique ; seul point d'entrée des écrans |
| `lib/core/pricing/pricing_labels.dart` (modifié) | Suffixe « + frais de service Yadony (min. X) », montant de frais avec « (minimum) » |
| `lib/features/config/data/config_datasource.dart`, `config_repository.dart` (modifiés) | `GET /config/commission-grid` et `/config/commission-grid/{id}` |
| `lib/features/package_request/data/models/thread_pricing.dart` (créé) | `ThreadPricer` : prix d'un fil de demande selon sa grille |
| `test/fixtures/commission/vectors.json` (créé) | Copie octet pour octet de `yadony-back:src/test/resources/commission/vectors.json` |
| `test/helpers/commission_grid_test_doubles.dart` (créé) | Grille 7/6/5 de test et `useTestCommissionGrid()` |

---

### Task 1: Portage Dart du calculateur et vecteurs du back

**Files:**
- Create: `lib/core/pricing/commission_calculator.dart`
- Create: `test/fixtures/commission/vectors.json`
- Test: `test/core/pricing/commission_calculator_vectors_test.dart`, `test/core/pricing/commission_grid_test.dart`

**Interfaces:**
- Produces:
  - `class CommissionTier { const CommissionTier({required double fromEur, required double rate}); factory CommissionTier.fromJson(Map<String, dynamic>); }`
  - `class CommissionGrid { const CommissionGrid({required String id, required DateTime effectiveFrom, required List<CommissionTier> tiers, required Map<String, double> minimums}); factory CommissionGrid.fromJson(Map<String, dynamic> json); double? minimumFor(String currencyCode); }` : `id` lu dans `gridId`, `effectiveFrom` toujours en UTC, `tiers` triées par `fromEur`, `minimums` indexés par code ISO majuscule.
  - `class CommissionReductions { const CommissionReductions({double? overrideRate, double? voucherFactor}); static const none; }`
  - `class CommissionResult { final double net; final double commission; final double gross; final bool minimumApplied; }`
  - `class BudgetBelowCommissionMinimumException implements Exception`
  - `CommissionResult computeCommission(double net, String currencyCode, CommissionGrid grid, {CommissionReductions reductions = CommissionReductions.none})` : `ArgumentError` si le net arrondi est ≤ 0.
  - `double netForGross(double gross, String currencyCode, CommissionGrid grid, {CommissionReductions reductions = CommissionReductions.none})` : plus grand net tel que `net + C(net) ≤ gross` ; `BudgetBelowCommissionMinimumException` si même une unité mineure de net coûte plus que `gross`.

- [ ] **Step 1: Recopier la fixture**

```bash
/usr/bin/git -C /Users/aboubakardiakite/Desktop/dony/dony-back show origin/main:src/test/resources/commission/vectors.json > test/fixtures/commission/vectors.json
```

- [ ] **Step 2: Écrire les tests qui échouent**

`commission_calculator_vectors_test.dart` lit `File('test/fixtures/commission/vectors.json')`, construit la grille depuis `grid` (même forme JSON que `/config/commission-grid` sans `gridId` ni `effectiveFrom` : fournir `id: 'vectors'`, `effectiveFrom: DateTime.utc(2026)`), puis pour chaque vecteur :
- vecteur dont `reductions` contient `promoPoints` ou `promoPricePercent` : ignoré (le code promo n'est jamais calculé dans l'app, seul le serveur le chiffre) et compté ;
- vecteur avec `net` : `computeCommission(net, currency, grid, reductions: …)` égal à `expected.commission`, `expected.gross`, `expected.minimumApplied` ;
- vecteur avec `gross` et `expected.net` : `netForGross` égal à `expected.net`, et `computeCommission(expected.net).commission` égal à `expected.commission` ;
- vecteur avec `expected.error == 'budget-below-commission-minimum'` : `throwsA(isA<BudgetBelowCommissionMinimumException>())`.
- Test final `exécute 23 vecteurs et en ignore 5 (promo)` : compteurs exacts (28 vecteurs dans la fixture du 19/10).
- Chaque vecteur est un `test()` nommé par son champ `case`.

`commission_grid_test.dart` :
```dart
test('fromJson lit une date sans fuseau comme UTC', () {
  final g = CommissionGrid.fromJson({
    'gridId': 'g1', 'effectiveFrom': '2026-11-20T09:00:00',
    'tiers': [{'fromEur': 100, 'rate': 0.06}, {'fromEur': 0, 'rate': 0.07}],
    'minimums': {'EUR': 1.00, 'XOF': 650},
  });
  expect(g.effectiveFrom, DateTime.utc(2026, 11, 20, 9));
  expect(g.tiers.first.fromEur, 0); // triées
  expect(g.minimumFor('XOF'), 650);
  expect(g.minimumFor('GBP'), isNull);
});
test('fromJson garde un suffixe Z ou un décalage explicite', …); // '2026-11-20T09:00:00Z' → même instant
test('computeCommission refuse un net nul', () => expect(() => computeCommission(0, 'EUR', grid), throwsArgumentError));
test('taux JSON 0.07 lu sans erreur flottante : 7,50 € → 1,00 € minimum, 15,00 € → 1,05 €', …);
```

- [ ] **Step 3: Lancer, constater l'échec**

Run: `flutter test test/core/pricing/commission_calculator_vectors_test.dart test/core/pricing/commission_grid_test.dart`
Expected: FAIL (fichier `commission_calculator.dart` absent).

- [ ] **Step 4: Implémenter `commission_calculator.dart`**

Ordre exact du back (`CommissionCalculator.commission`), promo exclue :
1. net arrondi HALF_UP à `minorUnit` ;
2. commission de grille `Σ rate_i × max(0, min(N, borne_sup_i) − borne_inf_i)`, bornes `fromEur × unitsPerEur` non arrondies, dernière tranche sans borne ;
3. taux spécial : `min(grille, N × overrideRate)` ;
4. si le résultat vaut 0 : commission 0, `minimumApplied` faux, ni minimum ni bon ;
5. sinon `max(résultat, minimum)` et `minimumApplied = résultat < minimum` ;
6. bon : `× voucherFactor` APRÈS le minimum ;
7. un seul arrondi HALF_UP à `minorUnit`.

Arithmétique : toutes les grandeurs en décimal exact `BigInt` (valeur entière + échelle commune, par exemple 10^18), chaque `double` d'entrée converti depuis sa représentation décimale la plus courte (`toString()`), jamais par multiplication flottante. Sortie convertie en `double` depuis l'entier d'unités mineures. `netForGross` : dichotomie sur les unités mineures entre 1 et `floor(gross)`, invariant du back (`lo` vérifie `lo + C(lo) ≤ gross`). Minimum absent pour la devise : `StateError` (la façade le traite, tâche 3).

- [ ] **Step 5: Lancer, constater le succès**

Run: `flutter test test/core/pricing/commission_calculator_vectors_test.dart test/core/pricing/commission_grid_test.dart`
Expected: PASS, 23 vecteurs exécutés, 5 ignorés.

- [ ] **Step 6: Commit**

```bash
git add lib/core/pricing/commission_calculator.dart test/fixtures/commission/vectors.json test/core/pricing/commission_calculator_vectors_test.dart test/core/pricing/commission_grid_test.dart
git commit -m "feat(commission): portage Dart du calcul par paliers, vecteurs du back"
```

---

### Task 2: Chargement des grilles et grille active

**Files:**
- Create: `lib/core/pricing/commission_grid_store.dart`
- Create: `test/helpers/commission_grid_test_doubles.dart`
- Modify: `lib/features/config/data/config_datasource.dart`, `lib/features/config/data/config_repository.dart`, `lib/main.dart:192` et `:245` (chargeur à côté de `_loadDonyCommissionRate`)
- Test: `test/core/pricing/commission_grid_store_test.dart`, `test/features/config/data/config_repository_test.dart`

**Interfaces:**
- Consumes: `CommissionGrid.fromJson` (tâche 1).
- Produces:
  - `class CommissionGridConfig { const CommissionGridConfig({CommissionGrid? current, CommissionGrid? next}); static const none; factory CommissionGridConfig.fromJson(Map<String, dynamic>); }`
  - `abstract final class CommissionGridStore { static void setConfig(CommissionGridConfig c); static CommissionGrid? activeAt(DateTime nowUtc); static CommissionGrid? byId(String? id); static void put(CommissionGrid g); static Future<CommissionGrid?> ensure(String? id, Future<CommissionGrid?> Function(String id) fetch); @visibleForTesting static void reset(); }`
  - `CommissionGrid? get activeCommissionGrid` (= `CommissionGridStore.activeAt(DateTime.now().toUtc())`).
  - `IConfigRepository.getCommissionGrid() → Future<CommissionGridConfig>` (404 → `CommissionGridConfig.none`) et `IConfigRepository.getCommissionGridById(String id) → Future<CommissionGrid?>` (404 → `null`) ; autres erreurs : `unwrapDioError` comme les autres méthodes.
  - `test/helpers/commission_grid_test_doubles.dart` : `const kTestGridId = 'grid-757'`, `CommissionGrid testGrid757()` (tranches et minimums de la fixture), `void useTestCommissionGrid([CommissionGrid? grid])` qui pose `CommissionGridStore.setConfig(CommissionGridConfig(current: grid ?? testGrid757()))` et `addTearDown(CommissionGridStore.reset)`.

- [ ] **Step 1: Écrire les tests qui échouent**

`commission_grid_store_test.dart` :
- `activeAt renvoie current avant la date de next` : current g1 (2026-10-01), next g2 (2026-11-20T09:00Z) ; `activeAt(DateTime.utc(2026,11,20,8,59))` → g1.
- `activeAt bascule sur next dès sa date franchie` : `activeAt(DateTime.utc(2026,11,20,9))` → g2.
- `activeAt sans current renvoie next une fois franchie, null avant` (cas de la première grille).
- `byId trouve current, next et les grilles ajoutées par put`.
- `ensure n'appelle pas fetch pour une grille déjà connue` ; `ensure met en cache le résultat de fetch` ; `ensure renvoie null et n'échoue pas si fetch lève` ; `ensure(null) renvoie null sans appel`.

`config_repository_test.dart` (même mode de simulation que les tests existants du fichier) :
- `getCommissionGrid lit current et next` ; `getCommissionGrid lit current null` ; `getCommissionGrid renvoie none sur 404` ; `getCommissionGrid relaie une erreur 500 en AppException` ;
- `getCommissionGridById lit la grille` ; `getCommissionGridById renvoie null sur 404`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/core/pricing/commission_grid_store_test.dart test/features/config/data/config_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Datasource : `getCommissionGrid()` sur `/config/commission-grid`, `getCommissionGridById(id)` sur `/config/commission-grid/$id`. `main.dart` : `unawaited(_loadCommissionGrid())` à côté de `_loadDonyCommissionRate()`, qui appelle `CommissionGridStore.setConfig(await repo.getCommissionGrid())` et avale toute erreur (repli : aucune grille, taux unique). DI : rien à ajouter (`IConfigRepository` existe déjà).

- [ ] **Step 4: Lancer, constater le succès**

Run: `flutter test test/core/pricing/commission_grid_store_test.dart test/features/config/data/config_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/pricing/commission_grid_store.dart lib/features/config/data lib/main.dart test/helpers/commission_grid_test_doubles.dart test/core/pricing/commission_grid_store_test.dart test/features/config/data/config_repository_test.dart
git commit -m "feat(commission): chargement de la grille en vigueur et des grilles figées"
```

---

### Task 3: Façade de prix, prix au kilo et paiement d'une offre

**Files:**
- Create: `lib/core/pricing/commission_pricing.dart`
- Modify: `lib/core/pricing/dony_pricing.dart:267-330` (extension `AnnouncementSenderPricing`), `lib/features/matching/data/models/bid_model.dart:201-203`, `lib/features/profile/presentation/screens/shipments_history_screen.dart:118-124`, `lib/features/payments/presentation/screens/payment_screen.dart:52-63,111-130`
- Test: `test/core/pricing/commission_pricing_test.dart`, `test/core/pricing/dony_pricing_test.dart`, `test/features/payments/presentation/screens/payment_screen_test.dart`, `test/features/profile/presentation/screens/shipments_history_screen_test.dart`

**Interfaces:**
- Consumes: `computeCommission`, `netForGross`, `CommissionReductions` (tâche 1) ; `activeCommissionGrid` (tâche 2).
- Produces (`commission_pricing.dart`) :
  - `class SenderPrice { final double net; final double commission; final double gross; final bool minimumApplied; final bool fromGrid; }`
  - `SenderPrice senderPriceForNet(double net, String? currencyCode, {CommissionGrid? grid, bool legacy = false, double? legacyRate, CommissionReductions reductions = CommissionReductions.none})` : `grid ?? activeCommissionGrid` ; aucune grille, `legacy: true` ou minimum absent pour la devise → chemin hérité exact d'aujourd'hui (commission = `net × (legacyRate ?? donyCommissionRate)` au centime, brut = net au centime + commission). Net ≤ 0 → tout à 0.
  - `double netForSenderGross(double gross, String? currencyCode, {CommissionGrid? grid, bool legacy = false})` : grille → `netForGross` (laisse remonter `BudgetBelowCommissionMinimumException`) ; hérité → `gross / (1 + donyCommissionRate)`.
  - `double listUnitPrice(double netUnit)` : prix unitaire des listes ; grille active → `netUnit` ; sinon `netUnit × (1 + donyCommissionRate)` (ancien `netToSenderPrice`).
  - `double? commissionMinimumFor(String? currencyCode)` : minimum de la grille active dans la devise, `null` sans grille.
  - `bool get commissionGridActive`.

- [ ] **Step 1: Écrire les tests qui échouent**

`commission_pricing_test.dart` (taux unique posé à 0,05 par `setDonyCommissionRate`, grille par `useTestCommissionGrid()`) :
```dart
test('sans grille : 35 € → 1,75 € de frais, 36,75 €, comme aujourd'hui', …); // fromGrid false
test('grille : 5 € → 1,00 € (minimum), 6,00 €', …); // minimumApplied true, fromGrid true
test('grille : 650 F CFA de minimum sur 5 000 XOF', …); // gross 5650
test('legacy: true force le taux unique malgré la grille', …);
test('minimum absent pour la devise : repli sur le taux unique', …);
test('listUnitPrice(8) vaut 8 sous grille et 8,40 sans', …);
test('commissionMinimumFor : 1 en EUR, 650 en XOF, null sans grille', …);
test('netForSenderGross(21.40) vaut 20,00 sous grille ; 1,00 € lève BudgetBelowCommissionMinimumException', …);
test('net nul : SenderPrice à zéro, sans exception', …);
```
`dony_pricing_test.dart` : `senderPricePerKg sous grille sans pricePerKgDisplay vaut le net` ; `convertedSenderPricePerKg sous grille vaut convertedPricePerKg` ; tests existants sans grille inchangés.
`payment_screen_test.dart` : `total = totalSenderAmountEur du serveur` (existant, à garder) ; `sans total serveur, sous grille, net 5 € : bouton « Payer 6,00 € »` ; retirer le `ConfigBloc` des montages si l'écran ne le lit plus.
`shipments_history_screen_test.dart` : `repli sous grille : 2 kg × 2,50 € → 6,00 €`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/core/pricing/commission_pricing_test.dart test/core/pricing/dony_pricing_test.dart test/features/payments/presentation/screens/payment_screen_test.dart test/features/profile/presentation/screens/shipments_history_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter et migrer les appelants de cette tâche**

- `AnnouncementSenderPricing.senderPricePerKg` : `pricePerKgDisplay ?? listUnitPrice(pricePerKg)` (sous grille le serveur sert déjà le net dans `pricePerKgDisplay`) ; `convertedSenderPricePerKg` inchangé dans sa formule (le ratio vaut 1 sous grille).
- `BidModel.senderPricePerKg` : repli `listUnitPrice`.
- `shipments_history_screen` : repli `senderPriceForNet(pricePerKg × weightKg, bid.currency).gross`.
- `payment_screen` : supprimer `_commission`, le paramètre `commissionRate` et le `BlocBuilder<ConfigBloc>` (la commission n'est pas affichée) ; `_total = bid.totalSenderAmountEur ?? senderPriceForNet(_amount, bid.currency).gross`. `payment_screen` était le seul lecteur de `ConfigBloc` : supprimer `lib/features/config/bloc/` (bloc, events, states), son `registerFactory` (`injection.dart:1018`), son `BlocProvider` (`router.dart:1046`) et `test/features/config/bloc/config_bloc_test.dart` ; retirer `ConfigBloc` des montages de `payment_screen_test.dart`, `payment_screen_flow_test.dart` et `test/a11y/large_text_smoke_test.dart`. `IConfigRepository.getCommissionRate` reste (lu par `main.dart`).
- Ne pas supprimer `netToSenderPrice` ni `donyCommissionMultiplier` ici : la tâche 11 les retire quand le dernier appelant a migré.

- [ ] **Step 4: Lancer, constater le succès**

Run: la commande du Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A lib/core lib/app/router.dart lib/features/config lib/features/matching/data/models/bid_model.dart lib/features/profile/presentation/screens/shipments_history_screen.dart lib/features/payments/presentation/screens/payment_screen.dart test/core/pricing test/features/config test/features/payments/presentation/screens test/features/profile/presentation/screens/shipments_history_screen_test.dart test/a11y/large_text_smoke_test.dart
git commit -m "feat(commission): façade de prix grille ou taux unique, prix au kilo au net sous grille"
```

---

### Task 4: « + frais de service Yadony (min. X) » sur les listes, la carte et les affiches

**Files:**
- Modify: `lib/core/pricing/pricing_labels.dart`, `lib/l10n/app_fr.arb`, `lib/l10n/app_en.arb`
- Modify (ajout du suffixe sous le prix affiché à l'expéditeur) : `lib/features/matching/presentation/widgets/traveler_card.dart`, `lib/features/corridor_alerts/presentation/widgets/trip_match_card.dart`, `lib/features/home/presentation/home_screen.dart` (≈ l. 1364), `lib/features/subscriptions/presentation/widgets/traveler_announcement_card.dart:55-70`, `lib/features/subscriptions/presentation/widgets/subscription_tile.dart:262`, `lib/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart`, `lib/features/matching/presentation/widgets/announcement_map_view.dart` (fiche du trajet sélectionné, pas les pastilles du plan), `lib/features/matching/presentation/widgets/poster/trip_poster_card.dart`, `lib/features/matching/presentation/screens/trip_poster_screen.dart:213-222`, `lib/features/matching/presentation/widgets/grid_item_selection_sheet.dart:54,187`
- Test: `test/core/pricing/pricing_labels_test.dart`, `test/features/matching/presentation/widgets/traveler_card_test.dart`, `test/features/matching/trip_poster_card_test.dart`, `test/features/subscriptions/traveler_announcement_card_test.dart`, `test/features/matching/presentation/widgets/grid_item_selection_sheet_test.dart`

**Interfaces:**
- Consumes: `commissionMinimumFor`, `listUnitPrice`, `senderPriceForNet` (tâche 3).
- Produces (`pricing_labels.dart`) :
  - `String? listPriceFeeSuffix(AppLocalizations l, String? currencyCode)` : `null` sans grille ; sinon `l.listPriceServiceFeeSuffix(formatPriceIn(min, currencyCode))`.
  - `String serviceFeeAmountLabel(AppLocalizations l, double amount, String? currencyCode, {required bool minimum})` : `formatPriceIn` (non compact, `PriceDisplay.money`) suivi de `l.serviceFeeMinimumTag` quand `minimum`.
- ARB (fr / en) :
  - `listPriceServiceFeeSuffix` : « + frais de service Yadony (min. {minimum}) » / « + Yadony service fee (min. {minimum}) »
  - `serviceFeeMinimumTag` : « (minimum) » / « (minimum) » (concaténé avec une espace insécable avant)

- [ ] **Step 1: Écrire les tests qui échouent**

- `pricing_labels_test.dart` : `suffixe sous grille en EUR : « + frais de service Yadony (min. 1 €) »` ; `suffixe en XOF contient « 650 » et « F CFA »` ; `aucun suffixe sans grille` ; `serviceFeeAmountLabel ajoute « (minimum) » seulement si minimum`.
- `traveler_card_test.dart` : `sous grille, prix au kilo net et suffixe affichés` (annonce `pricePerKgDisplay: 8` → « 8 € » et le suffixe) ; `sans grille, aucun suffixe`.
- `trip_poster_card_test.dart` : `l'affiche porte le suffixe sous grille` ; `affiche sans suffixe sans grille`.
- `traveler_announcement_card_test.dart` : `prix au kilo sous grille = net, pas net × (1 + taux)`.
- `grid_item_selection_sheet_test.dart` : `total sous grille : 1 article à 5 € → 6,00 €` (net + minimum, au lieu de la somme des `unitPriceDisplay`).

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/core/pricing/pricing_labels_test.dart test/features/matching/presentation/widgets/traveler_card_test.dart test/features/matching/trip_poster_card_test.dart test/features/subscriptions/traveler_announcement_card_test.dart test/features/matching/presentation/widgets/grid_item_selection_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Le suffixe est un `Text` secondaire (style `bodySmall`, `onSurfaceVariant`, une ligne, ellipse) sous le prix, rendu seulement si `listPriceFeeSuffix(...) != null`, devise = celle du prix affiché (annonce, ou devise convertie quand la carte affiche le prix converti). `traveler_announcement_card` : `netToSenderPrice(pricePerKg)` → `listUnitPrice(pricePerKg)`. `grid_item_selection_sheet` l. 54 : sous grille `senderPriceForNet(Σ unitPriceDisplay × qté, currency).gross` ; l. 187 (prix unitaire) inchangé. Pastilles de la carte : prix seul, faute de place.

- [ ] **Step 4: `flutter gen-l10n` puis relancer**

Run: `flutter gen-l10n && flutter test <fichiers du Step 2>`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/pricing/pricing_labels.dart lib/l10n lib/features test/core/pricing test/features
git commit -m "feat(commission): prix au kilo des listes suivi des frais de service minimum"
```

---

### Task 5: Aperçus de publication du voyageur

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart:290-295,537`, `lib/features/matching/presentation/widgets/open_surplus_bottom_sheet.dart:261-266`, `lib/features/price_grid/presentation/price_grid_item_form_sheet.dart:570-576`, `lib/features/price_grid/presentation/price_grid_screen.dart:491`, `lib/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart:272`, ARB fr/en
- Test: `test/features/matching/presentation/widgets/create_announcement/prix_conditions_step_test.dart`, `test/features/price_grid/presentation/price_grid_item_form_sheet_test.dart`, `test/features/price_grid/presentation/price_grid_screen_test.dart`, `test/features/matching/presentation/widgets/open_surplus_bottom_sheet_test.dart`

**Interfaces:**
- Consumes: `senderPriceForNet`, `listUnitPrice`, `commissionMinimumFor` (tâche 3) ; `listPriceFeeSuffix`, `serviceFeeAmountLabel` (tâche 4).
- ARB ajoutées (variantes sous grille ; les clés actuelles restent pour le chemin sans grille) :
  - `tripPublishGridCommissionNoticeGrid` : « Les frais de service Yadony s'ajoutent au total payé par l'expéditeur (min. {minimum}) » / « The Yadony service fee is added to the total paid by the sender (min. {minimum}) »
  - `tripPublishGridSheetCommissionNoteGrid` : « Prix touchés par le voyageur. Les frais de service Yadony s'ajoutent au total (min. {minimum}). » / « Prices received by the traveler. The Yadony service fee is added to the total (min. {minimum}). »
  - `priceGridCommissionNoticeGrid` : « Les frais de service Yadony s'ajoutent au total payé par l'expéditeur, avec un minimum de {minimum}. Vous encaissez exactement votre montant. » / « The Yadony service fee is added to the total paid by the sender, with a minimum of {minimum}. You receive exactly your amount. »

- [ ] **Step 1: Écrire les tests qui échouent**

- `prix_conditions_step_test.dart` : `sous grille, 10 kg à 2 € : l'expéditeur paiera 21,40 €` (net 20, frais 1,40) ; `sous grille, la notice cite le minimum` ; `sans grille, total et notice inchangés`.
- `price_grid_item_form_sheet_test.dart` : `sous grille, article à 5 € : l'expéditeur paiera 6,00 €, dont 1,00 € (minimum)`.
- `price_grid_screen_test.dart` : `sous grille, prix payé d'un article de 5 € = 6,00 €`.
- `open_surplus_bottom_sheet_test.dart` : `aperçu public sous grille : prix au kilo net et suffixe`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/matching/presentation/widgets/create_announcement/prix_conditions_step_test.dart test/features/price_grid/presentation/price_grid_item_form_sheet_test.dart test/features/price_grid/presentation/price_grid_screen_test.dart test/features/matching/presentation/widgets/open_surplus_bottom_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`prix_conditions_step` : `senderTotal = senderPriceForNet(travelerNet, currencyCode).gross`. `price_grid_item_form_sheet` : `final p = senderPriceForNet(price, activeCode)` ; message `priceGridSenderWillPayMessage(formatPriceActive(p.gross), serviceFeeAmountLabel(l, p.commission, activeCode, minimum: p.minimumApplied))`. `price_grid_screen` : `senderPriceForNet(item.unitPriceNet, activeCode).gross`. `open_surplus` : `senderPricePerKg: listUnitPrice(_pricePerKg)` plus le suffixe. Notices : clé `…Grid` quand `commissionMinimumFor(code) != null`.

- [ ] **Step 4: `flutter gen-l10n` puis relancer**

Run: `flutter gen-l10n && flutter test <fichiers du Step 2>`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets lib/features/price_grid lib/l10n test/features
git commit -m "feat(commission): aperçus de publication du voyageur selon la grille"
```

---

### Task 6: Contrats des devis (minimum, promo sans effet, fil scellé, devise)

**Files:**
- Modify: `lib/features/matching/data/models/bid_quote_response.dart` (+ `.g.dart` régénéré), `lib/features/package_request/data/models/negotiation_quote.dart`, `lib/features/package_request/data/package_request_repository.dart:243-253`, `lib/features/package_request/data/negotiation_repository.dart:206-215`, `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart:64-74`, `lib/core/error/error_catalog.dart`, ARB fr/en
- Test: `test/features/matching/data/bid_quote_response_test.dart`, `test/features/package_request/data/models/negotiation_quote_test.dart`, `test/features/package_request/data/package_request_repository_test.dart`, `test/features/package_request/data/negotiation_repository_test.dart`, `test/core/error/error_catalog_test.dart`

**Interfaces:**
- Produces :
  - `BidQuoteResponse` et `NegotiationQuote` gagnent `bool minimumApplied` (défaut `false`), `double? minimumAmount`, `String? commissionGridId`, `String? promoIneffectiveReason`, et `bool get promoIneffectiveBecauseMinimum => promoIneffectiveReason == 'COMMISSION_MINIMUM'`.
  - `PackageRequestRepository.quote(double budgetEur, {String? promoCode, String? currency})` : `currency` envoyé en paramètre de requête quand non nul.
  - `NegotiationRepository.quote(String id, {String? promoCode}) → Future<NegotiationQuote?>` : `null` sur 409 de code `negotiation/thread-sealed` (le total scellé est déjà dans `grossPriceEur`) ; tout autre échec relancé.
  - Entrée de catalogue `budget-below-commission-minimum` (avertissement) ; ARB `errorBudgetBelowCommissionMinimumTitle` « Budget trop faible » / « Budget too low », `errorBudgetBelowCommissionMinimumMessage` « Ce montant ne couvre pas les frais de service minimum de Yadony. » / « This amount does not cover the minimum Yadony service fee. » ; `promoIneffectiveCommissionMinimum` « Ce code ne change rien sur ce montant (frais minimum) » / « This code does not change this amount (minimum fee) ».

- [ ] **Step 1: Écrire les tests qui échouent**

- `bid_quote_response_test.dart` : `lit minimumApplied, minimumAmount, commissionGridId, promoIneffectiveReason` ; `ancien contrat sans ces champs : minimumApplied faux, le reste null`.
- `negotiation_quote_test.dart` : mêmes deux cas ; `promoIneffectiveBecauseMinimum vrai pour COMMISSION_MINIMUM`.
- `package_request_repository_test.dart` : `quote envoie currency=XOF` ; `quote sans currency n'envoie pas la clé`.
- `negotiation_repository_test.dart` : `quote renvoie null sur 409 negotiation/thread-sealed` ; `quote relance un autre 409`.
- `error_catalog_test.dart` : `budget-below-commission-minimum a un titre et un message`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/matching/data/bid_quote_response_test.dart test/features/package_request/data/models/negotiation_quote_test.dart test/features/package_request/data/package_request_repository_test.dart test/features/package_request/data/negotiation_repository_test.dart test/core/error/error_catalog_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Détection du fil scellé : `ConflictException` dont `code == 'negotiation/thread-sealed'` (le back pose `code` sur un `ResponseStatusException` à motif `a/b`). `accept_offer_bottom_sheet` : `quoteNotifier.value = await …quote(threadId)` accepte `null`, le bouton retombe alors sur `grossPriceEur` (déjà le cas). Puis `dart run build_runner build --delete-conflicting-outputs` et `flutter gen-l10n`.

- [ ] **Step 4: Lancer, constater le succès**

Run: la commande du Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/models lib/features/package_request lib/core/error lib/l10n test
git commit -m "feat(commission): devis avec minimum, promo sans effet, fil scellé et devise"
```

---

### Task 7: Formulaire d'offre sur un trajet (create_bid_bottom_sheet)

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart` (`_localSenderTotal` l. 802, `_computeStripeTotal` l. 915, `_gridDisplayTotal` l. 967, bloc « Prix live » l. 1708-1770, `_PriceBreakdown`, affichage du code promo l. 1590), ARB fr/en
- Test: `test/features/matching/presentation/create_bid_grid_test.dart` (créé), `test/features/matching/presentation/create_bid_promo_code_test.dart`

**Interfaces:**
- Consumes: `senderPriceForNet`, `commissionGridActive` (tâche 3) ; `serviceFeeAmountLabel` (tâche 4) ; champs `minimumApplied`, `promoIneffectiveBecauseMinimum` de `BidQuoteResponse` (tâche 6).
- Produces: `double _netTotal()` (poids × `senderPricePerKg` + Σ `unitPriceDisplay` × qté, valable sous grille seulement, où ces prix sont des nets) ; `_PriceBreakdown` gagne `double? serviceFee` et `bool serviceFeeMinimum` (ligne rendue seulement si `serviceFee != null`).

- [ ] **Step 1: Écrire les tests qui échouent**

`create_bid_grid_test.dart` (grille de test, annonce EUR `pricePerKgDisplay: 2.5`) :
- `sous grille, 2 kg : lignes 5,00 €, frais 1,00 € (minimum), total 6,00 €` ;
- `sous grille, 8 kg à 2,50 € : frais 1,40 €, total 21,40 €` ;
- `le devis serveur prime : totalEur 21,00 et minimumApplied affichent 21,00 € et « (minimum) »` ;
- `promo sans effet : message « Ce code ne change rien sur ce montant (frais minimum) », pas de prix barré` ;
- `mode négociation : la suggestion vaut net + frais de la grille` ;
- `sans grille : répartition au prorata inchangée, aucune ligne de frais`.
`create_bid_promo_code_test.dart` : tests existants verts sans grille.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/matching/presentation/create_bid_grid_test.dart test/features/matching/presentation/create_bid_promo_code_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Sous grille seulement (`commissionGridActive`) :
- `_localSenderTotal()` et le repli de `_computeStripeTotal()` : `senderPriceForNet(_netTotal(), currency).gross` ;
- « Prix live » : lignes au net (poids × prix au kilo, articles), ligne « Frais de service Yadony » = `quote != null ? quote.totalEur - quote.netEur : local.commission`, tag minimum `quote?.minimumApplied ?? local.minimumApplied`, total `quote?.totalEur ?? local.gross`, prix barré `quote.netEur + quote.commissionEur` si `promoApplied` ;
- code promo : si `promoIneffectiveBecauseMinimum`, message d'information sous le champ (pas de style d'erreur), code conservé dans l'envoi.
Sans grille : code actuel inchangé (`netToSenderPrice`, `donyCommissionMultiplier`, prorata).

- [ ] **Step 4: `flutter gen-l10n` si une clé a été ajoutée, puis relancer**

Run: la commande du Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart lib/l10n test/features/matching/presentation
git commit -m "feat(commission): offre sur un trajet, frais de service et minimum avant validation"
```

---

### Task 8: Demande de colis (budget, devis, édition)

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart:120-170` (`_applyPromoCode`, `_sync`) et `:745-830` (`_BudgetBreakdown`), `lib/features/package_request/data/package_request_limits.dart:57-60`, `lib/features/package_request/bloc/package_request_form_bloc.dart:80-84`, ARB fr/en
- Test: `test/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget_test.dart`, `test/features/package_request/data/package_request_limits_test.dart`, `test/features/package_request/bloc/package_request_form_bloc_test.dart`

**Interfaces:**
- Consumes: `netForSenderGross`, `senderPriceForNet`, `commissionMinimumFor`, `BudgetBelowCommissionMinimumException` (tâches 1 et 3) ; `quote(…, currency:)` et champs du devis (tâche 6).
- Produces: `PackageRequestLimits.isBudgetValid(double? amount, SupportedCurrency currency)` exige en plus, sous grille, que `netForSenderGross(amount, currency.code)` ne lève pas. ARB : `requestBudgetBelowCommissionMinimum` « Le budget doit dépasser les frais de service minimum ({minimum}). » / « The budget must be above the minimum service fee ({minimum}). », `requestCreatePromoDiscountLabel` « Réduction du code promo » / « Promo code discount », `requestCreateYouPayLabel` « Vous paierez » / « You will pay ».

- [ ] **Step 1: Écrire les tests qui échouent**

`step_3_recap_budget_test.dart` (grille de test, EUR) :
- `budget 21,40 € sans devis : frais 1,40 €, le voyageur reçoit 20,00 €` ;
- `devis avec promo (net 20, commission 1,00, total 21,00) : réduction −0,40 €, « Vous paierez 21,00 € », aucune ligne « le voyageur touche » de boost` ;
- `devis minimumApplied : frais suivis de « (minimum) »` ;
- `promo sans effet : message « Ce code ne change rien sur ce montant (frais minimum) »` ;
- `le devis part avec la devise de la demande (XOF)` ;
- `budget 1,00 € : bouton Continuer bloqué et message du minimum` ;
- `sans grille : décomposition et boost inchangés`.
`package_request_limits_test.dart` : `isBudgetValid(1.0, eur) faux sous grille, vrai sans grille` ; `isBudgetValid(1.01, eur) vrai sous grille` (net 0,01 €, frais 1,00 €).
`package_request_form_bloc_test.dart` : `l'édition préremplit grossPriceEur du serveur` ; `sans grossPriceEur, sous grille, net 20 → 21,40`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget_test.dart test/features/package_request/data/package_request_limits_test.dart test/features/package_request/bloc/package_request_form_bloc_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

`_BudgetBreakdown` sous grille (grille active ou `quote?.commissionGridId != null`) : `net = quote?.netEur ?? netForSenderGross(budget, code)`, `base = senderPriceForNet(net, code)` (sans promo), `commission = quote?.commissionEur ?? base.commission` (promo comprise, contrat §5.4 du devis de budget), `total = quote?.totalEur ?? base.gross`, réduction = `base.gross - total` affichée si > une demi-unité mineure. Lignes : budget public, frais (avec tag minimum), réduction, le voyageur reçoit, « Vous paierez » quand il y a réduction. `_applyPromoCode` passe `currency: _resolveCurrency(s).code`. Message du minimum à l'emplacement du message de budget hors bornes existant. Form bloc : `r.grossPriceEur ?? senderPriceForNet(r.targetPriceEur!, r.currency).gross`. Sans grille : chemin actuel.

- [ ] **Step 4: `flutter gen-l10n` puis relancer**

Run: `flutter gen-l10n && flutter test <fichiers du Step 2>`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request lib/l10n test/features/package_request
git commit -m "feat(commission): budget de demande sous grille, promo qui baisse le prix payé"
```

---

### Task 9: Fils de demande (replis `grossPriceEur ?? …`, contre-offre, bulles, commission espèces)

**Files:**
- Create: `lib/features/package_request/data/models/thread_pricing.dart`
- Modify: `lib/features/package_request/data/models/negotiation_thread.dart` (champ facultatif), `lib/features/package_request/data/models/price_display.dart` (retrait de `previewRate`, `grossFromNet`, `netFromGross`, `feeFromNet` ; `money` reste), `lib/features/package_request/presentation/package_request_labels.dart:55-65`, `widgets/thread/thread_message_bubble.dart`, `widgets/thread/thread_state_cta_bar.dart:198,528,702`, `widgets/counter_offer_bottom_sheet.dart:286-310`, `widgets/request_detail/request_offer_card.dart:74`, `widgets/request_detail/request_detail_view.dart:315`, `widgets/payment_recap_bottom_sheet.dart:52`, `widgets/accept_offer_bottom_sheet.dart:105,280`, `screens/sender/complete_details_screen.dart:329`, `screens/sender/package_request_detail_screen.dart:321`, `screens/shared/my_negotiations_screen.dart:840` (tous sous `lib/features/package_request/`)
- Test: `test/features/package_request/data/models/thread_pricing_test.dart` (créé), `test/features/package_request/data/models/price_display_test.dart`, `test/features/package_request/presentation/package_request_labels_test.dart`, `test/features/package_request/presentation/widgets/counter_offer_bottom_sheet_test.dart`, `test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart`, `test/features/package_request/presentation/widgets/thread/thread_state_cta_bar_test.dart`, `test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`, plus les tests listés par `grep -rl "grossFromNet\|feeFromNet\|netFromGross" test` à mettre à jour

**Interfaces:**
- Consumes: `senderPriceForNet` (tâche 3), `CommissionGridStore.byId`, `activeCommissionGrid` (tâche 2), `serviceFeeAmountLabel` (tâche 4).
- Produces:
  - `NegotiationThread` gagne `final String? commissionGridId` et `final bool commissionGridIdServed` (= `json.containsKey('commissionGridId')`). Le back #591 ne sert pas encore ce champ (voir question ouverte) : l'app est prête pour les deux contrats.
  - `class ThreadPricer { factory ThreadPricer.of(NegotiationThread t); SenderPrice priceFor(double net); }` : champ servi et non nul → `CommissionGridStore.byId(id) ?? activeCommissionGrid` ; servi et nul → `legacy: true` (fil d'avant les grilles) ; non servi → grille active, sinon taux unique.
  - `threadPriceLabel(AppLocalizations l, double net, double? gross, bool isTraveler, [String? currencyCode, ThreadPricer? pricer])` : repli `pricer?.priceFor(net).gross ?? senderPriceForNet(net, currencyCode).gross`.
  - `ThreadMessageBubble` et `CounterOfferCommissionPreview` reçoivent `ThreadPricer pricer` (construit par l'écran qui a le fil).

- [ ] **Step 1: Écrire les tests qui échouent**

- `thread_pricing_test.dart` : `champ non servi : grille active (20 € → 21,40 €)` ; `champ servi nul : taux unique (20 € → 21,00 € à 5 %)` ; `id connu du store : grille figée utilisée même si une autre est active` ; `id inconnu : repli sur la grille active`.
- `counter_offer_bottom_sheet_test.dart` : `sous grille, net 5 € : frais 1,00 € (minimum), total 6,00 €`.
- `thread_message_bubble_test.dart` : `expéditeur sous grille, proposition 20 € : « Tu paies 21,40 € »` ; `voyageur : « Tu reçois 20,00 € »` (inchangé).
- `thread_state_cta_bar_test.dart` : `commission espèces du voyageur sous grille, net 5 € : 1,00 € (minimum)`.
- `accept_offer_bottom_sheet_test.dart` : `fil scellé (devis null) : le bouton affiche grossPriceEur du serveur, aucun recalcul`.
- `package_request_labels_test.dart` et `price_display_test.dart` : retirer les cas des fonctions supprimées, garder `money`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/package_request`
Expected: FAIL sur les nouveaux cas.

- [ ] **Step 3: Implémenter**

Supprimer les trois fonctions de calcul de `PriceDisplay` d'abord : les erreurs de compilation listent tous les appelants, chacun passe par `ThreadPricer.of(thread).priceFor(net)` (ou `senderPriceForNet(net, currency)` hors fil) en gardant la priorité au montant serveur (`grossPriceEur`). `thread_state_cta_bar` l. 702 : `priceFor(thread.currentPriceEur).commission`, libellé via `serviceFeeAmountLabel`.

- [ ] **Step 4: Lancer, constater le succès**

Run: `flutter test test/features/package_request`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request test/features/package_request
git commit -m "feat(commission): fils de demande tarifés par la grille, montants serveur prioritaires"
```

---

### Task 10: Fil de négociation sur un trajet (grille et réductions figées)

**Files:**
- Modify: `lib/features/matching/data/models/bid_negotiation.dart:184-268`, `lib/features/matching/data/models/bid_negotiation_pricing.dart`, `lib/features/matching/bloc/bid_negotiation_bloc.dart` (constructeur et handlers qui émettent un fil), `lib/core/di/injection.dart` (enregistrement de `BidNegotiationBloc`), `lib/features/matching/presentation/screens/bid_negotiation_thread_screen.dart:1370-1380,1445-1451`
- Test: `test/features/matching/data/models/bid_negotiation_pricing_test.dart`, `test/features/matching/data/models/bid_negotiation_test.dart`, `test/features/matching/bloc/bid_negotiation_bloc_test.dart`, `test/features/matching/presentation/screens/bid_negotiation_thread_screen_test.dart`

**Interfaces:**
- Consumes: `senderPriceForNet`, `CommissionReductions` (tâches 1 et 3) ; `CommissionGridStore.ensure`, `byId`, `IConfigRepository.getCommissionGridById` (tâche 2).
- Produces:
  - `BidNegotiation` gagne `String? commissionGridId`, `double? commissionOverrideRate`, `double? commissionVoucherFactor` ; `counterInNet => isTravelerView && (commissionGridId != null || commissionRate != null)`.
  - `double grossForNegotiationNet(BidNegotiation n, double net)` dans `bid_negotiation_pricing.dart` : `commissionGridId != null` → `senderPriceForNet(net, n.currency, grid: CommissionGridStore.byId(id) ?? activeCommissionGrid, reductions: CommissionReductions(overrideRate: n.commissionOverrideRate, voucherFactor: n.commissionVoucherFactor)).gross` ; sinon `grossForNet(net, n.commissionRate ?? donyCommissionRate, n.currency)` (inchangé).
  - `BidNegotiationBloc(…, IConfigRepository config)` : avant chaque émission d'un fil chargé, `await CommissionGridStore.ensure(thread.commissionGridId, config.getCommissionGridById)`.
  - `_CounterProposalForm` remplace `double? netRate` par `double Function(double net)? grossOfNet` (null = saisie du brut).

- [ ] **Step 1: Écrire les tests qui échouent**

- `bid_negotiation_pricing_test.dart` : `fil à grille, taux spécial 4 % et bon ×0,5, net 50 € → 51,00 €` (vecteur de la fixture) ; `fil à grille sans réduction, net 20 € → 21,40 €` ; `grille figée connue par id prioritaire sur la grille active` ; `fil hérité au taux 0,12, net 35 € → 39,20 €` (existant).
- `bid_negotiation_test.dart` : `lit commissionGridId, commissionOverrideRate, commissionVoucherFactor` ; `counterInNet vrai pour un voyageur sur un fil à grille sans commissionRate`.
- `bid_negotiation_bloc_test.dart` : `fetch charge la grille figée avant d'émettre le fil` (`getCommissionGridById('g-thread')` appelé une fois, émission après) ; `échec du chargement de la grille : le fil est émis quand même`.
- `bid_negotiation_thread_screen_test.dart` : `contre-offre du voyageur sous grille, net 50 € avec réductions figées : aperçu 51,00 €`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/matching/data/models/bid_negotiation_pricing_test.dart test/features/matching/data/models/bid_negotiation_test.dart test/features/matching/bloc/bid_negotiation_bloc_test.dart test/features/matching/presentation/screens/bid_negotiation_thread_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter**

Un seul helper privé dans le bloc (`Future<BidNegotiation> _withGrid(BidNegotiation t)`) appelé par chaque handler avant `_emitLoaded`. L'écran passe `grossOfNet: negotiation.counterInNet ? (net) => grossForNegotiationNet(negotiation, net) : null`.

- [ ] **Step 4: Lancer, constater le succès**

Run: la commande du Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching lib/core/di/injection.dart test/features/matching
git commit -m "feat(commission): négociation de trajet sur la grille et les réductions figées du fil"
```

---

### Task 11: Textes, nettoyage final et vérification

**Files:**
- Modify: `lib/features/payments/cash/presentation/screens/commission_method_screen.dart:114-123`, `lib/features/profile/presentation/screens/faq_screen.dart:95`, `lib/core/pricing/dony_pricing.dart` (retrait de `netToSenderPrice`, `donyCommissionMultiplier` et mise à jour du commentaire d'en-tête), ARB fr/en
- Test: `test/features/payments/cash/presentation/screens/commission_method_screen_test.dart`, `test/features/profile/presentation/screens/faq_screen_test.dart`, `test/core/pricing/dony_pricing_test.dart`

**Interfaces:**
- Consumes: `commissionMinimumFor` (tâche 3).
- ARB :
  - `requestCreateCommissionLabel` (fr) : « Commission Yadony » devient « Frais de service Yadony » (l'anglais dit déjà « Yadony service fee »).
  - `faqPaymentsCommissionAGrid` : « Les frais de service couvrent les frais de paiement, le support, la prévention de la fraude et le développement de la plateforme. Ils dépendent du prix du transport, avec un minimum de {minimum}. Le montant exact est affiché avant de confirmer. » / « The service fee covers payment costs, support, fraud prevention and the development of the platform. It depends on the transport price, with a minimum of {minimum}. The exact amount is shown before you confirm. »

- [ ] **Step 1: Écrire les tests qui échouent**

- `commission_method_screen_test.dart` : `sous grille, devise active XOF : « min. 650 F CFA »` ; `sous grille, EUR : « min. 1 € » lu de la grille` (grille de test au minimum EUR 1,20 → « min. 1,20 € ») ; `sans grille : textes actuels`.
- `faq_screen_test.dart` : `sous grille, la réponse cite le minimum dans la devise active` ; `sans grille, réponse actuelle`.
- `dony_pricing_test.dart` : retirer les cas de `netToSenderPrice` et `donyCommissionMultiplier`.

- [ ] **Step 2: Lancer, constater l'échec**

Run: `flutter test test/features/payments/cash/presentation/screens/commission_method_screen_test.dart test/features/profile/presentation/screens/faq_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter et supprimer l'ancien calcul**

`commission_method_screen` : `final min = commissionMinimumFor(activeCode)` ; non nul → `commissionCardDebitNoticeMin(formatPriceIn(min, activeCode))` ; nul → condition actuelle (1 € en EUR, sinon notice sans minimum). Supprimer `netToSenderPrice` et `donyCommissionMultiplier`, puis vérifier :

```bash
/usr/bin/grep -rnE "netToSenderPrice|donyCommissionMultiplier|grossFromNet|netFromGross|feeFromNet|previewRate" lib test
```
Expected: aucune ligne. Puis `/usr/bin/grep -rnE "[0-9] ?%" lib/l10n/app_fr.arb lib/l10n/app_en.arb | /usr/bin/grep -iE "commission|frais|fee"` : aucune ligne.

- [ ] **Step 4: Vérification complète**

Run: `flutter gen-l10n && flutter analyze && dart run tool/check_hardcoded_strings.dart && flutter test --coverage`
Expected: 0 problème d'analyse, garde-fou à 0, 0 échec. Couverture : `lcov --summary coverage/lcov.info` ≥ 90 % de lignes ; les fichiers créés (`commission_calculator.dart`, `commission_grid_store.dart`, `commission_pricing.dart`, `thread_pricing.dart`) à 100 %.

- [ ] **Step 5: Fiche de story**

Créer `docs/stories-done/story-commission-paliers-app.md` au format du CLAUDE.md de l'app (résumé, fichiers, « Comment ça fonctionne » : chargement et bascule de la grille, façade, chemin hérité, fils de demande et de trajet ; pièges : état global à remettre à zéro en test, `effectiveFrom` en UTC, montants serveur prioritaires).

- [ ] **Step 6: Commit**

```bash
git add lib test docs/stories-done/story-commission-paliers-app.md
git commit -m "feat(commission): textes sans taux, minimum lu dans la grille, ancien calcul retiré"
```

- [ ] **Step 7: Description de la PR**

À inclure, sans build :
- PR jumelle back **#591** (fusionnée, staging) : fusionner celle-ci après elle ; l'app tolère un back sans #591.
- Mise à jour forcée (spec §7.2) : avant la date d'effet de la première grille, monter `min_supported_build` (Remote Config, clé unique iOS et Android, lue par `AppUpdateService`) au **numéro du premier build qui contient cette PR**. Derniers numéros connus le 19/10 : IPA prod 138, AAB staging 134. Le premier build visé est donc **139 au plus tôt**, et l'AAB qui contient la PR doit porter un numéro au moins égal à la valeur montée, sinon tous les Android seraient bloqués sur une version introuvable.
- Point juridique à faire relire (spec §7.3) : prix d'appel des listes hors frais, total frais compris affiché avant validation.
- Recette staging (spec §9.3) : grille de test programmée à J+5 minutes, app ouverte pendant la bascule (Review Focus 2), vecteurs §4.6 vérifiés à l'écran sur la carte, les espèces et le mobile money.

## Décisions du propriétaire (19/10, après le plan) — font foi
- Libellé : « Commission Yadony » devient partout « Frais de service Yadony » (FR), cohérent avec l'anglais et les CGU.
- Carte des trajets (pastilles ET fiche affichée depuis la carte) : uniquement « + frais de service », SANS le minimum. Les autres listes et fiches gardent « + frais de service Yadony (min. X) ».
- Le back ajoute `commissionGridId` dans `NegotiationThreadResponse` et `PackageRequestResponse` (PR back jumelle à venir) : les aperçus d'un fil/d'une demande utilisent la grille figée (via `GET /config/commission-grid/{id}`) quand le champ est présent, sinon la grille en vigueur (tolérer l'absence du champ).
- `min_supported_build` : rien à faire dans le code ; noter dans la PR que le propriétaire devra poser une condition Remote Config par plateforme (IPA et AAB n'ont pas le même numéro).
