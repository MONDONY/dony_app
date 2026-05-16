# Spec — Refonte de l'onglet « Acceptées » de l'écran Demandes

**Date :** 2026-05-16
**Écran concerné :** `lib/features/matching/presentation/screens/bid_list_screen.dart`
**Maquettes validées :** `.superpowers/brainstorm/3071508-1778945028/content/` (`search-filter.html`, `card-rework.html`, `status-badge.html`)

---

## 1. Contexte et problème

L'écran « Demandes » (côté voyageur) liste les bids reçus sur une annonce, répartis en
deux onglets : « En attente » et « Acceptées ».

Deux défauts :

1. **Statuts post-acceptation invisibles.** Le filtre de l'onglet « Acceptées » ne retenait
   que `ACCEPTED`, `IN_TRANSIT`, `COMPLETED`. Les statuts `HANDED_OVER` (« En route »),
   `NO_SHOW`, `PARCEL_REFUSED` et `CANCELLED` (post-acceptation) ne figurent dans aucun
   onglet : ces colis disparaissent de l'écran. *(Le cas `HANDED_OVER` a déjà reçu un
   correctif partiel — voir §9.)*
2. **Aucun moyen de retrouver un colis** parmi un trajet qui peut compter 20 colis ou plus.

## 2. Objectifs

- Rendre visibles **tous** les statuts post-acceptation dans l'onglet « Acceptées ».
- Permettre de **rechercher** un colis par nom d'expéditeur ou numéro de suivi.
- Permettre de **filtrer** par catégorie de statut (actif / clôturé).
- Retravailler la carte de bid et le badge de statut (design validé en maquette).

## 3. Périmètre

**Inclus :** refonte du contenu de l'onglet « Acceptées » uniquement.

**Exclus :** l'onglet « En attente » (pas de recherche pour l'instant), le reste de l'écran,
le backend (filtrage 100 % côté client — les bids sont déjà tous chargés par `BidBloc`).
Seule exception hors onglet « Acceptées » : l'onglet ouvert par défaut (§4.4).

## 4. Comportement UX

### 4.1 Barre de recherche

- Champ **toujours visible** en haut de l'onglet « Acceptées », **défile avec la liste**
  (premier élément scrollable : disparaît en scrollant vers le bas, réapparaît vers le haut).
- Placeholder : « Nom ou n° de suivi… ».
- Cherche dans : **nom résolu de l'expéditeur** (`BidModel.resolvedSenderName`) **et**
  **numéro de suivi** (`BidModel.trackingNumber`).
- Comparaison **insensible à la casse et aux accents** (normalisation : minuscules +
  suppression des diacritiques des deux côtés).
- Le terme recherché est **surligné** dans le nom et le numéro affichés.
- Bouton d'effacement (×) visible quand le champ est non vide → réinitialise la requête.
- Pas de recherche destinataire, pas de recherche par catégorie de contenu.

### 4.2 Chips de filtre statut

- Rangée de 3 chips sous la barre de recherche, défile avec la liste : `Tous` / `Actifs` /
  `Clôturés`.
- Chaque chip affiche un **compteur**, recalculé sur le résultat de recherche courant.
- `Actifs` = `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT`, `COMPLETED`.
- `Clôturés` = `NO_SHOW`, `PARCEL_REFUSED`, `CANCELLED`.
- Chip actif : style plein vert (`kGreenPrimary`) ; inactifs : fond surface + bordure.
- Filtre initial : `Tous`.

### 4.3 Combinaison recherche ∩ filtre

Recherche et filtre **se cumulent**. La liste affichée =
`bids acceptés` ∩ `correspondance recherche` ∩ `catégorie du filtre`.

### 4.4 Onglet ouvert par défaut

Au **premier** `BidListLoaded`, si l'onglet « En attente » est vide
(aucun bid `PENDING`/`PAYMENT_ESCROWED`) **et** que l'appelant n'a pas demandé d'onglet
précis (`initialTabIndex == 0`) **et** que l'utilisateur n'a pas déjà changé d'onglet
manuellement → bascule automatique sur « Acceptées ».
**L'ordre des onglets ne change jamais** (`En attente | Acceptées`).

### 4.5 Tri de la liste

Les bids affichés sont triés par `updatedAt` **décroissant** (activité la plus récente en
haut). Tri appliqué après filtrage, indépendamment de la catégorie.

### 4.6 États vides

| Situation | Affichage |
|-----------|-----------|
| Aucun bid accepté du tout | État vide existant « Aucune demande acceptée » (mascotte) |
| Recherche/filtre sans résultat, mais des bids acceptés existent | État vide en ligne « Aucun résultat » + rappel du terme ; **barre de recherche et chips restent visibles** pour ajuster |

## 5. Architecture

### 5.1 Nouveau — `BidListFilterCubit`

