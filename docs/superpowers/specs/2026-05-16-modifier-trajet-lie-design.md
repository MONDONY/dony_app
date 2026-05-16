# Modifier un trajet lié dans une négociation — Design

**Date :** 2026-05-16
**Feature :** Permettre au voyageur de modifier un trajet existant (capacité + paiement liquide) pendant qu'il le lie à une demande de colis, via un bottom sheet.

---

## 1. Contexte & objectif

Dans le flux de négociation d'une demande de colis, une fois que l'expéditeur a accepté l'offre, le thread passe à `AWAITING_TRIP` : le voyageur doit **lier un trajet**. L'écran `link_trip_screen.dart` liste ses trajets (annonces) compatibles — corridor + fenêtre de date qui matchent la demande. Aujourd'hui, le voyageur peut seulement **sélectionner** un trajet tel quel, ou en **créer un dédié**.

**Problème :** un trajet compatible peut ne pas convenir en l'état — typiquement le **paiement en liquide n'y est pas activé** alors que le voyageur veut le proposer, ou la **capacité disponible** n'est plus à jour. Le voyageur devrait pouvoir l'ajuster sans quitter le flux de liaison.

**Objectif :** depuis l'écran de liaison, permettre au voyageur de **modifier un trajet existant** — capacité disponible et activation du paiement en liquide — via un bottom sheet. La modification met à jour l'annonce **globalement**.

---

## 2. Périmètre

**Inclus :**
- Bouton « Modifier » + pastille d'état liquide en pied de chaque trajet compatible de `link_trip_screen.dart`.
- Bottom sheet `ModifyTripSheet` — design A (bloc verrouillé + bloc modifiable).
- 2 champs modifiables : capacité disponible (kg), activation du paiement en liquide.
- Détour vers la configuration de la carte commission si le liquide est activé sans carte.
- Garde-fous : champs verrouillés (date, corridor, lieux), bannière d'information si le trajet a déjà reçu des offres, validation de la capacité.
- Mise à jour **globale** de l'annonce, via l'événement `AnnouncementUpdateRequested` existant.

