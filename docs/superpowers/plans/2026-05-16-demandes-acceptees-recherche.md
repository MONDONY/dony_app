# Refonte onglet « Acceptées » — Recherche + filtre statut — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doter l'onglet « Acceptées » de l'écran Demandes d'une recherche (nom / n° de suivi) et d'un filtre statut, et y rendre visibles tous les statuts post-acceptation.

**Architecture:** Filtrage 100 % côté client (les bids sont déjà chargés par `BidBloc`). Un `BidListFilterCubit` porte l'état de vue (requête + catégorie). L'écran combine `BidBloc` (données) et `BidListFilterCubit` (vue). Carte de bid et badge de statut retravaillés.

**Tech Stack:** Flutter · flutter_bloc · equatable · go_router · widgets design system dony (`DonySearchField`, `DonyChip`, `DonyAvatar`).

**Spec de référence :** `docs/superpowers/specs/2026-05-16-demandes-acceptees-recherche-design.md`

---

## Structure des fichiers

| Fichier | Responsabilité |
|---------|----------------|
| `lib/features/matching/bloc/bid_list_filter_cubit.dart` | **Créer** — état de vue (requête + filtre) + helpers purs de filtrage (statuts, normalisation, correspondance recherche) |
| `lib/core/di/injection.dart` | **Modifier** — enregistrer `BidListFilterCubit` |
| `lib/features/matching/presentation/screens/bid_list_screen.dart` | **Modifier** — refonte de l'onglet Acceptées |
| `test/features/matching/bloc/bid_list_filter_cubit_test.dart` | **Créer** — tests unitaires Cubit + helpers |
| `test/features/matching/presentation/bid_list_screen_test.dart` | **Modifier** — tests widget de l'écran refondu |

---

## Task 1 : Baseline — commit du correctif HANDED_OVER existant

L'arbre de travail de la branche `feat/demandes-acceptees-recherche` contient déjà un correctif partiel non commité (`HANDED_OVER` ajouté au filtre `acceptedBids` + badge, et 2 tests dans `bid_list_screen_test.dart`). On le commite pour partir d'un arbre propre. Les tâches suivantes réécrivent ces deux fichiers.

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_list_screen.dart`
- Test: `test/features/matching/presentation/bid_list_screen_test.dart`

- [ ] **Step 1: Vérifier l'état de la branche**

Run: `git branch --show-current`
Expected: `feat/demandes-acceptees-recherche`

- [ ] **Step 2: Lancer les tests existants de l'écran**

Run: `flutter test test/features/matching/presentation/bid_list_screen_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 3: Commit**

