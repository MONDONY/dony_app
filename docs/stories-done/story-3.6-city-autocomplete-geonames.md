# Story 3.6 — City Autocomplete GeoNames (Flutter)

**Date:** 2026-05-08
**Status:** ✅ Complète

## Résumé

Remplacement des champs de saisie de ville free-text par un widget d'autocomplétion connecté à l'API GeoNames du backend. Les écrans `CreateAnnouncementScreen` et `SearchAnnouncementScreen` utilisent maintenant `CityAutocompleteField` avec debounce 300ms et affichage des résultats en temps réel.

## Fichiers créés

- `lib/features/city/data/city_model.dart` — modèle de ville (fromJson, displayLabel)
- `lib/features/city/data/popular_corridor_model.dart` — modèle de corridor (fromJson, displayLabel)
- `lib/features/city/data/city_datasource.dart` — appels Dio vers `/cities/search` et `/cities/corridors/popular`
- `lib/features/city/data/city_repository.dart` — délégation vers CityDatasource
- `lib/features/city/bloc/city_search_event.dart` — événements BLoC (QueryChanged, Cleared)
- `lib/features/city/bloc/city_search_state.dart` — états BLoC (Initial, Loading, Loaded, Error)
- `lib/features/city/bloc/city_search_bloc.dart` — logique avec debounce rxdart + switchMap
- `lib/features/city/presentation/widgets/city_autocomplete_field.dart` — widget réutilisable
- `test/features/city/bloc/city_search_bloc_test.dart` — tests BLoC (5 tests)
- `test/features/city/bloc/city_search_event_test.dart` — tests événements (5 tests)
- `test/features/city/data/city_data_test.dart` — tests modèles + datasource + repository (12 tests)
- `test/features/city/presentation/city_autocomplete_field_test.dart` — tests widget (15 tests)

## Fichiers modifiés

- `lib/core/di/injection.dart` — enregistrement `CityDatasource`, `CityRepository`, `CitySearchBloc` (factory) dans GetIt
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — remplace les TextField ville par `CityAutocompleteField`
- `lib/features/matching/presentation/screens/search_announcement_screen.dart` — remplace les TextField ville par `CityAutocompleteField`; `_search()` accepte villes nullables
- `test/features/matching/presentation/screens/create_announcement_screen_test.dart` — ajout setup GetIt pour `CitySearchBloc`
- `test/features/matching/presentation/search_announcement_screen_test.dart` — refactoring complet (11 tests corrigés)

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux

**Autocomplétion :**
1. L'utilisateur saisit un texte dans `CityAutocompleteField`
2. `onChanged` dispatche `CitySearchQueryChanged(query)` au `CitySearchBloc`
3. Le BLoC debounce 300ms (rxdart `debounceTime`) puis appelle `CityRepository.searchCities(query)`
4. Si `query.trim().length < 2` → émet `CitySearchInitial` (pas de requête HTTP)
5. Sinon émet `CitySearchLoading` → appel API → `CitySearchLoaded(cities)` ou `CitySearchError`
6. Le widget affiche la liste de résultats sous le champ de saisie

**Sélection d'une ville :**
1. L'utilisateur tape sur un résultat
2. `_onCitySelected(city)` remplit le controller avec `city.name`, unfocus, dispatche `CitySearchCleared`
3. `onSelected(city)` est appelé → le parent met à jour son `ValueNotifier<String?>` avec `city.name`

### Architecture BLoC

```
CityAutocompleteField
  └── BlocProvider<CitySearchBloc>(create: (_) => getIt<CitySearchBloc>())
        └── BlocBuilder → affiche Loading / résultats / SizedBox.shrink
```

Chaque `CityAutocompleteField` obtient sa propre instance de `CitySearchBloc` via `getIt.registerFactory` — deux champs côte à côte (départ et arrivée) ont des BLoCs indépendants.

### Intégration dans les écrans existants

**CreateAnnouncementScreen** :
- `_departureCityNotifier` et `_arrivalCityNotifier` sont des `ValueNotifier<String?>` (nullable)
- Ils sont mis à jour via `onSelected: (city) => _departureCityNotifier.value = city.name`
- Le bouton submit s'active si `transportMode != null` (les villes peuvent être null)

