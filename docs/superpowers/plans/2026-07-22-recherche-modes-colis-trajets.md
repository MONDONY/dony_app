# Recherche par mode : trajets ou colis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les trois modes de recherche (`all` / `parcels` / `trips`) par deux modes exclusifs dont les filtres s'adaptent, avec corridor et date partagés entre les deux, et transformer « Pour mes trajets » en filtre serveur.

**Architecture:** L'état de recherche sort de `home_screen.dart` (3456 lignes) vers un objet immuable `HomeSearchFilters`, testable sans Flutter, qui produit les deux payloads de recherche. La rangée de chips et la sheet de filtres deviennent des widgets dédiés. `HomeMapFocus` est remplacé par `SearchMode` à deux valeurs.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, Dio, `flutter_test`, `bloc_test`.

**Spec :** `docs/superpowers/specs/2026-07-22-recherche-modes-colis-trajets-design.md`
**Plan back associé :** `dony-back/docs/superpowers/plans/2026-07-22-matching-my-trips-filter.md`
**Maquettes :** https://claude.ai/code/artifact/4d117727-2a1a-461f-ac7f-6e92e0e27554

## Global Constraints

- Branche : `feature/recherche-modes-colis-trajets`. Ne jamais commit sur `main`.
- Jamais de ligne `Co-Authored-By: Claude` dans les messages de commit.
- Jamais de `setState` pour l'état de feature → BLoC. `home_screen.dart` utilise déjà `setState` pour ses filtres locaux : ce plan **ne migre pas** cet existant vers un Cubit, il extrait l'état dans un objet immuable manipulé par les `setState` déjà en place. Une migration BLoC serait un chantier séparé.
- Jamais de `Navigator.push` → GoRouter.
- Jamais de tiret cadratin dans un texte affiché à l'utilisateur (labels, messages, bannières). Virgule à la place. Les commentaires de code sont exemptés.
- Jamais d'icône camion (`Icons.local_shipping*`).
- Tout `DonyButton` dans un bottom sheet va dans `stickyBottom`, jamais dans le `child` scrollable.
- Tout nouvel event analytics est déclaré dans `AnalyticsEvents`, tiré depuis le BLoC, et ajouté à la table du `CLAUDE.md` dans le même commit. Aucune PII dans les propriétés.
- `flutter analyze` sans erreur et `flutter test` à 0 rouge avant chaque commit. Couverture ≥ 90 %.
- Ordre des tâches imposé : la Task 5 dépend du déploiement de la Task 5 du plan back.

---

### Task 1: `SearchMode` et `HomeSearchFilters`

Objet immuable portant tout l'état de recherche, sans dépendance Flutter, donc testable en `flutter test` pur.

**Files:**
- Create: `lib/features/home/domain/search_mode.dart`
- Create: `lib/features/home/domain/home_search_filters.dart`
- Test: `test/features/home/domain/home_search_filters_test.dart`

**Interfaces:**
- Consumes: `SearchParams` (`lib/features/matching/data/models/search_params.dart`), `ParcelSize`, `TransportMode`, `UrgencyFilter`.
- Produces:
  - `enum SearchMode { trips, parcels }`
  - `enum DonyDatePreset { none, today, thisWeek, thisMonth, custom }`
  - `class HomeSearchFilters` avec `copyWith`, `toSearchParams()`, `toPackageRequestQuery()`, `activeCountFor(SearchMode)`, `dateFrom`, `dateTo`, `hasCommonFilter`.
  - `class PackageRequestQuery` : porteur nommé des paramètres colis, consommé par la Task 4.

- [ ] **Step 1: Write the failing test**

Créer `test/features/home/domain/home_search_filters_test.dart` :

```dart
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeSearchFilters', () {
    test('vide : aucun filtre actif dans les deux modes', () {
      const f = HomeSearchFilters();
      expect(f.activeCountFor(SearchMode.trips), 0);
      expect(f.activeCountFor(SearchMode.parcels), 0);
      expect(f.hasCommonFilter, isFalse);
    });

    test('le corridor est partagé : il survit au changement de mode', () {
      const f = HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

      expect(f.toSearchParams().departureCity, 'Paris');
      expect(f.toSearchParams().arrivalCity, 'Dakar');
      expect(f.toPackageRequestQuery().departure, 'Paris');
      expect(f.toPackageRequestQuery().arrival, 'Dakar');
      expect(f.hasCommonFilter, isTrue);
    });

    test('la date est partagée et se traduit en plage pour les colis', () {
      final f = HomeSearchFilters(
        datePreset: DonyDatePreset.custom,
        customDate: DateTime(2026, 8, 12),
      );

      expect(f.toSearchParams().date, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateFrom, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateTo, DateTime(2026, 8, 12));
    });

    test('poids trajets et poids colis ne se propagent jamais l\'un vers l\'autre', () {
      const f = HomeSearchFilters(weightMin: 6, maxWeight: 3);

      // weightMin = « voyageur acceptant au moins 6 kg » — filtre trajets.
      expect(f.toSearchParams().weightKg, 6);
      // maxWeight = « demandes d'au plus 3 kg » — filtre colis.
      expect(f.toPackageRequestQuery().maxWeight, 3);
      // Aucune contamination croisée.
      expect(f.toPackageRequestQuery().maxWeight, isNot(6));
    });

    test('les filtres spécifiques ne comptent que dans leur mode', () {
      const f = HomeSearchFilters(
        kiloProOnly: true,      // trajets
        minRating: 4.5,         // trajets
        parcelSize: ParcelSize.medium, // colis
      );

      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 1);
    });

    test('les filtres communs comptent dans les deux modes', () {
      const f = HomeSearchFilters(departureCity: 'Paris', urgentOnly: true);

      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 2);
    });

    test('urgentOnly faux ne part jamais explicitement au serveur', () {
      const f = HomeSearchFilters(urgentOnly: false);

      expect(f.toSearchParams().urgencyFilter, isNull);
      expect(f.toPackageRequestQuery().urgent, isNull);
    });

    test('nearMe actif neutralise le corridor côté trajets', () {
      const f = HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        nearMeActive: true,
        nearMeRadiusKm: 25,
      );

      // Près de moi cherche tous les voyageurs autour, corridor ignoré.
      expect(f.toSearchParams().departureCity, isNull);
      expect(f.toSearchParams().arrivalCity, isNull);
    });

    test('copyWith efface un champ via le sentinel de suppression', () {
      const f = HomeSearchFilters(departureCity: 'Paris', minRating: 4.5);

      final sansNote = f.copyWith(clearMinRating: true);

      expect(sansNote.minRating, isNull);
      expect(sansNote.departureCity, 'Paris');
    });

    test('presets de date : today produit une borne basse à aujourd\'hui', () {
      final f = HomeSearchFilters(datePreset: DonyDatePreset.today);
      final today = DateTime.now();

      expect(f.dateFrom!.year, today.year);
      expect(f.dateFrom!.month, today.month);
      expect(f.dateFrom!.day, today.day);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/domain/home_search_filters_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'dony/features/home/domain/home_search_filters.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/features/home/domain/search_mode.dart` :

