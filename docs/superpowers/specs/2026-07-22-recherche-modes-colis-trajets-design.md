# Recherche par mode : trajets ou colis

**Date :** 2026-07-22
**Branches :** `dony_app` → `feature/recherche-modes-colis-trajets` · `dony-back` → `feature/matching-my-trips-filter`
**Maquettes :** https://claude.ai/code/artifact/4d117727-2a1a-461f-ac7f-6e92e0e27554

---

## 1. Problème

L'écran Rechercher (`home_screen.dart`, 3456 lignes) expose trois modes via `HomeMapFocus { all, parcels, trips }`, pilotés par deux chips-bascule indépendants. Six défauts en découlent.

| # | Défaut | Localisation |
|---|--------|--------------|
| 1 | Mode « Tout » = aucun chip actif. Rien à l'écran ne signale l'état par défaut. | `home_screen.dart:1364-1385` |
| 2 | En mode « Tout », la barre corridor ouvre la sheet **trajets**. Les colis affichés ne sont jamais filtrés. | `home_screen.dart:966-968` |
| 3 | Deux jeux de champs séparés en mémoire. Saisir Paris → Dakar côté trajets puis basculer sur Colis perd le corridor. | `_corridor` / `_allCorridors` vs `_prDeparture` / `_prArrival` |
| 4 | Une liste mixte n'a pas d'unité de tri commune : un trajet et une demande ne se comparent ni par prix, ni par date, ni par score. | `_buildSheet`, branche `showBothTypes` |
| 5 | La rangée de chips mélange le mode et les filtres, et son contenu change selon le mode. | `_filterChipsRow` |
| 6 | Deux sheets asymétriques : 10 filtres côté trajets, 2 champs côté colis, et deux libellés de bouton (« Rechercher » / « Appliquer »). | `SearchFormBottomSheet` vs `_SimpleSheet` |

S'y ajoute le chip « 🎯 Pour mes trajets » qui n'est pas un filtre mais une navigation vers `/package-requests/match` (`home_screen.dart:1314-1319`).

## 2. Décisions

| Décision | Retenu | Écarté |
|---|---|---|
| Nombre de modes | 2 exclusifs, un toujours actif | 3 modes avec vue mixte |
| Mode par défaut | Trajets, pour tout le monde | Déduction par rôle |
| Corridor et date | Filtres communs, partagés entre modes | Un jeu par mode |
| Placement du sélecteur | Premier élément de la rangée scrollable | Épinglé, ou dans le header de la sheet |
| Découverte croisée | Compteur sur le segment inactif + ligne complète dans l'état vide | Ligne en pied de liste |
| « Pour mes trajets » | Filtre serveur `matchingMyTrips=true` | Filtrage client, ou statu quo |
| Écran `/package-requests/match` | Supprimé | Conservé en parallèle |

Justification du mode unique : les filtres des deux domaines ne se recouvrent qu'en partie (corridor, date, urgent), les résultats n'ont pas d'unité de tri commune, et une carte à deux natures de marqueurs rend le tap ambigu. L'intention utilisateur est mono par session.

## 3. Contrat serveur (`dony-back`)

### 3.1 Nouveau paramètre

`GET /package-requests` reçoit `matchingMyTrips` (booléen optionnel, absent par défaut).

```
GET /package-requests?matchingMyTrips=true&departure=Paris&arrival=Dakar&page=0&size=20
```

Actif, il restreint les demandes à celles compatibles avec les trajets `ACTIVE` du voyageur connecté, combinable avec tous les filtres existants, et trie par `matchScore` décroissant. Absent ou `false`, le comportement est strictement inchangé — ne jamais envoyer `matchingMyTrips=false` explicitement, même convention que `urgent`.

### 3.2 Implémentation

`MatchingService.findMatchingRequests(travelerId)` calcule déjà la règle de match **en mémoire Java** : boucle sur les trajets actifs, `findOpenByCorridor`, puis `fitsWeight` (`request.weightKg <= announcement.availableKg`) et `fitsDate` (`|desiredDate - departureDate| <= dateToleranceDays`), score en Java, tri en Java. La règle n'est pas exprimable en SQL sans la dupliquer.

