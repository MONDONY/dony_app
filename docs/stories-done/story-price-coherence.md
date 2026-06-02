# Story — Cohérence du prix au kilo (expéditeur = net + 12 %) sur toute l'app (Flutter)

**Date:** 2026-06-02 | **Status:** ✅ Complète

## Résumé
Le prix au kilo était affiché de façon incohérente : selon l'écran, l'**expéditeur** voyait
tantôt le NET du voyageur, tantôt le NET + 12 %. On harmonise : **partout où un expéditeur
voit un prix, c'est net × 1,12** (commission Dony incluse) ; **partout où un voyageur voit ce
qu'il touche, c'est le net entier** (il reçoit l'intégralité du prix qu'il fixe — la
commission est payée EN SUS par l'expéditeur, cf. backend).

## Décisions produit (validées)
- **Source de vérité = backend + helper** : le backend expose `pricePerKgDisplay`
  (= net × 1,12) ; le front l'utilise s'il est présent, sinon recalcule.
- **« Vous touchez » = net entier** (plus de `× 0,88`). Le voyageur touche le prix qu'il
  fixe ; le cas cash/mobile money (Dony prélève 12 % au voyageur) reste géré séparément.

## Fichiers créés
- `core/pricing/dony_pricing.dart` — source unique côté app : `kDonyCommissionRate` (0,12),
  `kDonyCommissionMultiplier` (1,12), `netToSenderPrice(net)`, `formatKgPrice(v)` (entier si
  rond, 2 décimales sinon), et l'extension `AnnouncementModel.senderPricePerKg` (préfère
  `pricePerKgDisplay`, sinon `net × multiplicateur`).
- `test/core/pricing/dony_pricing_test.dart` — couvre constantes, conversion, formatage,
  extension (avec/sans champ backend).

## Fichiers modifiés
**Modèle**
- `matching/data/models/announcement_model.dart` (+ `.g.dart`) — champ nullable
  `pricePerKgDisplay` (lu du JSON backend).

