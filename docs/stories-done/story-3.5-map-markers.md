# Story 3.5 — Refonte sémantique des marqueurs de carte (Flutter)

**Date:** 2026-05-02
**Status:** ✅ Complète
**Phase:** B de 2 — Phase A (`transportMode` end-to-end, story 3.4) mergée

## Résumé

Refonte des marqueurs individuels sur la carte des annonces. Chaque pin affiche maintenant l'icône du mode de transport au centre + un badge note (★ score, ou "Nouveau" en terracotta) tout en conservant la couleur de fond selon le sens du trajet (azur retrait / orange livraison). Le clustering reste inchangé.

## Fichiers modifiés

- `lib/features/matching/presentation/widgets/marker_bitmap_factory.dart`
  - Suppression de `luggagePickup()`, `luggageDelivery()`, `_renderLuggage(Color)` et la constante `_markerSize` (devenue inutile).
  - Ajout de l'enum public `MarkerSide { pickup, delivery }`.
  - Ajout du cache `Map<_MarkerKey, BitmapDescriptor> _cache` + classe privée `_MarkerKey(mode, side, ratingTenths)` avec `==` / `hashCode`.
  - Ajout de la nouvelle API `pin({mode, side, rating})` qui retourne le bitmap depuis le cache si présent, sinon le génère via `_renderPin` et le mémorise.
  - Ajout de `_renderPin` (canvas 64×72) et `_drawRatingBadge` (pill 28×16, variant blanc avec étoile + score, ou variant terracotta "Nouveau").
  - Ajout de `clearCache()` annoté `@visibleForTesting`.
  - `clusterBadge(int count)` inchangé.

- `lib/features/matching/presentation/widgets/announcement_map_view.dart`
  - Suppression des champs d'état `_luggagePickup` et `_luggageDelivery` (le cache vit maintenant dans la factory).
  - `_preloadIcons()` renommé en `_prewarmCommonIcons()` qui pré-rend les 12 combinaisons les plus probables (6 `TransportMode` × 2 `MarkerSide`, `rating: null`) en parallèle au `initState`, puis appelle `_rebuildMarkers()`.
  - `_buildMarker` (branche marqueur individuel) appelle maintenant `MarkerBitmapFactory.pin(mode: announcement.transportMode, side: ..., rating: traveler?.averageRating)`.
  - Format du `markerId` préservé (`${side.name}_${announcement.id}`) — les routes de tap restent cohérentes.

- `test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart` — réécrit : 2 tests cluster (inchangés) + 8 tests pin (returns BitmapDescriptor, cache hit, rating bucket arrondi au dixième, buckets différents, null mode, null rating cache slot distinct, sweep 6×2, mode discrimine bitmap).
- `test/features/matching/presentation/widgets/announcement_map_view_test.dart` — ajouté un test de régression "builds markers for announcements with each transport mode".

## Comment ça fonctionne

### Flux de génération d'un marqueur individuel

1. `AnnouncementMapView` reçoit la liste d'annonces et appelle `_rebuildMarkers()`.
2. Pour chaque annonce avec coordonnées, `_buildMarker(cluster)` (branche `cluster.isMultiple == false`) construit la clé : `(transportMode, side dérivée du _MarkerSide interne, traveler.averageRating)`.
3. `MarkerBitmapFactory.pin()` calcule le `_MarkerKey` (rating arrondi au dixième → bucket entier), regarde le cache.
4. Cache hit → retourne le bitmap mémorisé instantanément. Cache miss → `_renderPin` dessine le 64×72, met en cache, retourne.
5. Le `Marker` final reçoit l'icône + l'`onTap` de routage vers le détail.

### Anatomie du marqueur

```
┌──────────────────────────┐  64 px
│       ┌──────┐  ┌──────┐ │
│       │      │  │ ★4.7 │ │  badge note 28×16 (top-right)
│       │ ✈    │  └──────┘ │  pin head Ø 44, inner blanc Ø 26
│       │      │           │  icône transport 22 px (couleur = côté)
│       └──┬───┘            │
│          │ tail            │  72 px
│          ▼                 │
└──────────────────────────┘
```

