# Plan d'implémentation — hub Activités

**Spec :** `docs/superpowers/specs/2026-07-20-activites-hub-design.md`
**Branche :** `feature/activites-hub`

Sept étapes, ordonnées pour que chacune soit vérifiable seule. La couche données passe en premier : l'UI ne peut afficher de vrais compteurs qu'une fois les sources câblées.

---

## Étape 1 — Couche données : demandes reçues

**Pourquoi d'abord.** L'écran Demandes est le seul manque fonctionnel réel. Le backend expose déjà `GET /travelers/me/bids` (`TravelerStatsController.java:197`) ; il n'y a que du câblage client.

### 1.1 Datasource

`lib/features/matching/data/datasources/bid_remote_datasource.dart`

```dart
Future<TravelerBidsPage> getTravelerBids({
  String? status,
  String? tripId,
  String? q,
  int page = 0,
  int size = 20,
}) async {
  final response = await _apiClient.dio.get(
    '/travelers/me/bids',
    queryParameters: {
      if (status != null) 'status': status,
      if (tripId != null) 'tripId': tripId,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'size': size,
    },
  );
  return TravelerBidsPage.fromJson(response.data as Map<String, dynamic>);
}
```

Nouveau modèle `TravelerBidsPage` dans `data/models/traveler_bids_page.dart` : `List<BidModel> content`, `int totalElements`, `int page`, `bool isLast`. Le backend renvoie une `Page<BidResponse>` Spring — champs `content`, `totalElements`, `number`, `last`.

### 1.2 Repository

`bid_repository.dart` — passthrough, comme les méthodes voisines.

### 1.3 Bloc

`lib/features/matching/bloc/traveler_bids_bloc.dart` (+ `_event.dart`, `_state.dart`)

- Events : `TravelerBidsRequested({bool force})`, `TravelerBidsNextPageRequested()`, `TravelerBidsFilterChanged(TravelerBidFilter)`
- States sealed : `TravelerBidsInitial` / `Loading` / `Loaded(bids, totalElements, hasMore, filter)` / `Error(message)`
- `TravelerBidsLoaded` expose `int get pendingCount` — compte des statuts `PENDING` + `PAYMENT_ESCROWED`, la valeur affichée sur la tuile Demandes
- TTL de rafraîchissement calqué sur `BidBloc` (`bid_bloc.dart:218`) pour éviter les rechargements en boucle au changement d'onglet

`TravelerBidFilter` — enum `{ aTraiter, acceptees, terminees }`, mappé sur les groupes de statuts déjà définis dans `bid_list_filter_cubit.dart:10-18`. Réutiliser ces constantes plutôt que d'en redéclarer.

### 1.4 DI

`lib/core/di/injection.dart` — `registerFactory<TravelerBidsBloc>(...)` à côté des autres blocs matching (`:290-335`).

### 1.5 Tests

`test/features/matching/bloc/traveler_bids_bloc_test.dart` — chargement nominal, pagination, filtre, erreur réseau, calcul de `pendingCount`.

**Vérification :** `flutter test test/features/matching/bloc/traveler_bids_bloc_test.dart`

---

## Étape 2 — Couche données : statistiques par période

### 2.1 Modèle

`trips_summary_model.dart` — ajouter `kgSold`, `revenue`, `tripsPublished`, `parcelsSent`, `period`. Le `fromJson` lit les nouveaux champs **avec repli sur les anciens** :

```dart
kgSold: (json['kgSold'] as num?)?.toDouble()
     ?? (json['kgSoldThisMonth'] as num?)?.toDouble() ?? 0,
revenue: (json['revenue'] as num?)?.toDouble()
      ?? (json['revenueThisMonth'] as num?)?.toDouble() ?? 0,
```

C'est ce repli qui assure la dégradation gracieuse contre un backend non mis à jour (spec §5.2).

### 2.2 Datasource

`announcement_remote_datasource.dart:107` — `getTripsSummary({String period = '30d'})`, paramètre passé en `queryParameters`.

### 2.3 Cubit

`trips_summary_cubit.dart` — `load({String period = '30d'})`. Conserver le comportement existant : en erreur, émettre `hidden()` plutôt que de casser l'écran.

`lib/features/matching/bloc/stats_period_cubit.dart` — `enum StatsPeriod { sevenDays, thirtyDays, twelveMonths }` avec `String get apiValue` → `'7d'` / `'30d'` / `'12m'`, et `String get label` → `'7 jours'` / `'30 jours'` / `'12 mois'`. Défaut : `thirtyDays`.