On réutilise donc ce service comme source de vérité plutôt que de réécrire la règle en `Specification` :

1. `findMatchingRequests(travelerId)` → liste de DTO triée par score.
2. **Déduplication par `requestId`, en gardant le meilleur score.** Le service produit un DTO par couple (trajet, demande) : une demande compatible avec deux trajets apparaît deux fois. Sans cette étape, la page contient des doublons.
3. Application de la `Specification` existante restreinte par `id IN (:matchedIds)`, avec tous les autres filtres.
4. Tri par score et pagination **en Java**, l'ensemble étant borné par `matchedIds`.

Ce n'est pas une régression de performance : l'endpoint actuel `/travelers/me/matching-requests` charge déjà l'intégralité des matchs sans pagination.

### 3.3 Champs de réponse

`PackageRequestSearchResponse` gagne trois champs nullables, renseignés uniquement quand `matchingMyTrips=true` :

| Champ | Type | Source |
|---|---|---|
| `matchScore` | `Integer` | `MatchingService.computeMatchScore` |
| `matchedTripId` | `String` (UUID) | `announcement.getId()` |
| `matchedTripDepartureDate` | `String` (ISO date) | `announcement.getDepartureDate()` |

Ils alimentent le badge « 94 % » et la mention « ton vol du 12 juil » sur la carte.

### 3.4 Cas limites

- **Aucun trajet actif** → page vide (`content: []`, `totalElements: 0`). Jamais d'erreur : le front désactive le chip en amont, le back reste tolérant.
- **`@PreAuthorize("hasRole('TRAVELER')")`** sur `search` : conservé. Le rôle est universel depuis `AuthService.createUser` et le backfill V176, mais `UserRoleService.deactivateTravelerRole` permet de le retirer — le front doit gérer ce cas (§ 4.6).
- **Aucune migration Flyway** : pas de changement de schéma.

### 3.5 Suppression

`GET /travelers/me/matching-requests` et `MatchingRequestDto` deviennent inutilisés côté application une fois l'écran front supprimé. **Ne pas les supprimer dans cette PR** : `MatchingService.findTravelersMatchingPackage` (notification temps réel) et `AlertService` dépendent du même service, et un retrait d'endpoint public mérite sa propre PR. À marquer `@Deprecated` avec un commentaire pointant vers `matchingMyTrips`.

## 4. Front (`dony_app`)

### 4.1 Nouveaux fichiers

```
lib/features/home/domain/search_mode.dart          enum SearchMode { trips, parcels }
lib/features/home/domain/home_search_filters.dart  état de recherche immuable
lib/features/home/presentation/widgets/search_mode_selector.dart
lib/features/home/presentation/widgets/home_filter_chips_row.dart   (extrait de home_screen)
lib/features/home/presentation/widgets/search_filter_sheet.dart     (fusion des deux sheets)
```

### 4.2 `HomeSearchFilters`

Objet immuable avec `copyWith`, sans dépendance Flutter, testable isolément.

| Bloc | Champs |
|---|---|
| Communs | `departureCity`, `arrivalCity`, `datePreset`, `customDate`, `urgentOnly`, `nearMeActive`, `nearMeRadiusKm` |
| Trajets | `maxPricePerKg`, `weightMin`, `weightMax`, `kiloProOnly`, `minRating`, `weekendOnly`, `transportMode`, `kycVerifiedOnly`, `contentType`, `urgencyFilter` |
| Colis | `maxWeight`, `parcelSize`, `matchingMyTrips` |

Méthodes pures : `toSearchParams()`, `toPackageRequestQuery()`, `activeCountFor(SearchMode)`.

`PackageRequestSearchItem` gagne en parallèle les trois champs nullables du § 3.3 (`matchScore`, `matchedTripId`, `matchedTripDepartureDate`), et `PackageRequestRepository.search` le paramètre `matchingMyTrips`, transmis selon la même convention que `urgent` : présent uniquement quand vrai.

