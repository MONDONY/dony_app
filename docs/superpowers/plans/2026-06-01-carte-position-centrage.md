# Lifting de la carte dony — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Afficher la position de l'utilisateur (point bleu natif), centrer la carte intelligemment (hybride : moi + annonces proches), transformer le FAB en bouton « recentrer », et appliquer un style Google clair/nuit + des marqueurs lisibles dans les deux thèmes.

**Architecture:** Toute la logique « ma position + caméra » est centralisée dans le widget `AnnouncementMapView` (déjà partagé par les 2 écrans home), qui possède le `GoogleMapController` et un `LocationService` injectable. Les décisions pures (calcul de cadre, choix de style) sont extraites dans des helpers testables sans rendre `GoogleMap`.

**Tech Stack:** Flutter, `google_maps_flutter ^2.9`, `geolocator ^13`, `flutter_test`, `mocktail`. Tout en tokens `DonyColors` (jamais de hex en dur).

**Référence design :** `docs/superpowers/specs/2026-06-01-carte-position-centrage-design.md`

> ⚠️ **Palette :** la marque dony est **bleue** (`DonyColors.primary = blue500 #0B5FFF`), pas verte (le CLAUDE.md est périmé). On ne touche **pas** aux couleurs du FAB/chips/clusters (déjà bleus, on-brand). Le seul changement de couleur marqueur est l'**anneau de sélection** : `DonyColors.success` (clair) / `successDark500` (sombre), pour le distinguer du point bleu « ma position ».

---

## Structure des fichiers

| Fichier | Responsabilité |
|---------|----------------|
| `lib/features/matching/presentation/widgets/map_camera_math.dart` *(nouveau)* | `distanceKm()` + `computeHybridBounds()` — calcul pur du cadre caméra |
| `lib/features/matching/presentation/widgets/map_styles.dart` *(nouveau)* | `kGoogleNightMapStyle` (dérivé des tokens dark) + `resolveMapStyle()` |
| `lib/features/matching/presentation/widgets/marker_bitmap_factory.dart` | Anneau de sélection `success`, pastilles dark-aware, clés de cache enrichies |
| `lib/features/matching/presentation/widgets/announcement_map_view.dart` | Cœur : `myLocationEnabled`, permission à l'ouverture, centrage hybride, FAB recentrer, style selon thème, boussole ; retrait des props/flux near-me du FAB |
| `lib/features/home/presentation/home_screen.dart` | Retrait des callbacks `onNearMeRequested`/`onNearMeDisabled` ; brightness passée aux marqueurs package-request |
| `lib/features/home/presentation/map_traveler_view.dart` | Retrait du `mapStyle: null` explicite |
| `test/.../map_camera_math_test.dart` *(nouveau)* | Tests `distanceKm` + `computeHybridBounds` |
| `test/.../map_styles_test.dart` *(nouveau)* | Tests `resolveMapStyle` |
| `test/.../marker_bitmap_factory_test.dart` | + tests brightness (cache clair/sombre, sélection) |
| `test/.../announcement_map_view_test.dart` | Adaptation FAB recentrer + permission à l'ouverture |

---

## Task 1 : Helper de calcul caméra (`map_camera_math.dart`)

