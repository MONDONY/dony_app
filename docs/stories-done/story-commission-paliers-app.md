# Story — Commission par paliers : adaptation de l'app (Flutter)
**Date:** 2026-10-20 | **Status:** ✅ Complète (code) | **Branche:** `feature/commission-paliers`

Contrats back jumeaux : MONDONY/yadony-back#591 (grilles de commission, fusionnée, staging),
#594 (`commissionGridId` dans les fils et les demandes, fusionnée, staging), #616
(`travelerCashCommissionEur`, à fusionner AVANT cette PR app).

## Résumé

Le back remplace le taux unique de commission par une **grille par paliers** : taux
marginal par tranche de prix (en euros, convertie dans la devise), **minimum par
devise** (1 € en EUR, 650 F CFA en XOF dans la grille de test), grille datée
(`effectiveFrom`) et **figée** sur chaque offre, demande et fil de négociation.

L'app suit :

1. Elle charge la grille en vigueur et la suivante au démarrage, bascule seule à la
   date d'effet, et lit à la demande les grilles figées des fils et des demandes.
2. Tous les prix payés par l'expéditeur passent par une **façade unique**
   (`commission_pricing.dart`) : grille quand elle existe, sinon taux unique
   historique (comportement d'avant, inchangé tant que le back n'a pas de grille).
3. Sous grille, les listes montrent le **prix du voyageur (net)** suivi de
   « + frais de service Yadony (min. X) » (carte des trajets : « + frais de service »
   sans minimum) ; le total frais compris, avec la mention « (minimum) » quand le
   plancher s'applique, est affiché avant toute validation.
4. Les textes ne citent plus aucun taux : libellé « Frais de service Yadony », FAQ et
   carte de commission citent le minimum de la grille dans la devise active.
5. L'ancien calcul sans façade (`netToSenderPrice`, `donyCommissionMultiplier`) est
   supprimé.

## Fichiers créés / modifiés

**Créés**
- `lib/core/pricing/commission_calculator.dart` : portage exact du calculateur du back
  (`CommissionGrid`, `CommissionTier`, `CommissionReductions`, `computeCommission`,
  `netForGross`, `exactProductHalfUp`), décimal exact privé, vecteurs du back.
- `lib/core/pricing/commission_grid_store.dart` : `CommissionGridConfig`,
  `CommissionGridStore` (grille courante, suivante, cache par id), `activeCommissionGrid`.
- `lib/core/pricing/commission_pricing.dart` : façade `SenderPrice`, `senderPriceForNet`,
  `netForSenderGross`, `listUnitPrice`, `commissionMinimumFor`, `commissionGridActive`,
  `halfMinorUnit`.
- `lib/core/pricing/commission_rate.dart` : taux unique historique
  (`donyCommissionRate`, `setDonyCommissionRate`), réexporté par `dony_pricing.dart`.
- `lib/features/config/data/commission_grid_preload.dart` : `CommissionGridLoader`,
  `kCommissionGridPreloadTimeout` (3 s), `preloadCommissionGrids`.
