# Onglet « Envoyer » — 3 onglets + recherche/filtres — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer l'onglet « Envoyer » de l'expéditeur (dashboard à 3 cartes) en 3 onglets directs (Envois · Demandes · Négos), avec recherche + filtres statut/période sur Envois et recherche sur Demandes/Négos.

**Architecture:** État de filtre porté par des Cubits (jamais `setState`), filtrage 100 % client sur les données déjà chargées (aucun appel réseau ajouté). Navigation entre onglets via `DefaultTabController`/`TabController`. Fonctions de filtrage pures et testables hors widget. Bottom sheets dony avec boutons en `stickyBottom`.

**Tech Stack:** Flutter, flutter_bloc (Cubit), equatable, GetIt, intl, flutter_animate, design system dony (DonySearchField, DonyBottomSheet, DonyButton, DonyCheckbox, DonyChip).

**Spec:** `docs/superpowers/specs/2026-06-03-mes-envois-search-filters-design.md`

---

## File Structure

| Fichier | Responsabilité |
|---------|----------------|
| `lib/core/utils/text_search.dart` | **Créer** — `normalizeSearch` (extrait de `bid_list_filter_cubit.dart`), partagé entre features |
| `lib/core/services/analytics_events.dart` | **Modifier** — ajouter `shipmentFilterApplied` |
| `lib/features/matching/bloc/shipment_filter_cubit.dart` | **Créer** — état + cubit + fonctions pures Envois |
| `lib/features/matching/presentation/widgets/shipment_status_filter_sheet.dart` | **Créer** — sheet statut multi |
| `lib/features/matching/presentation/widgets/shipment_period_filter_sheet.dart` | **Créer** — sheet période |
| `lib/features/matching/presentation/screens/shipment_list_screen.dart` | **Modifier** — filter-first, suppr. onglets/setState |
| `lib/features/matching/bloc/bid_list_filter_cubit.dart` | **Modifier** — importer `normalizeSearch` du core |
| `lib/features/package_request/bloc/request_filter_cubit.dart` | **Créer** — recherche Demandes |
| `lib/features/package_request/bloc/negotiation_filter_cubit.dart` | **Créer** — recherche Négos |
| `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart` | **Modifier** — + recherche, suppr. setState |
| `lib/features/package_request/presentation/screens/shared/my_negotiations_screen.dart` | **Modifier** — + recherche, suppr. setState |
| `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart` | **Modifier** — dashboard → 3 onglets |
| `lib/core/di/injection.dart` | **Modifier** — enregistrer les 3 cubits |
| `dony_app/CLAUDE.md` | **Modifier** — ligne event |

**Réutilisés sans modification de comportement :** `_ShipmentCard`, `_ShipmentListView`, `_ProgressStepper`, `_EmptyView`, `_LoadingView`, `_ErrorView`, `_DeleteBackground` (shipment_list_screen.dart) ; `_RequestCard`, `_StatusBadge` (my_package_requests_screen.dart) ; `_NegoCard`, `_StatusPill` (my_negotiations_screen.dart).

---

## Task 1 : Extraire `normalizeSearch` dans le core

**Files:**
- Create: `lib/core/utils/text_search.dart`
- Modify: `lib/features/matching/bloc/bid_list_filter_cubit.dart`
- Test: `test/core/utils/text_search_test.dart`

- [ ] **Step 1: Vérifier les importeurs actuels**

Run: `grep -rn "normalizeSearch" lib/ test/`
Expected: occurrences uniquement dans `bid_list_filter_cubit.dart` (définition + usage interne). Noter tout autre importeur.

- [ ] **Step 2: Écrire le test**

`test/core/utils/text_search_test.dart` :
```dart
import 'package:dony/core/utils/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeSearch', () {
    test('met en minuscules', () {
      expect(normalizeSearch('DAKAR'), 'dakar');
    });
    test('supprime les diacritiques', () {
      expect(normalizeSearch('Géné Abîmé çà'), 'gene abime ca');
    });
    test('préserve la longueur (1 char -> 1 char)', () {
      expect(normalizeSearch('éàü').length, 3);
    });
    test('chaîne vide -> vide', () {
      expect(normalizeSearch(''), '');
    });
  });
}
```

- [ ] **Step 3: Lancer le test (échoue)**

Run: `flutter test test/core/utils/text_search_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dony/core/utils/text_search.dart'`.

- [ ] **Step 4: Créer le fichier core**

`lib/core/utils/text_search.dart` :
```dart
const _diacriticsMap = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ñ': 'n',
  'ÿ': 'y',
};

/// Minuscule + suppression des diacritiques. Préserve la longueur (1 char -> 1 char).
String normalizeSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacriticsMap[ch] ?? ch);
  }
  return buffer.toString();
}
```

- [ ] **Step 5: Réorienter `bid_list_filter_cubit.dart` vers le core**