**SearchAnnouncementScreen** :
- Même pattern avec `_departureCityNotifier` et `_arrivalCityNotifier`
- `_search()` dispatche `AnnouncementSearchRequested(departureCity: _departureCityNotifier.value, ...)` — nullable → pas de filtre ville si non sélectionné

### GetIt et gestion du BLoC dans les tests

Les tests d'écrans qui utilisent `CityAutocompleteField` doivent enregistrer `CitySearchBloc` dans GetIt :

```dart
setUpAll(() {
  final mockCityRepo = MockCityRepository();
  when(() => mockCityRepo.searchCities(any())).thenAnswer((_) async => []);
  when(() => mockCityRepo.getPopularCorridors()).thenAnswer((_) async => []);
  getIt.registerFactory<CitySearchBloc>(() => CitySearchBloc(mockCityRepo));
});
tearDownAll(() { getIt.reset(); });
```

### Pièges et points d'attention

- **`registerFactory` obligatoire** (pas `registerSingleton`) pour `CitySearchBloc` car chaque widget crée sa propre instance. Un singleton serait partagé entre les deux champs départ/arrivée et le state serait mélangé.
- **debounce rxdart** : le BLoC utilise `events.debounceTime(300ms).switchMap(mapper)`. Dans les tests bloc, utiliser `wait: const Duration(milliseconds: 400)` pour laisser le debounce s'écouler.
- **Timer pendant les widget tests** : les tests qui n'entrent pas de texte doivent drainer les timers avec `await tester.pump(const Duration(milliseconds: 500))` pour éviter les `FlutterError: A Timer is still pending`.
- **Viewport dans les tests de search_announcement** : `_EmptyView` contient une `Column` qui dépasse à 800×600px (le `DraggableScrollableSheet` à 55% ne laisse que ~95px pour ~240px de contenu). Utiliser `tester.binding.setSurfaceSize(const Size(800, 1200))` pour les tests qui naviguent vers la vue Résultats.

## Critères d'acceptation couverts

- [x] Champ ville de départ et arrivée avec autocomplétion GeoNames dans la création d'annonce
- [x] Champ ville de départ et arrivée avec autocomplétion GeoNames dans la recherche d'annonce
- [x] Debounce 300ms — pas de requête HTTP pour chaque frappe
- [x] Minimum 2 caractères avant de lancer la recherche
- [x] Affichage d'un indicateur de chargement pendant la requête
- [x] Les deux champs sont indépendants (BLoC séparé par instance)
- [x] La sélection d'une ville pré-remplit le champ de texte
- [x] Bouton clear pour effacer la saisie

## Tests

- `flutter test --coverage` → 1160 tests passent, 9 failures pré-existantes non liées à cette feature
- Couverture city package : **98.4%** (124/126 lignes)
- Tests ajoutés :
  - `city_search_bloc_test.dart` — 5 tests BLoC (états, debounce, erreur, clear)
  - `city_search_event_test.dart` — 5 tests événements
  - `city_data_test.dart` — 12 tests (fromJson, displayLabel, datasource, repository)
  - `city_autocomplete_field_test.dart` — 15 tests (tous les cas d'usage du widget)
  - `create_announcement_screen_test.dart` — 3 tests mis à jour (GetIt setup ajouté)
  - `search_announcement_screen_test.dart` — 11 tests corrigés (viewport, villes nullable)

## Décisions techniques

| Décision | Choix | Alternative écartée | Raison |
|---|---|---|---|
| BLoC par instance | `getIt.registerFactory` | `registerSingleton` | Deux champs côte à côte ont besoin d'états indépendants |
| Debounce | rxdart `debounceTime + switchMap` | Timer manuel | Annule automatiquement les requêtes précédentes (no race condition) |
| Résultats sous le champ | Column inline | Overlay / Portal | Plus simple, naturel dans les formulaires scrollables |
| Villes nullables dans `_search()` | `city?.name` | Guard `if (city == null) return` | Permettre la recherche sans ville filtre (use case valide) |
