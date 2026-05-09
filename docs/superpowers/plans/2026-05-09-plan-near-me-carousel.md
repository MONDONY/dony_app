# NearMeCarousel Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activer le `NearMeCarousel` comme overlay fixe en bas d'écran quand "Près de moi" est actif, remplaçant le `DraggableScrollableSheet`, avec synchronisation bidirectionnelle map↔carousel.

**Architecture:** `_MapSenderViewState` orchestre via les variables d'état existantes `_isNearMeActive` et `_selectedAnnouncementId`. Quand near-me est actif, le `Stack` affiche un `Positioned(bottom: 0)` avec le carousel à la place du `DraggableScrollableSheet`. Le `NearMeCarousel` est refactorisé pour être un widget autonome (suppression de `CustomScrollView + scrollController`).

**Tech Stack:** Flutter BLoC, flutter_animate, GoRouter, geolocator_platform_interface + plugin_platform_interface (tests)

---

### Task 1 — Ajouter le chip "Près de moi" dans `_HomeFilterChipsRow`

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` (classe `_SmallChip` ≈ l. 1735 + classe `_HomeFilterChipsRow.build` ≈ l. 1720)

Les params `isNearMeActive` et `onNearMeTap` sont déjà déclarés dans `_HomeFilterChipsRow` mais le chip n'est pas rendu. Ce task l'ajoute.

- [ ] **Step 1.1 : Ajouter `super.key` au constructeur de `_SmallChip`**

Localiser (≈ l. 1739) :
```dart
  const _SmallChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
```
Remplacer par :
```dart
  const _SmallChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });
```

- [ ] **Step 1.2 : Ajouter le chip "Près de moi" à la fin de la `Row`**

Localiser (≈ l. 1721–1726) :
```dart
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: 'Tous corridors',
            isActive: allCorridors,
            onTap: onAllCorridorsToggle,
          ),
```
Remplacer par :
```dart
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            label: 'Tous corridors',
            isActive: allCorridors,
            onTap: onAllCorridorsToggle,
          ),
          const SizedBox(width: DonySpacing.xs),
          _SmallChip(
            key: const Key('chip-near-me'),
            label: 'Près de moi',
            isActive: isNearMeActive,
            icon: Icons.near_me_rounded,
            onTap: onNearMeTap,
          ),
```

- [ ] **Step 1.3 : Vérifier l'analyse statique**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/home/presentation/home_screen.dart
```
Attendu : aucune erreur ou warning.

- [ ] **Step 1.4 : Commit**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat(home): ajouter le chip 'Près de moi' dans la barre de filtres"
```

---

### Task 2 — Écrire les tests `NearMeCarousel` (TDD — ils échoueront avant Task 3)

**Files:**
- Create: `test/features/matching/presentation/widgets/near_me_carousel_test.dart`

Ces tests définissent l'API POST-refactoring du widget (sans `scrollController`, avec `Key('near-me-card-${a.id}')` sur chaque carte). Ils compilent seulement après Task 3.

- [ ] **Step 2.1 : Créer le fichier de tests**

```dart
// test/features/matching/presentation/widgets/near_me_carousel_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

UserModel _makeUser({String id = 'uid-1'}) => UserModel(
      id: id,
      phoneNumber: '+33600000000',
      firstName: 'Test',
      lastName: 'User',
      roles: ['ROLE_SENDER'],
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

AnnouncementModel _ann(String id, {String travelerId = 'traveler-1'}) =>
    AnnouncementModel(
      id: id,
      travelerId: travelerId,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 6, 15),
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 7,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      traveler: TravelerProfile(
          id: travelerId, displayName: 'Sékou Ba', kiloPro: false),
    );