### 2.4 Tests

`trips_summary_model_test.dart` — parsing avec anciens champs seuls, nouveaux champs seuls, les deux.
`stats_period_cubit_test.dart` — transitions et valeurs API.

**Vérification :** `flutter test test/features/matching/`

---

## Étape 3 — Widgets réutilisables

Le design system n'a aucune tuile KPI ; ces deux widgets comblent ce manque et restent dans la feature tant qu'ils n'ont qu'un consommateur.

### 3.1 `ActivityTile`

`lib/features/matching/presentation/widgets/activity_tile.dart`

Props : `IconData icon`, `Color iconColor`, `Color iconBackground`, `String value`, `String label`, `VoidCallback onTap`, `bool isLoading`, `bool hasError`, `bool showNotificationDot`.

Rendu : carte `DonyCard`, icône dans un conteneur arrondi, valeur en gros (`tabular figures`), libellé dessous. Chevron en haut à droite, ou pastille colorée si `showNotificationDot`. `isLoading` → shimmer sur la valeur seule. `hasError` → `—`, tuile toujours cliquable.

### 3.2 `StatTile`

`lib/features/matching/presentation/widgets/stat_tile.dart`

Props : `IconData icon`, `String label`, `String value`, `bool isLoading`. Largeur fixe (~128 px) pour le défilement horizontal.

### 3.3 Tests

`test/features/matching/presentation/widgets/activity_tile_test.dart` — valeur affichée, `onTap` déclenché, états loading / erreur, présence de la pastille.

**Vérification :** `flutter test test/features/matching/presentation/widgets/`

---

## Étape 4 — L'écran hub

`lib/features/matching/presentation/screens/activites_hub_screen.dart`

### 4.1 Providers

`MultiBlocProvider` :
- `BlocProvider.value(getIt<NegotiationListBloc>())` — singleton, déjà partagé
- `BlocProvider(create: (_) => getIt<TripsSummaryCubit>())`
- `BlocProvider(create: (_) => getIt<TravelerBidsBloc>())`
- `BlocProvider(create: (_) => getIt<BidBloc>())` — envois en cours
- `BlocProvider(create: (_) => getIt<StatsPeriodCubit>())`

### 4.2 Structure

`Scaffold` + `RefreshIndicator` + `CustomScrollView` :

1. Header — titre « Activités », icône recherche → `/tracking/search`
2. Ligne CTA — « Publier un trajet » (`/trips/create`), « Demande d'envoi » (gate KYC + wizard)
3. `DonySectionHeader('Activités')` + grille 2×2 de `ActivityTile`
4. `DonySectionHeader('Statistiques')` + `DonyChipGroup<StatsPeriod>` + `ListView` horizontal de `StatTile`
5. `DonySectionHeader('Autres')` + grille 2×1

### 4.3 Câblage des compteurs

| Tuile | Bloc écouté | Valeur |
|---|---|---|
| Trajets actifs | `TripsSummaryCubit` | `state.activeTrips` |
| Envois en cours | `BidBloc` | `bids.where((b) => kEnvoisEnCours.contains(b.status)).length` |
| Demandes | `TravelerBidsBloc` | `state.pendingCount` |
| Négociations | `NegotiationListBloc` | `state.activeCount` |

Un `BlocBuilder` par tuile — pas un `BlocBuilder` global : une erreur sur les stats ne doit pas vider les trois autres tuiles.

### 4.4 Action « Demande d'envoi »

Extraire `envoyer_hub_screen.dart:304-322` (gate KYC via `KycRequiredBottomSheet` puis `PackageRequestCreateWizard.show`) vers une fonction partagée `Future<void> openPackageRequestWizard(BuildContext)` dans `lib/features/package_request/presentation/package_request_actions.dart`, appelée par le hub **et** par l'écran Envoyer. Pas de duplication.

### 4.5 Refresh