- `lib/features/package_request/data/models/thread_pricing.dart` : `ThreadPricer`
  (prix d'un fil de demande sur sa grille figée, montants serveur prioritaires).
- Tests : `test/core/pricing/commission_*_test.dart`, `test/fixtures/commission/vectors.json`
  (copie de la fixture du back), `test/helpers/commission_grid_test_doubles.dart`,
  `test/features/config/data/commission_grid_preload_test.dart`,
  `test/features/package_request/data/models/thread_pricing_test.dart`,
  `test/features/matching/data/models/bid_negotiation_pricing_test.dart`,
  `test/features/matching/data/models/bid_negotiation_test.dart`.

**Modifiés (principaux)**
- Démarrage et données : `main.dart`, `config_datasource.dart`, `config_repository.dart`,
  `core/di/injection.dart`, modèles `bid_quote_response`, `negotiation_quote`,
  `negotiation_thread`, `package_request`, `bid_negotiation`, `bid_model`.
- Listes et carte : `traveler_card`, `trip_match_card`, `traveler_announcement_card`,
  `subscription_tile`, `traveler_announcement_bottom_sheet`, `announcement_map_view`,
  `marker_bitmap_factory`, affiches (`poster_parts`, `trip_poster_card`,
  `trip_poster_screen`), `pricing_labels.dart`.
- Voyageur : `prix_conditions_step`, `grid_preview_card`, `price_grid_screen`,
  `price_grid_item_form_sheet`, `open_surplus_bottom_sheet`.
- Offre sur un trajet : `create_bid_bottom_sheet`, `grid_item_selection_sheet`, `bid_bloc`.
- Demande et fils de demande : `step_3_recap_budget`, `package_request_form_bloc`,
  `package_request_limits`, écrans et feuilles du fil (`accept_offer_bottom_sheet`,
  `counter_offer_bottom_sheet`, `thread_*`, `request_offer_card`, …).
- Fil de négociation sur un trajet : `bid_negotiation_bloc`, `bid_negotiation_pricing`,
  `bid_negotiation_thread_screen`, `bid_negotiation_parcel_sheet`, `dony_nego_hero_card`.
- Textes : `commission_method_screen`, `faq_screen`, `error_catalog`, ARB fr/en.

## Comment ça fonctionne

### Chargement et bascule de la grille
- `main.dart` → `_loadCommissionGrid()` : `GET /config/commission-grid` →
  `{current, next}` → `CommissionGridStore.setConfig`. 404, `current` nul ou JSON
  malformé : `CommissionGridConfig.none`, l'app garde le taux unique
  (`GET /config/commission-rate`, inchangé).
- `activeCommissionGrid` relit `CommissionGridStore.activeAt(DateTime.now().toUtc())` à
  chaque appel : dès que `next.effectiveFrom` est franchi, la suivante sert, sans
  relancer l'app. Le store n'est pas `Listenable` : un écran déjà affiché se met à
  jour à sa prochaine reconstruction.
- Grilles figées : `GET /config/commission-grid/{id}` via
  `IConfigRepository.getCommissionGridById`, mises en cache par
  `CommissionGridStore.ensure` (jamais d'exception, lectures simultanées mutualisées).
  `preloadCommissionGrids` les charge avant d'émettre un fil ou une liste de fils, et
  rend la main au plus tard après 3 s (la lecture continue en cache).

### Façade (`commission_pricing.dart`)
- `senderPriceForNet(net, devise, {grid, legacy, legacyRate, reductions})` : grille
  `grid ?? activeCommissionGrid` si elle a un minimum pour la devise, sinon taux unique
  (`legacyRate ?? donyCommissionRate`), calculé par le même décimal exact. Ne lève
  jamais : net nul ou devise inconnue donnent `SenderPrice.zero` ou un repli EUR.
- `netForSenderGross` : budget TTC d'une demande vers le net du voyageur (lève
  `BudgetBelowCommissionMinimumException` sous le minimum).
- `listUnitPrice(netUnit, devise)` et `listPriceFeeSuffix(l, devise)` suivent la même
  règle : grille utilisable seulement avec un minimum pour la devise.
- `commissionMinimumFor(devise)` alimente les mentions « (min. X) », la carte de
  commission et la FAQ.

### Chemin hérité (taux unique)
- Sans grille publiée, tout est identique à avant : prix au kilo majorés du taux, mêmes
  totaux, mêmes textes (sauf le libellé « Frais de service Yadony » et la notice de la
  carte de commission, alignés sur l'anglais).
- Une offre, une demande ou un fil SANS `commissionGridId` (antérieur aux paliers) reste
  au taux unique, même quand une grille est en vigueur (Ruling A8) : le back la
  recalcule ainsi.

### Fils de demande (`ThreadPricer`)
- Grille figée du fil (`commissionGridId`), sinon grille en vigueur faute de mieux.
- Montants serveur prioritaires : `grossPriceEur`, devis (`/negotiations/{id}/quote`),
  `travelerCashCommissionEur` (commission espèces du voyageur, back #616) ; le calcul
  local n'est qu'un repli. La mention « (minimum) » n'est reprise que si le calcul local
  retombe sur les frais servis.

### Fils de négociation sur un trajet
- `BidNegotiationBloc` attend la grille figée du bid avant d'émettre, **seulement pour
  le voyageur et un fil encore en négociation** : lui seul calcule un aperçu (sa
  contre-offre se saisit en net, `grossForNegotiationNet` applique grille figée,
  taux spécial et bon de parrainage figés). L'expéditeur saisit un brut et lit les frais
  servis.
- Vue expéditeur d'un fil à grille : les lignes d'articles de grille sont au prix du
  voyageur, d'où « + frais de service » sur chaque ligne (récapitulatif et fiche du
  colis) et « Frais de service compris » sous « Vous paieriez ».

### Appels API
- `GET /config/commission-grid` (404 toléré), `GET /config/commission-grid/{id}`
  (404 → `null`).
- Devis : `POST /bids/quote`, `GET /package-requests/quote` (avec `currency`),
  `/negotiations/{id}/quote` (409 `negotiation/thread-sealed` → `null`). Champs lus :
  `minimumApplied`, `minimumAmount`, `commissionGridId`, `promoIneffectiveReason`.
- Erreur `budget-below-commission-minimum` (422) dans `error_catalog`.

### Pièges et points d'attention
- **État global à remettre à zéro en test** : `CommissionGridStore` et le taux unique
  sont des états de module. Toujours `useTestCommissionGrid()` (qui pose
  `addTearDown(CommissionGridStore.reset)`) et
  `setDonyCommissionRate(kDonyCommissionRateDefault)` en `tearDown`, sinon un test
  pollue les suivants.
- **`effectiveFrom` en UTC** : une date sans fuseau est lue en UTC, et la comparaison se
  fait sur `DateTime.now().toUtc()`. Ne jamais comparer avec une heure locale.
- **Montants serveur prioritaires** : `pricePerKgDisplay`, `unitPriceDisplay`,
  `totalSenderAmountEur`, `grossPriceEur`, devis : la façade ne sert qu'à défaut. Sous
  grille, `unitPriceDisplay` et `pricePerKgDisplay` sont des **nets** (le back les sert
  ainsi), pas des bruts.
- Les fils et demandes figent leur grille : ne jamais appliquer la grille du jour à un
  objet qui porte un `commissionGridId`, ni une grille à un objet qui n'en porte pas.
- `formatPriceIn` est compact : un montant rond s'écrit « 51 € », pas « 51,00 € ».
- Aucun pourcentage dans les textes (garde-fou du brief) : le minimum se formate dans
  la devise de l'objet, ou dans la devise active pour la FAQ et la carte de commission.

## Critères d'acceptation couverts
- Sans grille (`/config/commission-grid` 404 ou `current` nul) : comportement et
  montants inchangés (tests « sans grille » de chaque écran touché).
- Sous grille : prix d'appel au net, mention des frais de service avec minimum (sans
  minimum sur la carte), total frais compris et « (minimum) » avant validation (offre,
  demande, fils, espèces, mobile money).
- Bascule de grille à la date d'effet sans redémarrage.
- Grille figée des fils et des demandes, repli sur la grille en vigueur, puis sur le
  taux figé.
- Vecteurs du back reproduits au centime (`commission_calculator_vectors_test.dart`).
- Aucun taux dans les textes FR/EN ; libellé « Frais de service Yadony ».

## Décisions techniques
- Décisions du propriétaire (19/10) et rulings A1 à A9 :
  `.superpowers/sdd/2026-10-19-commission-paliers-app/progress.md` et fin de
  `docs/superpowers/plans/2026-10-19-commission-paliers-app.md`.
- Taux unique isolé dans `commission_rate.dart` : `dony_pricing.dart` et
  `commission_pricing.dart` ne s'importent plus mutuellement.
- `preloadCommissionGrids` vit dans `features/config/data/` (accès aux données, à côté
  de `getCommissionGridById`), partagé par les fils de demande et de trajet, avec un
  seul délai de 3 s.
- Mise à jour forcée : rien dans le code, `min_supported_build` (Remote Config) à poser
  par plateforme par le propriétaire (voir la description de PR).