Dans `lib/features/matching/bloc/bid_list_filter_cubit.dart` : supprimer le bloc `_diacriticsMap` + la fonction `normalizeSearch` locale, et ajouter en haut :
```dart
import 'package:dony/core/utils/text_search.dart';
export 'package:dony/core/utils/text_search.dart' show normalizeSearch;
```
(L'`export` garde la rétro-compat pour tout importeur existant de `normalizeSearch` via ce fichier.)

- [ ] **Step 6: Lancer les tests (passent)**

Run: `flutter test test/core/utils/text_search_test.dart test/features/matching/bloc/`
Expected: PASS (les tests existants de `bid_list_filter_cubit` continuent de passer — comportement identique).

- [ ] **Step 7: Commit**

```bash
git add lib/core/utils/text_search.dart lib/features/matching/bloc/bid_list_filter_cubit.dart test/core/utils/text_search_test.dart
git commit -m "refactor(core): extrait normalizeSearch dans core/utils/text_search"
```

---

## Task 2 : `ShipmentFilterCubit` + fonctions pures

**Files:**
- Create: `lib/features/matching/bloc/shipment_filter_cubit.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Test: `test/features/matching/bloc/shipment_filter_cubit_test.dart`

- [ ] **Step 1: Ajouter l'event analytics**

Dans `lib/core/services/analytics_events.dart`, ajouter dans la classe (section Bids/Envois) :
```dart
  // Envois
  static const shipmentFilterApplied = 'shipment_filter_applied';
```

- [ ] **Step 2: Écrire les tests**

`test/features/matching/bloc/shipment_filter_cubit_test.dart` :
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? depart = 'Paris',
  String? arrivee = 'Dakar',
  String? recipient,
  String? traveler,
  String? tracking,
  DateTime? departureDate,
  DateTime? createdAt,
}) =>
    BidModel(
      id: 'b-${status}_${depart}_$arrivee',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      departureCity: depart,
      arrivalCity: arrivee,
      recipientName: recipient,
      travelerName: traveler,
      trackingNumber: tracking,
      departureDate: departureDate,
      createdAt: createdAt ?? DateTime(2026, 5, 1),
      paymentMethod: BidPaymentMethod.stripe,
      pricingMode: BidPricingMode.kg,
    );

void main() {
  final now = DateTime(2026, 6, 3, 12);

  group('shipmentMatchesQuery', () {
    test('vide -> tout passe', () {
      expect(shipmentMatchesQuery(_bid(), ''), isTrue);
    });
    test('match ville (accents/casse)', () {
      expect(shipmentMatchesQuery(_bid(arrivee: 'Dákar'), 'dakar'), isTrue);
    });
    test('match destinataire', () {
      expect(shipmentMatchesQuery(_bid(recipient: 'Awa Ndiaye'), 'ndiaye'), isTrue);
    });
    test('match voyageur', () {
      expect(shipmentMatchesQuery(_bid(traveler: 'Modou'), 'modou'), isTrue);
    });
    test('match n° suivi', () {
      expect(shipmentMatchesQuery(_bid(tracking: 'TRK-99'), 'trk-99'), isTrue);
    });
    test('aucune correspondance -> false', () {
      expect(shipmentMatchesQuery(_bid(), 'zzz'), isFalse);
    });
  });

  group('shipmentDateFor', () {
    test('departure utilise departureDate', () {
      final b = _bid(departureDate: DateTime(2026, 5, 10), createdAt: DateTime(2026, 4, 1));
      expect(shipmentDateFor(b, ShipmentPeriodBasis.departure), DateTime(2026, 5, 10));
    });
    test('departure fallback createdAt si null', () {
      final b = _bid(departureDate: null, createdAt: DateTime(2026, 4, 1));
      expect(shipmentDateFor(b, ShipmentPeriodBasis.departure), DateTime(2026, 4, 1));
    });
    test('creation utilise createdAt', () {
      final b = _bid(departureDate: DateTime(2026, 5, 10), createdAt: DateTime(2026, 4, 1));
      expect(shipmentDateFor(b, ShipmentPeriodBasis.creation), DateTime(2026, 4, 1));
    });
  });

  group('rangeForPreset', () {
    test('all -> null', () {
      expect(rangeForPreset(ShipmentPeriodPreset.all, null, now), isNull);
    });
    test('thisMonth -> 1er du mois -> now', () {
      final r = rangeForPreset(ShipmentPeriodPreset.thisMonth, null, now)!;
      expect(r.start, DateTime(2026, 6, 1));
      expect(r.end, now);
    });
    test('thisYear -> 1er janvier', () {
      final r = rangeForPreset(ShipmentPeriodPreset.thisYear, null, now)!;
      expect(r.start, DateTime(2026, 1, 1));
    });
    test('custom -> bornes étendues (fin 23:59:59)', () {
      final custom = DateTimeRange(start: DateTime(2026, 5, 1), end: DateTime(2026, 5, 31));
      final r = rangeForPreset(ShipmentPeriodPreset.custom, custom, now)!;
      expect(r.start, DateTime(2026, 5, 1));
      expect(r.end, DateTime(2026, 5, 31, 23, 59, 59));
    });
    test('custom sans range -> null', () {
      expect(rangeForPreset(ShipmentPeriodPreset.custom, null, now), isNull);
    });
  });

  group('applyShipmentFilters', () {
    final bids = [
      _bid(status: 'ACCEPTED', arrivee: 'Dakar', departureDate: DateTime(2026, 6, 2)),
      _bid(status: 'COMPLETED', arrivee: 'Abidjan', departureDate: DateTime(2026, 5, 2)),
      _bid(status: 'PENDING', arrivee: 'Bamako', departureDate: DateTime(2026, 6, 1)),
    ];
    test('statuts vides -> tout', () {
      expect(applyShipmentFilters(bids, const ShipmentFilterState(), now).length, 3);
    });
    test('filtre statut', () {
      final r = applyShipmentFilters(bids, const ShipmentFilterState(statuses: {'COMPLETED'}), now);
      expect(r.single.status, 'COMPLETED');
    });
    test('filtre recherche', () {
      final r = applyShipmentFilters(bids, const ShipmentFilterState(query: 'bamako'), now);
      expect(r.single.arrivalCity, 'Bamako');
    });
    test('filtre période (ce mois, basé départ) exclut le 2 mai', () {
      final r = applyShipmentFilters(
          bids, const ShipmentFilterState(periodPreset: ShipmentPeriodPreset.thisMonth), now);
      expect(r.every((b) => b.arrivalCity != 'Abidjan'), isTrue);
      expect(r.length, 2);
    });
    test('combinaison statut + période (ET)', () {
      final r = applyShipmentFilters(
          bids,
          const ShipmentFilterState(
              statuses: {'ACCEPTED'}, periodPreset: ShipmentPeriodPreset.thisMonth),
          now);
      expect(r.single.status, 'ACCEPTED');
    });
    test('tri : statut le plus avancé en tête', () {
      final r = applyShipmentFilters(bids, const ShipmentFilterState(), now);
      expect(r.first.status, 'ACCEPTED'); // priorité > PENDING/COMPLETED
    });
  });

  group('ShipmentFilterCubit', () {
    late _MockAnalytics analytics;
    setUp(() {
      analytics = _MockAnalytics();
      when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
          .thenAnswer((_) async {});
    });

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setQuery met à jour query SANS analytics',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.setQuery('dakar'),
      expect: () => [const ShipmentFilterState(query: 'dakar')],
      verify: (_) => verifyNever(
          () => analytics.logEvent(any(), properties: any(named: 'properties'))),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'applyQuickPreset émet l\'event sans le texte',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.applyQuickPreset(kEnvoisEnCours),
      expect: () => [const ShipmentFilterState(statuses: kEnvoisEnCours)],
      verify: (_) => verify(() => analytics.logEvent(
            AnalyticsEvents.shipmentFilterApplied,
            properties: any(
                named: 'properties',
                that: isA<Map>().having((m) => m.containsKey('query'), 'no query', isFalse)),
          )).called(1),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'reset revient à l\'état initial',
      build: () => ShipmentFilterCubit(analytics),
      seed: () => const ShipmentFilterState(query: 'x', statuses: {'ACCEPTED'}),
      act: (c) => c.reset(),
      expect: () => [const ShipmentFilterState()],
    );
  });
}
```

- [ ] **Step 3: Lancer (échoue)**

Run: `flutter test test/features/matching/bloc/shipment_filter_cubit_test.dart`
Expected: FAIL — `shipment_filter_cubit.dart` n'existe pas.

- [ ] **Step 4: Implémenter le cubit + fonctions pures**

`lib/features/matching/bloc/shipment_filter_cubit.dart` :
```dart
import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange, DateUtils;
import 'package:flutter_bloc/flutter_bloc.dart';

enum ShipmentPeriodBasis { departure, creation }

enum ShipmentPeriodPreset { all, thisWeek, thisMonth, last3Months, thisYear, custom }

/// Groupes de statuts pour les puces rapides (miroir de _populateLists).
const kEnvoisEnCours = <String>{'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT'};
const kEnvoisAVenir = <String>{'PENDING', 'AWAITING_PAYMENT', 'PAYMENT_ESCROWED'};
const kEnvoisPasses = <String>{
  'COMPLETED', 'REJECTED', 'CANCELLED', 'NO_SHOW', 'EXPIRED', 'PARCEL_REFUSED'
};

const _statusPriority = {
  'IN_TRANSIT': 6, 'HANDED_OVER': 5, 'ACCEPTED': 4,
  'PAYMENT_ESCROWED': 3, 'AWAITING_PAYMENT': 2, 'PENDING': 1, 'COMPLETED': 0,
};

// ── État ────────────────────────────────────────────────────────────────────
class ShipmentFilterState extends Equatable {
  final String query;
  final Set<String> statuses; // {} = tous
  final ShipmentPeriodBasis periodBasis;
  final ShipmentPeriodPreset periodPreset;
  final DateTimeRange? customRange;

  const ShipmentFilterState({
    this.query = '',
    this.statuses = const {},
    this.periodBasis = ShipmentPeriodBasis.departure,
    this.periodPreset = ShipmentPeriodPreset.all,
    this.customRange,
  });

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      periodPreset != ShipmentPeriodPreset.all;

  ShipmentFilterState copyWith({String? query, Set<String>? statuses}) =>
      ShipmentFilterState(
        query: query ?? this.query,
        statuses: statuses ?? this.statuses,
        periodBasis: periodBasis,
        periodPreset: periodPreset,
        customRange: customRange,
      );

  @override
  List<Object?> get props => [query, statuses, periodBasis, periodPreset, customRange];
}

// ── Fonctions pures ───────────────────────────────────────────────────────────
bool shipmentMatchesQuery(BidModel b, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(b.departureCity) ||
      m(b.arrivalCity) ||
      m(b.recipientName) ||
      m(b.travelerName) ||
      m(b.trackingNumber);
}

DateTime shipmentDateFor(BidModel b, ShipmentPeriodBasis basis) =>
    basis == ShipmentPeriodBasis.departure ? (b.departureDate ?? b.createdAt) : b.createdAt;

DateTimeRange? rangeForPreset(
    ShipmentPeriodPreset preset, DateTimeRange? custom, DateTime now) {
  switch (preset) {
    case ShipmentPeriodPreset.all:
      return null;
    case ShipmentPeriodPreset.thisWeek:
      final monday = DateUtils.dateOnly(now).subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(start: monday, end: now);
    case ShipmentPeriodPreset.thisMonth:
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    case ShipmentPeriodPreset.last3Months:
      return DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now);
    case ShipmentPeriodPreset.thisYear:
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    case ShipmentPeriodPreset.custom:
      if (custom == null) return null;
      return DateTimeRange(
        start: DateUtils.dateOnly(custom.start),
        end: DateTime(custom.end.year, custom.end.month, custom.end.day, 23, 59, 59),
      );
  }
}

List<BidModel> _sortShipments(List<BidModel> bids) {
  bids.sort((a, b) {
    final pa = _statusPriority[a.status] ?? 0;
    final pb = _statusPriority[b.status] ?? 0;
    if (pa != pb) return pb.compareTo(pa);
    final da = a.departureDate ?? DateTime(9999);
    final db = b.departureDate ?? DateTime(9999);
    return da.compareTo(db);
  });
  return bids;
}

List<BidModel> applyShipmentFilters(
    List<BidModel> bids, ShipmentFilterState f, DateTime now) {
  Iterable<BidModel> out = bids;
  if (f.statuses.isNotEmpty) out = out.where((b) => f.statuses.contains(b.status));
  if (f.query.trim().isNotEmpty) out = out.where((b) => shipmentMatchesQuery(b, f.query));
  final range = rangeForPreset(f.periodPreset, f.customRange, now);
  if (range != null) {
    out = out.where((b) {
      final d = shipmentDateFor(b, f.periodBasis);
      return !d.isBefore(range.start) && !d.isAfter(range.end);
    });
  }
  return _sortShipments(out.toList());
}

// ── Cubit ─────────────────────────────────────────────────────────────────────
class ShipmentFilterCubit extends Cubit<ShipmentFilterState> {
  ShipmentFilterCubit(this._analytics) : super(const ShipmentFilterState());
  final AnalyticsService _analytics;

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setStatuses(Set<String> statuses) {
    emit(state.copyWith(statuses: statuses));
    _track();
  }

  void applyQuickPreset(Set<String> group) {
    emit(state.copyWith(statuses: group));
    _track();
  }

  void setPeriod({
    required ShipmentPeriodBasis basis,
    required ShipmentPeriodPreset preset,
    DateTimeRange? range,
  }) {
    emit(ShipmentFilterState(
      query: state.query,
      statuses: state.statuses,
      periodBasis: basis,
      periodPreset: preset,
      customRange: preset == ShipmentPeriodPreset.custom ? range : null,
    ));
    _track();
  }

  void reset() => emit(const ShipmentFilterState());

  void _track() {
    unawaited(_analytics.logEvent(
      AnalyticsEvents.shipmentFilterApplied,
      properties: {
        'has_query': state.query.trim().isNotEmpty,
        'status_count': state.statuses.length,
        'period_preset': state.periodPreset.name,
        'period_basis': state.periodBasis.name,
      },
    ));
  }
}
```

> Note : vérifier les paramètres requis du constructeur `BidModel` réel ; le helper `_bid` du test ne renseigne que les champs utilisés — compléter les `required` manquants si le compilateur les exige.

- [ ] **Step 5: Lancer (passent)**

Run: `flutter test test/features/matching/bloc/shipment_filter_cubit_test.dart`
Expected: PASS (tous les groupes).

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/bloc/shipment_filter_cubit.dart lib/core/services/analytics_events.dart test/features/matching/bloc/shipment_filter_cubit_test.dart
git commit -m "feat(envois): ShipmentFilterCubit + fonctions pures de filtrage"
```

---

## Task 3 : DI — enregistrer `ShipmentFilterCubit`

**Files:**
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 1: Ajouter la factory**

À côté des autres `registerFactory` de la feature matching :
```dart
getIt.registerFactory(() => ShipmentFilterCubit(getIt<AnalyticsService>()));
```
Ajouter l'import :
```dart
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
```

- [ ] **Step 2: Vérifier la compilation**

Run: `flutter analyze lib/core/di/injection.dart`
Expected: 0 erreur.

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/injection.dart
git commit -m "chore(di): enregistre ShipmentFilterCubit"
```

---

## Task 4 : `ShipmentStatusFilterSheet`

**Files:**
- Create: `lib/features/matching/presentation/widgets/shipment_status_filter_sheet.dart`
- Test: `test/features/matching/presentation/shipment_status_filter_sheet_test.dart`

- [ ] **Step 1: Écrire le test widget**

`test/features/matching/presentation/shipment_status_filter_sheet_test.dart` :
```dart
import 'package:dony/features/matching/presentation/widgets/shipment_status_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coche un statut et applique -> retourne le Set', (tester) async {
    Set<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ShipmentStatusFilterSheet.show(context, const {});
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrer par statut'), findsOneWidget);
    await tester.tap(find.text('Livré'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Appliquer'));
    await tester.pumpAndSettle();

    expect(result, contains('COMPLETED'));
  });
}
```

- [ ] **Step 2: Lancer (échoue)**

Run: `flutter test test/features/matching/presentation/shipment_status_filter_sheet_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter le sheet**

`lib/features/matching/presentation/widgets/shipment_status_filter_sheet.dart` :
```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_checkbox.dart';
import 'package:flutter/material.dart';

/// Un statut individuel sélectionnable, groupé pour l'affichage.
class _StatusOption {
  const _StatusOption(this.code, this.label);
  final String code;
  final String label;
}

const _groups = <String, List<_StatusOption>>{
  'En cours': [
    _StatusOption('ACCEPTED', 'Confirmé'),
    _StatusOption('HANDED_OVER', 'En route'),
    _StatusOption('IN_TRANSIT', 'En transit'),
  ],
  'En attente': [
    _StatusOption('PENDING', 'En attente'),
    _StatusOption('AWAITING_PAYMENT', 'À payer'),
    _StatusOption('PAYMENT_ESCROWED', 'Payé'),
  ],
  'Terminés': [
    _StatusOption('COMPLETED', 'Livré'),
  ],
  'Clôturés': [
    _StatusOption('CANCELLED', 'Annulé'),
    _StatusOption('REJECTED', 'Refusé'),
    _StatusOption('NO_SHOW', 'Absent'),
    _StatusOption('EXPIRED', 'Expiré'),
  ],
};

class ShipmentStatusFilterSheet {
  /// Retourne le Set de statuts choisi, ou null si annulé.
  static Future<Set<String>?> show(BuildContext context, Set<String> initial) {
    final selected = ValueNotifier<Set<String>>({...initial});
    return DonyBottomSheet.show<Set<String>>(
      context,
      title: 'Filtrer par statut',
      stickyBottom: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          label: value.isEmpty ? 'Appliquer' : 'Appliquer (${value.length})',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(value),
        ),
      ),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    0, DonySpacing.sm, 0, DonySpacing.xxs),
                child: Text(
                  entry.key.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DonyColors.textHint,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
              for (final opt in entry.value)
                DonyCheckbox(
                  label: opt.label,
                  value: value.contains(opt.code),
                  onChanged: (checked) {
                    final next = {...value};
                    if (checked == true) {
                      next.add(opt.code);
                    } else {
                      next.remove(opt.code);
                    }
                    selected.value = next;
                  },
                ),
            ],
          ],
        ),
      ),
    ).whenComplete(selected.dispose);
  }
}
```

- [ ] **Step 4: Lancer (passe)**

Run: `flutter test test/features/matching/presentation/shipment_status_filter_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/shipment_status_filter_sheet.dart test/features/matching/presentation/shipment_status_filter_sheet_test.dart
git commit -m "feat(envois): ShipmentStatusFilterSheet (statut multi-sélection)"
```

---

## Task 5 : `ShipmentPeriodFilterSheet`

**Files:**
- Create: `lib/features/matching/presentation/widgets/shipment_period_filter_sheet.dart`
- Test: `test/features/matching/presentation/shipment_period_filter_sheet_test.dart`

- [ ] **Step 1: Écrire le test**

`test/features/matching/presentation/shipment_period_filter_sheet_test.dart` :
```dart
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_period_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('choisit un preset + bascule basis -> retourne (basis, preset)',
      (tester) async {
    ShipmentPeriodResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ShipmentPeriodFilterSheet.show(
                context,
                basis: ShipmentPeriodBasis.departure,
                preset: ShipmentPeriodPreset.all,
                range: null,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrer par période'), findsOneWidget);
    await tester.tap(find.text('Ce mois-ci'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date de création'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(result!.preset, ShipmentPeriodPreset.thisMonth);
    expect(result!.basis, ShipmentPeriodBasis.creation);
  });
}
```

- [ ] **Step 2: Lancer (échoue)**

Run: `flutter test test/features/matching/presentation/shipment_period_filter_sheet_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter le sheet**

`lib/features/matching/presentation/widgets/shipment_period_filter_sheet.dart` :
```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:flutter/material.dart';

class ShipmentPeriodResult {
  const ShipmentPeriodResult(this.basis, this.preset, this.range);
  final ShipmentPeriodBasis basis;
  final ShipmentPeriodPreset preset;
  final DateTimeRange? range;
}

const _presetLabels = <ShipmentPeriodPreset, String>{
  ShipmentPeriodPreset.thisWeek: 'Cette semaine',
  ShipmentPeriodPreset.thisMonth: 'Ce mois-ci',
  ShipmentPeriodPreset.last3Months: '3 derniers mois',
  ShipmentPeriodPreset.thisYear: 'Cette année',
  ShipmentPeriodPreset.all: 'Tout',
};

class ShipmentPeriodFilterSheet {
  static Future<ShipmentPeriodResult?> show(
    BuildContext context, {
    required ShipmentPeriodBasis basis,
    required ShipmentPeriodPreset preset,
    required DateTimeRange? range,
  }) {
    final basisN = ValueNotifier(basis);
    final presetN = ValueNotifier(preset);
    final rangeN = ValueNotifier(range);

    return DonyBottomSheet.show<ShipmentPeriodResult>(
      context,
      title: 'Filtrer par période',
      stickyBottom: DonyButton(
        label: 'Appliquer',
        onPressed: () => Navigator.of(context, rootNavigator: true)
            .pop(ShipmentPeriodResult(basisN.value, presetN.value, rangeN.value)),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([basisN, presetN, rangeN]),
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle basis
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F6),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Row(
                  children: [
                    _BasisTab(
                      label: 'Date de départ',
                      active: basisN.value == ShipmentPeriodBasis.departure,
                      onTap: () => basisN.value = ShipmentPeriodBasis.departure,
                    ),
                    _BasisTab(
                      label: 'Date de création',
                      active: basisN.value == ShipmentPeriodBasis.creation,
                      onTap: () => basisN.value = ShipmentPeriodBasis.creation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              // Presets
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: [
                  for (final e in _presetLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: presetN.value == e.key,
                      onSelected: (_) {
                        presetN.value = e.key;
                        if (e.key != ShipmentPeriodPreset.custom) rangeN.value = null;
                      },
                    ),
                  ChoiceChip(
                    label: Text(rangeN.value != null && presetN.value == ShipmentPeriodPreset.custom
                        ? 'Personnalisé ✓'
                        : 'Personnalisé'),
                    selected: presetN.value == ShipmentPeriodPreset.custom,
                    onSelected: (_) async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: rangeN.value,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: Theme.of(ctx)
                                .colorScheme
                                .copyWith(primary: cs.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        rangeN.value = picked;
                        presetN.value = ShipmentPeriodPreset.custom;
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      basisN.dispose();
      presetN.dispose();
      rangeN.dispose();
    });
  }
}

class _BasisTab extends StatelessWidget {
  const _BasisTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? DonyColors.textPrimary : DonyColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer (passe)**

Run: `flutter test test/features/matching/presentation/shipment_period_filter_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/shipment_period_filter_sheet.dart test/features/matching/presentation/shipment_period_filter_sheet_test.dart
git commit -m "feat(envois): ShipmentPeriodFilterSheet (basis + presets + plage perso)"
```

---

## Task 6 : Refonte `shipment_list_screen.dart` (filter-first)

**Files:**
- Modify: `lib/features/matching/presentation/screens/shipment_list_screen.dart`
- Test: `test/features/matching/presentation/shipment_list_screen_test.dart`

**Plan de refonte :**
- Supprimer `enum _Tab`, les champs `_tab/_inProgress/_upcoming/_past`, `_populateLists`, `_buildTabBody`, `_sortBids`, `_statusPriority`, `_EmbeddedTabBar`, `_EmbeddedTab`, et les 3 onglets dans `_DarkHeader`.
- `ShipmentListScreen.build` enveloppe le contenu dans `BlocProvider(create: (_) => getIt<ShipmentFilterCubit>())` et délègue à un nouveau `_ShipmentListContent` (StatefulWidget) qui détient le timer de debounce, `_payingBidId`, le `EnvoisRefreshNotifier` et les `BlocListener`.
- Nouveau `_ShipmentFilterBar` (recherche + sélecteurs + puces rapides + chips actifs + compteur).
- La liste : `BlocBuilder<ShipmentFilterCubit>` + `BlocBuilder<BidBloc>` → `applyShipmentFilters(...)` → `_ShipmentListView` (réutilisé). `onDelete` actif uniquement pour les statuts clôturés/livrés (`kEnvoisPasses`).

- [ ] **Step 1: Écrire les tests widget**

`test/features/matching/presentation/shipment_list_screen_test.dart` :
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}
class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid(String status, String arrivee, {DateTime? departureDate}) => BidModel(
      id: 'b_$arrivee',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      departureCity: 'Paris',
      arrivalCity: arrivee,
      departureDate: departureDate,
      createdAt: DateTime(2026, 5, 1),
      paymentMethod: BidPaymentMethod.stripe,
      pricingMode: BidPricingMode.kg,
    );

void main() {
  late _MockBidBloc bidBloc;
  late _MockAnalytics analytics;

  setUpAll(() async => initializeDateFormatting('fr'));
  setUp(() {
    bidBloc = _MockBidBloc();
    analytics = _MockAnalytics();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
    if (getIt.isRegistered<ShipmentFilterCubit>()) getIt.unregister<ShipmentFilterCubit>();
    getIt.registerFactory(() => ShipmentFilterCubit(analytics));
  });

  Widget subject() => MaterialApp(
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: const ShipmentListBody(),
        ),
      );

  testWidgets('puce rapide « Passés » ne montre que les livrés/clôturés',
      (tester) async {
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([
        BidListLoaded([_bid('ACCEPTED', 'Dakar'), _bid('COMPLETED', 'Abidjan')]),
      ]),
      initialState: BidListLoaded([_bid('ACCEPTED', 'Dakar'), _bid('COMPLETED', 'Abidjan')]),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('Lyon → Abidjan').hitTestable(), findsNothing); // pas de tel bid
    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsNothing);
  });

  testWidgets('recherche filtre la liste après debounce', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar'), _bid('ACCEPTED', 'Bamako')];
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bamako');
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await tester.pumpAndSettle();

    expect(find.text('Paris → Bamako'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsNothing);
  });

  testWidgets('état vide filtré affiche Réinitialiser', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(bidBloc, Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucun envoi ne correspond'), findsOneWidget);
    expect(find.text('Réinitialiser'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer (échoue)**

Run: `flutter test test/features/matching/presentation/shipment_list_screen_test.dart`
Expected: FAIL (compilation/structure : pas encore de filter bar).

- [ ] **Step 3: Réécrire `ShipmentListScreen` + `_ShipmentListContent`**

Remplacer la classe `_ShipmentListScreenState` par : un `ShipmentListScreen.build` qui fournit le cubit, et un `_ShipmentListContent` portant l'état local. Code clé (le reste du fichier — `_ShipmentCard`, `_ShipmentListView`, `_ProgressStepper`, `_DarkHeader` sans onglets, `_EmptyView`, `_LoadingView`, `_ErrorView`, `_DeleteBackground`, `_ctaLabel` — est conservé) :

```dart
class ShipmentListScreen extends StatelessWidget {
  const ShipmentListScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<ShipmentFilterCubit>(),
        child: _ShipmentListContent(embedded: embedded),
      );
}

class ShipmentListBody extends StatelessWidget {
  const ShipmentListBody({super.key});
  @override
  Widget build(BuildContext context) => const ShipmentListScreen(embedded: true);
}

class _ShipmentListContent extends StatefulWidget {
  const _ShipmentListContent({required this.embedded});
  final bool embedded;
  @override
  State<_ShipmentListContent> createState() => _ShipmentListContentState();
}

class _ShipmentListContentState extends State<_ShipmentListContent> {
  late final EnvoisRefreshNotifier _refreshNotifier;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _payingBidId;

  @override
  void initState() {
    super.initState();
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
  }

  void _onTabRefreshRequested() {
    if (mounted) context.read<BidBloc>().add(const BidMyListAutoRefreshRequested());
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250),
        () => context.read<ShipmentFilterCubit>().setQuery(q));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    super.dispose();
  }

  // _startPayment / _presentPaymentSheet : INCHANGÉS (copiés tels quels)
  // ... (conserver le code de paiement existant, y compris setState(_payingBidId)) ...

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BidBloc, BidState>(listener: _onBidState),
        BlocListener<PaymentBloc, PaymentState>(listener: (context, state) async {
          if (state is CheckoutPaymentSheetReady) await _presentPaymentSheet(context, state);
        }),
      ],
      child: BlocBuilder<ShipmentFilterCubit, ShipmentFilterState>(
        builder: (context, filter) => BlocBuilder<BidBloc, BidState>(
          builder: (context, bidState) {
            final hasData = bidState is BidListLoaded;
            final filtered = hasData
                ? applyShipmentFilters(bidState.bids, filter, DateTime.now())
                : <BidModel>[];

            Widget body;
            if (!hasData && (bidState is BidLoading || bidState is BidInitial)) {
              body = const _LoadingView();
            } else if (!hasData && bidState is BidError) {
              body = _ErrorView(message: ErrorPresenter.resolve(bidState.error).message);
            } else if (bidState is BidListLoaded && bidState.bids.isEmpty) {
              body = _EmptyView(
                icon: Icons.local_shipping_outlined,
                title: 'Aucun envoi',
                subtitle: 'Vos colis acceptés par un voyageur apparaîtront ici.',
              );
            } else if (filtered.isEmpty) {
              body = _FilteredEmptyView(
                  onReset: () => context.read<ShipmentFilterCubit>().reset());
            } else {
              body = _ShipmentListView(
                bids: filtered,
                emptyMessage: '',
                emptySubtitle: '',
                emptyIcon: Icons.inbox_rounded,
                hPadding: DonyLayout.hPadding(context),
                payingBidId: _payingBidId,
                onPayTap: _startPayment,
                onRefresh: () async => context
                    .read<BidBloc>()
                    .add(const BidMyListAutoRefreshRequested(force: true)),
                onDelete: (bid) =>
                    context.read<BidBloc>().add(BidDeleteRequested(bid.id)),
              );
            }

            final header = widget.embedded
                ? const SizedBox.shrink()
                : _DarkHeader(total: hasData ? bidState.bids.length : 0);

            return Scaffold(
              backgroundColor: widget.embedded
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF2F1EF),
              body: Column(
                children: [
                  if (!widget.embedded) SafeArea(bottom: false, child: header),
                  _ShipmentFilterBar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    resultCount: filtered.length,
                    hasData: hasData,
                  ),
                  Expanded(child: body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _onBidState(BuildContext context, BidState state) {
    if (state is BidCheckoutReady) {
      context.read<PaymentBloc>().add(BidCheckoutPaymentRequested(
            clientSecret: state.response.clientSecret,
            publishableKey: state.response.publishableKey,
            bidId: state.response.bidId,
          ));
    } else if (state is BidDeleted) {
      DonySnackbar.show(context, message: 'Envoi supprimé', type: DonySnackbarType.success);
      context.read<BidBloc>().add(const BidMyListAutoRefreshRequested(force: true));
    } else if (state is BidError && _payingBidId != null) {
      setState(() => _payingBidId = null);
      ErrorPresenter.show(context, state.error);
    }
  }
}
```

> Le `_ShipmentListView.onDelete` ne doit s'activer que pour les bids clôturés. Comme la liste filtrée peut mélanger les statuts, encapsuler la suppression dans `_ShipmentListView` pour n'autoriser le `Dismissible` que si `kEnvoisPasses.contains(bid.status)`. Adapter `_ShipmentListView` : remplacer `if (onDelete == null) return card;` par `if (onDelete == null || !kEnvoisPasses.contains(bid.status)) return card;`.

- [ ] **Step 4: Écrire `_ShipmentFilterBar` et `_FilteredEmptyView`**

Ajouter dans le même fichier (imports : `shipment_filter_cubit.dart`, `shipment_status_filter_sheet.dart`, `shipment_period_filter_sheet.dart`, `dony_search_field.dart`, `package:flutter/foundation.dart` pour `setEquals`) :

```dart
String? _activeQuickPreset(Set<String> s) {
  if (s.isEmpty) return 'all';
  if (setEquals(s, kEnvoisEnCours)) return 'encours';
  if (setEquals(s, kEnvoisAVenir)) return 'avenir';
  if (setEquals(s, kEnvoisPasses)) return 'passes';
  return null; // sélection custom
}

const _quickPresets = <(String, String, Set<String>)>[
  ('all', 'Tous', {}),
  ('encours', 'En cours', kEnvoisEnCours),
  ('avenir', 'À venir', kEnvoisAVenir),
  ('passes', 'Passés', kEnvoisPasses),
];

class _ShipmentFilterBar extends StatelessWidget {
  const _ShipmentFilterBar({
    required this.controller,
    required this.onQueryChanged,
    required this.resultCount,
    required this.hasData,
  });
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final int resultCount;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShipmentFilterCubit>();
    final filter = context.watch<ShipmentFilterCubit>().state;
    final active = _activeQuickPreset(filter.statuses);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(
          DonySpacing.base, DonySpacing.sm, DonySpacing.base, DonySpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonySearchField(
            hint: 'Ville, destinataire, voyageur…',
            controller: controller,
            onChanged: onQueryChanged,
            onClear: () { controller.clear(); cubit.setQuery(''); },
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              _SelectorButton(
                label: 'Statut',
                onTap: () async {
                  final r = await ShipmentStatusFilterSheet.show(context, filter.statuses);
                  if (r != null) cubit.setStatuses(r);
                },
              ),
              const SizedBox(width: DonySpacing.xs),
              _SelectorButton(
                label: 'Période',
                onTap: () async {
                  final r = await ShipmentPeriodFilterSheet.show(
                    context,
                    basis: filter.periodBasis,
                    preset: filter.periodPreset,
                    range: filter.customRange,
                  );
                  if (r != null) {
                    cubit.setPeriod(basis: r.basis, preset: r.preset, range: r.range);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _quickPresets) ...[
                  DonyChip(
                    label: p.$2,
                    selected: active == p.$1,
                    onTap: () => cubit.applyQuickPreset(p.$3),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                ],
              ],
            ),
          ),
          if (filter.hasActiveFilters) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                Text(
                  hasData ? '$resultCount résultat${resultCount > 1 ? 's' : ''}' : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DonyColors.textMuted, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () { controller.clear(); cubit.reset(); },
                  child: Text(
                    'Réinitialiser',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectorButton extends StatelessWidget {
  const _SelectorButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md, vertical: DonySpacing.sm),
        decoration: BoxDecoration(
          color: DonyColors.textPrimary,
          borderRadius: BorderRadius.circular(DonyRadius.sm + 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 40, color: cs.outline),
            const SizedBox(height: DonySpacing.base),
            Text('Aucun envoi ne correspond à tes filtres',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: DonySpacing.md),
            DonyButton(
                label: 'Réinitialiser',
                variant: DonyButtonVariant.secondary,
                fullWidth: false,
                onPressed: onReset),
          ],
        ),
      ),
    );
  }
}
```

> Adapter `_DarkHeader` : retirer les 3 `_DarkTab` et la ligne de tabs ; remplacer la signature par `_DarkHeader({required int total})` ; conserver le titre « Mes envois » + badge `total` (au lieu de `activeCount`). Supprimer `_DarkTab`.

- [ ] **Step 5: Lancer les tests + analyze**

Run: `flutter test test/features/matching/presentation/shipment_list_screen_test.dart && flutter analyze lib/features/matching/presentation/screens/shipment_list_screen.dart`
Expected: PASS + 0 erreur. Corriger les imports inutilisés / références mortes signalées.

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/screens/shipment_list_screen.dart test/features/matching/presentation/shipment_list_screen_test.dart
git commit -m "feat(envois): liste Envois filter-first (recherche+statut+période, suppr. onglets/setState)"
```

---

## Task 7 : `RequestFilterCubit` + recherche Demandes

**Files:**
- Create: `lib/features/package_request/bloc/request_filter_cubit.dart`
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/features/package_request/bloc/request_filter_cubit_test.dart`

- [ ] **Step 1: Écrire le test cubit**

`test/features/package_request/bloc/request_filter_cubit_test.dart` :
```dart
import 'package:dony/features/package_request/bloc/request_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:flutter_test/flutter_test.dart';

PackageRequest _req({
  String depart = 'Paris',
  String arrivee = 'Dakar',
  ContentCategory cat = ContentCategory.vetements,
  PackageRequestStatus status = PackageRequestStatus.open,
}) =>
    PackageRequest(
      id: 'r_${arrivee}_${status.name}',
      senderId: 's1',
      departureCity: depart,
      arrivalCity: arrivee,
      desiredDate: DateTime(2026, 6, 8),
      dateToleranceDays: 2,
      weightKg: 5,
      contentCategory: cat,
      status: status,
      createdAt: DateTime(2026, 5, 1),
    );

void main() {
  group('requestMatchesQuery', () {
    test('vide -> tout', () => expect(requestMatchesQuery(_req(), ''), isTrue));
    test('ville (accents)', () => expect(requestMatchesQuery(_req(arrivee: 'Dákar'), 'dakar'), isTrue));
    test('catégorie', () => expect(requestMatchesQuery(_req(cat: ContentCategory.documents), 'doc'), isTrue));
    test('rien', () => expect(requestMatchesQuery(_req(), 'zzz'), isFalse));
  });

  group('applyRequestFilters', () {
    final all = [
      _req(arrivee: 'Dakar', status: PackageRequestStatus.open),
      _req(arrivee: 'Abidjan', status: PackageRequestStatus.accepted),
    ];
    test('preset open exclut accepted', () {
      final r = applyRequestFilters(all, const RequestFilterState(preset: RequestQuickFilter.open));
      expect(r.single.arrivalCity, 'Dakar');
    });
    test('preset accepted', () {
      final r = applyRequestFilters(all, const RequestFilterState(preset: RequestQuickFilter.accepted));
      expect(r.single.arrivalCity, 'Abidjan');
    });
    test('recherche + preset (ET)', () {
      final r = applyRequestFilters(all,
          const RequestFilterState(preset: RequestQuickFilter.all, query: 'abidjan'));
      expect(r.single.arrivalCity, 'Abidjan');
    });
  });
}
```

- [ ] **Step 2: Lancer (échoue)**

Run: `flutter test test/features/package_request/bloc/request_filter_cubit_test.dart`
Expected: FAIL — fichier inexistant.

- [ ] **Step 3: Implémenter le cubit**

`lib/features/package_request/bloc/request_filter_cubit.dart` :
```dart
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum RequestQuickFilter { all, open, accepted }

class RequestFilterState extends Equatable {
  final String query;
  final RequestQuickFilter preset;
  const RequestFilterState({this.query = '', this.preset = RequestQuickFilter.all});
  RequestFilterState copyWith({String? query, RequestQuickFilter? preset}) =>
      RequestFilterState(query: query ?? this.query, preset: preset ?? this.preset);
  @override
  List<Object?> get props => [query, preset];
}

bool requestMatchesQuery(PackageRequest r, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  bool m(String s) => normalizeSearch(s).contains(q);
  return m(r.departureCity) || m(r.arrivalCity) || m(r.contentCategory.label);
}

bool requestMatchesPreset(PackageRequest r, RequestQuickFilter preset) => switch (preset) {
      RequestQuickFilter.all => true,
      RequestQuickFilter.open => r.status == PackageRequestStatus.open ||
          r.status == PackageRequestStatus.negotiating,
      RequestQuickFilter.accepted => r.status == PackageRequestStatus.accepted ||
          r.status == PackageRequestStatus.completed,
    };

List<PackageRequest> applyRequestFilters(List<PackageRequest> all, RequestFilterState f) =>
    all.where((r) => requestMatchesPreset(r, f.preset) && requestMatchesQuery(r, f.query)).toList();

class RequestFilterCubit extends Cubit<RequestFilterState> {
  RequestFilterCubit() : super(const RequestFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(RequestQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const RequestFilterState());
}
```

- [ ] **Step 4: Lancer (passe)**

Run: `flutter test test/features/package_request/bloc/request_filter_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: DI**

Dans `injection.dart` : `getIt.registerFactory(() => RequestFilterCubit());` + import.

- [ ] **Step 6: Brancher la recherche dans `my_package_requests_screen.dart`**

Refonte de `_ListContentState` : supprimer `_StatusFilter _filter` + `setState`, fournir `RequestFilterCubit`, ajouter un `DonySearchField` au-dessus du `_FilterRow`, et calculer `filtered` via `applyRequestFilters`. `_FilterRow.current/onChanged` passe de `_StatusFilter` à `RequestQuickFilter` (mapping all/open/accepted ⇒ all/open/accepted). Le `_TextEditingController` + debounce 250 ms (comme Envois). Garder `_FilterEmptyState` ; ajouter cas « aucun résultat pour la recherche ».

Code clé (remplacer `_ListContent`) :
```dart
class _ListContent extends StatefulWidget {
  const _ListContent({required this.showFab});
  final bool showFab;
  @override
  State<_ListContent> createState() => _ListContentState();
}

class _ListContentState extends State<_ListContent> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250),
        () => context.read<RequestFilterCubit>().setQuery(q));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = BlocProvider(
      create: (_) => getIt<RequestFilterCubit>(),
      child: BlocBuilder<RequestFilterCubit, RequestFilterState>(
        builder: (context, filter) =>
            BlocBuilder<PackageRequestBloc, PackageRequestState>(
          builder: (context, state) {
            // loading / error / vide global : INCHANGÉS
            // ...
            final filtered = applyRequestFilters(state.requests, filter);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, 0),
                  child: DonySearchField(
                    hint: 'Ville, catégorie…',
                    controller: _searchController,
                    onChanged: _onQuery,
                    onClear: () {
                      _searchController.clear();
                      context.read<RequestFilterCubit>().setQuery('');
                    },
                  ),
                ),
                _FilterRow(
                  current: filter.preset,
                  total: state.requests.length,
                  openCount: state.requests
                      .where((r) =>
                          r.status == PackageRequestStatus.open ||
                          r.status == PackageRequestStatus.negotiating)
                      .length,
                  acceptedCount: state.requests
                      .where((r) =>
                          r.status == PackageRequestStatus.accepted ||
                          r.status == PackageRequestStatus.completed)
                      .length,
                  onChanged: (p) => context.read<RequestFilterCubit>().setPreset(p),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _FilterEmptyState(preset: filter.preset, hasQuery: filter.query.isNotEmpty)
                      : RefreshIndicator(/* … liste inchangée sur `filtered` … */),
                ),
              ],
            );
          },
        ),
      ),
    );
    // … bloc showFab inchangé …
  }
}
```
Adapter `_FilterRow` (`final RequestQuickFilter current; final ValueChanged<RequestQuickFilter> onChanged;`) et les 3 chips (`RequestQuickFilter.all/open/accepted`). Adapter `_FilterEmptyState` pour accepter `{required RequestQuickFilter preset, required bool hasQuery}` (message « Aucun résultat » si `hasQuery`).

- [ ] **Step 7: Écrire/mettre à jour le widget test**

`test/features/package_request/.../my_package_requests_screen_test.dart` : monter `MyPackageRequestsBody` avec un `PackageRequestBloc` mocké (état `requests` avec 2 villes), taper une recherche, vérifier le filtrage et le cas vide. (Structure identique au test Envois — mock du bloc via `MockBloc`, enregistrement `RequestFilterCubit` dans `getIt`.)

- [ ] **Step 8: Lancer + analyze + commit**

```bash
flutter test test/features/package_request/ && flutter analyze lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart
git add lib/features/package_request/bloc/request_filter_cubit.dart lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart lib/core/di/injection.dart test/features/package_request/
git commit -m "feat(demandes): recherche + RequestFilterCubit (suppr. setState)"
```

---

## Task 8 : `NegotiationFilterCubit` + recherche Négos

**Files:**
- Create: `lib/features/package_request/bloc/negotiation_filter_cubit.dart`
- Modify: `lib/features/package_request/presentation/screens/shared/my_negotiations_screen.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/features/package_request/bloc/negotiation_filter_cubit_test.dart`

- [ ] **Step 1: Écrire le test**

`test/features/package_request/bloc/negotiation_filter_cubit_test.dart` :
```dart
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

NegotiationThread _t({
  String? traveler = 'Awa',
  String? arrivee = 'Dakar',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
}) =>
    NegotiationThread(
      id: 't_${arrivee}_${status.name}',
      packageRequestId: 'p1',
      travelerId: 'v1',
      travelerName: traveler,
      departureCity: 'Paris',
      arrivalCity: arrivee,
      status: status,
      currentPriceEur: 15,
      lastActivityAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 5, 1),
    );

void main() {
  group('negoMatchesQuery', () {
    test('vide -> tout', () => expect(negoMatchesQuery(_t(), ''), isTrue));
    test('voyageur', () => expect(negoMatchesQuery(_t(traveler: 'Modou'), 'modou'), isTrue));
    test('ville', () => expect(negoMatchesQuery(_t(arrivee: 'Bamako'), 'bamako'), isTrue));
    test('rien', () => expect(negoMatchesQuery(_t(), 'zzz'), isFalse));
  });

  group('applyNegotiationFilters', () {
    final all = [
      _t(arrivee: 'Dakar', status: NegotiationThreadStatus.open),
      _t(arrivee: 'Abidjan', status: NegotiationThreadStatus.rejected),
    ];
    test('preset active exclut rejected', () {
      final r = applyNegotiationFilters(all, const NegotiationFilterState(preset: NegoQuickFilter.active));
      expect(r.single.arrivalCity, 'Dakar');
    });
    test('preset terminal', () {
      final r = applyNegotiationFilters(all, const NegotiationFilterState(preset: NegoQuickFilter.terminal));
      expect(r.single.arrivalCity, 'Abidjan');
    });
  });
}
```

- [ ] **Step 2: Lancer (échoue)** — Run: `flutter test test/features/package_request/bloc/negotiation_filter_cubit_test.dart` → FAIL.

- [ ] **Step 3: Implémenter**

`lib/features/package_request/bloc/negotiation_filter_cubit.dart` :
```dart
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NegoQuickFilter { all, active, terminal }

class NegotiationFilterState extends Equatable {
  final String query;
  final NegoQuickFilter preset;
  const NegotiationFilterState({this.query = '', this.preset = NegoQuickFilter.all});
  NegotiationFilterState copyWith({String? query, NegoQuickFilter? preset}) =>
      NegotiationFilterState(query: query ?? this.query, preset: preset ?? this.preset);
  @override
  List<Object?> get props => [query, preset];
}

bool negoMatchesQuery(NegotiationThread t, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(t.travelerName) || m(t.departureCity) || m(t.arrivalCity);
}

bool negoMatchesPreset(NegotiationThread t, NegoQuickFilter preset) => switch (preset) {
      NegoQuickFilter.all => true,
      NegoQuickFilter.active => t.status == NegotiationThreadStatus.open ||
          t.status == NegotiationThreadStatus.awaitingTrip ||
          t.status == NegotiationThreadStatus.awaitingPayment,
      NegoQuickFilter.terminal => t.status == NegotiationThreadStatus.accepted ||
          t.status == NegotiationThreadStatus.rejected ||
          t.status == NegotiationThreadStatus.autoRejected ||
          t.status == NegotiationThreadStatus.expired,
    };

List<NegotiationThread> applyNegotiationFilters(
        List<NegotiationThread> all, NegotiationFilterState f) =>
    all.where((t) => negoMatchesPreset(t, f.preset) && negoMatchesQuery(t, f.query)).toList();

class NegotiationFilterCubit extends Cubit<NegotiationFilterState> {
  NegotiationFilterCubit() : super(const NegotiationFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(NegoQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const NegotiationFilterState());
}
```

- [ ] **Step 4: Lancer (passe)** — `flutter test test/features/package_request/bloc/negotiation_filter_cubit_test.dart` → PASS.

- [ ] **Step 5: DI** — `getIt.registerFactory(() => NegotiationFilterCubit());` + import.

- [ ] **Step 6: Brancher dans `my_negotiations_screen.dart`**

Refonte de `_MyNegotiationsBodyState` : supprimer `_StatusFilter _filter` + `setState`, fournir `NegotiationFilterCubit`, ajouter un `DonySearchField` (« Voyageur, ville… ») au-dessus des chips, `filtered = applyNegotiationFilters(...)`. Mapping presets all/active/terminal ⇒ `NegoQuickFilter`. Debounce 250 ms. `_FilterEmptyState` adapté `{required NegoQuickFilter preset, required bool hasQuery}`.

- [ ] **Step 7: Widget test** — `my_negotiations_screen_test.dart` : recherche filtre la liste ; preset∩recherche ; vide filtré. (Mock `NegotiationListBloc`, `getIt` register `NegotiationFilterCubit`.)

- [ ] **Step 8: Lancer + analyze + commit**

```bash
flutter test test/features/package_request/ && flutter analyze lib/features/package_request/presentation/screens/shared/my_negotiations_screen.dart
git add lib/features/package_request/bloc/negotiation_filter_cubit.dart lib/features/package_request/presentation/screens/shared/my_negotiations_screen.dart lib/core/di/injection.dart test/features/package_request/
git commit -m "feat(negos): recherche + NegotiationFilterCubit (suppr. setState)"
```

---

## Task 9 : `EnvoyerHubScreen` — dashboard → 3 onglets

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart`
- Test: `test/features/package_request/presentation/envoyer_hub_screen_test.dart`

**Plan :** supprimer tout le dashboard (`_activeSection`, `_DashboardHeader`, `_DashboardScrollBody`, `_DemandesCard`/`_EnvoisCard`/`_NegosCard`, `_ActivityHubCard`, `_CountPill`, preview items, `_buildActivityDots`, `_PulseDot`, `_SectionHeader`). Conserver `MultiBlocProvider` + flux « + Nouveau ». Remplacer par `DefaultTabController`/`TabController` + segment + `TabBarView`.

- [ ] **Step 1: Écrire le test**

`test/features/package_request/presentation/envoyer_hub_screen_test.dart` :
```dart
// Monte EnvoyerHubScreen avec PackageRequestBloc, BidBloc, NegotiationListBloc, AuthBloc mockés.
// 1. Les 3 segments « Envois »/« Demandes »/« Négos » sont rendus.
// 2. Au démarrage, le body Envois est affiché (ShipmentListBody présent).
// 3. Tap sur « Demandes » -> MyPackageRequestsBody visible.
// 4. Le bouton « + Nouveau » est présent.
```
(Implémenter ces 4 attentes avec `MockBloc` pour chaque bloc + enregistrement des 3 filter cubits dans `getIt`.)

- [ ] **Step 2: Lancer (échoue)** — FAIL (structure dashboard encore présente).

- [ ] **Step 3: Réécrire `envoyer_hub_screen.dart`**

```dart
class EnvoyerHubScreen extends StatefulWidget {
  const EnvoyerHubScreen({super.key});
  @override
  State<EnvoyerHubScreen> createState() => _EnvoyerHubScreenState();
}

class _EnvoyerHubScreenState extends State<EnvoyerHubScreen> {
  @override
  void initState() {
    super.initState();
    getIt<PackageRequestBloc>().add(const FetchMyRequests());
    getIt<NegotiationListBloc>().add(const NegotiationListFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<PackageRequestBloc>()),
        BlocProvider(create: (_) => getIt<BidBloc>()..add(const BidMyListAutoRefreshRequested())),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
      ],
      child: const _EnvoyerTabsView(),
    );
  }
}

class _EnvoyerTabsView extends StatefulWidget {
  const _EnvoyerTabsView();
  @override
  State<_EnvoyerTabsView> createState() => _EnvoyerTabsViewState();
}

class _EnvoyerTabsViewState extends State<_EnvoyerTabsView>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  static const _screens = ['envoyer_envois', 'envoyer_demandes', 'envoyer_negos'];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this)..addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(getIt<AnalyticsService>().logScreen(_screens.first));
    });
  }

  void _onTab() {
    if (!_controller.indexIsChanging) {
      unawaited(getIt<AnalyticsService>().logScreen(_screens[_controller.index]));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTab);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onNew() async {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated
        ? authState.user
        : authState is AuthProfileUpdated
            ? authState.user
            : null;
    if (user == null || !user.isKycVerified) {
      await KycRequiredBottomSheet.show(context, kycStatus: user?.kycStatus ?? 'NOT_STARTED');
      return;
    }
    await PackageRequestCreateWizard.show(context);
    if (mounted) context.read<PackageRequestBloc>().add(const RefreshMyRequests());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EnvoyerHeader(onNew: _onNew),
            _EnvoyerSegmented(controller: _controller),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: const [
                  ShipmentListBody(),
                  MyPackageRequestsBody(),
                  MyNegotiationsBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`_EnvoyerHeader` : titre « Envoyer » (28/w800) + bouton « + Nouveau » (réutiliser le visuel pill vert existant du `_DashboardHeader`, l'extraire en `_EnvoyerHeader`).

`_EnvoyerSegmented` : 3 segments avec compteurs via les 3 `BlocBuilder` (mêmes calculs que l'ancien `_DashboardHeader` : envois actifs / demandes actives / `negoState.activeCount`), `AnimatedBuilder(animation: controller)`, `onTap: () => controller.animateTo(i)` ; segment actif en vert (réutiliser le style `_CountPill`/segment du mockup). Conserver le `_PulseDot` sur Négos si `activeCount > 0` (optionnel).

- [ ] **Step 4: Lancer le test + analyze**

Run: `flutter test test/features/package_request/presentation/envoyer_hub_screen_test.dart && flutter analyze lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart`
Expected: PASS + 0 erreur (supprimer tout code mort du dashboard).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/screens/sender/envoyer_hub_screen.dart test/features/package_request/presentation/envoyer_hub_screen_test.dart
git commit -m "feat(envoyer): hub 3 onglets (Envois/Demandes/Négos) — remplace le dashboard"
```

---

## Task 10 : Analytics doc + vérification globale

**Files:**
- Modify: `dony_app/CLAUDE.md`

- [ ] **Step 1: Mettre à jour la table d'events**

Dans `dony_app/CLAUDE.md`, section « Events actuellement implémentés », ajouter :
```
| `shipment_filter_applied` | ShipmentFilterCubit (statut/période/preset) |
```
Et noter le `logScreen` par onglet (`envoyer_envois`/`envoyer_demandes`/`envoyer_negos`) dans la même section.

- [ ] **Step 2: Analyze global**

Run: `flutter analyze`
Expected: 0 erreur, 0 warning lié au code ajouté.

- [ ] **Step 3: Tests + couverture**

Run: `flutter test --coverage`
Expected: tous verts. Vérifier la couverture des nouveaux fichiers ≥ 90 % :
```bash
genhtml coverage/lcov.info -o coverage/html  # optionnel
```
Si un fichier < 90 %, ajouter les tests manquants (branches de `rangeForPreset`, `copyWith`, états vides).

- [ ] **Step 4: Commit**

```bash
git add dony_app/CLAUDE.md
git commit -m "docs(analytics): event shipment_filter_applied + logScreen onglets Envoyer"
```

---

## Self-Review (rempli pendant la rédaction)

**Couverture spec ↔ tasks :**
- Structure 3 onglets → Task 9. Envois recherche/statut/période → Tasks 2,4,5,6. Demandes recherche → Task 7. Négos recherche → Task 8. `normalizeSearch` réutilisé → Task 1. Analytics → Tasks 2,9,10. DI → Tasks 3,7,8. Tests ≥ 90 % → chaque task + Task 10. ✅ Aucune section de spec sans task.

**Cohérence des types :** `ShipmentFilterState`, `ShipmentPeriodBasis/Preset`, `kEnvoisEnCours/AVenir/Passes`, `applyShipmentFilters`, `ShipmentPeriodResult`, `RequestFilterState/RequestQuickFilter/applyRequestFilters`, `NegotiationFilterState/NegoQuickFilter/applyNegotiationFilters` — noms identiques entre définition (Tasks 2,7,8) et usage (Tasks 5,6,7,8). ✅

**Points à valider à l'implémentation (signalés inline) :** champs `required` exacts du constructeur `BidModel`/`PackageRequest`/`NegotiationThread` dans les helpers de test ; nom exact de l'event `BidDeleteRequested` et `BidCheckoutReady`/`CheckoutPaymentSheetReady` (déjà présents dans le fichier d'origine, conservés). Le code de paiement (`_startPayment`/`_presentPaymentSheet`) est copié **tel quel** depuis l'existant (y compris son `setState(_payingBidId)`, hors périmètre).
