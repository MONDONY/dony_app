# Modifier un trajet lié dans une négociation — Design

**Date :** 2026-05-16
**Feature :** Permettre au voyageur de modifier un trajet existant (capacité + paiement liquide) pendant qu'il le lie à une demande de colis, via un bottom sheet.

---

## 1. Contexte & objectif

Dans le flux de négociation d'une demande de colis, une fois que l'expéditeur a accepté l'offre, le thread passe à `AWAITING_TRIP` : le voyageur doit **lier un trajet**. L'écran `link_trip_screen.dart` liste ses trajets (annonces) compatibles — corridor + date qui matchent la demande. Aujourd'hui, le voyageur peut seulement **sélectionner** un trajet tel quel, ou en **créer un dédié**.

**Problème :** un trajet compatible peut ne pas convenir en l'état — typiquement le **paiement en liquide n'y est pas activé** alors que le voyageur veut le proposer pour cette demande, ou la **capacité disponible** n'est plus à jour. Le voyageur devrait pouvoir l'ajuster sans quitter le flux de liaison.

**Objectif :** depuis l'écran de liaison, permettre au voyageur de **modifier un trajet existant** — capacité disponible et activation du paiement en liquide — via un bottom sheet. La modification met à jour l'annonce **globalement**.

---

## 2. Périmètre

**Inclus :**
- Bouton « Modifier » + pastille d'état liquide sur chaque trajet compatible de `link_trip_screen.dart`.
- Bottom sheet `ModifyTripSheet` — design A (bloc verrouillé + bloc modifiable).
- 2 champs modifiables : capacité disponible (kg), activation du paiement en liquide.
- Détour vers la configuration de la carte commission si le liquide est activé sans carte.
- Garde-fous : champs verrouillés (date, corridor, lieux), avertissement si le trajet a des colis acceptés, capacité ≥ poids déjà engagé.
- Mise à jour **globale** de l'annonce.

**Hors périmètre :**
- Modification d'autres champs du trajet (prix au kg, mode de transport, description, types de contenu).
- Modification de trajets en dehors du flux de liaison.
- Backend — l'endpoint de mise à jour d'annonce existe déjà ; aucune évolution backend.
- Le flux « Créer un nouveau trajet » (trajet dédié) — inchangé.

---

## 3. Point d'entrée — `link_trip_screen.dart`

Sur chaque trajet compatible (widget `_TripTile`), ajout d'un **pied de carte** séparé par un liseré :
- Bouton **« ✎ Modifier le trajet »** → ouvre `ModifyTripSheet` pour cette annonce.
- Pastille d'état **« Liquide activé / désactivé »** — reflète `announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash)`. Le voyageur voit l'état du paiement liquide sans ouvrir le sheet.

« Modifier » et « Lier » restent **deux actions distinctes** : le radio de sélection et le CTA collant « Lier ce trajet » sont inchangés. « Créer un nouveau trajet » inchangé.

Après une modification réussie, la liste des trajets compatibles est rafraîchie : la carte reflète la nouvelle capacité et la nouvelle pastille liquide.

---

## 4. Le bottom sheet `ModifyTripSheet` (design A)

`DonyBottomSheet` (`useRootNavigator: true`, handle, coins arrondis). Disposition « bloc verrouillé / bloc modifiable » :

- **Titre** : « Modifier le trajet ».
- **Bloc verrouillé** (fond grisé, cadenas, lecture seule) : corridor (départ → arrivée), date, lieux (adresses de remise/livraison). Affiché pour le contexte, non éditable.
- **Bloc modifiable** (fond vert teinté) :
  - **Capacité disponible (kg)** — stepper − / +.
  - **Paiement en liquide** — toggle.
- **Bannière d'avertissement** (ambre) si le trajet a des colis acceptés.
- **`stickyBottom`** : `DonyButton` « Enregistrer les modifications » (règle CLAUDE.md — bouton de bottom sheet toujours dans `stickyBottom`).

---

## 5. Logique du toggle liquide & carte commission