```bash
git add lib/features/matching/presentation/screens/bid_list_screen.dart test/features/matching/presentation/bid_list_screen_test.dart
git commit -m "fix(matching): HANDED_OVER visible dans l'onglet Acceptées

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 : `BidListFilterCubit` + helpers de filtrage (TDD)

**Files:**
- Create: `lib/features/matching/bloc/bid_list_filter_cubit.dart`
- Test: `test/features/matching/bloc/bid_list_filter_cubit_test.dart`

- [ ] **Step 1: Écrire le test**

Créer `test/features/matching/bloc/bid_list_filter_cubit_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  required String status,
  String? senderName,
  String? trackingNumber,
  String? rejectionReason,
}) =>
    BidModel(
      id: 'b1',
      announcementId: 'a1',
      senderId: 's1',
      senderName: senderName,
      trackingNumber: trackingNumber,
      rejectionReason: rejectionReason,
      weightKg: 1,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('BidListFilterCubit', () {
    test('état initial : query vide, filtre all', () {
      final cubit = BidListFilterCubit();
      expect(cubit.state, const BidListFilterState());
      expect(cubit.state.query, '');
      expect(cubit.state.filter, AcceptedStatusFilter.all);
      cubit.close();
    });

    blocTest<BidListFilterCubit, BidListFilterState>(
      'setQuery émet le nouvel état',
      build: BidListFilterCubit.new,
      act: (c) => c.setQuery('tra'),
      expect: () => const [BidListFilterState(query: 'tra')],
    );

    blocTest<BidListFilterCubit, BidListFilterState>(
      'setFilter émet le nouvel état',
      build: BidListFilterCubit.new,
      act: (c) => c.setFilter(AcceptedStatusFilter.closed),
      expect: () =>
          const [BidListFilterState(filter: AcceptedStatusFilter.closed)],
    );

    blocTest<BidListFilterCubit, BidListFilterState>(
      "reset revient à l'état initial",
      build: BidListFilterCubit.new,
      seed: () => const BidListFilterState(
          query: 'x', filter: AcceptedStatusFilter.active),
      act: (c) => c.reset(),
      expect: () => const [BidListFilterState()],
    );
  });

  group('isAcceptedTabBid', () {
    test('inclut les statuts actifs et clôturés', () {
      for (final s in [...kActiveBidStatuses, ...kClosedBidStatuses]) {
        expect(isAcceptedTabBid(_bid(status: s)), isTrue, reason: s);
      }
    });

    test('exclut PENDING / REJECTED', () {
      expect(isAcceptedTabBid(_bid(status: 'PENDING')), isFalse);
      expect(isAcceptedTabBid(_bid(status: 'REJECTED')), isFalse);
    });

    test('exclut CANCELLED auto-annulé (TRAVELER_NO_RESPONSE)', () {
      expect(
        isAcceptedTabBid(_bid(
            status: 'CANCELLED', rejectionReason: 'TRAVELER_NO_RESPONSE')),
        isFalse,
      );
    });

    test('inclut CANCELLED post-acceptation (autre motif ou nul)', () {
      expect(
        isAcceptedTabBid(
            _bid(status: 'CANCELLED', rejectionReason: 'TRIP_CANCELLED')),
        isTrue,
      );
      expect(isAcceptedTabBid(_bid(status: 'CANCELLED')), isTrue);
    });
  });

  group('normalizeSearch', () {
    test('minuscule + suppression des accents', () {
      expect(normalizeSearch('Moussa TRAORÉ'), 'moussa traore');
      expect(normalizeSearch('Aïcha Côté'), 'aicha cote');
    });

    test('préserve la longueur (1 char → 1 char)', () {
      const s = 'Éàçùî';
      expect(normalizeSearch(s).length, s.length);
    });
  });

  group('bidMatchesQuery', () {
    test('requête vide ou espaces → match', () {
      expect(bidMatchesQuery(_bid(status: 'ACCEPTED'), ''), isTrue);
      expect(bidMatchesQuery(_bid(status: 'ACCEPTED'), '   '), isTrue);
    });

    test('match par nom, insensible casse/accents', () {
      final b = _bid(status: 'ACCEPTED', senderName: 'Moussa Traoré');
      expect(bidMatchesQuery(b, 'TRAORE'), isTrue);
      expect(bidMatchesQuery(b, 'mou'), isTrue);
      expect(bidMatchesQuery(b, 'diallo'), isFalse);
    });

    test('match par numéro de suivi', () {
      final b = _bid(
          status: 'ACCEPTED', senderName: 'X', trackingNumber: 'DNY-4815');
      expect(bidMatchesQuery(b, 'dny-48'), isTrue);
      expect(bidMatchesQuery(b, '4815'), isTrue);
      expect(bidMatchesQuery(b, '9999'), isFalse);
    });

    test('trackingNumber nul → pas de crash, pas de match numéro', () {
      final b = _bid(status: 'ACCEPTED', senderName: 'X', trackingNumber: null);
      expect(bidMatchesQuery(b, 'dny'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Lancer le test — il échoue**

Run: `flutter test test/features/matching/bloc/bid_list_filter_cubit_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'bid_list_filter_cubit.dart'`

- [ ] **Step 3: Créer le Cubit + helpers**

Créer `lib/features/matching/bloc/bid_list_filter_cubit.dart` :

```dart
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Groupes de statuts ────────────────────────────────────────────────────────

/// Statuts d'un bid « actif » dans l'onglet Acceptées.
const kActiveBidStatuses = <String>{
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'COMPLETED',
};

/// Statuts d'un bid « clôturé » dans l'onglet Acceptées.
const kClosedBidStatuses = <String>{
  'NO_SHOW',
  'PARCEL_REFUSED',
  'CANCELLED',
};

/// `true` si le bid doit figurer dans l'onglet « Acceptées ».
///
/// Exclut les `CANCELLED` auto-annulés (`rejectionReason == TRAVELER_NO_RESPONSE`) :
/// ce sont des bids PENDING jamais traités par le voyageur — jamais acceptés.
bool isAcceptedTabBid(BidModel bid) {
  if (bid.status == 'CANCELLED' &&
      bid.rejectionReason == 'TRAVELER_NO_RESPONSE') {
    return false;
  }
  return kActiveBidStatuses.contains(bid.status) ||
      kClosedBidStatuses.contains(bid.status);
}

bool isActiveBid(BidModel bid) => kActiveBidStatuses.contains(bid.status);

bool isClosedBid(BidModel bid) => kClosedBidStatuses.contains(bid.status);

// ── Normalisation de recherche ────────────────────────────────────────────────

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

/// Minuscule + suppression des diacritiques. Préserve la longueur (1 char → 1 char),
/// ce qui garantit que les index de correspondance restent valides sur la chaîne
/// d'origine (utilisé pour le surlignage).
String normalizeSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacriticsMap[ch] ?? ch);
  }
  return buffer.toString();
}

/// `true` si le bid correspond à la requête (nom de l'expéditeur ou n° de suivi).
bool bidMatchesQuery(BidModel bid, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  final name = normalizeSearch(bid.resolvedSenderName);
  final track = normalizeSearch(bid.trackingNumber ?? '');
  return name.contains(q) || track.contains(q);
}

// ── État de filtre ────────────────────────────────────────────────────────────

enum AcceptedStatusFilter { all, active, closed }

class BidListFilterState extends Equatable {
  final String query;
  final AcceptedStatusFilter filter;

  const BidListFilterState({
    this.query = '',
    this.filter = AcceptedStatusFilter.all,
  });

  BidListFilterState copyWith({
    String? query,
    AcceptedStatusFilter? filter,
  }) =>
      BidListFilterState(
        query: query ?? this.query,
        filter: filter ?? this.filter,
      );

  @override
  List<Object?> get props => [query, filter];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Porte l'état de vue de l'onglet « Acceptées » : requête de recherche et
/// catégorie de filtre. Aucune donnée métier, aucun appel réseau.
class BidListFilterCubit extends Cubit<BidListFilterState> {
  BidListFilterCubit() : super(const BidListFilterState());

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setFilter(AcceptedStatusFilter filter) =>
      emit(state.copyWith(filter: filter));

  void reset() => emit(const BidListFilterState());
}
```

- [ ] **Step 4: Lancer le test — il passe**

Run: `flutter test test/features/matching/bloc/bid_list_filter_cubit_test.dart`
Expected: PASS (tous les tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/bloc/bid_list_filter_cubit.dart test/features/matching/bloc/bid_list_filter_cubit_test.dart
git commit -m "feat(matching): BidListFilterCubit + helpers de filtrage des bids

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 : Enregistrement DI du `BidListFilterCubit`

**Files:**
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 1: Ajouter l'import**

En haut de `lib/core/di/injection.dart`, dans le bloc d'imports `features/matching`, ajouter :

```dart
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
```

- [ ] **Step 2: Enregistrer le Cubit**

Dans `injection.dart`, juste après l'enregistrement de `BidAcceptanceBloc` (`getIt.registerFactory<BidAcceptanceBloc>(...)`), ajouter :

```dart
  getIt.registerFactory<BidListFilterCubit>(
    () => BidListFilterCubit(),
  );
```

- [ ] **Step 3: Vérifier la compilation**

Run: `flutter analyze lib/core/di/injection.dart`
Expected: `No issues found` (ou uniquement des `info` préexistants)

- [ ] **Step 4: Commit**

```bash
git add lib/core/di/injection.dart
git commit -m "chore(di): enregistrer BidListFilterCubit

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 : Tests widget de l'écran refondu (écrire — ils échouent)

On remplace **intégralement** `bid_list_screen_test.dart` par la suite complète. Les tests référencent l'API cible (`BidListScreenTesting` fournit lui-même le `BidListFilterCubit`, recherche, chips, badges `_StatusDot`). Ils échouent jusqu'à la Task 5.

**Files:**
- Test: `test/features/matching/presentation/bid_list_screen_test.dart` (remplacer tout le contenu)

- [ ] **Step 1: Remplacer le contenu du fichier de test**

Remplacer **tout** le contenu de `test/features/matching/presentation/bid_list_screen_test.dart` par :

```dart
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  String? trackingNumber,
  String? rejectionReason,
  DateTime? updatedAt,
}) =>
    BidModel(
      id: id,
      announcementId: 'ann-1',
      senderId: 'sender-1',
      senderName: senderName,
      weightKg: 3,
      pricePerKg: 15,
      contentCategory: 'Vêtements',
      trackingNumber: trackingNumber,
      rejectionReason: rejectionReason,
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: updatedAt ?? DateTime(2026, 5, 1),
    );

Future<void> _pump(
  WidgetTester tester,
  MockBidBloc bidBloc, {
  MockBidAcceptanceBloc? acceptanceBloc,
  int initialTabIndex = 0,
}) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(
                value: acceptanceBloc ?? MockBidAcceptanceBloc()),
          ],
          child: BidListScreenTesting(
            announcementId: 'ann-1',
            initialTabIndex: initialTabIndex,
          ),
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Bid detail ${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/tracking/scan',
        builder: (_, __) => const Scaffold(body: Text('scan')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  await tester.pump();
}

/// Branche un stream de states sur le bloc mocké et renvoie le controller.
StreamController<BidState> _wireStates(
    MockBidBloc bidBloc, WidgetTester tester) {
  final ctrl = StreamController<BidState>.broadcast();
  whenListen(bidBloc, ctrl.stream, initialState: BidInitial());
  return ctrl;
}

void main() {
  setUpAll(() {
    registerFallbackValue(BidListRequested('ann-1'));
  });

  late MockBidBloc bidBloc;
  late MockBidAcceptanceBloc acceptanceBloc;

  setUp(() {
    bidBloc = MockBidBloc();
    acceptanceBloc = MockBidAcceptanceBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
  });

  tearDown(() {
    bidBloc.close();
    acceptanceBloc.close();
  });

  // ── Onglet « En attente » ───────────────────────────────────────────────────

  testWidgets('PAYMENT_ESCROWED apparaît dans « En attente » avec badge et boutons',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PAYMENT_ESCROWED')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paiement reçu'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets('PENDING apparaît dans « En attente » sans badge Paiement reçu',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'PENDING')]));
    await tester.pumpAndSettle();

    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.textContaining('Paiement reçu'), findsNothing);
  });

  testWidgets(
      'PENDING + PAYMENT_ESCROWED comptent dans le compteur « En attente »',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'bid-1'),
      _makeBid(status: 'PAYMENT_ESCROWED', id: 'bid-2'),
      _makeBid(status: 'ACCEPTED', id: 'bid-3'),
    ]));
    await tester.pumpAndSettle();

    // 2 bids en attente → 2 boutons « Accepter » visibles sur l'onglet par défaut.
    expect(find.text('Accepter'), findsNWidgets(2));
  });

  // ── Onglet « Acceptées » — statuts ──────────────────────────────────────────

  testWidgets('les 7 statuts post-acceptation s\'affichent avec le bon libellé',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'HANDED_OVER', id: 'b2'),
      _makeBid(status: 'IN_TRANSIT', id: 'b3'),
      _makeBid(status: 'COMPLETED', id: 'b4'),
      _makeBid(status: 'NO_SHOW', id: 'b5'),
      _makeBid(status: 'PARCEL_REFUSED', id: 'b6'),
      _makeBid(status: 'CANCELLED', id: 'b7'),
    ]));
    await tester.pumpAndSettle();

    // « En attente » vide → onglet « Acceptées » auto-sélectionné.
    expect(find.text('Acceptées (7)'), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    expect(find.text('En transit'), findsOneWidget);
    expect(find.text('Livré'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Colis refusé'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
  });

  testWidgets('CANCELLED auto (TRAVELER_NO_RESPONSE) est exclu de la liste',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(
          status: 'CANCELLED',
          id: 'b2',
          rejectionReason: 'TRAVELER_NO_RESPONSE'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Acceptées (1)'), findsOneWidget);
    expect(find.text('Annulé'), findsNothing);
    expect(find.byType(DonyAvatar), findsOneWidget);
  });

  // ── Recherche ───────────────────────────────────────────────────────────────

  testWidgets('la recherche par nom filtre la liste', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'IN_TRANSIT', id: 'b2', senderName: 'Awa Diop'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('En transit'), findsOneWidget);
    expect(find.text('Accepté'), findsNothing);
  });

  testWidgets('la recherche par numéro de suivi filtre la liste',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(
          status: 'ACCEPTED',
          id: 'b1',
          senderName: 'Moussa Traoré',
          trackingNumber: 'DNY-4815'),
      _makeBid(
          status: 'IN_TRANSIT',
          id: 'b2',
          senderName: 'Awa Diop',
          trackingNumber: 'DNY-9999'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'DNY-48');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('En transit'), findsNothing);
  });

  testWidgets('recherche infructueuse → état vide « Aucun résultat »',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNothing);
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.textContaining('zzz'), findsOneWidget);
  });

  // ── Filtre statut ───────────────────────────────────────────────────────────

  testWidgets('le filtre « Clôturés » n\'affiche que les bids clôturés',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'IN_TRANSIT', id: 'b2'),
      _makeBid(status: 'NO_SHOW', id: 'b3'),
      _makeBid(status: 'CANCELLED', id: 'b4'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clôturés (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsNWidgets(2));
    expect(find.text('Absent'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
    expect(find.text('Accepté'), findsNothing);
    expect(find.text('En transit'), findsNothing);
  });

  testWidgets('le filtre « Actifs » n\'affiche que les bids actifs',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1'),
      _makeBid(status: 'NO_SHOW', id: 'b2'),
      _makeBid(status: 'CANCELLED', id: 'b3'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actifs (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Accepté'), findsOneWidget);
    expect(find.text('Absent'), findsNothing);
  });

  testWidgets('recherche et filtre se cumulent', (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'CANCELLED', id: 'b2', senderName: 'Moussa Diop'),
      _makeBid(status: 'CANCELLED', id: 'b3', senderName: 'Awa Sow'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'moussa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clôturés (1)'));
    await tester.pumpAndSettle();

    // « moussa » → 2 bids ; ∩ « Clôturés » → 1 (Moussa Diop CANCELLED).
    expect(find.byType(DonyAvatar), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
  });

  testWidgets('les compteurs des chips sont recalculés sur la recherche',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'ACCEPTED', id: 'b1', senderName: 'Moussa Traoré'),
      _makeBid(status: 'ACCEPTED', id: 'b2', senderName: 'Moussa Diop'),
      _makeBid(status: 'NO_SHOW', id: 'b3', senderName: 'Awa Sow'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Tous (3)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'moussa');
    await tester.pumpAndSettle();

    expect(find.text('Tous (2)'), findsOneWidget);
    expect(find.text('Actifs (2)'), findsOneWidget);
    expect(find.text('Clôturés (0)'), findsOneWidget);
  });

  // ── Onglet ouvert par défaut ────────────────────────────────────────────────

  testWidgets('auto-sélection de « Acceptées » quand « En attente » est vide',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([_makeBid(status: 'ACCEPTED')]));
    await tester.pumpAndSettle();

    // La barre de recherche n'existe que dans l'onglet « Acceptées ».
    expect(find.byType(DonySearchField), findsOneWidget);
  });

  testWidgets('pas d\'auto-sélection quand « En attente » n\'est pas vide',
      (tester) async {
    final ctrl = _wireStates(bidBloc, tester);
    addTearDown(ctrl.close);

    await _pump(tester, bidBloc, acceptanceBloc: acceptanceBloc);
    ctrl.add(BidListLoaded([
      _makeBid(status: 'PENDING', id: 'b1'),
      _makeBid(status: 'ACCEPTED', id: 'b2'),
    ]));
    await tester.pumpAndSettle();

    // Reste sur l'onglet « En attente » : boutons visibles, pas de recherche.
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.byType(DonySearchField), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer les tests — ils échouent**

Run: `flutter test test/features/matching/presentation/bid_list_screen_test.dart`
Expected: FAIL — `BidListScreenTesting` ne fournit pas `BidListFilterCubit`, `DonySearchField` absent, libellés de badge incorrects, etc.

- [ ] **Step 3: Commit**

```bash
git add test/features/matching/presentation/bid_list_screen_test.dart
git commit -m "test(matching): suite widget de l'onglet Acceptées refondu (échoue)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 : Refonte de `bid_list_screen.dart`

On remplace **intégralement** le fichier. La structure : `BidListScreen` fournit les 3 blocs ; `_BidListView` gère les onglets et l'auto-sélection ; `_AcceptedTab` (nouveau) porte recherche + chips + liste filtrée ; `_BidCard` retravaillée (Option B) ; `_StatusDot` (nouveau) pour les badges.

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_list_screen.dart` (remplacer tout le contenu)

- [ ] **Step 1: Remplacer le contenu du fichier**

Remplacer **tout** le contenu de `lib/features/matching/presentation/screens/bid_list_screen.dart` par :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── Status constants (onglet « En attente ») ──────────────────────────────────
const _kPending         = 'PENDING';
const _kPaymentEscrowed = 'PAYMENT_ESCROWED';
const _kRejected        = 'REJECTED';

// ─────────────────────────────────────────────────────────────────────────────
// BidListScreen — root widget, fournit les BloCs
// ─────────────────────────────────────────────────────────────────────────────

class BidListScreen extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const BidListScreen({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<BidBloc>()..add(BidListRequested(announcementId)),
        ),
        BlocProvider(create: (_) => getIt<BidAcceptanceBloc>()),
        BlocProvider(create: (_) => getIt<BidListFilterCubit>()),
      ],
      child: _BidListView(
        announcementId: announcementId,
        departureCityCode: departureCityCode,
        arrivalCityCode: arrivalCityCode,
        departureDate: departureDate,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

/// Variante de test : `BidBloc` et `BidAcceptanceBloc` doivent être fournis par
/// le contexte parent. `BidListFilterCubit` est créé ici (Cubit déterministe,
/// aucun mock nécessaire). Utilisé uniquement en tests.
@visibleForTesting
class BidListScreenTesting extends StatelessWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const BidListScreenTesting({
    super.key,
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => BidListFilterCubit(),
        child: _BidListView(
          announcementId: announcementId,
          departureCityCode: departureCityCode,
          arrivalCityCode: arrivalCityCode,
          departureDate: departureDate,
          initialTabIndex: initialTabIndex,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidListView — StatefulWidget avec TabController
// ─────────────────────────────────────────────────────────────────────────────

class _BidListView extends StatefulWidget {
  final String announcementId;
  final String? departureCityCode;
  final String? arrivalCityCode;
  final DateTime? departureDate;
  final int initialTabIndex;

  const _BidListView({
    required this.announcementId,
    this.departureCityCode,
    this.arrivalCityCode,
    this.departureDate,
    this.initialTabIndex = 0,
  });

  @override
  State<_BidListView> createState() => _BidListViewState();
}

class _BidListViewState extends State<_BidListView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Bids en cours d'acceptation (requête en vol) — anti double-tap.
  final _processingBidIds = <String>{};

  /// L'auto-sélection d'onglet ne se fait qu'une fois, au premier chargement.
  bool _didAutoSelectTab = false;

  /// Passe à `true` dès que l'utilisateur change d'onglet.
  bool _userSwitchedTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _userSwitchedTab = true;
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildSubtitle() {
    final parts = <String>[];
    if (widget.departureCityCode != null && widget.arrivalCityCode != null) {
      parts.add('${widget.departureCityCode} → ${widget.arrivalCityCode}');
    }
    if (widget.departureDate != null) {
      parts.add(DateFormat('EEE d MMMM', 'fr').format(widget.departureDate!));
    }
    return parts.join(' · ');
  }

  void _addProcessing(String bidId) =>
      setState(() => _processingBidIds.add(bidId));

  void _removeProcessing(String bidId) =>
      setState(() => _processingBidIds.remove(bidId));

  // ── BLoC listeners ─────────────────────────────────────────────────────────

  void _onCashAcceptanceStateChange(
      BuildContext context, acs.BidAcceptanceState state) {
    if (state is acs.BidAccepted) {
      setState(() => _processingBidIds.clear());
      DonySnackbar.show(context,
          message: 'Demande acceptée !', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is acs.BidFailed) {
      setState(() => _processingBidIds.clear());
      DonySnackbar.show(context,
          message: state.message, type: DonySnackbarType.error);
    }
  }

  void _onStateChange(BuildContext context, BidState state) {
    if (state is BidAccepted) {
      _removeProcessing(state.bid.id);
      DonySnackbar.show(context,
          message: 'Demande acceptée !', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidRejected) {
      DonySnackbar.show(context, message: 'Demande refusée.');
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidDeleted) {
      DonySnackbar.show(context,
          message: 'Demande supprimée.', type: DonySnackbarType.success);
      context.read<BidBloc>().add(BidListRequested(widget.announcementId));
    } else if (state is BidNotFound) {
      DonySnackbar.show(
        context,
        message: 'Cette annonce n\'existe plus',
        type: DonySnackbarType.warning,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else if (state is BidError) {
      if (_processingBidIds.isNotEmpty) {
        setState(() => _processingBidIds.clear());
      }
      ErrorPresenter.show(context, state.error);
    }
  }

  /// Bascule sur l'onglet « Acceptées » au premier chargement si « En attente »
  /// est vide et que l'utilisateur n'a pas demandé/choisi un onglet précis.
  void _maybeAutoSelectTab(List<BidModel> pendingBids) {
    if (_didAutoSelectTab) return;
    _didAutoSelectTab = true;
    if (pendingBids.isEmpty &&
        widget.initialTabIndex == 0 &&
        !_userSwitchedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController.index == 0) {
          _tabController.animateTo(1);
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = _buildSubtitle();

    return BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
      listener: _onCashAcceptanceStateChange,
      child: BlocConsumer<BidBloc, BidState>(
        listener: _onStateChange,
        builder: (context, state) {
          final allBids = state is BidListLoaded ? state.bids : <BidModel>[];
          final pendingBids = allBids
              .where((b) =>
                  b.status == _kPending || b.status == _kPaymentEscrowed)
              .toList();
          final acceptedBids = allBids.where(isAcceptedTabBid).toList();

          if (state is BidListLoaded) {
            _maybeAutoSelectTab(pendingBids);
          }

          final isOnPendingTab = _tabController.index == 0;
          final titleCount =
              isOnPendingTab ? pendingBids.length : acceptedBids.length;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                  ),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 20, color: cs.primary),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: 200.ms,
                    child: Text(
                      titleCount > 0
                          ? '$titleCount demande${titleCount > 1 ? 's' : ''}'
                          : 'Demandes',
                      key: ValueKey('${_tabController.index}_$titleCount'),
                      style: tt.headlineLarge,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: DonySpacing.md),
                  child: _ScannerChipButton(
                    onTap: () => context.push('/tracking/scan'),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1 + kTextTabBarHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: cs.primary,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      indicatorColor: cs.primary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: tt.labelLarge,
                      unselectedLabelStyle: tt.labelLarge,
                      tabs: [
                        Tab(
                          text: pendingBids.isNotEmpty
                              ? 'En attente (${pendingBids.length})'
                              : 'En attente',
                        ),
                        Tab(
                          text: acceptedBids.isNotEmpty
                              ? 'Acceptées (${acceptedBids.length})'
                              : 'Acceptées',
                        ),
                      ],
                    ),
                    Divider(height: 1, color: cs.outline),
                  ],
                ),
              ),
            ),
            body: _buildBody(context, state, pendingBids, acceptedBids),
          );
        },
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    BidState state,
    List<BidModel> pendingBids,
    List<BidModel> acceptedBids,
  ) {
    if (state is BidLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary),
      );
    }

    if (state is BidError) {
      return _ErrorView(
        message: ErrorPresenter.resolve(state.error).message,
        onRetry: () => context
            .read<BidBloc>()
            .add(BidListRequested(widget.announcementId)),
      );
    }

    if (state is BidListLoaded) {
      return TabBarView(
        controller: _tabController,
        children: [
          // Tab 0 — En attente
          _PendingTab(
            bids: pendingBids,
            processingBidIds: _processingBidIds,
            onAccept: (bidId) {
              _addProcessing(bidId);
              final bid = pendingBids.firstWhere((b) => b.id == bidId);
              if (bid.paymentMethod == BidPaymentMethod.cash) {
                context
                    .read<BidAcceptanceBloc>()
                    .add(ace.BidAcceptRequested(bidId));
              } else {
                context.read<BidBloc>().add(BidAcceptRequested(bidId));
              }
            },
            onReject: (bidId) => _showRejectDialog(context, bidId),
          ),
          // Tab 1 — Acceptées
          _AcceptedTab(acceptedBids: acceptedBids),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Reject confirmation dialog ─────────────────────────────────────────────

  Future<void> _showRejectDialog(BuildContext context, String bidId) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Refuser cette demande ?',
      message: "L'expéditeur sera informé. Cette action est irréversible.",
      confirmLabel: 'Refuser',
      variant: DonyDialogVariant.destructive,
      icon: Icons.cancel_rounded,
    );
    if (confirmed == true && context.mounted) {
      context.read<BidBloc>().add(BidRejectRequested(bidId));
    }
  }
}
```

(Le fichier continue à l'étape suivante — coller la suite à la fin du même fichier.)

- [ ] **Step 2: Compléter le fichier — onglets et widgets**

Coller la suite, **à la fin du même fichier** `bid_list_screen.dart` :

```dart
// ─────────────────────────────────────────────────────────────────────────────
// _PendingTab — onglet « En attente »
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final List<BidModel> bids;
  final Set<String> processingBidIds;
  final void Function(String bidId) onAccept;
  final void Function(String bidId) onReject;

  const _PendingTab({
    required this.bids,
    required this.processingBidIds,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande en attente',
        description: 'Partagez votre annonce pour recevoir des demandes.',
      ).animate().fadeIn(duration: 300.ms);
    }

    final hp = DonyLayout.hPadding(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hp, DonySpacing.xl, hp, DonySpacing.huge),
      itemCount: bids.length,
      separatorBuilder: (_, __) => const SizedBox(height: DonySpacing.md),
      itemBuilder: (context, i) {
        final bid = bids[i];
        final card = _BidCard(
          bid: bid,
          isProcessing: processingBidIds.contains(bid.id),
          onAccept: () => onAccept(bid.id),
          onReject: () => onReject(bid.id),
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);

        // Swipe-to-delete défensif pour les bids REJECTED (n'apparaissent
        // normalement pas dans cet onglet).
        if (bid.status == _kRejected) {
          return Dismissible(
            key: ValueKey('dismiss_${bid.id}'),
            direction: DismissDirection.endToStart,
            background: _DismissBackground(),
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) => context
                .read<BidBloc>()
                .add(BidTravelerDismissRequested(bid.id)),
            child: card,
          );
        }
        return card;
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Supprimer cette demande ?',
      message:
          'Cette demande refusée sera retirée définitivement de votre liste.',
      confirmLabel: 'Supprimer',
      variant: DonyDialogVariant.destructive,
      icon: Icons.delete_outline_rounded,
    );
    return confirmed == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AcceptedTab — onglet « Acceptées » : recherche + filtre + liste
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptedTab extends StatefulWidget {
  final List<BidModel> acceptedBids;
  const _AcceptedTab({required this.acceptedBids});

  @override
  State<_AcceptedTab> createState() => _AcceptedTabState();
}

class _AcceptedTabState extends State<_AcceptedTab> {
  /// L'animation en cascade ne se joue qu'au premier affichage de la liste,
  /// jamais à chaque frappe de recherche (sinon scintillement).
  bool _hasAnimatedOnce = false;

  @override
  Widget build(BuildContext context) {
    if (widget.acceptedBids.isEmpty) {
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: 'Aucune demande acceptée',
        description: "Vous n'avez accepté aucune demande pour l'instant.",
      ).animate().fadeIn(duration: 300.ms);
    }

    return BlocBuilder<BidListFilterCubit, BidListFilterState>(
      builder: (context, filter) {
        final queryFiltered = widget.acceptedBids
            .where((b) => bidMatchesQuery(b, filter.query))
            .toList();
        final allCount = queryFiltered.length;
        final activeCount = queryFiltered.where(isActiveBid).length;
        final closedCount = queryFiltered.where(isClosedBid).length;

        List<BidModel> displayed;
        switch (filter.filter) {
          case AcceptedStatusFilter.all:
            displayed = queryFiltered;
          case AcceptedStatusFilter.active:
            displayed = queryFiltered.where(isActiveBid).toList();
          case AcceptedStatusFilter.closed:
            displayed = queryFiltered.where(isClosedBid).toList();
        }
        displayed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final animate = !_hasAnimatedOnce;
        if (animate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hasAnimatedOnce = true;
          });
        }

        final hp = DonyLayout.hPadding(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
              hp, DonySpacing.base, hp, DonySpacing.huge),
          children: [
            const _BidSearchField(),
            const SizedBox(height: DonySpacing.md),
            _StatusFilterChips(
              active: filter.filter,
              allCount: allCount,
              activeCount: activeCount,
              closedCount: closedCount,
            ),
            const SizedBox(height: DonySpacing.base),
            if (displayed.isEmpty)
              _SearchEmptyState(query: filter.query)
            else
              for (var i = 0; i < displayed.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        i == displayed.length - 1 ? 0 : DonySpacing.md,
                  ),
                  child: _maybeAnimate(
                    animate,
                    i,
                    _BidCard(
                      bid: displayed[i],
                      isProcessing: false,
                      query: filter.query,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _maybeAnimate(bool animate, int index, Widget card) {
    if (!animate) return card;
    return card
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BidSearchField — barre de recherche (nom / n° de suivi)
// ─────────────────────────────────────────────────────────────────────────────

class _BidSearchField extends StatelessWidget {
  const _BidSearchField();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return DonySearchField(
      hint: 'Nom ou n° de suivi…',
      onChanged: cubit.setQuery,
      onClear: () => cubit.setQuery(''),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusFilterChips — chips Tous / Actifs / Clôturés
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  final AcceptedStatusFilter active;
  final int allCount;
  final int activeCount;
  final int closedCount;

  const _StatusFilterChips({
    required this.active,
    required this.allCount,
    required this.activeCount,
    required this.closedCount,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BidListFilterCubit>();
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: [
        DonyChip(
          label: 'Tous ($allCount)',
          selected: active == AcceptedStatusFilter.all,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.all),
        ),
        DonyChip(
          label: 'Actifs ($activeCount)',
          selected: active == AcceptedStatusFilter.active,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.active),
        ),
        DonyChip(
          label: 'Clôturés ($closedCount)',
          selected: active == AcceptedStatusFilter.closed,
          onTap: () => cubit.setFilter(AcceptedStatusFilter.closed),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchEmptyState — état vide quand recherche/filtre sans résultat
// ─────────────────────────────────────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxl),
      child: Column(
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.inbox_outlined,
            size: 44,
            color: cs.outlineVariant,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            hasQuery ? 'Aucun résultat' : 'Aucun envoi',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            hasQuery
                ? 'Aucun envoi ne correspond à « ${query.trim()} ».'
                : 'Aucun envoi dans cette catégorie.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

(Le fichier continue à l'étape suivante.)

- [ ] **Step 3: Compléter le fichier — carte et badges**

Coller la suite, **à la fin du même fichier** `bid_list_screen.dart` :

```dart
// ─────────────────────────────────────────────────────────────────────────────
// _BidCard — carte de bid (Option B)
// ─────────────────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final BidModel bid;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  /// Requête de recherche courante — pour le surlignage. Vide hors recherche.
  final String query;

  const _BidCard({
    required this.bid,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
    this.query = '',
  });

  bool get _isPending =>
      bid.status == _kPending || bid.status == _kPaymentEscrowed;
  bool get _isPaymentEscrowed => bid.status == _kPaymentEscrowed;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final amount = bid.pricePerKg != null
        ? '${(bid.weightKg * bid.pricePerKg!).toStringAsFixed(0)} €'
        : '—';
    final content = bid.contentCategory ?? bid.description;
    final hasTracking =
        bid.trackingNumber != null && bid.trackingNumber!.isNotEmpty;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: () => context.push('/bids/${bid.id}', extra: bid),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : avatar + identité + montant ──────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyAvatar(name: bid.resolvedSenderName),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: bid.resolvedSenderName,
                          query: query,
                          style: tt.titleLarge,
                        ),
                        if (hasTracking) ...[
                          const SizedBox(height: DonySpacing.xxs),
                          _HighlightedText(
                            text: 'N° ${bid.trackingNumber}',
                            query: query,
                            style: tt.labelSmall
                                ?.copyWith(color: cs.outlineVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MONTANT',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.outlineVariant),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        amount,
                        style: tt.titleLarge?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              // ── Ligne 2 : pastilles méta ───────────────────────────
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  _MetaPill(
                    icon: Icons.scale_outlined,
                    label: '${bid.weightKg.toStringAsFixed(0)} kg',
                  ),
                  if (content != null && content.isNotEmpty)
                    _MetaPill(
                      icon: Icons.inventory_2_outlined,
                      label: content,
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.md),

              Divider(color: cs.outline, height: 1),
              const SizedBox(height: DonySpacing.md),

              // ── Bas : actions OU badge de statut ───────────────────
              if (_isPending && onAccept != null && onReject != null) ...[
                if (_isPaymentEscrowed) ...[
                  _EscrowedHint(),
                  const SizedBox(height: DonySpacing.sm),
                ],
                _PendingActions(
                  isProcessing: isProcessing,
                  onAccept: onAccept!,
                  onReject: onReject!,
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusDot(status: bid.status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HighlightedText — texte avec terme de recherche surligné
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearch(query.trim());
    if (q.isEmpty) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    // normalizeSearch préserve la longueur → les index sont valides sur `text`.
    final idx = normalizeSearch(text).indexOf(q);
    if (idx < 0) {
      return Text(text, style: style, overflow: TextOverflow.ellipsis);
    }
    final cs = Theme.of(context).colorScheme;
    final highlight = (style ?? const TextStyle()).copyWith(
      backgroundColor: cs.warningLight,
      color: cs.onSurface,
      fontWeight: FontWeight.w800,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
              text: text.substring(idx, idx + q.length), style: highlight),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetaPill — pastille discrète (poids, contenu)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingActions — Refuser + Accepter
// ─────────────────────────────────────────────────────────────────────────────

class _PendingActions extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingActions({
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            label: 'Refuser',
            variant: DonyButtonVariant.ghost,
            onPressed: isProcessing ? null : onReject,
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: DonyButton(
            label: 'Accepter',
            isLoading: isProcessing,
            onPressed: isProcessing ? null : onAccept,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EscrowedHint — bandeau « Paiement reçu » (bids PAYMENT_ESCROWED)
// ─────────────────────────────────────────────────────────────────────────────

class _EscrowedHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 14, color: cs.warning),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              '💳 Paiement reçu — en attente de votre réponse',
              style: tt.labelMedium?.copyWith(color: cs.warning),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusDot — badge « point coloré » (statuts post-acceptation)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final (Color color, Color bg, String label) = switch (status) {
      'ACCEPTED' => (cs.success, cs.successLight, 'Accepté'),
      'HANDED_OVER' => (cs.primary, cs.primaryContainer, 'En route'),
      'IN_TRANSIT' => (cs.info, cs.infoLight, 'En transit'),
      'COMPLETED' => (cs.success, cs.successLight, 'Livré'),
      'NO_SHOW' => (cs.warning, cs.warningLight, 'Absent'),
      'PARCEL_REFUSED' => (cs.error, cs.errorLight, 'Colis refusé'),
      'CANCELLED' => (
          cs.onSurfaceVariant,
          cs.surfaceContainerHighest,
          'Annulé'
        ),
      'REJECTED' => (cs.error, cs.errorLight, 'Refusé'),
      _ => (cs.onSurfaceVariant, cs.surfaceContainerHighest, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Text(label, style: tt.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DismissBackground — fond rouge du swipe-to-delete
// ─────────────────────────────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline_rounded,
              color: DonyColors.neutral0, size: 28),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Supprimer',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: DonyColors.neutral0),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ScannerChipButton — chip QR scanner dans l'AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerChipButton extends StatelessWidget {
  const _ScannerChipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 16, color: cs.onSurface),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Scanner',
              style: tt.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorView — état d'erreur avec « Réessayer »
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cs.outlineVariant),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Réessayer',
              onPressed: onRetry,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Vérifier l'analyse statique**

Run: `flutter analyze lib/features/matching/presentation/screens/bid_list_screen.dart`
Expected: `No issues found` (ou uniquement des `info` préexistants, ex. `unnecessary_import`). Corriger toute **erreur** (rouge) avant de continuer.

- [ ] **Step 5: Lancer les tests de l'écran**

Run: `flutter test test/features/matching/presentation/bid_list_screen_test.dart`
Expected: PASS (15 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/screens/bid_list_screen.dart
git commit -m "feat(matching): recherche + filtre statut dans l'onglet Acceptées

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 : Vérification finale (analyse, tests, couverture)

**Files:** aucun fichier modifié — étape de validation.

- [ ] **Step 1: Analyse statique du périmètre**

Run: `flutter analyze lib/features/matching/ test/features/matching/`
Expected: aucune **erreur**. Corriger toute erreur introduite. Les `info` préexistants sont tolérés.

- [ ] **Step 2: Lancer toute la suite de tests matching**

Run: `flutter test test/features/matching/`
Expected: PASS — tous les tests, dont les 2 nouveaux fichiers de cette feature.

- [ ] **Step 3: Lancer la suite complète avec couverture**

Run: `flutter test --coverage`
Expected: PASS. En cas d'échec hors périmètre matching, vérifier qu'il préexistait (`git stash` + run sur `main` si doute) ; sinon corriger.

- [ ] **Step 4: Vérifier la couverture des fichiers de la feature**

Run: `genhtml coverage/lcov.info -o coverage/html` puis ouvrir `coverage/html/index.html`
Expected: `bid_list_filter_cubit.dart` et `bid_list_screen.dart` ≥ 90 %. Si en dessous, ajouter des tests ciblés (cas non couverts : branche `_EscrowedHint`, état d'erreur `_ErrorView`, navigation `onTap` de carte) et recommencer aux Steps 2-3.

- [ ] **Step 5: Commit final éventuel**

Si des tests ont été ajoutés au Step 4 :

```bash
git add test/features/matching/
git commit -m "test(matching): compléter la couverture de l'onglet Acceptées

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (auteur du plan)

**1. Couverture du spec**

| Exigence du spec | Tâche |
|------------------|-------|
| §4.1 Barre de recherche (nom + n° suivi, défile, insensible casse/accents, surlignage, clear) | Task 2 (`bidMatchesQuery`, `normalizeSearch`), Task 5 (`_BidSearchField`, `_HighlightedText`) |
| §4.2 Chips Tous/Actifs/Clôturés + compteurs | Task 5 (`_StatusFilterChips`, `_AcceptedTab`) |
| §4.3 Recherche ∩ filtre | Task 5 (`_AcceptedTab`), test « recherche et filtre se cumulent » |
| §4.4 Onglet par défaut | Task 5 (`_maybeAutoSelectTab`), tests auto-sélection |
| §4.5 Tri `updatedAt` desc | Task 5 (`_AcceptedTab` — `displayed.sort`) |
| §4.6 États vides | Task 5 (`_PendingTab`/`_AcceptedTab` `DonyEmptyState`, `_SearchEmptyState`) |
| §5.1 `BidListFilterCubit` | Task 2 |
| §5.2 Modifs écran + DI | Task 3, Task 5 |
| §5.3 Logique de filtrage | Task 2 (helpers), Task 5 (`_AcceptedTab`) |
| §6.1 Carte Option B | Task 5 (`_BidCard`, `_MetaPill`) |
| §6.2 Badge `_StatusDot` 7 statuts | Task 5 (`_StatusDot`) |
| §6.3 Animation premier affichage uniquement | Task 5 (`_AcceptedTabState._hasAnimatedOnce`) |
| §7.1 Exclusion CANCELLED auto | Task 2 (`isAcceptedTabBid`), test dédié |
| §7.2 Champs nuls | Task 2 (`bidMatchesQuery`), Task 5 (`_BidCard` — `hasTracking`, `content`) |
| §8 Tests ≥ 90 % | Task 2, Task 4, Task 6 |

Aucune exigence sans tâche.

**2. Scan des placeholders** — aucun `TBD`/`TODO` ; tout le code est fourni intégralement.

**3. Cohérence des types** — `BidListFilterState`, `AcceptedStatusFilter`, `isAcceptedTabBid`, `isActiveBid`, `isClosedBid`, `bidMatchesQuery`, `normalizeSearch`, `kActiveBidStatuses`, `kClosedBidStatuses` définis en Task 2 et utilisés tels quels en Task 5. `BidListFilterCubit.setQuery/setFilter` cohérents entre Task 2, 4 et 5. `BidListScreenTesting(announcementId:, initialTabIndex:)` cohérent entre Task 4 (test) et Task 5 (déclaration).

**4. Ambiguïtés** — l'animation en cascade est explicitement bornée au premier affichage via `_hasAnimatedOnce` ; les statuts « actifs/clôturés » sont des `Set` constants uniques (Task 2) référencés partout.

---

## Notes d'exécution

- **Dépôt** : tout se passe dans le dépôt `dony_app/` (imbriqué), branche `feat/demandes-acceptees-recherche`. Ne jamais commiter sur `main`.
- **`find.text` et surlignage** : `_HighlightedText` rend un `Text.rich` quand le terme correspond ; les tests comptent donc les cartes via `find.byType(DonyAvatar)` et identifient les statuts via les libellés de `_StatusDot` (texte simple), jamais via le nom surligné.
- **Hauteur de viewport en test** : `_pump` fixe `physicalSize` à `800×2200` pour que la `ListView` eager construise toutes les cartes (jusqu'à 7) et les rende trouvables.