**Surfaces EXPÉDITEUR → affichent net × 1,12**
- `matching/.../traveler_card.dart`, `subscriptions/.../traveler_announcement_card.dart`
  (modèle `TravelerAnnouncement` → helper `netToSenderPrice`), `matching/.../screens/traveler_profile_screen.dart`,
  `matching/.../widgets/traveler_announcement_bottom_sheet.dart`,
  `matching/.../widgets/announcement_map_view.dart` (pastilles cluster + marqueur),
  `cancellation/.../rematch_search_screen.dart`, `cancellation/.../rematch_bottom_sheet.dart`,
  `payments/.../payment_screen.dart` (voir ci-dessous), `matching/.../widgets/trajet_card.dart`
  (carte visible **uniquement par l'expéditeur** dans `bid_detail_screen`, `if (isSender)`).

**Surfaces VOYAGEUR → « vous touchez » = net entier (suppression des × 0,88)**
- `matching/.../widgets/announcement_preview_sheet.dart`, `screens/create_announcement_screen.dart`,
  `widgets/create_announcement/prix_conditions_step.dart`,
  `trip_templates/.../trip_template_edit_screen.dart`,
  `matching/.../widgets/payment_release_card.dart`.
  Message unifié : **« Vous touchez {net}€ · l'expéditeur paie {net×1,12}€ »**.

**payment_screen (écran de paiement expéditeur) — correction de fond**
- Bug : affichait « Payer {net}€ » et « Vous payez {net}€ » avec la commission en **déduction
  (−)**, alors que le backend facture **net × 1,12**. Corrigé : `_total = net + commission`,
  bouton + « Vous payez » = `_total`, commission présentée comme un **ajout (+)**, libellé
  escrow reformulé (« bloqués … libérés » au lieu de « versés au voyageur {montant} »).

## Comment ça fonctionne
- **Expéditeur** : sur toute surface portant un `AnnouncementModel`, on appelle
  `announcement.senderPricePerKg` (→ `pricePerKgDisplay` backend, sinon `net × 1,12`), formaté
  par `formatKgPrice`. Pour les modèles hors `AnnouncementModel` (suggestion de re-match, bid),
  on appelle directement `netToSenderPrice(...)`.
- **Voyageur** : on affiche le `pricePerKg` net tel quel (« ce que tu touches ») et, en
  complément informatif, le prix expéditeur `net × 1,12`.
- **MIXED inchangé** : `unitPriceNet` (voyageur) / `unitPriceDisplay` (expéditeur) déjà fournis
  par le backend — aucune surface MIXED touchée.

## Pièges et points d'attention
- `senderPricePerKg` est une **extension sur `AnnouncementModel`** : ne s'applique pas à
  `TravelerAnnouncement` (subscriptions) ni au bid → utiliser `netToSenderPrice` à la place.
- Le prix expéditeur (net × 1,12) est rarement entier → toujours formater via `formatKgPrice`
  (sinon `toStringAsFixed(0)` arrondit faussement). Le texte plus large a exposé un débordement
  320px sur `traveler_announcement_card` (corrigé : prix en `Flexible` + ellipsis).
- Animations `flutter_animate` : en widget test, `pumpAndSettle()` après le 1ᵉʳ frame pour
  vider le timer du `fadeIn` (sinon « A Timer is still pending »).

## Critères d'acceptation couverts
- [x] Expéditeur voit net × 1,12 partout (cartes, fiches, carte/markers, sheets, re-match, paiement).
- [x] Voyageur voit son net entier ; « vous touchez × 0,88 » supprimé.
- [x] payment_screen facture et affiche net × 1,12 (commission ajoutée, pas déduite).
- [x] Source unique : champ backend `pricePerKgDisplay` + helper de repli.

## Tests
- Suite ciblée (politique projet) : `dony_pricing_test`, `traveler_card_test`,
  `traveler_announcement_card_test` (+ régression débordement 320px), `payment_release_card_test`,
  `prix_conditions_step_test`, `payment_screen_test` (total 33,60 € = 30 net × 1,12, commission « + »),
  `traveler_announcement_bottom_sheet_test`, `announcement_map_view_test`, `near_me_carousel_test`,
  `saved_trips_service_test`, `cartes_secondaires_test`, `create_announcement_screen_test`,
  `announcement_bloc_test` — **tous verts**. `flutter analyze` : 0 erreur.

## Décisions techniques
- **Helper centralisé** plutôt que littéraux dispersés (`1.12/0.12/0.88`) : un seul endroit
  pour le multiplicateur côté app, aligné sur le backend.
- **`trajet_card` rendu net×1,12** (et non role-aware) car prouvé sender-only dans
  `bid_detail_screen` (`if (isSender) … TrajetCard(bid)`).
- `bid_list` (demandes reçues) laissé en **net** : surface voyageur → correct tel quel.

## Mise à jour — taux de commission piloté par le backend
Le taux n'est plus une constante figée côté app. `dony_pricing` expose désormais
`donyCommissionRate` / `donyCommissionMultiplier` (repli 12 % via `kDonyCommissionRateDefault`)
et `setDonyCommissionRate(rate)`. Au démarrage, `main.dart` charge le taux réel
(`GET /config/commission-rate` via `IConfigRepository`) et le pousse dans le helper
(best-effort, non bloquant). Les calculs locaux de l'aperçu checkout
(`create_bid_bottom_sheet`, `create_bid_screen`) et le hint grille
(`price_grid_item_form_sheet`) passent par le helper → suivent le taux. Les surfaces
d'affichage suivent déjà via les champs backend `*Display`. **Résultat : changer
`dony.commission.rate` côté backend ajuste la commission partout, app comprise.**
Test `dony_pricing_test` : `setDonyCommissionRate(0.20)` → `netToSenderPrice(10) == 12,0`,
valeurs aberrantes ignorées.