```dart
/// Mode de recherche de l'écran Rechercher. Deux valeurs exclusives, une
/// toujours active : il n'existe pas de mode « les deux ». Les filtres, la
/// liste de résultats et les marqueurs de carte découlent de ce mode.
enum SearchMode {
  trips,
  parcels;

  bool get isTrips => this == SearchMode.trips;
  bool get isParcels => this == SearchMode.parcels;

  SearchMode get other => isTrips ? SearchMode.parcels : SearchMode.trips;
}
```

Créer `lib/features/home/domain/home_search_filters.dart` :

```dart
import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';

/// Presets de date partagés par les deux modes. Remplace l'ancien `_DatePreset`
/// privé de home_screen et le `showDateRangePicker` du mode colis.
enum DonyDatePreset { none, today, thisWeek, thisMonth, custom }

/// Paramètres de recherche de demandes, produits par [HomeSearchFilters].
/// Porteur nommé plutôt qu'un tuple : les champs sont nombreux et homogènes en
/// type, une inversion d'arguments positionnels passerait inaperçue.
class PackageRequestQuery {
  const PackageRequestQuery({
    this.departure,
    this.arrival,
    this.dateFrom,
    this.dateTo,
    this.maxWeight,
    this.parcelSize,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.urgent,
    this.matchingMyTrips,
  });

  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final bool? urgent;
  final bool? matchingMyTrips;
}

/// État de recherche de l'écran Rechercher, immuable et sans dépendance Flutter.
///
/// Trois familles de champs : les communs, partagés par les deux modes et
/// conservés lors d'une bascule ; les spécifiques aux trajets ; les spécifiques
/// aux colis. C'est le partage des communs qui corrige la perte du corridor au
/// changement de mode.
class HomeSearchFilters {
  const HomeSearchFilters({
    // Communs
    this.departureCity,
    this.arrivalCity,
    this.datePreset = DonyDatePreset.none,
    this.customDate,
    this.urgentOnly = false,
    this.nearMeActive = false,
    this.nearMeRadiusKm,
    this.userLat,
    this.userLng,
    // Trajets
    this.maxPricePerKg,
    this.weightMin,
    this.weightMax,
    this.kiloProOnly = false,
    this.minRating,
    this.weekendOnly = false,
    this.transportMode,
    this.kycVerifiedOnly = false,
    this.contentType,
    this.urgencyFilter,
    // Colis
    this.maxWeight,
    this.parcelSize,
    this.matchingMyTrips = false,
  });

  // ── Communs ────────────────────────────────────────────────────────────────
  final String? departureCity;
  final String? arrivalCity;
  final DonyDatePreset datePreset;
  final DateTime? customDate;
  final bool urgentOnly;
  final bool nearMeActive;
  final double? nearMeRadiusKm;
  final double? userLat;
  final double? userLng;

  // ── Trajets ────────────────────────────────────────────────────────────────
  final double? maxPricePerKg;

  /// Capacité minimale attendue du voyageur, en kg. À ne pas confondre avec
  /// [maxWeight] : sémantiques opposées, jamais propagées l'une vers l'autre.
  final double? weightMin;
  final double? weightMax;
  final bool kiloProOnly;
  final double? minRating;
  final bool weekendOnly;
  final TransportMode? transportMode;
  final bool kycVerifiedOnly;
  final String? contentType;
  final UrgencyFilter? urgencyFilter;

  // ── Colis ──────────────────────────────────────────────────────────────────
  /// Poids maximal des demandes recherchées, en kg. Voir [weightMin].
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final bool matchingMyTrips;

  /// Vrai dès qu'un filtre commun est posé. Conditionne l'affichage du compteur
  /// sur le segment inactif : sans corridor ni date, le nombre de résultats de
  /// l'autre mode est un total plateforme sans valeur informative.
  bool get hasCommonFilter =>
      departureCity != null ||
      arrivalCity != null ||
      datePreset != DonyDatePreset.none;

  DateTime? get dateFrom {
    final now = DateTime.now();
    switch (datePreset) {
      case DonyDatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DonyDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case DonyDatePreset.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DonyDatePreset.custom:
        return customDate;
      case DonyDatePreset.none:
        return null;
    }
  }

  DateTime? get dateTo {
    final now = DateTime.now();
    switch (datePreset) {
      case DonyDatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DonyDatePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateTime(sunday.year, sunday.month, sunday.day);
      case DonyDatePreset.thisMonth:
        return DateTime(now.year, now.month + 1, 0);
      case DonyDatePreset.custom:
        return customDate;
      case DonyDatePreset.none:
        return null;
    }
  }

  /// Payload de recherche de trajets. « Près de moi » neutralise le corridor :
  /// on veut tous les voyageurs autour de l'utilisateur, pas ceux d'un corridor.
  SearchParams toSearchParams() {
    final ignoreCorridor = nearMeActive;
    return SearchParams(
      departureCity: ignoreCorridor ? null : departureCity,
      arrivalCity: ignoreCorridor ? null : arrivalCity,
      date: customDate,
      weightKg: weightMin ?? 6,
      maxPricePerKg: maxPricePerKg ?? 25,
      kiloProOnly: kiloProOnly,
      ratingFilter: minRating != null,
      weekendFilter: weekendOnly,
      priceFilter: maxPricePerKg != null,
      transportMode: transportMode,
      kycVerifiedOnly: kycVerifiedOnly,
      contentType: contentType,
      urgencyFilter: urgencyFilter,
    );
  }

  /// Payload de recherche de demandes. Les booléens serveur ne partent jamais
  /// à `false` explicitement, même convention que le back : présent ou absent.
  PackageRequestQuery toPackageRequestQuery() => PackageRequestQuery(
        departure: departureCity,
        arrival: arrivalCity,
        dateFrom: dateFrom,
        dateTo: dateTo,
        maxWeight: maxWeight,
        parcelSize: parcelSize,
        userLat: nearMeActive ? userLat : null,
        userLng: nearMeActive ? userLng : null,
        radiusKm: nearMeActive ? nearMeRadiusKm : null,
        urgent: urgentOnly ? true : null,
        matchingMyTrips: matchingMyTrips ? true : null,
      );

  /// Nombre de filtres actifs pour le badge de la barre corridor : communs
  /// plus ceux du mode courant. Un filtre spécifique à l'autre mode ne compte pas.
  int activeCountFor(SearchMode mode) {
    var n = 0;
    if (departureCity != null || arrivalCity != null) n++;
    if (datePreset != DonyDatePreset.none) n++;
    if (urgentOnly) n++;
    if (nearMeActive) n++;

    if (mode.isTrips) {
      if (kiloProOnly) n++;
      if (minRating != null) n++;
      if (weightMin != null || weightMax != null) n++;
      if (maxPricePerKg != null) n++;
      if (weekendOnly) n++;
      if (transportMode != null) n++;
      if (kycVerifiedOnly) n++;
      if (contentType != null) n++;
      if (urgencyFilter != null) n++;
    } else {
      if (maxWeight != null) n++;
      if (parcelSize != null) n++;
      if (matchingMyTrips) n++;
    }
    return n;
  }

  /// Les drapeaux `clearXxx` permettent de remettre un champ à null, ce qu'un
  /// paramètre optionnel seul ne sait pas exprimer.
  HomeSearchFilters copyWith({
    String? departureCity,
    String? arrivalCity,
    DonyDatePreset? datePreset,
    DateTime? customDate,
    bool? urgentOnly,
    bool? nearMeActive,
    double? nearMeRadiusKm,
    double? userLat,
    double? userLng,
    double? maxPricePerKg,
    double? weightMin,
    double? weightMax,
    bool? kiloProOnly,
    double? minRating,
    bool? weekendOnly,
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
    UrgencyFilter? urgencyFilter,
    double? maxWeight,
    ParcelSize? parcelSize,
    bool? matchingMyTrips,
    bool clearCorridor = false,
    bool clearCustomDate = false,
    bool clearMaxPricePerKg = false,
    bool clearWeight = false,
    bool clearMinRating = false,
    bool clearTransportMode = false,
    bool clearContentType = false,
    bool clearUrgencyFilter = false,
    bool clearMaxWeight = false,
    bool clearParcelSize = false,
    bool clearNearMe = false,
  }) {
    return HomeSearchFilters(
      departureCity: clearCorridor ? null : (departureCity ?? this.departureCity),
      arrivalCity: clearCorridor ? null : (arrivalCity ?? this.arrivalCity),
      datePreset: datePreset ?? this.datePreset,
      customDate: clearCustomDate ? null : (customDate ?? this.customDate),
      urgentOnly: urgentOnly ?? this.urgentOnly,
      nearMeActive: clearNearMe ? false : (nearMeActive ?? this.nearMeActive),
      nearMeRadiusKm: clearNearMe ? null : (nearMeRadiusKm ?? this.nearMeRadiusKm),
      userLat: clearNearMe ? null : (userLat ?? this.userLat),
      userLng: clearNearMe ? null : (userLng ?? this.userLng),
      maxPricePerKg:
          clearMaxPricePerKg ? null : (maxPricePerKg ?? this.maxPricePerKg),
      weightMin: clearWeight ? null : (weightMin ?? this.weightMin),
      weightMax: clearWeight ? null : (weightMax ?? this.weightMax),
      kiloProOnly: kiloProOnly ?? this.kiloProOnly,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      weekendOnly: weekendOnly ?? this.weekendOnly,
      transportMode:
          clearTransportMode ? null : (transportMode ?? this.transportMode),
      kycVerifiedOnly: kycVerifiedOnly ?? this.kycVerifiedOnly,
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      urgencyFilter:
          clearUrgencyFilter ? null : (urgencyFilter ?? this.urgencyFilter),
      maxWeight: clearMaxWeight ? null : (maxWeight ?? this.maxWeight),
      parcelSize: clearParcelSize ? null : (parcelSize ?? this.parcelSize),
      matchingMyTrips: matchingMyTrips ?? this.matchingMyTrips,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/domain/home_search_filters_test.dart`