**Hors périmètre :**
- Modification d'autres champs du trajet (prix au kg, mode de transport, description, types de contenu).
- Modification de trajets en dehors du flux de liaison.
- Toute évolution backend — l'endpoint de mise à jour d'annonce existe déjà et porte déjà sa logique de validation (voir §6).
- Refonte de `link_trip_screen` (l'écran reste un `StatefulWidget` ; voir §9).
- Le flux « Créer un nouveau trajet » (trajet dédié) — inchangé.

---

## 3. Point d'entrée — `link_trip_screen.dart`

L'écran liste les trajets compatibles via le widget `_TripTile`, qui reçoit déjà le `AnnouncementModel` complet de chaque trajet. Sur chaque tuile, ajout d'un **pied de carte** séparé par un liseré :
- Bouton **« ✎ Modifier le trajet »** → ouvre `ModifyTripSheet` pour ce `AnnouncementModel`.
- Pastille d'état **« Liquide activé / désactivé »** — reflète `announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash)`.

« Modifier » et la sélection restent **deux actions distinctes** : le tap sur le corps de la tuile sélectionne le trajet (inchangé) ; le bouton « Modifier » du pied est une cible tactile séparée qui n'affecte pas la sélection. La barre de bas d'écran `DonySelectBar` (« Sélectionner / Confirmer ce trajet ») et « Créer un nouveau trajet » sont inchangés.

`_TripTile` reçoit un nouveau callback `onModify` (en plus de `onTap`), câblé dans `_buildBody` vers une méthode qui ouvre le sheet.

Après une modification réussie, l'écran rafraîchit la liste via sa méthode `_load()` existante — exactement comme `_createNewTrip()` le fait déjà après création. La tuile reflète alors la nouvelle capacité et la nouvelle pastille liquide.

---

## 4. Le bottom sheet `ModifyTripSheet` (design A)

`DonyBottomSheet` (`useRootNavigator: true`, handle, coins arrondis). Disposition « bloc verrouillé / bloc modifiable » :

- **Titre** : « Modifier le trajet ».
- **Bloc verrouillé** (fond grisé, cadenas, lecture seule) : corridor (départ → arrivée), date, lieux (adresses de remise/livraison). Affiché pour le contexte, non éditable.
- **Bloc modifiable** (fond vert teinté) :
  - **Capacité disponible (kg)** — stepper − / +.
  - **Paiement en liquide** — toggle.
- **Bannière d'information** (ambre) si le trajet a déjà reçu des offres (voir §6).
- **`stickyBottom`** : `DonyButton` « Enregistrer les modifications » (règle CLAUDE.md — bouton de bottom sheet toujours dans `stickyBottom`).

L'écran `link_trip_screen` ne fournit pas de `AnnouncementBloc` dans son arbre. Le sheet provisionne donc lui-même ses blocs via le `wrapper` de `DonyBottomSheet` : un `MultiBlocProvider` avec `AnnouncementBloc` (mise à jour) et `CommissionMethodBloc` (état carte commission), tous deux résolus via `getIt`.

---

## 5. Logique du toggle liquide & carte commission

À l'ouverture, le sheet charge l'état de la carte commission via `CommissionMethodBloc` (`CommissionMethodLoadRequested` → `CommissionMethodLoaded` / `CommissionMethodNotConfigured`).

- Liquide **déjà activé** sur l'annonce → toggle ON à l'ouverture.
- Toggle ON **avec** carte commission configurée → OK.
- Toggle ON **sans** carte commission → navigation vers `/payments/commission-method` via `context.push`. Le sheet **reste monté** sous la route poussée ; son état (capacité saisie, intention d'activer le liquide) est donc préservé sans effort. Au retour (`pop`), le sheet ré-interroge l'état de la carte : si elle est désormais configurée, le toggle reste ON ; sinon il revient à OFF.
- Toggle OFF → désactive le liquide (`acceptedPaymentMethods` ne contiendra plus `cash`).

Rationale : activer le liquide engage le voyageur à payer la commission dony (12 %, min. 1 €) prélevée sur sa carte commission — la carte est donc un prérequis.

**Référence d'implémentation :** le pattern « toggle liquide + détour carte commission » existe déjà dans `create_announcement_bottom_sheet.dart` (flux de création de trajet). `ModifyTripSheet` s'en inspire pour rester cohérent.

---

## 6. Garde-fous

**Champs verrouillés** — date, corridor, lieux : lecture seule dans le sheet (bloc verrouillé). `AnnouncementUpdateRequested` étant un remplacement complet (voir §7), ces champs sont renvoyés inchangés.

**Trajet avec colis acceptés — blocage backend.** Le backend **refuse entièrement** la mise à jour d'une annonce qui a des colis acceptés : il renvoie HTTP 409, que `AnnouncementBloc` traduit déjà en `ConflictException` (code `announcement-update-blocked`, message « Modification impossible : des colis sont déjà acceptés pour ce trajet »). Le backend est donc le véritable garde-fou — aucun contrôle client à dupliquer, aucune évolution backend nécessaire.

**Bannière d'information.** Le `AnnouncementModel` n'expose que `bidsCount` (nombre **total** d'offres, sans distinguer acceptées et en attente). Le client ne peut donc pas savoir de façon fiable si un colis est accepté. Quand `bidsCount != null && bidsCount > 0`, le sheet affiche une bannière ambre informative : « Ce trajet a déjà reçu des offres. Si un colis y est déjà accepté, la modification sera refusée. » Elle fixe les attentes ; le blocage réel reste le 409 backend.

**Validation de la capacité.** La capacité saisie doit être strictement positive. Le stepper est borné par la même plage min/max que le formulaire de création de trajet (valeurs exactes à reprendre depuis ce formulaire lors du plan). Hors bornes → bouton « Enregistrer » désactivé. Aucun contrôle « capacité ≥ poids des colis acceptés » n'est nécessaire : un trajet avec des colis acceptés est de toute façon non modifiable (refus 409 ci-dessus).

---

## 7. Enregistrement & flux de données

`AnnouncementUpdateRequested` est un **événement de remplacement complet** : il porte tous les champs de l'annonce (`id`, `departureCity`, `arrivalCity`, `departureDate`, `departureTime?`, `arrivalTime?`, `pickupAddress`, `deliveryAddress`, `availableKg`, `pricePerKg`, `transportMode`, `description?`, `acceptedContentTypes`, `refusedTypes`, `acceptedPaymentMethods`).

« Enregistrer » construit donc un `AnnouncementUpdateRequested` à partir du `AnnouncementModel` reçu, en ne changeant que deux valeurs :
- `availableKg` ← capacité saisie (c'est le seul champ de capacité porté par l'événement ; il n'y a pas de `totalKg`).
- `acceptedPaymentMethods` ← liste mise à jour selon le toggle.

**Conversions & points d'attention :**
- `acceptedPaymentMethods` : `Set<BidPaymentMethod>` (modèle) → `List<String>` codes wire (`'STRIPE'` / `'CASH'`, d'après les `@JsonValue` de `BidPaymentMethod`). `stripe` est toujours conservé ; `cash` ajouté/retiré selon le toggle.
- `transportMode` : nullable sur `AnnouncementModel`, **requis non-null** sur l'événement. `pickupAddress` / `deliveryAddress` : idem (nullables sur le modèle, requis sur l'événement). En pratique ces champs sont toujours renseignés pour un trajet créé via l'app ; le plan définit le repli au cas où (valeur par défaut ou neutralisation de l'action « Modifier » sur un trajet incomplet).

L'événement est dispatché sur le `AnnouncementBloc` du sheet. États :
- `AnnouncementLoading` → bouton « Enregistrer » en état loading.
- `AnnouncementUpdated(announcement)` → succès : fermer le sheet ; `link_trip_screen` rafraîchit via `_load()`.
- `AnnouncementError(error)` → échec : sheet maintenu ouvert, valeurs préservées, message via `ErrorPresenter` (le cas 409 « colis acceptés » est déjà formaté par le bloc).

Mise à jour **globale** : l'annonce est modifiée côté backend, donc reflétée partout (toutes les vues du trajet).

---

## 8. États & gestion des erreurs

- **Chargement initial** — spinner pendant le chargement de l'état de la carte commission (`CommissionMethodLoading`).
- **Enregistrement en cours** — `AnnouncementLoading` → bouton « Enregistrer » en état loading, sheet non dismissable.
- **Échec de mise à jour** — `AnnouncementError` → `ErrorPresenter` (RFC 7807). Le sheet reste ouvert, valeurs préservées, réessai possible. Le 409 « colis acceptés » affiche le message dédié déjà fourni par le bloc.
- **Capacité invalide** — valeur ≤ 0 ou hors bornes du stepper → validation inline, « Enregistrer » désactivé.

---

## 9. Découpage / fichiers

- **Modifier** : `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart`
  - `_TripTile` : ajout d'un pied de carte (bouton « Modifier » + pastille liquide) et d'un callback `onModify`.
  - `_LinkTripScreenState` : méthode d'ouverture du sheet ; rafraîchissement via `_load()` existant après succès. L'écran reste un `StatefulWidget` avec `setState`/`_load()` — c'est le pattern déjà en place (cf. `_createNewTrip`), on ne le refactore pas.
- **Créer** : `lib/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart` — le widget `ModifyTripSheet` et sa méthode statique `show()`.
- **Réutilise** : `AnnouncementBloc` + `AnnouncementUpdateRequested` / `AnnouncementUpdated` / `AnnouncementError`, `CommissionMethodBloc`, `DonyBottomSheet`, `DonyButton`, `ErrorPresenter`. Pattern de référence : `create_announcement_bottom_sheet.dart` (toggle liquide + carte commission).
- **Aucun** nouveau bloc, événement ou modèle.

---

## 10. Tests

- **Widget tests `ModifyTripSheet`** :
  - champs verrouillés (date, corridor, lieux) affichés en lecture seule ;
  - stepper de capacité borné ; « Enregistrer » désactivé si capacité invalide ;
  - toggle liquide : carte commission présente → activable ; carte absente → détour vers `/payments/commission-method` ;
  - bannière d'information affichée quand `bidsCount > 0`, absente sinon ;
  - « Enregistrer » dispatche `AnnouncementUpdateRequested` avec `availableKg` et `acceptedPaymentMethods` corrects, les autres champs inchangés ;
  - `AnnouncementUpdated` → sheet fermé ; `AnnouncementError` (dont 409) → sheet maintenu + message d'erreur.
- **Widget test `link_trip_screen`** : le bouton « Modifier » et la pastille liquide apparaissent en pied de chaque trajet compatible ; la pastille reflète l'état liquide de l'annonce.
- **Couverture ≥ 90 %** (`flutter test --coverage`).

---

## 11. Suites possibles (hors périmètre)

- Édition d'autres champs du trajet (prix, mode de transport…).
- Exposer un champ `committedKg` / `acceptedBidsCount` sur le DTO d'annonce permettrait des garde-fous client proactifs et précis (désactiver « Modifier » plutôt que d'attendre le 409).
- Remplacer le détour « carte commission » (navigation) par un sheet imbriqué, pour ne pas perdre le contexte visuel.