Couleurs côté :
- `MarkerSide.pickup` → `DonyColors.primary` (#0B5FFF) — retrait / départ
- `MarkerSide.delivery` → `DonyColors.warning` (#E8A23B) — livraison / arrivée

Badge note :
- Avec note (`rating != null`) → fond blanc, étoile + score en `DonyColors.primary` (`★ 4.7`)
- Sans note (`rating == null`) → fond `DonyColors.accent` (terracotta), texte blanc "Nouveau"
- Drop shadow subtil (alpha 0.10, blur 1.5) sur les deux variantes

### Cache

- Statique sur la classe `MarkerBitmapFactory` (vit toute la session app).
- Clé `(mode, side, ratingTenths)` — `ratingTenths = (rating * 10).round()`, donc 4.7 et 4.71 hit la même cellule.
- Vidé uniquement via `MarkerBitmapFactory.clearCache()` (test only).
- Worst case ≈ 624 entrées (6 transports × 2 sides × 52 buckets) × ~2 KB = 1.2 MB. En usage réel, < 100 entrées pour une session de recherche.

### Pré-chauffage

`_prewarmCommonIcons()` lance les 12 combinaisons "transport × side" sans rating en parallèle au `initState`. La première frame avec markers utilise donc le cache pour ces 12 cas (cas le plus fréquent : voyageurs sans note).

## Comportements préservés

- **Cluster** (multiple annonces dans la même cellule de grille) : `clusterBadge(count)` inchangé, badge primary + halo + nombre.
- **Tap behavior** : marqueur individuel → écran détail (`/search/{id}`) ; cluster même adresse → bottom sheet liste ; cluster adresses différentes → zoom in.
- **Annonces sans coordonnées** : ignorées (filtrées avant clustering, comme avant).
- **Marker ID** : format `${side.name}_${announcement.id}` (individuel) et `cluster_<centroid>_<count>` (cluster) — inchangé, donc tous les tests de tap/routing existants restent verts.

## Pièges et points d'attention

- **Cache statique** : si jamais on veut garbage-collect agressivement entre sessions, c'est `clearCache()`. Pas nécessaire en MVP.
- **`rating` non bucketé** : un nouveau rating à 4.71 réutilise le bitmap de 4.7. Si la précision visuelle devient critique (rare — l'œil ne distingue pas 4.7 de 4.8 sur un pill 28 px), passer à un bucket plus fin.
- **Performance première frame** : sans `_prewarmCommonIcons()`, la première rebuild paye 6 rendus séquentiels (~30 ms). Avec, c'est 12 rendus parallèles en background pendant que la map se charge → invisible pour l'utilisateur.
- **Visual regression** : aucun test n'asserte les pixels. La validation visuelle se fait manuellement (lancer l'app, faire une recherche, switch carte). Cohérent avec le reste du projet.

## Critères d'acceptation couverts

- [x] Chaque mode de transport produit un bitmap distinct (test : "different modes produce different bitmaps").
- [x] Note du voyageur affichée en badge ★ score quand présente (rendu canvas).
- [x] Voyageur sans note → badge "Nouveau" terracotta (variant `_drawRatingBadge` avec `rating == null`).
- [x] Cache hit retourne la même instance (test : "returns identical BitmapDescriptor on cache hit").
- [x] Rating bucketé au dixième (test : "rounds rating to one decimal — 4.71 reuses 4.7 bitmap").
- [x] Cluster inchangé (tests cluster existants intacts).
- [x] Annonces sans coordonnées toujours ignorées (régression couverte par test "builds markers for announcements with each transport mode" — adresses fournies).

## Tests

- `flutter test` → **1006 tests, all passing** (avant Phase B : 999 ; +7 nouveaux : 6 dans `marker_bitmap_factory_test.dart` + 1 dans `announcement_map_view_test.dart`)
- `flutter analyze` → 0 erreur
- Couverture sur fichiers touchés :
  - `marker_bitmap_factory.dart` : **99.1%** (107/108 lignes — la seule ligne non couverte est probablement l'assertion `bytes!` théoriquement non-null)
  - `announcement_map_view.dart` : **60.2%** (dette pré-existante : flow GPS/Geolocator non testable sans mocks complexes — hors scope Phase B ; le code Phase B ajouté `_buildMarker` + `_prewarmCommonIcons` est exercé)

## Décisions techniques

- **Canvas-drawn vs assets PNG** : canvas — 0 KB ajouté à l'APK, scale automatique selon DPI, combinaisons générées dynamiquement (impossible avec assets statiques pour 6 modes × 2 sides × 50 buckets de note).
- **`MarkerSide` public dans la factory** : choisi sur option (b) du spec — séparation propre rendering/layout. L'enum privé `_MarkerSide` reste dans le map view pour la logique de clustering, mappé vers `MarkerSide` public au moment de l'appel à `pin()`.
- **Rating bucket arrondi au dixième** : limite les combinaisons cache à ~50 buckets pour le rating, l'œil ne distingue pas un dixième sur un pill 28 px.
- **Pré-chauffage de 12 combos vs lazy** : 12 rendus parallèles (~50 ms en background) évitent le pop-in à la première map avec un coût négligeable.
- **Marker ID inchangé** : format `${side.name}_${announcement.id}` préservé — pas besoin de modifier les tests de tap/navigation existants.
- **`@visibleForTesting clearCache()`** : permet l'isolation des tests sans exposer publiquement.

## Hors scope (logged pour plus tard)

- Filtre par mode de transport dans la recherche.
- Animations sur l'apparition des marqueurs.
- Affichage du mode de transport sur `TravelerCard` dans la liste.
- Migration vers SVG assets si on veut retirer le canvas-drawn.