Expected: PASS, 10 tests.

Run: `flutter analyze lib/features/home/domain/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/domain/ test/features/home/domain/
git commit -m "feat(home): extraire l'état de recherche dans HomeSearchFilters

Objet immuable sans dépendance Flutter portant les filtres communs,
trajets et colis, avec les deux mappings de sortie. Le partage des
communs corrige la perte du corridor au changement de mode."
```

---

### Task 2: Sélecteur de mode

**Files:**
- Create: `lib/features/home/presentation/widgets/search_mode_selector.dart`
- Test: `test/features/home/presentation/widgets/search_mode_selector_test.dart`

**Interfaces:**
- Consumes: `SearchMode` (Task 1).
- Produces: `SearchModeSelector({required SearchMode mode, required ValueChanged<SearchMode> onChanged, int? otherModeCount})`. Le compteur n'est rendu que si `otherModeCount != null && otherModeCount > 0` ; l'appelant décide de le passer ou non selon `hasCommonFilter`.

- [ ] **Step 1: Write the failing test**

Créer `test/features/home/presentation/widgets/search_mode_selector_test.dart` :

```dart
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('affiche les deux segments', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
    )));

    expect(find.text('Trajets'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
  });

  testWidgets('taper sur le segment inactif notifie le nouveau mode', (tester) async {
    SearchMode? recu;
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (m) => recu = m,
    )));

    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(recu, SearchMode.parcels);
  });

  testWidgets('taper sur le segment déjà actif ne notifie pas', (tester) async {
    var appels = 0;
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) => appels++,
    )));

    await tester.tap(find.text('Trajets'));
    await tester.pumpAndSettle();

    expect(appels, 0);
  });

  testWidgets('le compteur est rendu sur le segment inactif', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
      otherModeCount: 8,
    )));

    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('compteur nul ou zéro : rien rendu', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
      otherModeCount: 0,
    )));

    expect(find.text('0'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/presentation/widgets/search_mode_selector_test.dart`