Fichier : `lib/features/matching/bloc/bid_list_filter_cubit.dart`.

État de **vue** uniquement (pas de données métier, pas d'appel réseau) :

```
enum AcceptedStatusFilter { all, active, closed }

BidListFilterState {
  String query;                  // requête de recherche brute
  AcceptedStatusFilter filter;    // catégorie sélectionnée
}
```

État comparable par valeur (`==`/`hashCode` ou `Equatable`, selon la convention du projet).

Méthodes du Cubit :
- `setQuery(String)` — met à jour la requête.
- `setFilter(AcceptedStatusFilter)` — met à jour le filtre.
- `reset()` — revient à `query: '', filter: all`.

État initial : `query: ''`, `filter: AcceptedStatusFilter.all`.

Enregistré en DI via `registerFactory` dans `lib/core/di/injection.dart`.

### 5.2 Modifié — `bid_list_screen.dart`

- `BidListFilterCubit` ajouté au `MultiBlocProvider` de `BidListScreen` (via `getIt`).
  `BidListScreenTesting` en crée une instance réelle (Cubit déterministe, pas de mock).
- **Calcul de `acceptedBids`** élargi à tous les statuts post-acceptation :
  `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT`, `COMPLETED`, `NO_SHOW`, `PARCEL_REFUSED`,
  `CANCELLED` — **en excluant** les `CANCELLED` auto (voir §7.1).
- Le contenu de l'onglet « Acceptées » est encapsulé dans un `BlocBuilder<BidListFilterCubit>`
  qui applique recherche + filtre + tri à `acceptedBids`.
- Nouveaux widgets privés : `_BidSearchField`, `_StatusFilterChips`, `_SearchEmptyState`.
- `_BidCard` retravaillée (§6.1) ; `_StatusBadge` remplacé par `_StatusDot` (§6.2).
- Auto-sélection d'onglet (§4.4) : flag `_didAutoSelectTab` posé une seule fois ;
  flag `_userSwitchedTab` posé dès que l'utilisateur change d'onglet manuellement.

### 5.3 Logique de filtrage (fonction pure)

Ordre d'application :

1. `acceptedBids` = bids dont le statut est post-acceptation, hors `CANCELLED` auto.
2. **Recherche** : si requête normalisée vide → tout ; sinon garder les bids dont
   `resolvedSenderName` normalisé **ou** `trackingNumber` normalisé contient la requête.
3. **Compteurs des chips** calculés sur le résultat de l'étape 2
   (`Tous` = total, `Actifs` = sous-ensemble actif, `Clôturés` = sous-ensemble clôturé).
4. **Filtre** : selon le chip actif, restreindre à la catégorie.
5. **Tri** par `updatedAt` décroissant.

## 6. Détails composants

### 6.1 Carte de bid — `_BidCard` (Option B validée)

De haut en bas :

- **Ligne 1** : avatar (initiales, `DonyAvatar`) · au centre nom de l'expéditeur
  (`titleLarge`, w800) puis numéro de suivi en dessous (`N° DNY-XXXX`, petit, `kTextHint`) ·
  à droite montant avec micro-label « MONTANT » au-dessus (`pricePerKg * weightKg`).
- **Ligne 2** : deux pastilles méta discrètes — `⚖ {poids} kg` et
  `📦 {catégorie de contenu}` (fond `kBackground`, texte `kTextSecondary`).
  Si la catégorie est nulle → repli sur la description, sinon pastille omise.
- **Séparateur** fin.
- **Badge de statut** `_StatusDot` (§6.2).
- La note expéditeur « ★ — » (jamais renseignée) est **supprimée**.
- Comportement inchangé : toute la carte navigue vers `/bids/{id}`.
- Sur l'onglet « Acceptées » la carte n'a **pas** de boutons d'action (lecture seule) —
  inchangé.

### 6.2 Badge de statut — `_StatusDot` (Option 1 « point coloré » validée)

Pastille à fond teinté doux, contenant un **point de couleur** (≈ 7-8 px) suivi du libellé.
**Aucune icône.** Radius 9.

| Statut | Libellé | Couleur point + texte | Fond |
|--------|---------|----------------------|------|
| `ACCEPTED` | Accepté | `cs.success` | `cs.successLight` |
| `HANDED_OVER` | En route | `cs.primary` | `cs.primaryContainer` |
| `IN_TRANSIT` | En transit | `cs.info` | `cs.infoLight` |
| `COMPLETED` | Livré | `cs.success` | `cs.successLight` |
| `NO_SHOW` | Absent | `cs.warning` | `cs.warningLight` |
| `PARCEL_REFUSED` | Colis refusé | `cs.error` | `cs.errorLight` |
| `CANCELLED` | Annulé | `cs.onSurfaceVariant` | fond neutre clair |

Libellés alignés sur `shipment_list_screen.dart` / `billet_status_stamp.dart`.
Accessibilité : l'information passe par le **point + le texte**, jamais par la couleur seule.

### 6.3 Animation

L'animation d'entrée en cascade (`flutter_animate`, stagger 60 ms × index) ne se joue
**qu'au premier affichage** de la liste. Lors d'un filtrage (frappe au clavier, changement
de chip), la liste se met à jour **sans rejouer** la cascade — sinon scintillement à chaque
touche. Implémentation : indicateur « première construction » dans l'état du widget.

## 7. Cas limites et erreurs

### 7.1 `CANCELLED` ambigu — exclusion des annulations automatiques

Un bid `PENDING` jamais traité peut s'auto-annuler (`BidTimeoutScheduler` →
`status = CANCELLED`, `rejectionReason = "TRAVELER_NO_RESPONSE"`). Ce bid n'a **jamais été
accepté** par le voyageur.