**Piège à ne pas simplifier :** `weightMin` (trajets, « voyageur acceptant au moins X kg ») et `maxWeight` (colis, « demandes d'au plus X kg ») portent le même mot mais des sémantiques opposées. Ils restent deux champs distincts et ne se propagent pas d'un mode à l'autre.

**Unification de la date :** aujourd'hui presets côté trajets (`_DatePreset`), `showDateRangePicker` côté colis. Un seul contrôle, le preset partagé, avec option de plage personnalisée. Le mapping vers `dateFrom`/`dateTo` de l'API colis se fait dans `toPackageRequestQuery()`.

Disparaissent : `_prDeparture`, `_prArrival`, `_prDateFrom`, `_prDateTo`, et `_allCorridors` comme booléen — « Tous les corridors » devient `departureCity == null`.

### 4.3 Rangée de chips

Ordre fixe, rangée entièrement scrollable :

```
[ ✈️ Trajets | 📦 Colis ·8 ] │ 🎯* 🔥 Urgent  📅 <date>  <spécifiques du mode>
                                (* mode colis uniquement)
```

- Segmented à deux états, un toujours actif, réutilisant l'animation de `HomeFocusFilter._Segment` (200 ms `easeOutCubic`).
- Chips communs avec `key` stable, donc immobiles à la bascule. Les spécifiques sortent en 150 ms `easeInCubic` et entrent en 250 ms avec stagger de 40 ms.
- Trajets : `💶 Prix max`, `⚖️ Poids min`, `⭐ Note ≥ 4.5`, `🏅 Kilo Pro`, `🛡 KYC vérifié`.
- Colis : `🎯 Pour mes trajets`, `⚖️ Poids max`, `📐 Taille`.

`HomeFocusFilter` (widget à trois segments) et `homeMapVisibility` sont remplacés par `SearchModeSelector` et une visibilité dérivée directement de `SearchMode`.

### 4.4 Sheet de filtres

Une seule `SearchFilterSheet(mode:)` remplace `SearchFormBottomSheet` et `_SimpleSheet`.

- Bloc haut **commun**, le même widget dans les deux modes : ville de départ, ville d'arrivée, date. C'est ce qui rend le partage réel plutôt que déclaratif.
- Bloc bas spécifique au mode.
- Titre « Filtrer les trajets » / « Filtrer les colis ». Bouton unique « Rechercher » dans `stickyBottom` (règle bottom sheet du CLAUDE.md). « Tout effacer » dans le header quand le compteur est supérieur à zéro.
- Sheet colis : le filtre `🎯 Pour mes trajets` en filtre rapide, et juste dessous la ligne « Me prévenir des nouveaux colis compatibles » qui pilote `package-match-alert`.

La sheet colis reste plus courte, et c'est structurel : le back n'expose ni note ni KYC sur les demandes.

### 4.5 Découverte croisée

- **Compteur sur le segment inactif.** Affiché seulement si un filtre commun est posé (corridor ou date). Sans corridor, le nombre est un total plateforme sans valeur informative.
- **Ligne complète dans l'état vide uniquement** : « 📦 5 colis cherchent un voyageur sur Lyon → Bamako › ». Le tap bascule en conservant corridor et date.
- **Coût réseau** : le compteur de l'autre mode part en `size=1`, on ne lit que `totalElements`. Requête légère, pas une seconde recherche.

### 4.6 Filtre « Pour mes trajets »

- Toggle dans la rangée et dans la sheet, envoie `matchingMyTrips=true`.
- Actif : header « Colis sur tes trajets · N trajets actifs », cartes portant le badge de score et la mention du trajet concerné, tri par compatibilité. Inactif : tri par date, comme aujourd'hui.
- **Aucun trajet actif** → chip désactivé (`opacity: 0.4`), tap affichant une explication et un CTA « Publier un trajet ». Le nombre de trajets actifs vient de `TripsSummaryCubit.activeTrips`, déjà disponible. Sans ce garde-fou, le filtre renvoie zéro sans raison visible.
- **Rôle voyageur retiré** (`isTraveler == false`, via `deactivateTravelerRole`) → le segment Colis reste visible mais son tap explique la situation et renvoie vers les réglages. On ne laisse jamais partir la requête, qui répondrait 403.

### 4.7 Suppressions

| Élément | Fichier |
|---|---|
| `HomeMapFocus.all` et `homeMapVisibility` | `home_map_focus.dart` |
| `HomeFocusFilter` (3 segments) | `widgets/home_focus_filter.dart` |
| Les deux onglets du carousel « Près de moi » | `home_screen.dart`, branche `showBothTypes` |
| Le gate `isTraveler` sur les chips de mode | `home_screen.dart:1364`, `:1438` |
| `ColisMatchScreen` et la route `/package-requests/match` | `colis_match_screen.dart`, `router.dart:1227` |
| `TripMatchingBloc` et son enregistrement DI | `trip_matching_bloc.dart`, `injection.dart` |

La cloche `package-match-alert` portée par `TripMatchingBloc` est reprise par `NotificationPrefsBloc` et affichée dans `notification_settings_screen.dart`, section « Matchs & enchères ». Elle est rappelée dans la sheet de filtres colis.

## 5. Analytics

| Event | Déclencheur | Propriétés |
|---|---|---|
| `home_search_mode_changed` | tap sur le segmented control | `mode` : `trips` / `parcels` |
| `home_cross_discovery_tapped` | tap sur la ligne de l'état vide | `from_mode`, `count` |
| `home_matching_trips_filter_toggled` | toggle « Pour mes trajets » | `active`, `active_trips` |

`home_colis_match_opened` est retiré : l'écran qu'il traçait disparaît. Les deux events portés par `TripMatchingBloc`, qui est supprimé, changent de point d'appel :

- `trip_matching_viewed` → émis par `PackageRequestSearchBloc` au chargement d'une recherche avec `matchingMyTrips=true` (propriété `count` conservée).
- `package_match_alert_toggled` → émis par `NotificationPrefsBloc` au basculement de la ligne dans les réglages (propriété `enabled` conservée).

Table du `CLAUDE.md` à mettre à jour dans la même PR.

## 6. Tests

**Back**
- `MatchingService` : déduplication d'une demande compatible avec deux trajets, meilleur score conservé.
- `PackageRequestController` : `matchingMyTrips=true` combiné à `departure` + `maxWeight`, tri par score décroissant, pagination cohérente sur deux pages.
- Aucun trajet actif → page vide, pas d'erreur.
- `matchingMyTrips` absent → réponse identique à l'existant (test de non-régression).

**Front**
- `home_search_filters_test.dart` : `toSearchParams`, `toPackageRequestQuery`, `activeCountFor`, conservation du corridor et de la date à la bascule, non-propagation de `weightMin` vers `maxWeight`.
- Widget : la bascule conserve le corridor, remplace les chips spécifiques, adapte le titre et les champs de la sheet.
- Widget : chip « Pour mes trajets » désactivé quand `activeTrips == 0`, et son tap n'émet aucune requête.
- Compteur du segment inactif absent tant qu'aucun filtre commun n'est posé.
- Tests existants de `homeMapVisibility` : supprimés avec la fonction, remplacés par les tests de `SearchMode`.

Couverture ≥ 90 % sur les deux repos, conformément au CLAUDE.md.

## 7. Séquencement

1. **Back** — `matchingMyTrips` sur `GET /package-requests`, déduplication, champs de réponse, tests. Livrable seul, sans effet sur le front existant.
2. **Front A** — `HomeSearchFilters`, `SearchMode`, extraction de la rangée de chips et de la sheet unifiée. Aucun changement visible tant que le sélecteur n'est pas branché.
3. **Front B** — sélecteur à deux modes, suppression du mode « Tout », découverte croisée.
4. **Front C** — filtre « Pour mes trajets », suppression de `ColisMatchScreen`, relogement de la cloche.

Le front B dépend du A. Le front C dépend du back étape 1 déployé.