Expected: FAIL — le fichier `search_mode_selector.dart` n'existe pas.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/features/home/presentation/widgets/search_mode_selector.dart`. Reprendre la structure visuelle de `HomeFocusFilter` (`lib/features/home/presentation/widgets/home_focus_filter.dart`), qui sera supprimé en Task 6 : même `ClipRRect` + `BackdropFilter`, même hauteur 44, même `AnimatedContainer` à 200 ms `easeOutCubic` sur le segment actif.

```dart
import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter/material.dart';

/// Sélecteur de mode de la recherche : deux états exclusifs, un toujours actif.
///
/// Premier élément de la rangée de chips, qui défile avec elle. Le compteur
/// [otherModeCount] renseigne sur l'autre mode sans occuper de surface propre ;
/// l'appelant ne le passe que lorsqu'il porte une information, c'est-à-dire
/// quand un filtre commun est posé.
class SearchModeSelector extends StatelessWidget {
  const SearchModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.otherModeCount,
  });

  final SearchMode mode;
  final ValueChanged<SearchMode> onChanged;
  final int? otherModeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(DonyRadius.full),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                label: 'Trajets',
                emoji: '✈️',
                isActive: mode.isTrips,
                badge: mode.isTrips ? null : otherModeCount,
                onTap: () => mode.isTrips ? null : onChanged(SearchMode.trips),
              ),
              _Segment(
                label: 'Colis',
                emoji: '📦',
                isActive: mode.isParcels,
                badge: mode.isParcels ? null : otherModeCount,
                onTap: () =>
                    mode.isParcels ? null : onChanged(SearchMode.parcels),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String emoji;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final showBadge = badge != null && badge! > 0;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label${showBadge ? ', $badge résultats' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isActive ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: DonySpacing.xs),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: DonySpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    '$badge',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/presentation/widgets/search_mode_selector_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/search_mode_selector.dart test/features/home/presentation/widgets/search_mode_selector_test.dart
git commit -m "feat(home): sélecteur de mode à deux états

Un segment toujours actif, compteur optionnel sur le segment inactif.
Reprend l'animation de HomeFocusFilter, qui sera retiré avec le mode Tout."
```

---

### Task 3: Sheet de filtres unifiée

Fusionne `SearchFormBottomSheet` (riche, trajets) et `_showPrFilterSheet` (2 champs, colis) en une sheet dont le bloc haut est littéralement le même widget dans les deux modes.