→ Les bids `CANCELLED` dont `rejectionReason == "TRAVELER_NO_RESPONSE"` sont **exclus** de
l'onglet « Acceptées ». Seules les annulations post-acceptation y figurent.

### 7.2 Champs nuls

- `trackingNumber` nul → le bid n'est jamais trouvé par recherche de numéro (toujours
  trouvable par nom). Aucun crash.
- `pricePerKg` nul → montant affiché « — » (comportement existant conservé).
- `contentCategory` et `description` nuls → pastille catégorie omise.

### 7.3 Erreurs de chargement

Le filtrage est purement client-side : aucun nouveau chemin d'erreur. `BidError`/`BidLoading`
conservent leur rendu actuel. L'état du `BidListFilterCubit` (requête, filtre) survit à un
rafraîchissement de `BidBloc` puisqu'il est indépendant.

## 8. Tests (couverture ≥ 90 %)

### 8.1 `test/features/matching/bloc/bid_list_filter_cubit_test.dart` (nouveau)

- état initial (`query: ''`, `filter: all`) ;
- `setQuery` émet le nouvel état ;
- `setFilter` émet le nouvel état ;
- `reset` revient à l'état initial.

### 8.2 `test/features/matching/presentation/bid_list_screen_test.dart` (étendu)

- recherche par nom filtre la liste (insensible casse/accents) ;
- recherche par numéro de suivi filtre la liste ;
- filtre `Clôturés` n'affiche que `NO_SHOW` / `PARCEL_REFUSED` / `CANCELLED` ;
- filtre `Actifs` n'affiche que les 4 statuts actifs ;
- recherche + filtre se cumulent ;
- compteurs des chips recalculés sur le résultat de recherche ;
- état vide « Aucun résultat » quand recherche infructueuse ;
- `CANCELLED` auto (`TRAVELER_NO_RESPONSE`) absent de la liste ;
- les 7 statuts affichent le bon libellé de badge ;
- auto-sélection de l'onglet « Acceptées » quand « En attente » est vide ;
- pas d'auto-sélection si `initialTabIndex` explicite ou si l'utilisateur a changé d'onglet.

## 9. Articulation avec le correctif `HANDED_OVER` existant

Un correctif partiel est déjà en place (non commité) : ajout de `HANDED_OVER` au filtre
`acceptedBids` et d'un badge dédié, plus deux tests. Cette refonte **englobe et remplace**
ce correctif : le filtre `acceptedBids` est de toute façon réécrit (§5.3), et `_StatusBadge`
est remplacé par `_StatusDot` (§6.2). Les tests déjà ajoutés restent valides ou sont
adaptés aux nouveaux libellés.

## 10. Fichiers

| Fichier | Action |
|---------|--------|
| `lib/features/matching/bloc/bid_list_filter_cubit.dart` | créer |
| `lib/features/matching/presentation/screens/bid_list_screen.dart` | modifier |
| `lib/core/di/injection.dart` | modifier (registerFactory) |
| `test/features/matching/bloc/bid_list_filter_cubit_test.dart` | créer |
| `test/features/matching/presentation/bid_list_screen_test.dart` | modifier |

## 11. Décisions

- **Filtrage client-side** : les bids sont déjà chargés ; pas d'appel backend, réactivité
  immédiate, état de recherche indépendant du cycle de `BidBloc`.
- **Cubit dédié** (pas `setState`, pas extension de `BidBloc`) : sépare l'état de vue de
  l'état métier, respecte la règle BLoC, testable isolément.
- **Recherche « Acceptées » uniquement** : c'est là que les colis s'accumulent sur la durée
  d'un trajet. « En attente » est transitoire — recherche reportée (YAGNI).
- **Ordre des onglets fixe** : seul l'onglet *sélectionné* par défaut change, jamais leur
  position, pour éviter une réorganisation à chaud désorientante.
- **Carte Option B + badge « point coloré »** : validés en maquette avec l'utilisateur.
