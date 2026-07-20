# Refonte de l'onglet Activités — hub unifié double rôle

**Date :** 2026-07-20
**Branche :** `feature/activites-hub`
**Statut :** spec validée, prête pour le plan d'implémentation

---

## 1. Contexte et problème

Le refacto en cours donne à **tout utilisateur les deux rôles en permanence** (expéditeur *et* transporteur). L'onglet Activités actuel contredit ce modèle : il choisit une vue exclusive selon le profil.

Aujourd'hui, `lib/app/router.dart:1178` monte `MatchingManagementScreen`, qui dispatche via `annoncesLayoutFor()` (`lib/features/matching/presentation/annonces_layout.dart:17`) :

| Profil | Vue montée |
|---|---|
| `senderOnly` (non-voyageur) | `EnvoyerHubScreen` — aucun accès aux trajets |
| `occasionalTraveler` | `EnvoyerHubScreen` + pill « Mes trajets » |
| `proTraveler` | `AnnouncementListScreen` (« Mes trajets ») + pill « Envoyer » |

Trois conséquences :

1. **Un rôle est toujours caché.** Un expéditeur pur ne voit jamais ses trajets ; un voyageur pro atterrit sur « Mes trajets » et doit ouvrir un écran secondaire pour ses envois.
2. **Les demandes et négociations sont enterrées.** Les demandes reçues ne sont consultables que trajet par trajet (`/announcements/:id/bids`) — il n'existe aucune vue globale. Les négociations vivent sous `/negotiations`, atteignable seulement depuis le profil.
3. **L'onglet mélange navigation et contenu.** Il ouvre directement sur une liste longue, sans donner l'état global de l'activité.

Le code anticipe déjà ce changement — `matching_management_screen.dart:22-24` :

> *« ActiveRoleCubit n'est intentionnellement PAS lu ici (cf. Phase 2 — il sera retiré de ce tab à terme). »*

Cette spec **est** la Phase 2.

---

## 2. Objectif

Transformer l'onglet Activités en **hub de navigation unique, identique pour tous les utilisateurs**, qui :

- montre en un coup d'œil l'état des quatre domaines d'activité (trajets, envois, demandes, négociations) ;
- donne un accès direct aux deux actions de création (publier un trajet, demander un envoi) ;
- expose des statistiques d'activité filtrables par période ;
- **route chaque élément vers un écran réellement fonctionnel** — en câblant l'existant quand il existe, en l'implémentant quand il manque.

Aucun élément décoratif : chaque tuile, chaque bouton, chaque chip est cliquable et mène quelque part.

---

## 3. Architecture de l'écran

```
Activités                                    [🔍]
┌─────────────────────┬─────────────────────┐
│ Publier un trajet   │ Demande d'envoi     │   ← 2 CTA
└─────────────────────┴─────────────────────┘

Activités
┌──────────────────┐ ┌──────────────────┐
│ ✈  6          ›  │ │ 📦  3         ›  │
│ Trajets actifs   │ │ Envois en cours  │
└──────────────────┘ └──────────────────┘
┌──────────────────┐ ┌──────────────────┐
│ 🔔  4         ●  │ │ ⇄  2          ●  │
│ Demandes         │ │ Négociations     │
└──────────────────┘ └──────────────────┘

Statistiques
( 7 jours ) (30 jours) ( 12 mois )
┌────────┐┌────────┐┌────────┐┌────────┐  → scroll horizontal
│ Revenus││Kg vendus││Trajets ││ Envois │
└────────┘└────────┘└────────┘└────────┘

Autres
┌──────────────────┐ ┌──────────────────┐
│ Historique       │ │ Aide & support   │
└──────────────────┘ └──────────────────┘
```

**Choix de disposition** — grille fixe 2×2 pour les activités (scan immédiat des quatre domaines, aucune information hors écran), scroll horizontal réservé aux statistiques (comparaison de métriques sur une période, où le hors-écran est acceptable).