`didChangeDependencies` + `EnvoisRefreshNotifier` (`main_shell.dart:46-73`, déjà déclenché sur l'index 1) → recharger les quatre blocs. Pull-to-refresh identique.

### 4.6 Changement de période

`StatsPeriodCubit` → `listener` qui appelle `TripsSummaryCubit.load(period: p.apiValue)`.

### 4.7 Analytics

Déclarer dans `AnalyticsEvents` : `activitesHubTripsOpened`, `activitesHubEnvoisOpened`, `activitesHubDemandesOpened`, `activitesHubNegotiationsOpened`, `activitesHubTripCreateOpened`, `activitesHubRequestCreateOpened`, `activitesHubStatsPeriodChanged`. Un `logEvent` par tuile et par CTA. Le `$screen` est automatique via `PosthogObserver`.

**Vérification :** lancement de l'app, l'onglet affiche le hub avec des compteurs réels.

---

## Étape 5 — L'écran Demandes reçues

`lib/features/matching/presentation/screens/demandes_recues_screen.dart`

- `AppBar` « Demandes », `RefreshIndicator`
- `DonyChipGroup<TravelerBidFilter>` — À traiter / Acceptées / Terminées, avec compteurs
- Liste de cartes réutilisant les widgets de `pending_bids_screen.dart` (`BidCard`, boutons Accepter / Refuser)
- Accepter / refuser via `BidAcceptanceBloc` (`injection.dart:328`) — flux commission déjà existant, ne pas réimplémenter
- Pagination — `TravelerBidsNextPageRequested` sur atteinte du bas
- `DonyEmptyState` par filtre
- Tap sur une carte → `/bids/:bidId` (`router.dart:332`)

**Vérification :** `flutter test test/features/matching/presentation/screens/demandes_recues_screen_test.dart`

---

## Étape 6 — Routes et retrait de l'ancien dispatch

### 6.1 `lib/app/router.dart`

- Branche 1 du `StatefulShellRoute` (`:1178-1186`) → `ActivitesHubScreen` au lieu de `MatchingManagementScreen`
- Nouvelle route `/envois` → `ShipmentListScreen()` (le widget existe, `shipment_list_screen.dart:24`, sans route jusqu'ici)
- Nouvelle route `/demandes` → `DemandesRecuesScreen()` avec son `BlocProvider`

### 6.2 Suppressions

- `lib/features/matching/presentation/screens/matching_management_screen.dart`
- `lib/features/matching/presentation/annonces_layout.dart`
- Leurs tests

Vérifier par `grep` qu'aucune référence ne subsiste avant suppression.

### 6.3 `EnvoyerHubScreen` — retrait des tabs

Supprimer `_EnvoyerTabsView`, `_EnvoyerSegmented`, `_SlidingSegmented`, `_SegLabel`, le `TabController` et la logique de badges (`:73-250`, `:458-620`). Conserver le header et « + Nouveau ». Le corps devient directement `ShipmentListBody`.

`MyPackageRequestsBody` reste atteignable par `/package-requests/me` — vérifier que cette route fonctionne toujours.

**Vérification :** `flutter analyze` sans erreur, aucune référence morte.

---

## Étape 7 — Vérification complète

```bash
flutter analyze
dart format lib/ test/
flutter test
```

**Passe manuelle** — chaque élément interactif de la spec §4 mène à un écran fonctionnel :

- [ ] Publier un trajet → formulaire de création
- [ ] Demande d'envoi → wizard (avec gate KYC si non vérifié)
- [ ] Recherche → écran de recherche
- [ ] Trajets actifs → liste des trajets
- [ ] Envois en cours → liste des envois
- [ ] Demandes → demandes reçues, tous trajets confondus
- [ ] Négociations → liste des négociations
- [ ] 7 jours / 30 jours / 12 mois → les valeurs changent
- [ ] Historique complet → historique
- [ ] Aide & support → FAQ
- [ ] Onglet Envoyer → plus de tab Demandes

---

## Hors périmètre — PR backend séparée

Repo `dony-back`, branche dédiée :

- `TripsSummaryController` — `@RequestParam(defaultValue = "30d") String period`
- `TripsSummaryService.computeSummary(traveler, period)` — résolution des bornes selon `7d` / `30d` / `12m`, ajout de `tripsPublished` et `parcelsSent`
- Clé de cache incluant la période (`CacheConfig.java:37`)
- **Conserver** `kgSoldThisMonth` et `revenueThisMonth` dans la réponse — rétrocompatibilité avec les clients déployés

Sans cette PR, l'app fonctionne : les trois chips affichent les chiffres du mois courant.

---

## Ordre de commit

1. `feat(matching): câblage GET /travelers/me/bids + TravelerBidsBloc`
2. `feat(matching): statistiques filtrables par période`
3. `feat(matching): widgets ActivityTile et StatTile`
4. `feat(matching): écran hub Activités`
5. `feat(matching): écran Demandes reçues`
6. `refactor(matching): hub Activités unique, retrait du dispatch par rôle`
7. `test(matching): couverture du hub Activités`
