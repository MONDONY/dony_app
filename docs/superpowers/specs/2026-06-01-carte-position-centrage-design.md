# Design — Lifting de la carte dony (position, centrage, contrôles, marqueurs, style)

**Date :** 2026-06-01
**Statut :** Design validé (approche A + 4 phases)
**Périmètre :** `dony_app` — feature `matching` (carte d'accueil expéditeur + voyageur)

---

## 1. Contexte & problème

La carte d'accueil (`AnnouncementMapView`) est partagée par les deux écrans home :
- `lib/features/home/presentation/home_screen.dart` (`_MapSenderView`)
- `lib/features/home/presentation/map_traveler_view.dart` (`_MapTravelerViewContent`)

Problèmes constatés dans le code actuel :

1. **Pas de point bleu "ma position".** `GoogleMap` n'active pas `myLocationEnabled` → la position de l'utilisateur n'apparaît jamais (contrairement à Google Maps / Plans).
2. **Centrage aveugle.** La caméra démarre sur un point fixe `LatLng(30, -5)` zoom 3.5, puis se recadre sur les annonces (`_fitInitialBounds`). Elle ne tient jamais compte de *où est l'utilisateur*.
3. **"Près de moi" ≠ recentrer.** Le FAB `my_location` actuel ouvre un sélecteur de rayon et filtre les annonces ; ce n'est ni un point de position vivant ni un bouton de recentrage.
4. **Aucun style sombre.** La carte affiche le style Google par défaut en clair, mais **aucun style sombre n'existe** → en mode sombre la carte reste claire et éblouissante (incohérent avec le thème). La constante `kAnnouncementMapStyle` (beige/crème) définie dans le fichier n'est **jamais appliquée** et sera retirée (cf. décision §2 : on garde le look Google).
5. **Logique de localisation dupliquée** dans 3 endroits (`home_screen._activateNearMe`, `map_traveler_view._activateNearMe`, `announcement_map_view._onNearMeTapped`).

Config native déjà prête : iOS a `NSLocationWhenInUseUsageDescription` (Info.plist L73), Android a `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`. Aucun blocage pour demander la permission à l'ouverture.

---

## 2. Décisions validées avec l'utilisateur

| Sujet | Décision |
|-------|----------|
| Affichage position | **Point bleu natif** Google Maps (`myLocationEnabled`) |
| Centrage à l'ouverture | **Hybride intelligent** : ma position + annonces proches dans le cadre |
| Bouton recentrer | **Fusionné** avec "Près de moi" |
| Permission localisation | **Demandée à l'ouverture** de la carte |
| Style de carte | **Google standard en clair + Google « nuit » en sombre** (pas de beige custom) |
| Périmètre | Position+centrage (cœur) · Contrôles · Marqueurs · Style |
| Architecture | **Approche A** — logique centralisée dans `AnnouncementMapView` |

---

## 3. Architecture (Approche A)

Toute la logique « ma position + caméra » est **centralisée dans `AnnouncementMapView`**, qui possède déjà le `GoogleMapController` et un `LocationService` injectable. Les deux écrans home utilisent ce widget → ils héritent du point bleu + recentrage + centrage hybride **sans modification de leur propre code**.

Pour respecter la couverture ≥ 90 % alors que `GoogleMap` ne se rend pas en test, les décisions pures sont extraites en fonctions/helpers testables, indépendantes du widget :

- `computeHybridBounds(LatLng user, List<LatLng> points) → LatLngBounds?` — cadre englobant position + annonces proches.
- `resolveMapStyle(Brightness) → String` — choisit le style clair/sombre.
- Le flux de permission passe par l'interface `LocationService` (déjà mockable).

Ces helpers vivent dans `lib/features/matching/presentation/widgets/` (ex. `map_camera_math.dart`, et les styles dans `map_styles.dart`) pour rester proches du widget tout en étant importables par les tests.

### Pourquoi pas un LocationCubit partagé (alternative B)

Plus « propre » au sens BLoC et réutilisable ailleurs (KYC…), mais c'est un plus gros chantier qui combat le pattern existant : `AnnouncementMapView` est déjà un îlot impératif (`setState` + pilotage direct du `GoogleMapController`). Réécrire en BLoC = risque et scope hors de ce lot. Reporté.

---

## 4. Phase 1 — Position + centrage (cœur)

### 4.1 Point bleu natif
- `GoogleMap.myLocationEnabled = true` **dès que la permission est accordée** (sinon `false`).
- On garde `myLocationButtonEnabled: false` (on pilote le recentrage via notre FAB).

### 4.2 Permission à l'ouverture
- Dans `initState` (ou premier `addPostFrameCallback`) de `AnnouncementMapView` : `checkPermission()` → si `denied`, `requestPermission()` (non bloquant, **sans** bottom sheet).
- Si accordée : activer le point bleu (`setState`), récupérer `getCurrentPosition()`, déclencher le centrage hybride.
- Si refusée / `deniedForever` : pas de point bleu, fallback de centrage sur les annonces. Aucun sheet intrusif au démarrage (le sheet de réglages reste réservé au flux "Près de moi" explicite).

### 4.3 Centrage hybride (`computeHybridBounds`)
Au premier `onMapCreated`, une fois la position connue :
- **Position + annonces proches** → cadre englobant `user` + annonces à ≤ 150 km ; s'il n'y en a aucune à 150 km, prendre les 10 plus proches. Padding 60. Zoom plafonné (max ~13) pour ne pas coller, plancher pour ne pas dézoomer sur le monde.
- **Position seule (aucune annonce)** → `newLatLngZoom(user, 12)` (zoom ville).
- **Position refusée** → comportement actuel `_fitInitialBounds` (annonces) ; si pas d'annonces, caméra initiale par défaut.

Règle de distance : approximation équirectangulaire (cohérente avec `_fitNearMeBounds` déjà présent). Helper pur et testé.

### 4.4 FAB fusionné « ma position / recentrer »
- Le FAB `_NearMeFab` devient un **bouton de recentrage** style Google Maps.
- **Tap** → si permission absente, la demander ; puis `animateCamera` vers le point bleu (zoom ~15 si on était dézoomé, sinon conserver le zoom courant).
- Le **filtrage par rayon "Près de moi" reste sur le chip existant** (`_HomeFilterChipsRow` côté sender, chip équivalent côté traveler). Le FAB n'ouvre plus le `NearMeRadiusSheet`.
- L'icône du FAB reflète l'état near-me (rempli si actif), mais son action est toujours « recentrer ».

> **Point d'interprétation à confirmer en revue de spec :** « fusionner » est lu comme « le FAB ne fait plus que recentrer ; le réglage du rayon vit sur le chip ». Si le FAB doit *aussi* rouvrir le sélecteur de rayon, l'ajuster ici.

---

## 5. Phase 2 — Contrôles de la carte

- Contrôles flottants empilés en bas à droite, espacés au-dessus du sheet (déjà géré par `fabBottomPadding`).
- **Boussole activée quand la carte est tournée** (`compassEnabled: true`) pour se réorienter au nord.
- FAB aligné design system : 48×48, ombres, états clair/sombre via `colorScheme`.

---

## 6. Phase 3 — Marqueurs (lisibilité)

- **Anneau de sélection en vert primaire** (`DonyColors.primary`) au lieu du bleu (`blue500`), pour ne pas le confondre avec le point bleu « ma position ». S'applique à `_renderPricePill` et `_renderStackedPricePill`.
- **Pastilles prix adaptées au mode sombre** : fond `surface` sombre + texte clair au lieu du blanc / `ink900` figé, pour rester lisibles sur une carte dark. Le `MarkerBitmapFactory` reçoit la `Brightness` (paramètre + clés de cache enrichies).
- Légère augmentation de la zone de tap (marge transparente autour de la pastille).

---

## 7. Phase 4 — Style de la carte (Google clair + Google nuit)

> **Mise à jour suite aux maquettes :** on garde le **look Google standard**, pas le style beige custom.

- **Mode clair → style Google par défaut** (aucun JSON appliqué, `style: null`). C'est l'apparence Google standard.
- **Mode sombre → style Google « nuit »** : nouvelle constante `kGoogleNightMapStyle` (le night style standard de Google : géométrie `#242f3e`, eau `#17263c`, routes `#38414e`, parcs `#263c3f`, labels clairs ; POI masqués pour rester épuré). Cohérent avec le thème sombre dony.
- `resolveMapStyle(Brightness) → String?` : `null` en clair, `kGoogleNightMapStyle` en sombre. La prop `mapStyle` reste un **override optionnel** (rétrocompatible).
- **Retirer la constante `kAnnouncementMapStyle` (beige)** devenue inutile, ainsi que le `mapStyle: null` explicite côté écrans (le widget décide selon la `Brightness`).
- Réappliquer le style sur changement de thème (le hook `didChangeDependencies` suit déjà la `Brightness` ; il appellera `controller.setMapStyle` / passera la nouvelle valeur).

---

## 8. Tests (cible ≥ 90 %)

**Unitaires (helpers purs) :**
- `computeHybridBounds` : position+annonces proches / position seule / annonces toutes lointaines (→ 10 plus proches) / liste vide.
- `resolveMapStyle` : clair → `null` (Google par défaut), sombre → `kGoogleNightMapStyle`.
- Flux permission via `LocationService` mocké : accordée, `denied`→`requestPermission`, `deniedForever`.

**Widget :**
- `AnnouncementMapView` rend le FAB ; tap déclenche le recentrage (controller mocké/espionné) ; l'icône reflète l'état near-me ; rebuild des marqueurs sur changement d'annonces et de `selectedAnnouncementId`.
- `MarkerBitmapFactory` : rendu pastille clair vs sombre produit des bitmaps distincts (clé de cache).

---

## 9. Fichiers impactés (prévision)

| Fichier | Nature |
|---------|--------|
| `announcement_map_view.dart` | Cœur : `myLocationEnabled`, permission init, centrage hybride, FAB recentrer, choix de style, boussole |
| `marker_bitmap_factory.dart` | Anneau vert, pastilles dark-aware |
| `map_camera_math.dart` *(nouveau)* | `computeHybridBounds` + distance (helpers testables) |
| `map_styles.dart` *(nouveau)* | `kGoogleNightMapStyle` + `resolveMapStyle` (clair → null, sombre → night) |
| `announcement_map_view.dart` | Retrait de la constante beige `kAnnouncementMapStyle` (inutile) |
| `home_screen.dart` | Le chip "Près de moi" reste le point d'entrée du filtre rayon (FAB ne l'ouvre plus) — vérifier la cohérence |
| `map_traveler_view.dart` | Idem chip ; retrait du `mapStyle: null` explicite (laisser le widget décider) |
| Tests associés | Nouveaux fichiers de tests unitaires + widget |

---

## 10. Hors périmètre (YAGNI)

- Pas de `LocationCubit` partagé global (alternative B reportée).
- Pas de suivi GPS continu custom (le point bleu natif suffit).
- Pas de refonte du clustering ni du flux de négociation.
- Pas de boutons de zoom +/- (le pinch suffit).