À l'ouverture, le sheet charge l'état de la carte commission via `CommissionMethodBloc` (`CommissionMethodLoadRequested` → `CommissionMethodLoaded` / `CommissionMethodNotConfigured`).

- Liquide **déjà activé** sur l'annonce → toggle ON à l'ouverture.
- Toggle ON **avec** carte commission configurée → OK, modification possible.
- Toggle ON **sans** carte commission → navigation vers `/payments/commission-method`. L'**état du sheet est préservé** (capacité saisie, intention d'activer le liquide) ; au retour, si la carte est configurée, le sheet se ré-affiche avec le liquide activé, prêt à enregistrer.
- Toggle OFF → désactive le liquide (`acceptedPaymentMethods` ne contiendra plus `cash`).

Rationale : activer le liquide engage le voyageur à payer la commission dony (12 %, min. 1 €) prélevée sur sa carte commission — la carte est donc un prérequis.

---

## 6. Garde-fous

- **Champs verrouillés** — date, corridor, lieux : lecture seule dans le sheet.
- **Avertissement colis** — si l'annonce a des bids/colis acceptés (`bidsCount > 0` ou bids au statut accepté), bannière : « X colis déjà acceptés — la modification s'applique à tous ».
- **Capacité plancher** — la capacité disponible ne peut pas descendre **sous le poids déjà engagé** par les colis acceptés. Validation inline ; le bouton « Enregistrer » est désactivé tant que la valeur est invalide.

---

## 7. Enregistrement & flux de données

- « Enregistrer » → `AnnouncementUpdateRequested(id, …)` sur `AnnouncementBloc`, avec la nouvelle capacité (`availableKg`) et les `acceptedPaymentMethods` mis à jour.
- Mise à jour **globale** : l'annonce est modifiée côté backend, donc partout (toutes les vues du trajet).
- Succès → fermeture du sheet ; `link_trip_screen` rafraîchit la liste des trajets compatibles.
- Blocs fournis au sheet : `AnnouncementBloc` (mise à jour), `CommissionMethodBloc` (état carte commission).

---

## 8. États & gestion des erreurs

- **Chargement** — spinner pendant le chargement de l'état de la carte commission.
- **Échec de mise à jour** — message via `ErrorPresenter` (RFC 7807) ; le sheet reste ouvert, valeurs préservées, réessai possible.
- **Capacité invalide** (< poids engagé) — validation inline, « Enregistrer » désactivé.
- **Enregistrement en cours** — bouton « Enregistrer » en état loading.

---

## 9. Découpage / fichiers

- **Modifier** : `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart` — pied de `_TripTile` (bouton « Modifier » + pastille liquide), rafraîchissement après modification.
- **Créer** : `lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart` — le widget `ModifyTripSheet`.
- **Réutilise** : `AnnouncementBloc` + `AnnouncementUpdateRequested`, `CommissionMethodBloc`, `DonyBottomSheet`, `DonyButton`, `ErrorPresenter`.
- **Aucun** nouveau bloc, événement ou modèle.

**Point à vérifier en implémentation :** la signature exacte de `AnnouncementUpdateRequested` — confirmer qu'on peut mettre à jour `availableKg` et `acceptedPaymentMethods` via cet événement (sinon, étendre l'événement ou ajouter un événement de mise à jour partielle).

---

## 10. Tests

- **Widget tests `ModifyTripSheet`** : champs verrouillés en lecture seule ; stepper capacité borné par le poids engagé ; états du toggle liquide (carte présente → activable ; carte absente → détour vers `/payments/commission-method`) ; bannière d'avertissement affichée quand le trajet a des colis acceptés ; « Enregistrer » dispatche `AnnouncementUpdateRequested` avec les bonnes valeurs.
- **Widget test `link_trip_screen`** : le bouton « Modifier » et la pastille liquide apparaissent sur chaque trajet compatible.
- **Couverture ≥ 90 %** (`flutter test --coverage`).

---

## 11. Suites possibles (hors périmètre)

- Édition d'autres champs du trajet (prix, mode de transport…).
- Remplacer le détour « carte commission » (navigation) par un sheet imbriqué, pour ne pas perdre le contexte visuel.