**Files:**
- Create: `lib/features/home/presentation/widgets/search_filter_sheet.dart`
- Modify: `lib/features/matching/presentation/widgets/search_form_bottom_sheet.dart` — en extraire les sous-widgets réutilisables (`_DateField`, `_WeightField`, `_PriceField`, `_TransportModeField`, les pastilles de filtre rapide) vers `lib/features/home/presentation/widgets/search_filter_fields.dart` pour qu'ils servent aux deux modes
- Create: `lib/features/home/presentation/widgets/search_filter_fields.dart`
- Test: `test/features/home/presentation/widgets/search_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `HomeSearchFilters`, `SearchMode` (Task 1).
- Produces: `SearchFilterSheet.show(BuildContext, {required SearchMode mode, required HomeSearchFilters initial}) → Future<HomeSearchFilters?>` — `null` si l'utilisateur ferme sans valider.

- [ ] **Step 1: Write the failing test**

Créer `test/features/home/presentation/widgets/search_filter_sheet_test.dart` :

```dart
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> ouvrir(
    WidgetTester tester, {
    required SearchMode mode,
    HomeSearchFilters initial = const HomeSearchFilters(),
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () =>
                SearchFilterSheet.show(ctx, mode: mode, initial: initial),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('mode trajets : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Filtrer les trajets'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsOneWidget);
    expect(find.text('KYC vérifié'), findsOneWidget);
  });

  testWidgets('mode colis : titre et filtres spécifiques', (tester) async {
    await ouvrir(tester, mode: SearchMode.parcels);

    expect(find.text('Filtrer les colis'), findsOneWidget);
    expect(find.text('Kilo Pro'), findsNothing);
    expect(find.text('KYC vérifié'), findsNothing);
  });

  testWidgets('le bloc commun est présent dans les deux modes', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await ouvrir(tester, mode: SearchMode.parcels);
    expect(find.text('Ville de départ'), findsOneWidget);
    expect(find.text("Ville d'arrivée"), findsOneWidget);
  });

  testWidgets('le corridor initial est pré-rempli dans les deux modes', (tester) async {
    const initial = HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

    await ouvrir(tester, mode: SearchMode.parcels, initial: initial);

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets('le bouton porte le même libellé dans les deux modes', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);
    expect(find.widgetWithText(ElevatedButton, 'Rechercher'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing);
  });

  testWidgets('« Tout effacer » absent quand aucun filtre actif', (tester) async {
    await ouvrir(tester, mode: SearchMode.trips);

    expect(find.text('Tout effacer'), findsNothing);
  });

  testWidgets('« Tout effacer » présent dès qu'un filtre est actif', (tester) async {
    await ouvrir(
      tester,
      mode: SearchMode.trips,
      initial: const HomeSearchFilters(kiloProOnly: true),
    );

    expect(find.text('Tout effacer'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/presentation/widgets/search_filter_sheet_test.dart`
Expected: FAIL — `search_filter_sheet.dart` n'existe pas.

- [ ] **Step 3: Write minimal implementation**

Lire d'abord `lib/features/matching/presentation/widgets/search_form_bottom_sheet.dart` en entier : les champs `_DateField` (ligne ~918), `_WeightField` (~979), `_PriceField` (~708), `_TransportModeField` (~754) et les pastilles y sont déjà implémentés avec le style attendu. Les déplacer tels quels dans `search_filter_fields.dart` en les rendant publics (retirer le `_` initial), puis construire `SearchFilterSheet` par composition.

Contraintes de structure :

- `DonyBottomSheet.show` avec `stickyBottom: DonyButton(label: 'Rechercher', ...)`. **Jamais** de `DonyButton` dans le `child` scrollable.
- Le bloc commun est **un seul widget** `CommonFilterBlock({required HomeSearchFilters value, required ValueChanged<HomeSearchFilters> onChanged})`, instancié à l'identique dans les deux branches. Ne pas le dupliquer par mode : c'est ce partage qui garantit que le corridor survit.
- L'état local d'édition de la sheet est un `ValueNotifier<HomeSearchFilters>` créé dans `show()` et disposé via `.whenComplete(notifier.dispose)`. Le `stickyBottom` lit ce notifier avec un `ValueListenableBuilder` pour afficher « Tout effacer » et activer le bouton.
- Le mode colis n'expose ni note ni KYC : le back ne les filtre pas sur les demandes.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/presentation/widgets/search_filter_sheet_test.dart`
Expected: PASS, 7 tests.

Run: `flutter test test/features/matching/`
Expected: PASS — les tests existants de `SearchFormBottomSheet` doivent suivre le déplacement des sous-widgets.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/widgets/search_filter_sheet.dart lib/features/home/presentation/widgets/search_filter_fields.dart lib/features/matching/presentation/widgets/search_form_bottom_sheet.dart test/
git commit -m "feat(home): sheet de filtres unique adaptée au mode

Le bloc corridor + date est le même widget dans les deux modes, ce qui rend
le partage réel. Libellé de bouton unifié et « Tout effacer » ajouté côté
colis, absent jusqu'ici."
```

---

### Task 4: Bascule à deux modes dans `home_screen`

Le cœur du chantier : remplacer `HomeMapFocus` par `SearchMode`, brancher `HomeSearchFilters`, retirer le mode « Tout ».

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` — champs d'état (129-178), `_dispatchSearch` (401-428), `_dispatchPackageRequestSearch` (430-445), `_showFilterSheet` / `_showPrFilterSheet` (676-774), `build` (865-1040), `_filterChipsRow` (1351-1520)
- Create: `lib/features/home/presentation/widgets/home_filter_chips_row.dart` — extraction des classes privées `_HomeFilterChipsRow` (2279-2410), `_PackageRequestFilterChipsRow` (3227+) et `_SmallChip` (2413+) de `home_screen.dart`, fusionnées en une seule `HomeFilterChipsRow({required SearchMode mode, required HomeSearchFilters filters, ...})`
- Delete: `lib/features/home/presentation/home_map_focus.dart`
- Delete: `lib/features/home/presentation/widgets/home_focus_filter.dart`
- Delete: `test/features/home/presentation/home_map_focus_test.dart`
- Delete: `test/features/home/presentation/widgets/home_focus_filter_test.dart`
- Modify: `test/features/home/presentation/home_screen_test.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `lib/features/matching/data/datasources/announcement_remote_datasource.dart` et `lib/features/matching/data/repositories/announcement_repository.dart` — voir la note ci-dessous

**Note sur le compteur de trajets.** `searchAnnouncements` renvoie une `List<AnnouncementModel>` construite à partir du seul `content` de la réponse : le `totalElements` est lu puis jeté, et `size` est figé à 20 dans le datasource. Compter les trajets sans charger une page entière n'est donc pas possible en l'état. Ajouter au datasource, puis exposer au repository :

```dart
  /// Nombre de trajets correspondant aux critères, sans charger les résultats.
  /// Lit `totalElements` d'une page de taille 1. Alimente le compteur du
  /// segment inactif du sélecteur de mode.
  Future<int> countAnnouncements({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateFrom,
    DateTime? departureDateTo,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/announcements/search',
      queryParameters: {
        'page': 0,
        'size': 1,
        if (departureCity != null) 'departureCity': departureCity,
        if (arrivalCity != null) 'arrivalCity': arrivalCity,
        if (departureDateFrom != null)
          'departureDateFrom': departureDateFrom.toIso8601String().substring(0, 10),
        if (departureDateTo != null)
          'departureDateTo': departureDateTo.toIso8601String().substring(0, 10),
      },
    );
    return (response.data?['totalElements'] as num?)?.toInt() ?? 0;
  }
```

Vérifier le chemin exact de l'endpoint et la forme du `queryParameters` en relisant `searchAnnouncements` dans le datasource, et reprendre les siens à l'identique.

**Interfaces:**
- Consumes: `HomeSearchFilters`, `SearchMode` (Task 1), `SearchModeSelector` (Task 2), `SearchFilterSheet` (Task 3).
- Produces: `_HomeScreenState._mode` (`SearchMode`, initialisé à `SearchMode.trips`) et `_filters` (`HomeSearchFilters`), qui remplacent les 18 champs de filtre actuels.

- [ ] **Step 1: Write the failing test**

Ajouter à `test/features/home/presentation/home_screen_test.dart`, en reprenant le harnais de pompage et les mocks de BLoC déjà présents dans ce fichier :

```dart
  group('modes de recherche', () {
    testWidgets('ouvre en mode Trajets', (tester) async {
      await pumpHome(tester);

      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('VOYAGEURS DISPONIBLES'), findsOneWidget);
    });

    testWidgets('le mode Colis est proposé à tout utilisateur', (tester) async {
      // Anciennement conditionné à isTraveler. Le rôle voyageur est universel.
      await pumpHome(tester, isTraveler: false);

      expect(find.text('Colis'), findsOneWidget);
    });

    testWidgets('basculer sur Colis change le header de la liste', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text("DEMANDES D'ENVOI"), findsOneWidget);
      expect(find.text('VOYAGEURS DISPONIBLES'), findsNothing);
    });

    testWidgets('le corridor survit à la bascule de mode', (tester) async {
      await pumpHome(tester);
      // Poser Paris → Dakar via la sheet de filtres en mode trajets.
      await ouvrirSheetEtSaisirCorridor(tester, 'Paris', 'Dakar');

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('la bascule dispatche la recherche du nouveau mode', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      verify(() => packageRequestSearchBloc.add(any(that: isA<SearchFiltersChanged>())))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('les chips spécifiques changent avec le mode', (tester) async {
      await pumpHome(tester);
      expect(find.text('Kilo Pro'), findsOneWidget);

      await tester.tap(find.text('Colis'));
      await tester.pumpAndSettle();

      expect(find.text('Kilo Pro'), findsNothing);
      expect(find.text('Taille'), findsOneWidget);
    });

    testWidgets('compteur de l\'autre mode absent sans filtre commun', (tester) async {
      await pumpHome(tester);

      // Aucun corridor ni date posé : le nombre serait un total plateforme.
      expect(find.byKey(const Key('mode-other-count')), findsNothing);
    });
  });
```

Écrire le helper `ouvrirSheetEtSaisirCorridor` dans le même fichier.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/presentation/home_screen_test.dart`
Expected: FAIL — les libellés « Trajets » et « Colis » existent encore sous forme de chips mais la bascule ne change ni le header ni les chips spécifiques.

- [ ] **Step 3: Write minimal implementation**

Dans `home_screen.dart` :

1. Remplacer les 18 champs de filtre (`_corridor`, `_allCorridors`, `_kiloProOnly`, `_minRating`, `_weightMin`, `_weightMax`, `_maxPricePerKg`, `_weekendOnly`, `_transportMode`, `_kycVerifiedOnly`, `_contentType`, `_urgencyFilter`, `_datePreset`, `_customDate`, `_urgentOnly`, `_prDeparture`, `_prArrival`, `_prDateFrom`, `_prDateTo`, `_prMaxWeight`, `_prParcelSize`) par :

```dart
  SearchMode _mode = SearchMode.trips;
  HomeSearchFilters _filters = const HomeSearchFilters();

  /// Nombre de résultats de l'autre mode, pour le compteur du segment inactif.
  /// Null tant qu'aucun filtre commun n'est posé, le total serait alors un
  /// nombre plateforme sans valeur informative.
  int? _otherModeCount;
```

2. `_dispatchSearch` et `_dispatchPackageRequestSearch` consomment `_filters.toSearchParams()` et `_filters.toPackageRequestQuery()`.

3. Ajouter le dispatch du compteur de l'autre mode, en `size: 1` :

```dart
  /// Compteur de l'autre mode, sans charger les résultats : on ne lit que le
  /// total de la page. Une requête légère, pas une seconde recherche.
  ///
  /// Appel direct au repository plutôt qu'au BLoC de recherche : l'état de ce
  /// dernier porte les résultats affichés, et y injecter une page de taille 1
  /// écraserait la liste à l'écran.
  Future<void> _dispatchOtherModeCount() async {
    if (!_filters.hasCommonFilter) {
      if (mounted) setState(() => _otherModeCount = null);
      return;
    }
    try {
      final int total;
      if (_mode.isTrips) {
        // Mode courant trajets : on compte les colis.
        final q = _filters.toPackageRequestQuery();
        final page = await getIt<PackageRequestRepository>().search(
          departure: q.departure,
          arrival: q.arrival,
          dateFrom: q.dateFrom,
          dateTo: q.dateTo,
          page: 0,
          size: 1,
        );
        total = page.totalElements;
      } else {
        // Mode courant colis : on compte les trajets.
        total = await getIt<AnnouncementRepository>().countAnnouncements(
          departureCity: _filters.departureCity,
          arrivalCity: _filters.arrivalCity,
          departureDateFrom: _filters.dateFrom,
          departureDateTo: _filters.dateTo,
        );
      }
      if (mounted) setState(() => _otherModeCount = total);
    } catch (_) {
      // Le compteur est une aide à la découverte, jamais un bloquant :
      // en cas d'échec on le masque au lieu de remonter une erreur.
      if (mounted) setState(() => _otherModeCount = null);
    }
  }
```

4. `_onModeChanged` :

```dart
  void _onModeChanged(SearchMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    unawaited(getIt<AnalyticsService>().logEvent(
      AnalyticsEvents.homeSearchModeChanged,
      properties: {'mode': mode.name},
    ));
    _dispatchForMode();
    _dispatchOtherModeCount();
  }
```

5. `build` : `homeMapVisibility` disparaît, remplacé par `_mode.isTrips` / `_mode.isParcels` pour le choix des marqueurs. La branche `showBothTypes` du carousel « Près de moi » et son `DefaultTabController(length: 2)` sont supprimés au profit de la liste unique du mode courant.

6. `_filterChipsRow` : une seule implémentation, `SearchModeSelector` en premier enfant, séparateur, chips communs à `key` stable, puis chips du mode.

7. La barre corridor appelle `SearchFilterSheet.show(ctx, mode: _mode, initial: _filters)` dans les deux modes.

8. Dans `analytics_events.dart` :

```dart
  /// Bascule du sélecteur de mode de la recherche. Propriété `mode` : trips / parcels.
  static const homeSearchModeChanged = 'home_search_mode_changed';

  /// Tap sur la ligne de bascule de l'état vide. Propriétés `from_mode`, `count`.
  static const homeCrossDiscoveryTapped = 'home_cross_discovery_tapped';
```

Retirer `homeColisMatchOpened` et son point d'appel `_openColisMatch`.

9. Supprimer les 4 fichiers listés dans **Files**.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/`
Expected: PASS.

Run: `flutter analyze`
Expected: `No issues found!` — en particulier plus aucune référence à `HomeMapFocus` ou `homeMapVisibility`.

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/home lib/core/services/analytics_events.dart test/features/home
git commit -m "feat(home): deux modes de recherche exclusifs

HomeMapFocus.all et la vue mixte disparaissent, le corridor et la date sont
partagés, le gate isTraveler sur les chips de mode est retiré : le rôle
voyageur est universel côté serveur."
```

---

### Task 5: Découverte croisée dans l'état vide

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` — état vide de `_buildSheet` (~1941-1955)
- Test: `test/features/home/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: `_otherModeCount` et `_onModeChanged` (Task 4).

- [ ] **Step 1: Write the failing test**

```dart
  group('découverte croisée', () {
    testWidgets('0 résultat et autre mode non vide : la ligne est proposée', (tester) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.textContaining('5 colis'), findsOneWidget);
    });

    testWidgets('taper la ligne bascule en conservant le corridor', (tester) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 5);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      await tester.tap(find.textContaining('5 colis'));
      await tester.pumpAndSettle();

      expect(find.text("DEMANDES D'ENVOI"), findsOneWidget);
      expect(find.text('Lyon → Bamako'), findsOneWidget);
    });

    testWidgets('0 résultat des deux côtés : aucune ligne', (tester) async {
      await pumpHome(tester, tripResults: const [], otherModeCount: 0);
      await ouvrirSheetEtSaisirCorridor(tester, 'Lyon', 'Bamako');

      expect(find.textContaining('colis'), findsNothing);
    });

    testWidgets('résultats présents : aucune ligne, le compteur suffit', (tester) async {
      await pumpHome(tester, tripResults: troisTrajets, otherModeCount: 5);

      expect(find.textContaining('5 colis'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/presentation/home_screen_test.dart --name "découverte croisée"`
Expected: FAIL — la ligne n'existe pas.

- [ ] **Step 3: Write minimal implementation**

Dans l'état vide de `_buildSheet`, sous le message existant :

```dart
              if (_otherModeCount != null && _otherModeCount! > 0)
                _CrossDiscoveryTile(
                  key: const Key('cross-discovery'),
                  label: _mode.isTrips
                      ? '$_otherModeCount colis cherchent un voyageur sur ${_corridorLabel}'
                      : '$_otherModeCount voyageurs passent sur ${_corridorLabel}',
                  onTap: () {
                    unawaited(getIt<AnalyticsService>().logEvent(
                      AnalyticsEvents.homeCrossDiscoveryTapped,
                      properties: {
                        'from_mode': _mode.name,
                        'count': _otherModeCount,
                      },
                    ));
                    _onModeChanged(_mode.other);
                  },
                ),
```

Écrire `_CrossDiscoveryTile` dans le même fichier, sur le modèle visuel des cartes existantes : bordure `cs.primary`, fond `cs.primaryContainer`, chevron à droite, hauteur de touche ≥ 44.

Aucun tiret cadratin dans ces libellés.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/home/presentation/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_screen.dart lib/core/services/analytics_events.dart test/features/home/presentation/home_screen_test.dart
git commit -m "feat(home): bascule de mode proposée dans l'état vide

Zéro résultat sur un corridor est le moment où l'autre mode a de la valeur.
La bascule conserve corridor et date."
```

---

### Task 6: Filtre « Pour mes trajets »

**Dépend du déploiement de la Task 5 du plan back.** Vérifier avant de commencer que `GET /package-requests?matchingMyTrips=true` répond sur l'environnement de dev.

**Files:**
- Modify: `lib/features/package_request/data/models/package_request_search_item.dart`
- Modify: `lib/features/package_request/data/package_request_repository.dart:291-327`
- Modify: `lib/features/package_request/bloc/package_request_search_bloc.dart:17-37`
- Modify: `lib/features/home/presentation/home_screen.dart`
- Delete: `lib/features/package_request/presentation/screens/traveler/colis_match_screen.dart`
- Delete: `lib/features/package_request/bloc/trip_matching_bloc.dart`
- Modify: `lib/app/router.dart:1227`
- Modify: `lib/core/di/injection.dart`
- Modify: `lib/features/settings/presentation/screens/notification_settings_screen.dart`
- Modify: `lib/features/settings/bloc/notification_prefs_bloc.dart`
- Test: `test/features/package_request/`, `test/features/home/`, `test/features/settings/`

**Interfaces:**
- Consumes: `GET /package-requests?matchingMyTrips=true` (contrat back), `TripsSummaryCubit.activeTrips`.
- Produces: `PackageRequestSearchItem.matchScore` (`int?`), `.matchedTripId` (`String?`), `.matchedTripDepartureDate` (`DateTime?`).

- [ ] **Step 1: Write the failing test**

Les tests de modèle et de repository vont dans `test/features/package_request/`. `jsonDeBase` est la map JSON d'une demande valide déjà utilisée par les tests existants de `PackageRequestSearchItem` : la reprendre du fichier de test existant plutôt que d'en réécrire une. `capturedQueryParameters()` lit les `queryParameters` du `MockDio` du harnais de test du repository, également déjà en place.

```dart
  group('matchingMyTrips', () {
    test('fromJson lit les trois champs de match', () {
      final item = PackageRequestSearchItem.fromJson({
        ...jsonDeBase,
        'matchScore': 94,
        'matchedTripId': 'b1f0…',
        'matchedTripDepartureDate': '2026-08-12',
      });

      expect(item.matchScore, 94);
      expect(item.matchedTripId, 'b1f0…');
      expect(item.matchedTripDepartureDate, DateTime(2026, 8, 12));
    });

    test('les trois champs sont nuls quand le serveur ne les renvoie pas', () {
      final item = PackageRequestSearchItem.fromJson(jsonDeBase);

      expect(item.matchScore, isNull);
      expect(item.matchedTripId, isNull);
      expect(item.matchedTripDepartureDate, isNull);
    });

    test('le repository n\'envoie jamais matchingMyTrips=false', () async {
      await repository.search(matchingMyTrips: false);

      final query = capturedQueryParameters();
      expect(query.containsKey('matchingMyTrips'), isFalse);
    });

    test('le repository envoie matchingMyTrips=true quand actif', () async {
      await repository.search(matchingMyTrips: true);

      expect(capturedQueryParameters()['matchingMyTrips'], true);
    });
  });
```

Côté widget :

```dart
  testWidgets('chip « Pour mes trajets » désactivé sans trajet actif', (tester) async {
    await pumpHome(tester, activeTrips: 0);
    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pour mes trajets'));
    await tester.pumpAndSettle();

    // Aucune recherche filtrée déclenchée, une explication est affichée.
    verifyNever(() => packageRequestSearchBloc.add(
        any(that: isA<SearchFiltersChanged>().having(
            (e) => e.matchingMyTrips, 'matchingMyTrips', true))));
    expect(find.text('Publier un trajet'), findsOneWidget);
  });

  testWidgets('chip actif avec des trajets : la recherche part filtrée', (tester) async {
    await pumpHome(tester, activeTrips: 2);
    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pour mes trajets'));
    await tester.pumpAndSettle();

    verify(() => packageRequestSearchBloc.add(
        any(that: isA<SearchFiltersChanged>().having(
            (e) => e.matchingMyTrips, 'matchingMyTrips', true)))).called(1);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/ test/features/home/`
Expected: FAIL — `matchingMyTrips` n'existe ni sur le repository, ni sur l'event, ni sur le modèle.

- [ ] **Step 3: Write minimal implementation**

1. `PackageRequestSearchItem` : trois champs nullables, lus dans `fromJson`, ajoutés à `props`.

2. `PackageRequestRepository.search` : paramètre `bool? matchingMyTrips`, avec la même convention que `urgent` :

```dart
      // Filtre « compatibles avec mes trajets » — jamais envoyer false,
      // seulement présent quand le filtre est actif (cf. plan back Task 5).
      if (matchingMyTrips == true) 'matchingMyTrips': true,
```

3. `SearchFiltersChanged` et `PackageRequestSearchState` : champ `matchingMyTrips`, ajouté à `props`, transmis au repository.

4. `home_screen` : chip `🎯 Pour mes trajets` en mode colis, désactivé (`opacity: 0.4`) quand `activeTrips == 0`, avec au tap une `DonyBottomSheet` expliquant la situation et un `DonyButton` « Publier un trajet » en `stickyBottom` qui route vers la création de trajet.

5. Header de la liste quand le filtre est actif : « COLIS SUR TES TRAJETS » et « N résultats · M trajets actifs ». Carte : badge de score et mention du trajet, à partir de `matchScore` et `matchedTripDepartureDate`.

6. Rôle voyageur retiré (`isTraveler == false`) : le tap sur le segment Colis ouvre une explication et route vers les réglages, sans laisser partir la requête qui répondrait 403.

7. Supprimer `ColisMatchScreen`, `TripMatchingBloc`, la route `/package-requests/match` et l'enregistrement DI.

8. Déplacer la cloche : ajouter une ligne « Me prévenir des nouveaux colis compatibles » à `notification_settings_screen.dart`, section « Matchs & enchères », branchée sur `getPackageMatchAlert` / `setPackageMatchAlert` via `NotificationPrefsBloc`. La rappeler dans la sheet de filtres colis sous le filtre 🎯.

9. Analytics : ajouter `homeMatchingTripsFilterToggled = 'home_matching_trips_filter_toggled'` (propriétés `active`, `active_trips`). Rebrancher `trip_matching_viewed` sur `PackageRequestSearchBloc` au chargement d'une recherche filtrée, et `package_match_alert_toggled` sur `NotificationPrefsBloc`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS, 0 rouge.

Run: `flutter analyze`
Expected: `No issues found!` — plus aucune référence à `TripMatchingBloc`, `ColisMatchScreen` ou `/package-requests/match`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(home): « Pour mes trajets » devient un filtre de recherche

Le chip envoie matchingMyTrips=true au lieu de router vers un écran dédié,
qui est supprimé. Désactivé sans trajet actif, avec une explication : sinon
le filtre renvoie zéro sans raison visible. La cloche de notification passe
dans les réglages."
```

---

### Task 7: Couverture, analytics et documentation

- [ ] **Step 1: Vérifier la suite complète**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` puis 0 test rouge.

- [ ] **Step 2: Vérifier la couverture**

Run: `flutter test --coverage`
Puis `genhtml coverage/lcov.info -o coverage/html` et vérifier ≥ 90 % global. Compléter les tests des fichiers touchés si le seuil n'est pas atteint.

- [ ] **Step 3: Mettre à jour la table analytics du CLAUDE.md**

Dans `dony_app/CLAUDE.md`, section « Events actuellement implémentés » :

- Ajouter `home_search_mode_changed`, `home_cross_discovery_tapped`, `home_matching_trips_filter_toggled`.
- Retirer `home_colis_match_opened`.
- Corriger les déclencheurs de `trip_matching_viewed` et `package_match_alert_toggled`, dont les points d'appel ont changé.

- [ ] **Step 4: Documenter la story**

Créer `docs/stories-done/story-recherche-modes-colis-trajets.md` selon le gabarit du `CLAUDE.md` : Résumé, Fichiers créés et modifiés, Comment ça fonctionne (flux utilisateur, BLoC, écrans, appels API), Pièges, Critères d'acceptation, Décisions techniques.

Pièges à consigner : le partage des filtres communs et pourquoi `weightMin` et `maxWeight` restent séparés, la dépendance de la Task 6 au déploiement back, le cas du rôle voyageur retiré, et la condition d'affichage du compteur de l'autre mode.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/stories-done/story-recherche-modes-colis-trajets.md
git commit -m "docs(home): documenter la recherche par mode et mettre à jour les events"
```

---

## Récapitulatif des livrables

| Task | Livrable | Test | Dépend de |
|---|---|---|---|
| 1 | `SearchMode`, `HomeSearchFilters` | 10 tests unitaires | — |
| 2 | `SearchModeSelector` | 5 widget tests | 1 |
| 3 | `SearchFilterSheet` unifiée | 7 widget tests | 1 |
| 4 | Bascule à deux modes, suppression de `all` | tests `home_screen` | 1, 2, 3 |
| 5 | Découverte croisée dans l'état vide | 4 widget tests | 4 |
| 6 | Filtre « Pour mes trajets » | tests modèle, repo, widget | 4 + **back Task 5 déployée** |
| 7 | Couverture, analytics, story | suite complète | 1–6 |

Les tasks 1 à 5 sont livrables sans le back. La task 6 nécessite `matchingMyTrips` déployé.