**Files:**
- Create: `lib/features/matching/presentation/widgets/map_camera_math.dart`
- Test: `test/features/matching/presentation/widgets/map_camera_math_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

Create `test/features/matching/presentation/widgets/map_camera_math_test.dart` :

```dart
import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const paris = LatLng(48.8566, 2.3522);
  const parisNear = LatLng(48.90, 2.40); // ~6 km
  const lyon = LatLng(45.7640, 4.8357);  // ~392 km
  const dakar = LatLng(14.6928, -17.4467); // ~4200 km

  group('distanceKm', () {
    test('returns ~0 for the same point', () {
      expect(distanceKm(paris, paris), lessThan(0.001));
    });
    test('Paris→Lyon is ~392 km (±15)', () {
      expect(distanceKm(paris, lyon), closeTo(392, 15));
    });
  });

  group('computeHybridBounds', () {
    test('returns null when there are no points', () {
      expect(computeHybridBounds(paris, const []), isNull);
    });

    test('keeps only nearby points (≤150 km) with the user', () {
      final b = computeHybridBounds(paris, const [parisNear, lyon]);
      expect(b, isNotNull);
      expect(b!.contains(paris), isTrue);
      expect(b.contains(parisNear), isTrue);
      expect(b.contains(lyon), isFalse); // 392 km → exclu
    });

    test('falls back to nearest points when none are within radius', () {
      final b = computeHybridBounds(paris, const [lyon, dakar]);
      expect(b, isNotNull);
      expect(b!.contains(paris), isTrue);
      expect(b.contains(lyon), isTrue);
      expect(b.contains(dakar), isTrue); // les 2 plus proches retenues
    });

    test('returns null when the only point equals the user (degenerate)', () {
      expect(computeHybridBounds(paris, const [paris]), isNull);
    });
  });
}
```

- [ ] **Step 2 : Lancer le test → échec attendu**

Run: `flutter test test/features/matching/presentation/widgets/map_camera_math_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'map_camera_math.dart'` / `distanceKm` introuvable.

- [ ] **Step 3 : Implémenter le helper**

Create `lib/features/matching/presentation/widgets/map_camera_math.dart` :

```dart
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Distance grand-cercle (Haversine) entre deux points, en kilomètres.
double distanceKm(LatLng a, LatLng b) {
  const earthR = 6371.0;
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final lat1 = rad(a.latitude);
  final lat2 = rad(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthR * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Cadre « hybride » : englobe la position [user] + les annonces proches.
///
/// - Aucune annonce → `null` (l'appelant centre sur l'utilisateur au zoom ville).
/// - Annonces ≤ [nearbyRadiusKm] → cadre = user + ces annonces.
/// - Aucune dans le rayon → cadre = user + les [maxNearest] plus proches.
/// - Cadre dégénéré (un seul point ≈ user) → `null`.
LatLngBounds? computeHybridBounds(
  LatLng user,
  List<LatLng> points, {
  double nearbyRadiusKm = 150,
  int maxNearest = 10,
}) {
  if (points.isEmpty) return null;

  final within =
      points.where((p) => distanceKm(user, p) <= nearbyRadiusKm).toList();

  final List<LatLng> selected;
  if (within.isNotEmpty) {
    selected = within;
  } else {
    final sorted = [...points]
      ..sort((a, b) => distanceKm(user, a).compareTo(distanceKm(user, b)));
    selected = sorted.take(maxNearest).toList();
  }

  final all = <LatLng>[user, ...selected];
  double minLat = all.first.latitude, maxLat = all.first.latitude;
  double minLng = all.first.longitude, maxLng = all.first.longitude;
  for (final p in all) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }

  // Garde anti-crash : `newLatLngBounds` plante si SW == NE.
  if ((maxLat - minLat).abs() < 1e-6 && (maxLng - minLng).abs() < 1e-6) {
    return null;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}
```

- [ ] **Step 4 : Lancer le test → succès attendu**

Run: `flutter test test/features/matching/presentation/widgets/map_camera_math_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/matching/presentation/widgets/map_camera_math.dart test/features/matching/presentation/widgets/map_camera_math_test.dart
git commit -m "feat(carte): helper computeHybridBounds + distanceKm (testé)"
```

---

## Task 2 : Styles de carte (`map_styles.dart`)

**Files:**
- Create: `lib/features/matching/presentation/widgets/map_styles.dart`
- Test: `test/features/matching/presentation/widgets/map_styles_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

Create `test/features/matching/presentation/widgets/map_styles_test.dart` :

```dart
import 'dart:convert';

import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMapStyle', () {
    test('light → null (style Google par défaut)', () {
      expect(resolveMapStyle(Brightness.light), isNull);
    });
    test('dark → kGoogleNightMapStyle', () {
      expect(resolveMapStyle(Brightness.dark), kGoogleNightMapStyle);
    });
  });

  test('kGoogleNightMapStyle is valid JSON (a non-empty array)', () {
    final decoded = jsonDecode(kGoogleNightMapStyle);
    expect(decoded, isA<List>());
    expect((decoded as List), isNotEmpty);
  });
}
```

- [ ] **Step 2 : Lancer le test → échec attendu**

Run: `flutter test test/features/matching/presentation/widgets/map_styles_test.dart`
Expected: FAIL — `map_styles.dart` introuvable.

- [ ] **Step 3 : Implémenter les styles**

Create `lib/features/matching/presentation/widgets/map_styles.dart` :

```dart
import 'package:flutter/material.dart';

/// Style Google « nuit » dérivé des tokens dark du design system dony :
/// geometry = neutralDark50 (#11161E), water = neutralDark0 (#0A0E14),
/// road = neutralDark200 (#222932), road stroke = neutralDark100 (#161B23),
/// highway = neutralDark300 (#2D333D), labels = neutralDark500 (#B5AFA5).
/// POI/transit masqués pour rester épuré (comme l'ancien style clair).
const String kGoogleNightMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#11161E"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#B5AFA5"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0A0E14"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#222932"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#161B23"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7E7972"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2D333D"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#0A0E14"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#54504A"}]}
]''';

/// Style de carte selon le thème :
/// clair → `null` (apparence Google standard), sombre → style nuit.
String? resolveMapStyle(Brightness brightness) =>
    brightness == Brightness.dark ? kGoogleNightMapStyle : null;
```

- [ ] **Step 4 : Lancer le test → succès attendu**

Run: `flutter test test/features/matching/presentation/widgets/map_styles_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/matching/presentation/widgets/map_styles.dart test/features/matching/presentation/widgets/map_styles_test.dart
git commit -m "feat(carte): style Google nuit + resolveMapStyle (tokens dark)"
```

---

## Task 3 : Marqueurs dark-aware + anneau de sélection vert

**Files:**
- Modify: `lib/features/matching/presentation/widgets/marker_bitmap_factory.dart`
- Test: `test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart`

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajouter ce groupe à la fin du `main()` de `test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart` (avant la dernière `}`) :

```dart
  group('MarkerBitmapFactory.pricePill brightness', () {
    test('light vs dark produce different bitmaps', () async {
      final light = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.light);
      final dark = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      expect(identical(light, dark), isFalse);
    });

    test('same brightness hits the cache', () async {
      final a = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      final b = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, brightness: Brightness.dark);
      expect(identical(a, b), isTrue);
    });

    test('selected vs not produce different bitmaps', () async {
      final plain = await MarkerBitmapFactory.pricePill(pricePerKg: 12);
      final selected = await MarkerBitmapFactory.pricePill(
        pricePerKg: 12, isSelected: true);
      expect(identical(plain, selected), isFalse);
    });
  });
```

Ajouter l'import Material en tête du fichier de test s'il manque :

```dart
import 'package:flutter/material.dart';
```

- [ ] **Step 2 : Lancer → échec attendu**

Run: `flutter test test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart`
Expected: FAIL — `No named parameter with the name 'brightness'`.

- [ ] **Step 3 : Ajouter le paramètre `brightness` aux signatures publiques**

Dans `marker_bitmap_factory.dart`, remplacer la signature de `pricePill` :

```dart
  static Future<BitmapDescriptor> pricePill({
    required double pricePerKg,
    Color dotColor = Colors.transparent,
    bool isSelected = false,
    Brightness brightness = Brightness.light,
  }) async {
    final key = _PricePillKey(
      priceCents: (pricePerKg * 100).round(),
      colorValue: dotColor.value,
      isSelected: isSelected,
      isDark: brightness == Brightness.dark,
    );
    final cached = _pillCache[key];
    if (cached != null) return cached;
    final bitmap = await _renderPricePill(
      pricePerKg: pricePerKg,
      dotColor: dotColor,
      isSelected: isSelected,
      brightness: brightness,
    );
    _pillCache[key] = bitmap;
    return bitmap;
  }
```

Et la signature de `stackedPricePill` :

```dart
  static Future<BitmapDescriptor> stackedPricePill({
    required double pricePerKg,
    required int count,
    Color dotColor = Colors.transparent,
    bool isSelected = false,
    Brightness brightness = Brightness.light,
  }) async {
    final key = _StackedPillKey(
      priceCents: (pricePerKg * 100).round(),
      count: count,
      colorValue: dotColor.value,
      isSelected: isSelected,
      isDark: brightness == Brightness.dark,
    );
    final cached = _stackedPillCache[key];
    if (cached != null) return cached;
    final bitmap = await _renderStackedPricePill(
      pricePerKg: pricePerKg,
      count: count,
      dotColor: dotColor,
      isSelected: isSelected,
      brightness: brightness,
    );
    _stackedPillCache[key] = bitmap;
    return bitmap;
  }
```

- [ ] **Step 4 : Ajouter un helper palette + propager `brightness` aux renderers**

Ajouter ces helpers privés dans la classe `MarkerBitmapFactory` (par ex. juste après `_kTailW`) :

```dart
  /// Couleurs de pastille selon le thème (tokens design system).
  static ({Color fill, Color text, Color border, Color ghostFill, Color ghostStroke})
      _pillPalette(Brightness b) {
    if (b == Brightness.dark) {
      return (
        fill: DonyColors.neutralDark200,
        text: DonyColors.neutralDark700,
        border: DonyColors.neutralDark300,
        ghostFill: DonyColors.neutralDark300,
        ghostStroke: DonyColors.neutralDark400,
      );
    }
    return (
      fill: DonyColors.neutral0,
      text: DonyColors.ink800,
      border: DonyColors.neutral200,
      ghostFill: DonyColors.neutral300,
      ghostStroke: DonyColors.neutral400,
    );
  }

  /// Anneau de sélection — vert `success`, distinct du point bleu « ma position ».
  static Color _selectionRing(Brightness b) =>
      b == Brightness.dark ? DonyColors.successDark500 : DonyColors.success;
```

Modifier `_renderPricePill` : remplacer son en-tête et les couleurs codées en dur.

En-tête :

```dart
  static Future<BitmapDescriptor> _renderPricePill({
    required double pricePerKg,
    required Color dotColor,
    required bool isSelected,
    required Brightness brightness,
  }) async {
    final palette = _pillPalette(brightness);
```

Puis remplacer, dans le corps de `_renderPricePill` :
- `const textColor = DonyColors.ink900;` → `final textColor = palette.text;`
- dans le `TextSpan` du `TextPainter`, `color: textColor` reste (devient non-const : enlever `const` du `TextStyle` parent → `style: TextStyle(...)`).
- L'anneau sélection : `..color = DonyColors.blue500` → `..color = _selectionRing(brightness)`
- Le fond : `..color = Colors.white` (white pill background) → `..color = palette.fill`
- La bordure : `..color = DonyColors.neutral200` → `..color = palette.border`
- La queue (tail) : `Paint()..color = Colors.white` → `Paint()..color = palette.fill`

Modifier `_renderStackedPricePill` de la même façon.

En-tête :

```dart
  static Future<BitmapDescriptor> _renderStackedPricePill({
    required double pricePerKg,
    required int count,
    required Color dotColor,
    required bool isSelected,
    required Brightness brightness,
  }) async {
    final palette = _pillPalette(brightness);
```

Remplacements dans `_renderStackedPricePill` :
- `const textColor = DonyColors.ink900;` → `final textColor = palette.text;` (et enlever `const` du `TextStyle` qui l'utilise)
- ghost fill `..color = DonyColors.neutral300` → `..color = palette.ghostFill`
- ghost stroke `..color = DonyColors.neutral400` → `..color = palette.ghostStroke`
- anneau `..color = DonyColors.blue500` → `..color = _selectionRing(brightness)`
- fond pill `..color = Colors.white` → `..color = palette.fill`
- bordure `..color = DonyColors.neutral200` → `..color = palette.border`
- tail `Paint()..color = Colors.white` → `Paint()..color = palette.fill`
- (Le badge de comptage reste `DonyColors.blue500` — couleur de marque, inchangée.)

- [ ] **Step 5 : Enrichir les clés de cache avec `isDark`**

Dans `_PricePillKey`, ajouter le champ et l'inclure dans `==`/`hashCode` :

```dart
class _PricePillKey {
  const _PricePillKey({
    required this.priceCents,
    required this.colorValue,
    required this.isSelected,
    required this.isDark,
  });

  final int priceCents;
  final int colorValue;
  final bool isSelected;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PricePillKey &&
          priceCents == other.priceCents &&
          colorValue == other.colorValue &&
          isSelected == other.isSelected &&
          isDark == other.isDark;

  @override
  int get hashCode => Object.hash(priceCents, colorValue, isSelected, isDark);
}
```

Idem pour `_StackedPillKey` (ajouter `required this.isDark;`, le champ `final bool isDark;`, l'inclure dans `==` et dans `Object.hash(priceCents, count, colorValue, isSelected, isDark)`).

- [ ] **Step 6 : Lancer les tests marqueurs → succès attendu**

Run: `flutter test test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart`
Expected: PASS (tous les tests existants + les 3 nouveaux).

- [ ] **Step 7 : Commit**

```bash
git add lib/features/matching/presentation/widgets/marker_bitmap_factory.dart test/features/matching/presentation/widgets/marker_bitmap_factory_test.dart
git commit -m "feat(carte): marqueurs dark-aware + anneau de sélection vert (success)"
```

---

## Task 4 : Carte — style selon thème, boussole, point bleu, brightness aux marqueurs

**Files:**
- Modify: `lib/features/matching/presentation/widgets/announcement_map_view.dart`

Cette tâche ne change que le rendu (pas de logique de permission encore). Elle compile et garde les tests verts.

- [ ] **Step 1 : Importer les nouveaux helpers**

En tête de `announcement_map_view.dart`, ajouter :

```dart
import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
```

Supprimer la constante locale devenue inutile `kAnnouncementMapStyle` (le bloc `const String kAnnouncementMapStyle = '''[ ... ]''';` et son commentaire d'en-tête « Map style (beige/crème) »).

- [ ] **Step 2 : Ajouter le flag de localisation accordée**

Dans `_AnnouncementMapViewState`, ajouter près des autres champs :

```dart
  bool _locationGranted = false;
  LatLng? _myLocation;
```

- [ ] **Step 3 : Brancher style + boussole + point bleu dans `GoogleMap`**

Dans `build`, sur le widget `GoogleMap`, modifier :

```dart
          style: widget.mapStyle ?? resolveMapStyle(_brightness),
          myLocationEnabled: _locationGranted,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
```

(`style:` passait `widget.mapStyle` ; `compassEnabled` passait `false`.)

- [ ] **Step 4 : Passer la `brightness` à la fabrique de marqueurs**

Dans `_buildMarker`, ajouter `brightness: _brightness` aux 3 appels factory :

- `MarkerBitmapFactory.stackedPricePill(... , isSelected: isSelected)` → ajouter `, brightness: _brightness`
- `MarkerBitmapFactory.pricePill(... , isSelected: isSelected)` (cas single) → ajouter `, brightness: _brightness`

(Le `clusterBadge` reste inchangé — couleur de marque.)

- [ ] **Step 5 : Vérifier la compilation et les tests existants**

Run: `flutter analyze lib/features/matching/presentation/widgets/announcement_map_view.dart`
Expected: aucune erreur (warnings éventuels traités plus tard).

Run: `flutter test test/features/matching/presentation/widgets/announcement_map_view_test.dart`
Expected: PASS (les tests existants passent encore — le FAB n'a pas changé).

- [ ] **Step 6 : Commit**

```bash
git add lib/features/matching/presentation/widgets/announcement_map_view.dart
git commit -m "feat(carte): style clair/nuit auto + boussole + point bleu + marqueurs themés"
```

---

## Task 5 : Permission à l'ouverture + centrage hybride

**Files:**
- Modify: `lib/features/matching/presentation/widgets/announcement_map_view.dart`

- [ ] **Step 1 : Demander la permission à l'ouverture**

Dans `initState`, après `_prewarmCommonIcons();`, ajouter un post-frame :

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocationOnOpen());
```

Ajouter la méthode dans l'état :

```dart
  Future<void> _initLocationOnOpen() async {
    var permission = await widget.locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await widget.locationService.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // pas de point bleu, pas de sheet intrusif au démarrage
    }
    if (!mounted) return;
    setState(() => _locationGranted = true);
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _applyInitialCamera();
    } catch (_) {
      // GPS indisponible → on garde le point bleu, fallback annonces géré ailleurs
    }
  }
```

- [ ] **Step 2 : Centrage hybride au démarrage**

Ajouter la méthode :

```dart
  void _applyInitialCamera() {
    final controller = _mapController;
    if (controller == null) return; // onMapCreated rappellera
    final me = _myLocation;
    if (me != null) {
      final points = _pickupPoints().map((p) => p.location).toList();
      final bounds = computeHybridBounds(me, points);
      if (bounds != null) {
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
      } else {
        controller.animateCamera(CameraUpdate.newLatLngZoom(me, 12));
      }
    } else {
      _fitInitialBounds();
    }
  }
```

- [ ] **Step 3 : Brancher `onMapCreated` sur le centrage hybride**

Dans `build`, remplacer le callback `onMapCreated` :

```dart
          onMapCreated: (controller) {
            _mapController = controller;
            _applyInitialCamera();
          },
```

(Avant il appelait `_fitInitialBounds()`. `_applyInitialCamera` couvre les deux cas : position connue → hybride, sinon → annonces.)

- [ ] **Step 4 : Vérifier la compilation**

Run: `flutter analyze lib/features/matching/presentation/widgets/announcement_map_view.dart`
Expected: aucune erreur.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/matching/presentation/widgets/announcement_map_view.dart
git commit -m "feat(carte): permission à l'ouverture + centrage hybride (moi + annonces proches)"
```

---

## Task 6 : FAB « recentrer » (fusion Près de moi) + nettoyage props + tests

**Files:**
- Modify: `lib/features/matching/presentation/widgets/announcement_map_view.dart`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Test: `test/features/matching/presentation/widgets/announcement_map_view_test.dart`

Cette tâche transforme le FAB en bouton recentrer, supprime le flux near-me du FAB, et met à jour le seul appelant (`home_screen`) + les tests, en un commit qui compile.

- [ ] **Step 1 : Écrire/adapter les tests d'abord**

Dans `announcement_map_view_test.dart` :

(a) Le test « Près de moi triggers permission flow when denied » devient un test du **FAB recentrer** quand refusé. Remplacer son corps par :

```dart
    testWidgets('recenter FAB shows permission sheet when denied',
        (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockLoc.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('permission-denied-sheet')), findsOneWidget);
    });
```

(b) Ajouter un test du recentrage quand accordé (vérifie l'appel GPS) :

```dart
    testWidgets('recenter FAB requests current position when granted',
        (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockLoc.getCurrentPosition())
          .thenAnswer((_) async => _fakePosition());

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      verify(() => mockLoc.getCurrentPosition()).called(greaterThanOrEqualTo(1));
    });
```

(c) Le test « FAB shows active state when isNearMeActive » : enlever `onNearMeRequested` (il n'existe plus comme prop). Il reste valide tel quel (il ne passe pas `onNearMeRequested`).

(d) Ajouter un helper `Position` en haut du fichier (après les imports) :

```dart
Position _fakePosition() => Position(
      latitude: 48.8566,
      longitude: 2.3522,
      timestamp: DateTime(2026, 6, 1),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
```

(e) Le test existant qui passait `onNearMeRequested: (_, __, ___) {}` doit retirer cette ligne (déjà couvert en (a)).

- [ ] **Step 2 : Lancer → échec attendu**

Run: `flutter test test/features/matching/presentation/widgets/announcement_map_view_test.dart`
Expected: FAIL — `onNearMeRequested` n'existe plus / `getCurrentPosition` non appelé (recentrage pas encore implémenté).

- [ ] **Step 3 : Supprimer les props near-me du widget**

Dans `AnnouncementMapView`, supprimer du constructeur et des champs :
- `this.onNearMeRequested`
- `this.onNearMeDisabled`
- les déclarations `final void Function(double, double, double)? onNearMeRequested;` et `final VoidCallback? onNearMeDisabled;`

Supprimer la méthode `_onNearMeTapped` en entier, et l'import devenu inutile :
`import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';`

(On conserve `_showPermissionDeniedSheet`, `_PermissionDeniedSheet`, et les props `isNearMeActive`/`activeRadiusKm`/`userPosition` + `_fitNearMeBounds` : toujours utilisés pour le cercle et l'auto-fit, pilotés par le chip parent.)

- [ ] **Step 4 : Implémenter `_recenterOnMe`**

Ajouter la méthode :

```dart
  Future<void> _recenterOnMe() async {
    var permission = await widget.locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await widget.locationService.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedSheet(true);
      return;
    }
    if (permission == LocationPermission.denied) {
      _showPermissionDeniedSheet(false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _locationGranted = true;
      _isLocating = true;
    });
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (!mounted) return;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = target);
      final zoom = _currentZoom < 13 ? 15.0 : _currentZoom;
      await _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }
```

- [ ] **Step 5 : Câbler le FAB sur `_recenterOnMe` et simplifier `_NearMeFab`**

Dans `build`, le `_NearMeFab` :

```dart
          child: _NearMeFab(
            key: const Key('near-me-fab'),
            isActive: widget.isNearMeActive,
            isLoading: _isLocating,
            onTap: _recenterOnMe,
          ),
```

(Retirer `radiusKm:`, `onDoubleTap:`.)

Modifier la classe `_NearMeFab` : retirer les champs `radiusKm`, `onDoubleTap` et le `GestureDetector.onDoubleTap`. Le `GestureDetector` ne garde que `onTap: isLoading ? null : onTap`. La logique d'icône (active → `Icons.my_location_rounded` blanc ; inactive → `Icons.my_location_outlined` primary) reste inchangée.

- [ ] **Step 6 : Retirer les callbacks chez l'appelant (`home_screen.dart`)**

Dans `home_screen.dart`, dans l'appel `AnnouncementMapView(...)`, supprimer les deux arguments :

```dart
                  onNearMeRequested: (lat, lng, radius) { ... },
                  onNearMeDisabled: _deactivateNearMe,
```

(L'entrée near-me reste assurée par le chip « Près de moi » de `_HomeFilterChipsRow` → `_activateNearMe`, et la sortie par `_NearMeBackButton` → `_deactivateNearMe`. La méthode `_deactivateNearMe` reste utilisée.)

- [ ] **Step 7 : Lancer les tests → succès attendu**

Run: `flutter test test/features/matching/presentation/widgets/announcement_map_view_test.dart`
Expected: PASS.

Run: `flutter analyze lib/features/matching/ lib/features/home/`
Expected: aucune erreur (vérifier qu'aucun import/variable n'est devenu inutilisé).

- [ ] **Step 8 : Commit**

```bash
git add lib/features/matching/presentation/widgets/announcement_map_view.dart lib/features/home/presentation/home_screen.dart test/features/matching/presentation/widgets/announcement_map_view_test.dart
git commit -m "feat(carte): FAB recentrer (fusion Près de moi) + nettoyage flux near-me"
```

---

## Task 7 : Câblage final des écrans (brightness + style)

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/features/home/presentation/map_traveler_view.dart`

- [ ] **Step 1 : Passer la `brightness` aux marqueurs package-request (home)**

Dans `home_screen.dart`, méthode `_rebuildPackageRequestMarkers`, l'appel `MarkerBitmapFactory.pricePill(...)` :

```dart
      final icon = await MarkerBitmapFactory.pricePill(
        pricePerKg: price,
        dotColor: DonyColors.terra500,
        brightness: Theme.of(context).brightness,
      );
```

(`context` est disponible dans la méthode d'état ; elle est déjà appelée après vérif `mounted`.)

- [ ] **Step 2 : Retirer le `mapStyle: null` explicite (traveler)**

Dans `map_traveler_view.dart`, dans l'appel `AnnouncementMapView(...)`, supprimer la ligne `mapStyle: null,` (le widget choisit désormais le style selon le thème). 

- [ ] **Step 3 : Vérifier compilation + analyze**

Run: `flutter analyze lib/`
Expected: aucune erreur.

- [ ] **Step 4 : Commit**

```bash
git add lib/features/home/presentation/home_screen.dart lib/features/home/presentation/map_traveler_view.dart
git commit -m "feat(carte): marqueurs package-request themés + style auto côté traveler"
```

---

## Task 8 : Vérification globale (tests + couverture + analyze)

**Files:** aucun (validation).

- [ ] **Step 1 : Analyse statique**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2 : Suite de tests complète**

Run: `flutter test`
Expected: tous les tests passent (0 failure).

- [ ] **Step 3 : Couverture ≥ 90 %**

Run: `flutter test --coverage`
Puis vérifier la couverture des fichiers touchés. Pour un résumé rapide :

```bash
lcov --summary coverage/lcov.info 2>/dev/null || genhtml coverage/lcov.info -o coverage/html
```

Cibler en priorité `map_camera_math.dart`, `map_styles.dart`, `marker_bitmap_factory.dart`. Si un fichier touché est < 90 %, ajouter les tests manquants (ex. cas `computeHybridBounds` supplémentaires, branche `_pillPalette` clair/sombre déjà couverte par les bitmaps distincts).

- [ ] **Step 4 : Commit (si tests ajoutés en Step 3)**

```bash
git add test/
git commit -m "test(carte): compléments de couverture ≥ 90 %"
```

- [ ] **Step 5 : Test manuel (device/simulateur)**

Lancer l'app (`flutter run --dart-define-from-file=env.dev.json`) et vérifier visuellement :
1. À l'ouverture → demande de permission ; accordée → point bleu visible.
2. Carte centrée sur moi + annonces proches (plus le point fixe Méditerranée).
3. Tap FAB → recentre sur le point bleu.
4. Filtre « Près de moi » via le chip → cercle de rayon + carrousel (inchangé).
5. Basculer thème sombre → carte passe en style nuit, pastilles lisibles, anneau de sélection vert.

---

## Notes de cohérence (types/signatures)

- `pricePill` / `stackedPricePill` : nouveau param `Brightness brightness = Brightness.light` (défaut → call sites non modifiés compilent ; Tasks 4 & 7 passent la vraie valeur).
- Clés de cache `_PricePillKey` / `_StackedPillKey` : nouveau champ `bool isDark` (sinon collision clair/sombre).
- `computeHybridBounds(LatLng, List<LatLng>, {nearbyRadiusKm, maxNearest}) → LatLngBounds?` ; `null` ⇒ l'appelant centre au zoom 12.
- `resolveMapStyle(Brightness) → String?` ; `null` en clair (Google par défaut).
- Props supprimées de `AnnouncementMapView` : `onNearMeRequested`, `onNearMeDisabled` (seul `home_screen` les passait).
- Conservés : `isNearMeActive`, `activeRadiusKm`, `userPosition`, `_fitNearMeBounds`, `_showPermissionDeniedSheet`, `_PermissionDeniedSheet`.