BidModel _bid({
  required String id,
  required String announcementId,
  String status = 'PENDING',
}) =>
    BidModel(
      id: id,
      announcementId: announcementId,
      senderId: 'uid-1',
      weightKg: 5,
      declaredValueEur: 100,
      description: 'Test',
      status: status,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

Widget _wrap(
  Widget child, {
  BidState? bidState,
  AuthState? authState,
}) {
  final bidBloc = _MockBidBloc();
  final authBloc = _MockAuthBloc();
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state)
      .thenReturn(authState ?? AuthAuthenticated(_makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            Scaffold(body: SizedBox(height: 280, child: child)),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (_, __) => const Scaffold(key: Key('bids-route')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<BidBloc>.value(value: bidBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('1 — affiche un PageView avec autant de pages que d\'annonces',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2'), _ann('a3')];
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(TravelerCard), findsWidgets);
  });

  testWidgets(
      '2 — affiche le bouton "Voir les N annonces" avec le bon compteur',
      (tester) async {
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1'), _ann('a2')],
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Voir les 2 annonces'), findsOneWidget);
  });

  testWidgets('3 — affiche l\'empty state quand announcements est vide',
      (tester) async {
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: const [],
      userPosition: null,
      onSeeAll: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Aucun voyageur à proximité'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets(
      '4 — selectedAnnouncementId initialise le PageController sur la bonne page',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2'), _ann('a3')];
    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
      selectedAnnouncementId: 'a2',
    )));
    await tester.pumpAndSettle();

    // Avec initialPage = 1, la card a2 est la page centrale (viewportFraction 0.85)
    expect(find.byKey(const Key('near-me-card-a2')), findsWidgets);
  });

  testWidgets(
      '5 — onCardChanged est appelé avec le bon id quand on swipe vers la page suivante',
      (tester) async {
    final anns = [_ann('a1'), _ann('a2')];
    String? captured;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: anns,
      userPosition: null,
      onSeeAll: () {},
      onCardChanged: (id) => captured = id,
    )));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(captured, 'a2');
  });

  testWidgets(
      '6 — tap sur une card sans bid invoque onTapCard avec l\'annonce',
      (tester) async {
    AnnouncementModel? tapped;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1')],
      userPosition: null,
      onSeeAll: () {},
      onTapCard: (a) => tapped = a,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-card-a1')));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'a1');
  });

  testWidgets(
      '7 — tap sur une card avec bid PENDING navigue vers /bids/{id}',
      (tester) async {
    final bid = _bid(id: 'bid-1', announcementId: 'a1', status: 'PENDING');

    await tester.pumpWidget(_wrap(
      NearMeCarousel(
        announcements: [_ann('a1')],
        userPosition: null,
        onSeeAll: () {},
      ),
      bidState: BidListLoaded([bid]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-card-a1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bids-route')), findsOneWidget);
  });

  testWidgets('8 — tap sur "Voir tout" invoque onSeeAll', (tester) async {
    bool called = false;

    await tester.pumpWidget(_wrap(NearMeCarousel(
      announcements: [_ann('a1')],
      userPosition: null,
      onSeeAll: () => called = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('near-me-see-all-btn')));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });
}
```

- [ ] **Step 2.2 : Vérifier que les tests échouent (erreur de compilation attendue : `scrollController` manquant)**

```bash
flutter test test/features/matching/presentation/widgets/near_me_carousel_test.dart
```
Attendu : erreur de compilation — `NearMeCarousel` requiert encore `scrollController`.

---

### Task 3 — Refactoriser `NearMeCarousel` (supprimer `scrollController` + `CustomScrollView`)

**Files:**
- Modify: `lib/features/matching/presentation/widgets/near_me_carousel.dart`

- [ ] **Step 3.1 : Réécrire intégralement `near_me_carousel.dart`**

Remplacer l'intégralité du fichier par :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

/// Retourne un badge formaté "CDG · 3 km" ou null si indisponible.
String? buildDistanceBadge(
  AnnouncementModel announcement,
  ({double lat, double lng})? userPos,
) {
  if (userPos == null) return null;
  final pickup = announcement.pickupAddress;
  if (pickup == null) return null;

  final distanceM = Geolocator.distanceBetween(
      userPos.lat, userPos.lng, pickup.lat, pickup.lng);
  final distanceKm = (distanceM / 1000).round();

  final allMatches = RegExp(r'\b([A-Z]{3})\b').allMatches(pickup.label);
  final locationCode = allMatches.isNotEmpty
      ? allMatches.last.group(1)!
      : pickup.label.split(' ').first;

  final distanceLabel = distanceKm == 0 ? '< 1 km' : '$distanceKm km';
  return '$locationCode · $distanceLabel';
}

class NearMeCarousel extends StatefulWidget {
  const NearMeCarousel({
    super.key,
    required this.announcements,
    required this.userPosition,
    required this.onSeeAll,
    this.selectedAnnouncementId,
    this.onCardChanged,
    this.onTapCard,
  });

  final List<AnnouncementModel> announcements;
  final ({double lat, double lng})? userPosition;
  final VoidCallback onSeeAll;
  final String? selectedAnnouncementId;
  final void Function(String id)? onCardChanged;
  /// Gestionnaire de tap custom. Si null, ouvre [showTravelerAnnouncementSheet].
  final void Function(AnnouncementModel)? onTapCard;

  @override
  State<NearMeCarousel> createState() => _NearMeCarouselState();
}

class _NearMeCarouselState extends State<NearMeCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _pageForId(widget.selectedAnnouncementId),
    );
  }

  @override
  void didUpdateWidget(covariant NearMeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAnnouncementId != widget.selectedAnnouncementId &&
        widget.selectedAnnouncementId != null) {
      final page = _pageForId(widget.selectedAnnouncementId);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  int _pageForId(String? id) {
    if (id == null) return 0;
    final i = widget.announcements.indexWhere((a) => a.id == id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    if (widget.announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: DonyColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.near_me_rounded,
                    color: DonyColors.primary, size: 26),
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                'Aucun voyageur à proximité',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                "Essaie d'augmenter le rayon ou de changer de date.",
                style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.announcements.length,
            onPageChanged: (i) {
              widget.onCardChanged?.call(widget.announcements[i].id);
            },
            itemBuilder: (context, i) {
              final a = widget.announcements[i];
              final badge = buildDistanceBadge(a, widget.userPosition);
              final authState = context.read<AuthBloc>().state;
              final currentUserId =
                  authState is AuthAuthenticated ? authState.user.id : null;
              final isOwn =
                  currentUserId != null && a.travelerId == currentUserId;
              return BlocBuilder<BidBloc, BidState>(
                buildWhen: (prev, curr) =>
                    curr is BidListLoaded || prev is BidListLoaded,
                builder: (context, bidState) {
                  final existingBid =
                      bidState.activeBidsByAnnouncement()[a.id];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm),
                    child: TravelerCard(
                      key: Key('near-me-card-${a.id}'),
                      announcement: a,
                      index: i,
                      isOwnAnnouncement: isOwn,
                      distanceBadge: badge,
                      existingBidStatus: existingBid?.status,
                      onTap: isOwn
                          ? null
                          : existingBid != null
                              ? () => context.push(
                                    '/bids/${existingBid.id}',
                                    extra: existingBid,
                                  )
                              : () {
                                  if (widget.onTapCard != null) {
                                    widget.onTapCard!(a);
                                  } else {
                                    showTravelerAnnouncementSheet(context,
                                        announcement: a);
                                  }
                                },
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.md),
          child: GestureDetector(
            onTap: widget.onSeeAll,
            child: Container(
              key: const Key('near-me-see-all-btn'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              decoration: BoxDecoration(
                color: DonyColors.primarySoft,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(
                    color: DonyColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Voir les ${widget.announcements.length} annonce${widget.announcements.length > 1 ? 's' : ''}',
                style: tt.labelLarge?.copyWith(
                    color: DonyColors.primary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3.2 : Lancer les 8 tests — tous doivent passer**

```bash
flutter test test/features/matching/presentation/widgets/near_me_carousel_test.dart --reporter=expanded
```
Attendu : 8 tests PASS.

- [ ] **Step 3.3 : Vérifier aucune régression globale**

```bash
flutter test --reporter=compact
```
Attendu : tous les tests passent (même baseline qu'avant).

- [ ] **Step 3.4 : Commit**

```bash
git add lib/features/matching/presentation/widgets/near_me_carousel.dart \
        test/features/matching/presentation/widgets/near_me_carousel_test.dart
git commit -m "refactor(carousel): widget autonome sans scrollController + 8 tests unitaires"
```

---

### Task 4 — Écrire les tests `home_screen` pour le rendu conditionnel (TDD)

**Files:**
- Modify: `test/features/home/presentation/home_screen_test.dart`

Ces tests échoueront jusqu'à Task 5.

- [ ] **Step 4.1 : Ajouter les imports manquants dans `home_screen_test.dart`**

En haut du fichier, après les imports existants, ajouter :
```dart
import 'package:dony/features/matching/presentation/widgets/near_me_carousel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
```

- [ ] **Step 4.2 : Ajouter le mock Geolocator juste après les mocks existants (≈ l. 48)**

Après `class MockHiveService extends Mock implements HiveService {}`, ajouter :

```dart
class _MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}
```

- [ ] **Step 4.3 : Ajouter les 2 tests dans le groupe `'HomeScreen — Map sender view'`**

À la fin du groupe `'HomeScreen — Map sender view'` (avant la fermeture `}`), ajouter :

```dart
    testWidgets('shows DraggableScrollableSheet by default (regression)',
        (tester) async {
      await tester.pumpWidget(_buildHome(
        announcementState: AnnouncementSearchLoaded([_makeAnn()]),
      ));
      await tester.pump();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byType(NearMeCarousel), findsNothing);
    });

    testWidgets(
        'shows NearMeCarousel and hides sheet when near-me chip activated',
        (tester) async {
      GeolocatorPlatform.instance = _MockGeolocatorPlatform();

      await tester.pumpWidget(_buildHome(
        announcementState: AnnouncementSearchLoaded([_makeAnn()]),
      ));
      await tester.pump();

      // Scroll le filtre pour rendre "Près de moi" visible
      await tester.ensureVisible(find.byKey(const Key('chip-near-me')));
      await tester.tap(find.byKey(const Key('chip-near-me')));
      await tester.pumpAndSettle();

      // NearMeRadiusSheet est affiché — confirmer le filtre
      await tester.tap(find.text('Activer le filtre'));
      await tester.pumpAndSettle();

      expect(find.byType(NearMeCarousel), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });
```

- [ ] **Step 4.4 : Vérifier que les 2 nouveaux tests échouent**

```bash
flutter test test/features/home/presentation/home_screen_test.dart --reporter=expanded
```
Attendu : les 2 nouveaux tests FAIL (`DraggableScrollableSheet` toujours là, `NearMeCarousel` absent) ; les tests existants PASS.

---

### Task 5 — Activer le carousel dans `home_screen.dart`

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` (classe `_MapSenderViewState`)

- [ ] **Step 5.1 : Ajouter `_exitNearMeAndShowList()` et `_onTravelerCardTap()` avant `build()`**

Localiser (≈ l. 394–400) la méthode `_showMap()`. Insérer AVANT elle :

```dart
  void _exitNearMeAndShowList() {
    _deactivateNearMe();
    // Animer le sheet à plein écran après le rebuild (controller reattaché)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onTravelerCardTap(BuildContext context, AnnouncementModel a) {
    final bidState = context.read<BidBloc>().state;
    final existingBid = bidState.activeBidsByAnnouncement()[a.id];
    if (existingBid != null) {
      context.push('/bids/${existingBid.id}', extra: existingBid);
    } else {
      showTravelerAnnouncementSheet(context, announcement: a);
    }
  }

```

- [ ] **Step 5.2 : Remplacer le `DraggableScrollableSheet` inconditionnel par le bloc conditionnel**

Localiser (≈ l. 576–591) :
```dart
              // ── DraggableScrollableSheet ──────────────────────────────────
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.20,
                minChildSize: 0.15,
                maxChildSize: 1.0,
                snap: true,
                snapSizes: const [0.20, 0.45, 1.0],
                builder: (ctx, scrollCtrl) => _buildSheet(
                  ctx,
                  scrollCtrl,
                  announcements,
                  MediaQuery.of(context).padding.bottom,
                ),
              ),
```

Remplacer par :
```dart
              // ── Liste ou Carousel selon le mode Près de moi ───────────────
              if (!_isNearMeActive)
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.20,
                  minChildSize: 0.15,
                  maxChildSize: 1.0,
                  snap: true,
                  snapSizes: const [0.20, 0.45, 1.0],
                  builder: (ctx, scrollCtrl) => _buildSheet(
                    ctx,
                    scrollCtrl,
                    announcements,
                    MediaQuery.of(context).padding.bottom,
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: SizedBox(
                      height: 280,
                      child: NearMeCarousel(
                        announcements: announcements,
                        userPosition: _userPosition != null
                            ? (
                                lat: _userPosition!.latitude,
                                lng: _userPosition!.longitude
                              )
                            : null,
                        selectedAnnouncementId: _selectedAnnouncementId,
                        onCardChanged: (id) =>
                            setState(() => _selectedAnnouncementId = id),
                        onSeeAll: _exitNearMeAndShowList,
                        onTapCard: (a) => _onTravelerCardTap(context, a),
                      )
                          .animate()
                          .fadeIn(duration: 250.ms)
                          .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                    ),
                  ),
                ),
```

- [ ] **Step 5.3 : Vérifier l'analyse statique**

```bash
flutter analyze lib/features/home/presentation/home_screen.dart
```
Attendu : aucune erreur.

- [ ] **Step 5.4 : Lancer les 2 nouveaux tests — doivent passer**

```bash
flutter test test/features/home/presentation/home_screen_test.dart --reporter=expanded
```
Attendu : tous les tests PASS, y compris les 2 nouveaux.

- [ ] **Step 5.5 : Lancer la suite complète — aucune régression**

```bash
flutter test --reporter=compact
```
Attendu : tous les tests passent.

- [ ] **Step 5.6 : Commit final**

```bash
git add lib/features/home/presentation/home_screen.dart \
        test/features/home/presentation/home_screen_test.dart
git commit -m "feat(home): activer NearMeCarousel en overlay fixe quand Près de moi est actif"
```

---

## Récapitulatif des fichiers touchés

| Fichier | Type | Changement |
|---|---|---|
| `lib/features/home/presentation/home_screen.dart` | Modify | Chip + 2 méthodes + `if (!_isNearMeActive)` |
| `lib/features/matching/presentation/widgets/near_me_carousel.dart` | Modify | Suppression `scrollController` + `CustomScrollView`, ajout clés |
| `test/features/matching/presentation/widgets/near_me_carousel_test.dart` | Create | 8 tests unitaires |
| `test/features/home/presentation/home_screen_test.dart` | Modify | 2 tests + mock Geolocator |