**Ordre des tuiles** — Trajets et Envois d'abord (les objets que l'utilisateur possède), puis Demandes et Négociations (les sollicitations qu'il reçoit). Les deux dernières portent une pastille de notification plutôt qu'un chevron, car elles appellent une action.

---

## 4. Câblage — destination de chaque élément

### 4.1 Boutons d'action

| Élément | Destination | État |
|---|---|---|
| **Publier un trajet** | `context.push('/trips/create')` (`router.dart:484`) | existe |
| **Demande d'envoi** | Gate KYC puis `PackageRequestCreateWizard.show()` — même logique que `envoyer_hub_screen.dart:304-322` | existe, à extraire |
| **Recherche** (icône header) | `context.push('/tracking/search')` (`router.dart:763`) | existe |

### 4.2 Tuiles d'activité

| Tuile | Compteur — source | Destination | État |
|---|---|---|---|
| **Trajets actifs** | `TripsSummaryCubit.activeTrips` (`trips_summary_cubit.dart:31`) | `/announcements/trips` (`router.dart:510`) | existe |
| **Envois en cours** | `BidBloc` filtré par `kEnvoisEnCours` (`shipment_filter_cubit.dart:16`) | **`/envois`** → `ShipmentListScreen` | widget existe, **route à créer** |
| **Demandes** | `TravelerBidsBloc` — statuts `PENDING` + `PAYMENT_ESCROWED` | **`/demandes`** → `DemandesRecuesScreen` | **à implémenter** |
| **Négociations** | `NegotiationListBloc.activeCount` (`negotiation_list_bloc.dart:50`) | `/negotiations` (`router.dart:1269`) | existe |

### 4.3 Section Autres

| Tuile | Destination | État |
|---|---|---|
| **Historique complet** | `/profile/shipments/history` (`router.dart:819`) | existe |
| **Aide & support** | `/profile/help/faq` (`router.dart:808`) | existe |

---

## 5. Les deux manques à combler

### 5.1 Écran « Demandes » global

**Le problème.** Les demandes reçues ne sont consultables que par trajet (`BidListScreen`, route `/announcements/:id/bids`). `getMyBids()` → `GET /bids/me` ne renvoie **que les bids que j'ai créés en tant qu'expéditeur** (backend : `BidService.getMyBids()` → `findBySenderId`). Le seul contournement en production est une boucle N+1 (`scan_hub_cubit.dart:79-82`).

**La solution.** Le backend expose **déjà** l'endpoint nécessaire, jamais câblé côté Flutter :

```
GET /travelers/me/bids?status=&tripId=&q=&page=0&size=20
→ Page<BidResponse>
```
`TravelerStatsController.java:197-206` → `BidService.getTravelerBids()` — paginé, filtrable par statut, par trajet et par recherche texte.

Le travail est donc du **câblage client**, pas du backend :

- `BidRemoteDatasource.getTravelerBids({status, tripId, q, page, size})`
- `BidRepository.getTravelerBids(...)`
- `TravelerBidsBloc` — liste paginée + compteur des demandes à traiter
- `DemandesRecuesScreen` — liste avec chips de filtre (À traiter / Acceptées / Terminées), réutilisant `BidCard` et les widgets de `pending_bids_screen.dart`
- Actions accepter / refuser : réutiliser `BidAcceptanceBloc` (`injection.dart:328`), déjà branché sur ces flux

**Effet de bord positif.** `scan_hub_cubit.dart` peut abandonner sa boucle N+1 au profit d'un seul appel. Hors périmètre de cette spec, mais à noter.

### 5.2 Statistiques par période

**Le problème.** `GET /travelers/me/trips-summary` renvoie `{activeTrips, kgSoldThisMonth, revenueThisMonth}` — le mois courant est **codé en dur côté serveur** (`TripsSummaryService.java:39-63`, `YearMonth.now()`), sans paramètre de période.

**Pourquoi ne pas agréger côté client.** Trois obstacles qui rendraient les chiffres faux :
1. `BidModel` n'a **ni `completedAt` ni `deliveredAt`** — seulement `createdAt`, `updatedAt`, `departureAt`. Le backend borne les revenus sur la date de libération de l'escrow ; aucun proxy client n'est équivalent.
2. `weightKg` est **null en mode GRID** (`bid_model.dart:51`) — sous-comptage systématique des kg.
3. Les revenus viennent des paiements `RELEASED` (`sumCapturedRevenueForTraveler`), une table à laquelle le client n'a pas accès.

Agréger côté client produirait des chiffres qui contredisent ceux déjà affichés ailleurs dans l'app.

**La solution.** Étendre l'endpoint existant avec un paramètre de période **additif et rétrocompatible** :

```
GET /travelers/me/trips-summary?period=7d|30d|12m     (défaut : 30d)
→ {activeTrips, kgSold, revenue, tripsPublished, parcelsSent, period}
```

- Côté backend (`dony-back`, PR séparée) : `@RequestParam(defaultValue="30d") String period`, résolution des bornes, clé de cache incluant la période. Les champs `kgSoldThisMonth` / `revenueThisMonth` sont **conservés** en plus des nouveaux, pour ne casser aucun client déployé.
- Côté Flutter : `getTripsSummary({String period})`, `TripsSummaryModel` étendu avec `tripsPublished` et `parcelsSent`, `TripsSummaryCubit.load(period)`.

**Dégradation gracieuse.** Si l'app tourne contre un backend non encore mis à jour, Spring ignore le paramètre inconnu et renvoie les chiffres du mois courant. Les trois chips restent alors sélectionnables mais affichent la même valeur — pas de crash, pas d'écran vide. Le modèle Flutter lit les nouveaux champs avec un repli sur les anciens (`kgSold ?? kgSoldThisMonth`).

---

## 6. Ce qui est supprimé

| Élément | Raison |
|---|---|
| `MatchingManagementScreen` + son test | Remplacé par `ActivitesHubScreen` — le dispatch par rôle disparaît |
| `annonces_layout.dart` (`AnnoncesLayout`, `annoncesLayoutFor`) + son test | La logique de layout par rôle est exactement ce que le refacto élimine |
| Tab interne **« Demandes »** de `EnvoyerHubScreen` | Les demandes remontent au niveau du hub. `EnvoyerHubScreen` devient une liste d'envois simple, sans segmented control — conformément à la maquette validée |

**Conséquences sur `EnvoyerHubScreen`.** Suppression de `_EnvoyerTabsView`, `_EnvoyerSegmented`, `_SlidingSegmented`, `_SegLabel`, du `TabController` et de la logique de badges associée (`envoyer_hub_screen.dart:73-250, 458-620`). Le header et le bouton « + Nouveau » sont conservés. `MyPackageRequestsBody` reste accessible via sa route `/package-requests/me`.

---

## 7. Découpage technique

### Nouveaux fichiers

```
lib/features/matching/presentation/screens/activites_hub_screen.dart
lib/features/matching/presentation/screens/demandes_recues_screen.dart
lib/features/matching/presentation/widgets/activity_tile.dart      # tuile 2×2
lib/features/matching/presentation/widgets/stat_tile.dart          # carte stat scrollable
lib/features/matching/bloc/traveler_bids_bloc.dart
lib/features/matching/bloc/traveler_bids_event.dart
lib/features/matching/bloc/traveler_bids_state.dart
lib/features/matching/bloc/stats_period_cubit.dart
```

### Fichiers modifiés

```
lib/app/router.dart                          # branche 1 → ActivitesHubScreen ; routes /envois, /demandes
lib/features/matching/data/datasources/bid_remote_datasource.dart      # getTravelerBids
lib/features/matching/data/repositories/bid_repository.dart            # getTravelerBids
lib/features/matching/data/datasources/announcement_remote_datasource.dart  # period
lib/features/matching/data/models/trips_summary_model.dart             # champs période
lib/features/matching/bloc/trips_summary_cubit.dart                    # load(period)
lib/features/package_request/.../sender/envoyer_hub_screen.dart        # retrait des tabs
lib/core/di/injection.dart                                             # TravelerBidsBloc, StatsPeriodCubit
lib/core/services/analytics_events.dart                                # events du hub
```

**Placement.** Le hub vit dans `features/matching/presentation/screens/` — c'est déjà là que réside `MatchingManagementScreen`, qui monte des écrans de `package_request`. Le précédent est établi et la règle « feature = `bloc/` + `data/` + `presentation/` » est respectée.

### Conventions respectées

- **flutter_bloc** exclusivement, jamais `setState` — events suffixés `Requested`, états sealed
- **GoRouter** — toutes les routes dans `lib/app/router.dart`, `context.push` / `context.go`
- **GetIt** — `registerFactory` pour les blocs, `registerLazySingleton` pour repos et datasources
- **Design system** — `DonyCard`, `DonyChip`, `DonySectionHeader`, `DonyEmptyState`, tokens `DonySpacing` ; les deux nouveaux widgets (`ActivityTile`, `StatTile`) comblent un manque réel — le design system n'a aucune tuile KPI
- **Analytics PostHog** — tout nouvel écran et toute action métier trackés, noms déclarés dans `AnalyticsEvents`

---

## 8. États et cas limites

| Cas | Comportement |
|---|---|
| Compteurs en cours de chargement | Tuile affichée avec un shimmer sur la valeur ; le libellé et l'icône restent visibles |
| Compteur en erreur réseau | Tuile affichée avec `—` à la place du nombre ; la tuile **reste cliquable** (l'écran cible gère sa propre erreur) |
| Compteur à zéro | `0` affiché, tuile cliquable, l'écran cible affiche son `DonyEmptyState` |
| `trips-summary` en 403 (`traveler-required`) | Les stats voyageur affichent `—` ; les tuiles Envois et Demandes restent alimentées |
| Aucune activité (nouvel utilisateur) | Les quatre tuiles à `0`, les deux CTA restent l'action principale de l'écran |
| Pull-to-refresh | Recharge en parallèle : `TripsSummaryCubit`, `BidBloc`, `TravelerBidsBloc`, `NegotiationListBloc` |
| Retour sur l'onglet | `EnvoisRefreshNotifier` (`main_shell.dart:46-73`) déclenche déjà un refresh sur l'index 1 — à brancher sur le hub |

---

## 9. Tests

| Niveau | Couverture |
|---|---|
| **Unitaire** | `TravelerBidsBloc` (chargement, pagination, filtre par statut, erreur) ; `StatsPeriodCubit` ; `TripsSummaryCubit.load(period)` ; `TripsSummaryModel.fromJson` avec anciens *et* nouveaux champs |
| **Widget** | `ActivitesHubScreen` — les 4 tuiles affichent les bons compteurs, chaque tuile pousse la bonne route, les 2 CTA poussent la bonne route, états loading / erreur / zéro ; `ActivityTile` et `StatTile` isolément |
| **Widget** | `DemandesRecuesScreen` — liste, chips de filtre, état vide, accepter / refuser |
| **Régression** | `EnvoyerHubScreen` sans tabs — le segmented control a disparu, la liste d'envois s'affiche toujours |
| **Navigation** | Chaque destination citée en §4 est atteignable depuis le hub (test de router) |

Les tests miroir de l'arborescence `lib/` dans `test/`, conformément aux conventions.

---

## 10. Critères d'acceptation

1. L'onglet Activités affiche le même hub pour **tout** utilisateur, quel que soit son profil — plus aucun dispatch par rôle.
2. Les quatre tuiles affichent des compteurs réels issus des blocs, pas des valeurs codées en dur.
3. **Chaque** élément interactif de l'écran mène à un écran fonctionnel : 2 CTA, 4 tuiles, 3 chips de période, 2 tuiles Autres, 1 recherche.
4. L'écran « Demandes » liste les demandes reçues sur **tous** les trajets en un seul appel réseau, et permet de les accepter ou refuser.
5. Les chips de période changent effectivement les valeurs statistiques affichées.
6. Le tab « Demandes » a disparu de l'écran Envoyer.
7. `flutter analyze` sans erreur, `flutter test` au vert.

---

## 11. Décisions ouvertes

**Statistiques et backend.** Le paramètre `period` demande une modification de `dony-back`, livrée en **PR séparée** sur ce repo. Tant qu'elle n'est pas déployée, les trois chips renvoient les chiffres du mois courant (dégradation gracieuse décrite en §5.2). Si cette dépendance backend n'est pas souhaitée, l'alternative est de réduire la section Statistiques aux seules métriques disponibles sans période — mais le filtre perdrait alors sa raison d'être.
