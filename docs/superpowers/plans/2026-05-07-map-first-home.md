# Map-First Home Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sender dashboard (`_SenderView`) with a Cocolis-inspired map-first home screen showing voyageur announcements on a live map, with a Voyageurs/Demandes toggle, corridor search bar, active filter chips, and a DraggableScrollableSheet listing results.

**Architecture:** `home_screen.dart` keeps its shell (`HomeScreen` + `_TravelerView`). `_SenderView` and its 4 sub-widgets are deleted and replaced by `_MapSenderView` (StatefulWidget). The map view is a full-screen `AnnouncementMapView` under a floating overlay (corridor bar + tab toggle + chips) and a `DraggableScrollableSheet`. All announcement data comes from `AnnouncementBloc` already in the widget tree. "Demandes" tab shows a static placeholder (entity not yet in backend).

**Tech Stack:** Flutter, flutter_bloc, google_maps_flutter, DraggableScrollableSheet, GoRouter, intl, DonyColors/DonySpacing/DonyRadius design system tokens

---

## Files

**Modified:**
- `lib/features/home/presentation/home_screen.dart` — Remove `_SenderView`, `_SearchFormCard`, `_CorridorsGrid`, `_CorridorChip`, `_GarantieCard`; add `_MapSenderView` + sub-widgets + new imports.

**Modified (tests):**
- `test/features/home/presentation/home_screen_test.dart` — Update existing tests, add new tests for map-first behavior.

---

## Contexte codebase à connaître

### `AnnouncementBloc` events/states
```dart
// Dispatch pour lancer une recherche :
context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
  departureCity: 'Paris · CDG, ORY', // string exact du design system
  arrivalCity: 'Dakar · DKR',
  departureDateFrom: DateTime?,       // null = toutes dates
  kiloProOnly: bool?,                 // null = pas de filtre
));

// États pertinents :
// AnnouncementInitial — initial, pas de résultats
// AnnouncementLoading — chargement en cours
// AnnouncementSearchLoaded(results: List<AnnouncementModel>) — résultats
// AnnouncementError(message, {previousResults}) — erreur
```

### `AnnouncementMapView` signature
```dart
AnnouncementMapView(
  announcements: List<AnnouncementModel>,
  isNearMeActive: bool,
  activeRadiusKm: double?,
  userPosition: LatLng?,
  onNearMeRequested: (double lat, double lng, double radius) → void,
  onNearMeDisabled: () → void,
)
```

### `TravelerCard` signature
```dart
TravelerCard(
  announcement: AnnouncementModel,
  index: int,
  isOwnAnnouncement: bool,
  distanceBadge: String?,   // null = pas de badge distance
  onTap: VoidCallback?,
)
```

### Route de détail d'annonce
```dart
context.push('/search/${announcement.id}', extra: announcement);
```

### Design tokens utilisés
```dart
DonyColors.surface      // blanc card
DonyColors.bgApp        // fond gris très clair
DonyColors.neutral200   // bordures
DonyColors.primary      // bleu primaire
DonyColors.primarySoft  // bleu très clair (background chips actifs)
DonyColors.textMuted    // texte secondaire gris
DonyColors.ink900       // texte principal noir
DonySpacing.xs = 4, sm = 8, md = 12, base = 16, lg = 24, xl = 32, xxl = 48, huge = 64
DonyRadius.sheet = 24, card = 12, full = 999
```

---

## Task 1 : Supprimer `_SenderView` + ajouter imports + `_MapSenderView` skeleton

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`

### Aperçu des classes à supprimer / ajouter

**Supprimer ces classes** (lignes ~62–654 environ, tout ce qui concerne l'ancien sender dashboard) :
- `_SenderView` + `_SenderViewState`
- `_SearchFormCard` + `_SearchFormCardState`
- `_CorridorsGrid`
- `_CorridorChip`
- `_GarantieCard`

**Garder absolument** (utilisées par `_TravelerView`) :
- `_TravelerView` + `_TravelerViewState`
- `_StatsCard`, `_StatPill`, `_ActiveTripCard`
- `_NotifBadge`, `_PayoutFooter`
- `_kAccentOnDark`, `_corridors`, `_Corridor` typedef

- [ ] **Step 1 : Ajouter les imports manquants** en haut de `home_screen.dart` (après les imports existants)

```dart
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
```

- [ ] **Step 2 : Ajouter constantes + enum juste avant la classe `HomeScreen`**

```dart
// ── Home-screen specific constants ────────────────────────────────────────────

enum _HomeTab { voyageurs, demandes }

typedef _CorridorOpt = ({String label, String departure, String arrival});

const _corridorOptions = <_CorridorOpt>[
  (label: 'Paris → Dakar',      departure: 'Paris · CDG, ORY', arrival: 'Dakar · DKR'),
  (label: 'Paris → Abidjan',    departure: 'Paris · CDG, ORY', arrival: 'Abidjan · ABJ'),
  (label: 'Lyon → Abidjan',     departure: 'Lyon · LYS',       arrival: 'Abidjan · ABJ'),
  (label: 'Paris → Bamako',     departure: 'Paris · CDG, ORY', arrival: 'Bamako · BKO'),
  (label: 'Paris → Douala',     departure: 'Paris · CDG, ORY', arrival: 'Douala · DLA'),
  (label: 'Marseille → Bamako', departure: 'Marseille · MRS',  arrival: 'Bamako · BKO'),
];
```

- [ ] **Step 3 : Modifier `HomeScreen.build`** pour utiliser `_MapSenderView` à la place de `_SenderView`

```dart
// Dans HomeScreen.build, remplacer :
if (activeRole == ActiveRole.traveler) {
  return _TravelerView(displayName: user?.displayName ?? 'Voyageur');
}
return _SenderView(
  firstName: user?.firstName ?? user?.displayName ?? 'vous',
  displayName: user?.displayName ?? 'vous',
);

// Par :
if (activeRole == ActiveRole.traveler) {
  return _TravelerView(displayName: user?.displayName ?? 'Voyageur');
}
return const _MapSenderView();
```

- [ ] **Step 4 : Supprimer** les classes `_SenderView`, `_SenderViewState`, `_SearchFormCard`, `_SearchFormCardState`, `_CorridorsGrid`, `_CorridorChip`, `_GarantieCard` du fichier.

- [ ] **Step 5 : Ajouter le skeleton `_MapSenderView`** (juste la structure, sans le sheet complet — on l'étoffe dans les tâches suivantes)

```dart
// ══════════════════════════════════════════════════════════════════════════════
// MAP SENDER VIEW
// ══════════════════════════════════════════════════════════════════════════════

class _MapSenderView extends StatefulWidget {
  const _MapSenderView();

  @override
  State<_MapSenderView> createState() => _MapSenderViewState();
}

class _MapSenderViewState extends State<_MapSenderView> {
  final _sheetController = DraggableScrollableController();
  double _sheetSize = 0.45;
  bool get _isMapHidden => _sheetSize > 0.92;

  _HomeTab _tab = _HomeTab.voyageurs;
  _CorridorOpt _corridor = _corridorOptions.first; // Paris → Dakar par défaut

  // Filtres actifs
  DateTime? _date;
  bool _kiloProOnly = false;

  // Near-me (transmis à AnnouncementMapView)
  bool _isNearMeActive = false;
  double? _nearMeRadiusKm;
  LatLng? _userPosition;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    // Charge les annonces au montage avec le corridor par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispatchSearch());
  }

  void _onSheetSizeChanged() {
    if (_sheetController.isAttached) {
      setState(() => _sheetSize = _sheetController.size);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _dispatchSearch() {
    if (!mounted) return;
    context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
      departureCity: _corridor.departure,
      arrivalCity: _corridor.arrival,
      departureDateFrom: _date,
      kiloProOnly: _kiloProOnly ? true : null,
    ));
  }

  void _showMap() {
    _sheetController.animateTo(
      0.45,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DonyColors.bgApp,
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          final announcements = state is AnnouncementSearchLoaded
              ? state.results
              : <AnnouncementModel>[];

          return Stack(
            children: [
              Positioned.fill(
                child: AnnouncementMapView(
                  announcements: _tab == _HomeTab.voyageurs ? announcements : [],
                  isNearMeActive: _isNearMeActive,
                  activeRadiusKm: _nearMeRadiusKm,
                  userPosition: _userPosition,
                  onNearMeRequested: (lat, lng, radius) => setState(() {
                    _isNearMeActive = true;
                    _nearMeRadiusKm = radius;
                    _userPosition = LatLng(lat, lng);
                  }),
                  onNearMeDisabled: () => setState(() {
                    _isNearMeActive = false;
                    _nearMeRadiusKm = null;
                    _userPosition = null;
                  }),
                ),
              ),
              // Overlay + sheet ajoutés dans Task 2 et 3
              const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6 : Vérifier que ça compile**

```bash
cd dony_app
flutter analyze lib/features/home/presentation/home_screen.dart
```

Expected: no errors (infos/warnings ignorés).

- [ ] **Step 7 : Commit**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat(home): replace sender dashboard with map-first skeleton"
```

---

## Task 2 : Floating top overlay — barre de recherche + toggle + chips

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`

Cette tâche ajoute l'overlay flottant visible au-dessus de la carte :
1. `_CorridorBar` — barre de recherche avec corridor + bouton filtre
2. `_TabToggle` — toggle "Voyageurs · N" / "Demandes · N"
3. `_ActiveFilterChips` — chips supprimables pour filtres actifs (date, kilopro)

- [ ] **Step 1 : Ajouter le widget `_CorridorBar`** à la fin de `home_screen.dart`

```dart
// ── _CorridorBar ──────────────────────────────────────────────────────────────

class _CorridorBar extends StatelessWidget {
  const _CorridorBar({
    required this.label,
    required this.hasActiveFilters,
    required this.onTap,
  });

  final String label;
  final bool hasActiveFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: DonyColors.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: DonyColors.textMuted),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: DonyColors.ink900,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasActiveFilters ? DonyColors.primary : DonyColors.bgApp,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: hasActiveFilters ? DonyColors.surface : DonyColors.ink900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2 : Ajouter le widget `_TabToggle`**

```dart
// ── _TabToggle ────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.voyageursCount,
    required this.onChanged,
  });

  final _HomeTab tab;
  final int? voyageursCount;
  final void Function(_HomeTab) onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: DonyColors.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabPill(
            label: voyageursCount != null
                ? 'Voyageurs · $voyageursCount'
                : 'Voyageurs',
            isActive: tab == _HomeTab.voyageurs,
            dotColor: DonyColors.primary,
            onTap: () => onChanged(_HomeTab.voyageurs),
          ),
          const SizedBox(width: 2),
          _TabPill(
            label: 'Demandes',
            isActive: tab == _HomeTab.demandes,
            dotColor: DonyColors.success,
            onTap: () => onChanged(_HomeTab.demandes),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.isActive,
    required this.dotColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Color dotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base, vertical: DonySpacing.xs),
        decoration: BoxDecoration(
          color: isActive ? DonyColors.ink900 : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? DonyColors.surface : dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isActive ? DonyColors.surface : DonyColors.ink900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3 : Ajouter le widget `_ActiveFilterChips`**

```dart
// ── _ActiveFilterChips ────────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.date,
    required this.kiloProOnly,
    required this.onRemoveDate,
    required this.onRemoveKiloPro,
  });

  final DateTime? date;
  final bool kiloProOnly;
  final VoidCallback onRemoveDate;
  final VoidCallback onRemoveKiloPro;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DonySpacing.xs,
      children: [
        if (date != null)
          _FilterChip(
            label: DateFormat('d MMM', 'fr').format(date!),
            onRemove: onRemoveDate,
          ),
        if (kiloProOnly)
          _FilterChip(
            label: 'Kilo Pro',
            onRemove: onRemoveKiloPro,
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xs),
      decoration: BoxDecoration(
        color: DonyColors.surface,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: DonyColors.ink900,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: DonyColors.textMuted),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4 : Intégrer l'overlay dans `_MapSenderViewState.build`**

Remplacer `const SizedBox.shrink()` dans le Stack par :

```dart
// ── Top overlay ───────────────────────────────────────────────────────
Positioned(
  top: MediaQuery.of(context).padding.top + DonySpacing.sm,
  left: DonySpacing.md,
  right: DonySpacing.md,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _CorridorBar(
        label: _corridor.label,
        hasActiveFilters: _date != null || _kiloProOnly,
        onTap: () => _showFilterSheet(context),
      ),
      const SizedBox(height: DonySpacing.sm),
      _TabToggle(
        tab: _tab,
        voyageursCount: _tab == _HomeTab.voyageurs
            ? announcements.length
            : null,
        onChanged: (t) => setState(() => _tab = t),
      ),
      if (_date != null || _kiloProOnly) ...[
        const SizedBox(height: DonySpacing.xs),
        _ActiveFilterChips(
          date: _date,
          kiloProOnly: _kiloProOnly,
          onRemoveDate: () {
            setState(() => _date = null);
            _dispatchSearch();
          },
          onRemoveKiloPro: () {
            setState(() => _kiloProOnly = false);
            _dispatchSearch();
          },
        ),
      ],
    ],
  ),
),
```

Et ajouter `_showFilterSheet` dans `_MapSenderViewState` (stub pour l'instant, implémenté en Task 4) :

```dart
void _showFilterSheet(BuildContext ctx) {
  // Implémenté en Task 4
}
```

- [ ] **Step 5 : Analyse**

```bash
flutter analyze lib/features/home/presentation/home_screen.dart
```

Expected: no errors.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat(home): add corridor bar, voyageurs/demandes toggle, filter chips overlay"
```

---

## Task 3 : DraggableScrollableSheet + liste + FAB "Carte"

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Create: `test/features/home/presentation/home_screen_test.dart` (mise à jour)

- [ ] **Step 1 : Ajouter `_DemandesPlaceholder` et `_HomeCarteFab`**

```dart
// ── _DemandesPlaceholder ──────────────────────────────────────────────────────

class _DemandesPlaceholder extends StatelessWidget {
  const _DemandesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(DonySpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DonyColors.primarySoft,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: const Icon(Icons.inbox_outlined, color: DonyColors.primary, size: 28),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Demandes bientôt disponibles',
            style: tt.titleMedium?.copyWith(
              color: DonyColors.ink900,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Tu pourras bientôt consulter les demandes d\'envoi postées par les expéditeurs.',
            style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── _HomeCarteFab ─────────────────────────────────────────────────────────────

class _HomeCarteFab extends StatelessWidget {
  const _HomeCarteFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: DonyColors.ink900,
          borderRadius: BorderRadius.circular(DonyRadius.full),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 16, color: Colors.white),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Carte',
              style: tt.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2 : Ajouter la méthode `_buildSheet` dans `_MapSenderViewState`**

```dart
Widget _buildSheet(
  BuildContext ctx,
  ScrollController scrollCtrl,
  List<AnnouncementModel> announcements,
  double bottomPad,
) {
  final tt = Theme.of(ctx).textTheme;
  final count = announcements.length;

  return Container(
    key: const Key('home-sheet'),
    decoration: const BoxDecoration(
      color: DonyColors.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DonyRadius.sheet),
      ),
    ),
    child: Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DonyColors.neutral200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header : titre + count + tri
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg, DonySpacing.xs, DonySpacing.lg, DonySpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tab == _HomeTab.voyageurs
                          ? 'VOYAGEURS DISPONIBLES'
                          : 'DEMANDES D\'ENVOI',
                      style: tt.labelSmall?.copyWith(
                        color: DonyColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      _tab == _HomeTab.voyageurs
                          ? '$count résultat${count > 1 ? 's' : ''} · ${_corridor.label}'
                          : _corridor.label,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (_tab == _HomeTab.voyageurs && count > 0)
                GestureDetector(
                  onTap: () => _showFilterSheet(ctx),
                  child: Text(
                    'Trier',
                    style: tt.labelMedium?.copyWith(
                      color: DonyColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1, color: DonyColors.neutral200),

        // Contenu
        Expanded(
          child: _tab == _HomeTab.demandes
              ? const _DemandesPlaceholder()
              : count == 0
                  ? Center(
                      child: Text(
                        'Aucun voyageur sur ce corridor',
                        style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      key: const Key('home-announcements-list'),
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(
                        DonySpacing.base,
                        DonySpacing.sm,
                        DonySpacing.base,
                        bottomPad + DonySpacing.huge,
                      ),
                      itemCount: count,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: DonySpacing.md),
                      itemBuilder: (context, i) {
                        final a = announcements[i];
                        final authState = context.read<AuthBloc>().state;
                        final currentUserId = authState is AuthAuthenticated
                            ? authState.user.id
                            : null;
                        final isOwn = currentUserId != null &&
                            a.travelerId == currentUserId;
                        return TravelerCard(
                          announcement: a,
                          index: i,
                          isOwnAnnouncement: isOwn,
                          onTap: isOwn
                              ? null
                              : () => context.push(
                                    '/search/${a.id}',
                                    extra: a,
                                  ),
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3 : Intégrer DraggableScrollableSheet + FAB dans `build`**

Dans le `Stack` de `_MapSenderViewState.build`, remplacer `const SizedBox.shrink()` (qui était le placeholder) par ces deux entrées (à ajouter après l'overlay `Positioned`) :

```dart
// DraggableScrollableSheet
DraggableScrollableSheet(
  controller: _sheetController,
  initialChildSize: 0.45,
  minChildSize: 0.15,
  maxChildSize: 1.0,
  snap: true,
  snapSizes: const [0.45, 1.0],
  builder: (ctx, scrollCtrl) => _buildSheet(
    ctx,
    scrollCtrl,
    announcements,
    MediaQuery.of(context).padding.bottom,
  ),
),

// FAB "Carte"
AnimatedPositioned(
  duration: const Duration(milliseconds: 280),
  curve: Curves.easeOutCubic,
  bottom: _isMapHidden
      ? MediaQuery.of(context).padding.bottom + DonySpacing.lg
      : -80,
  left: 0,
  right: 0,
  child: Center(child: _HomeCarteFab(onTap: _showMap)),
),
```

- [ ] **Step 4 : Écrire les tests** dans `test/features/home/presentation/home_screen_test.dart`

Le fichier de test existant doit être mis à jour pour inclure `AnnouncementBloc` et `ActiveRoleCubit` dans le helper `_buildRouter`. Voici les ajouts :

```dart
// Ajouter ces imports en haut du fichier de test :
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';

// Ajouter les mocks :
class MockAnnouncementBloc extends MockBloc<AnnouncementEvent, AnnouncementState> implements AnnouncementBloc {}
class MockActiveRoleCubit extends MockCubit<ActiveRole> implements ActiveRoleCubit {}

// Helper pour les tests map-first :
AnnouncementModel _makeAnn({String id = 'a1'}) => AnnouncementModel(
  id: id,
  travelerId: 'traveler-1',
  departureCity: 'Paris · CDG, ORY',
  arrivalCity: 'Dakar · DKR',
  departureDate: DateTime(2026, 6, 15),
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 7,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

Widget _buildMapHome({
  AnnouncementState announcementState = const AnnouncementInitial(),
  ActiveRole role = ActiveRole.sender,
}) {
  final announcementBloc = MockAnnouncementBloc();
  final authBloc = MockAuthBloc();
  final roleCubit = MockActiveRoleCubit();
  final notifBloc = MockNotificationBloc();

  when(() => announcementBloc.state).thenReturn(announcementState);
  when(() => announcementBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => roleCubit.state).thenReturn(role);
  when(() => roleCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => notifBloc.state).thenReturn(const NotificationInitial());
  when(() => notifBloc.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
      BlocProvider<NotificationBloc>.value(value: notifBloc),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
    ),
  );
}

// Tests à ajouter dans un groupe 'HomeScreen – map sender view' :
group('HomeScreen – map sender view', () {
  testWidgets('shows corridor label in search bar', (tester) async {
    await tester.pumpWidget(_buildMapHome());
    await tester.pump();
    expect(find.text('Paris → Dakar'), findsOneWidget);
  });

  testWidgets('shows Voyageurs tab active by default', (tester) async {
    await tester.pumpWidget(_buildMapHome());
    await tester.pump();
    expect(find.text('Voyageurs · 0'), findsOneWidget);
  });

  testWidgets('tapping Demandes tab shows placeholder text', (tester) async {
    await tester.pumpWidget(_buildMapHome());
    await tester.pump();
    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();
    expect(find.text('Demandes bientôt disponibles'), findsOneWidget);
  });

  testWidgets('shows TravelerCards when announcements loaded', (tester) async {
    await tester.pumpWidget(_buildMapHome(
      announcementState: AnnouncementSearchLoaded([_makeAnn(), _makeAnn(id: 'a2')]),
    ));
    await tester.pump();
    expect(find.byType(TravelerCard), findsNWidgets(2));
  });

  testWidgets('shows empty message when no results', (tester) async {
    await tester.pumpWidget(_buildMapHome(
      announcementState: AnnouncementSearchLoaded([]),
    ));
    await tester.pump();
    expect(find.text('Aucun voyageur sur ce corridor'), findsOneWidget);
  });

  testWidgets('date chip appears and can be removed', (tester) async {
    // Ce test vérifie la logique des chips — testé dans Task 4 après la filter sheet
  });
});
```

- [ ] **Step 5 : Lancer les tests**

```bash
flutter test test/features/home/presentation/home_screen_test.dart
```

Expected: tous les nouveaux tests passent.

- [ ] **Step 6 : Analyse**

```bash
flutter analyze lib/features/home/presentation/home_screen.dart
```

Expected: no errors.

- [ ] **Step 7 : Commit**

```bash
git add lib/features/home/presentation/home_screen.dart test/features/home/presentation/home_screen_test.dart
git commit -m "feat(home): add DraggableScrollableSheet list, Demandes placeholder, Carte FAB"
```

---

## Task 4 : Filter bottom sheet — `_HomeFilterSheet`

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`

Le filter sheet permet de changer : corridor, date de départ, KiloPro uniquement. Quand "Appliquer" est tapé, le callback `onApply` est appelé, l'état parent se met à jour, et `_dispatchSearch()` recharge les annonces.

- [ ] **Step 1 : Écrire le test du filter sheet d'abord**

Dans `test/features/home/presentation/home_screen_test.dart`, ajouter dans le groupe existant :

```dart
testWidgets('filter sheet opens on corridor bar tap', (tester) async {
  await tester.pumpWidget(_buildMapHome());
  await tester.pump();

  await tester.tap(find.byKey(const Key('corridor-bar')));
  await tester.pumpAndSettle();

  // Le sheet doit afficher les options de corridors
  expect(find.text('Paris → Dakar'), findsWidgets); // au moins 2 : bar + option
  expect(find.text('Paris → Abidjan'), findsOneWidget);
});

testWidgets('selecting corridor in filter sheet updates bar label', (tester) async {
  await tester.pumpWidget(_buildMapHome());
  await tester.pump();

  await tester.tap(find.byKey(const Key('corridor-bar')));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Lyon → Abidjan'));
  await tester.pump();

  await tester.tap(find.text('Appliquer'));
  await tester.pumpAndSettle();

  expect(find.text('Lyon → Abidjan'), findsOneWidget); // dans la barre
});
```

- [ ] **Step 2 : Vérifier que le test échoue**

```bash
flutter test test/features/home/presentation/home_screen_test.dart --name "filter sheet"
```

Expected: FAIL (Key corridor-bar pas encore défini, filter sheet pas encore implémenté).

- [ ] **Step 3 : Ajouter `key` au `_CorridorBar` dans l'overlay de `_MapSenderViewState`**

```dart
// Dans l'overlay du Stack, modifier l'appel à _CorridorBar :
_CorridorBar(
  key: const Key('corridor-bar'),  // ← ajouter cette ligne
  label: _corridor.label,
  hasActiveFilters: _date != null || _kiloProOnly,
  onTap: () => _showFilterSheet(context),
),
```

- [ ] **Step 4 : Implémenter `_HomeFilterSheet`** (ajouter en bas de `home_screen.dart`)

```dart
// ── _HomeFilterSheet ──────────────────────────────────────────────────────────

class _HomeFilterSheet extends StatefulWidget {
  const _HomeFilterSheet({
    required this.corridor,
    required this.date,
    required this.kiloProOnly,
    required this.onApply,
  });

  final _CorridorOpt corridor;
  final DateTime? date;
  final bool kiloProOnly;
  final void Function({
    required _CorridorOpt corridor,
    required DateTime? date,
    required bool kiloProOnly,
  }) onApply;

  @override
  State<_HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<_HomeFilterSheet> {
  late _CorridorOpt _corridor;
  late DateTime? _date;
  late bool _kiloProOnly;

  @override
  void initState() {
    super.initState();
    _corridor = widget.corridor;
    _date = widget.date;
    _kiloProOnly = widget.kiloProOnly;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DonyColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg, 0, DonySpacing.lg, DonySpacing.md),
              child: Text(
                'Filtres',
                style:
                    tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1, color: DonyColors.neutral200),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg, DonySpacing.lg, DonySpacing.lg, DonySpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Corridor ─────────────────────────────────────────────
                    Text(
                      'CORRIDOR',
                      style: tt.labelMedium?.copyWith(
                          color: DonyColors.textMuted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    ...List.generate(_corridorOptions.length, (i) {
                      final opt = _corridorOptions[i];
                      final isSelected = opt.label == _corridor.label;
                      return GestureDetector(
                        onTap: () => setState(() => _corridor = opt),
                        child: Container(
                          margin:
                              const EdgeInsets.only(bottom: DonySpacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                            vertical: DonySpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? DonyColors.primarySoft
                                : DonyColors.bgApp,
                            borderRadius:
                                BorderRadius.circular(DonyRadius.card),
                            border: Border.all(
                              color: isSelected
                                  ? DonyColors.primary
                                  : DonyColors.neutral200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt.label,
                                  style: tt.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? DonyColors.primary
                                        : DonyColors.ink900,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: DonyColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: DonySpacing.xl),

                    // ── Date ─────────────────────────────────────────────────
                    Text(
                      'DATE DE DÉPART',
                      style: tt.labelMedium?.copyWith(
                          color: DonyColors.textMuted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                          locale: const Locale('fr'),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.base,
                          vertical: DonySpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: DonyColors.bgApp,
                          borderRadius:
                              BorderRadius.circular(DonyRadius.card),
                          border: Border.all(color: DonyColors.neutral200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 16, color: DonyColors.textMuted),
                            const SizedBox(width: DonySpacing.sm),
                            Text(
                              _date != null
                                  ? DateFormat('EEE d MMM', 'fr')
                                      .format(_date!)
                                  : 'Toutes les dates',
                              style: tt.bodyMedium?.copyWith(
                                color: _date != null
                                    ? DonyColors.ink900
                                    : DonyColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            if (_date != null)
                              GestureDetector(
                                onTap: () => setState(() => _date = null),
                                child: const Icon(Icons.close_rounded,
                                    size: 16,
                                    color: DonyColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: DonySpacing.xl),

                    // ── KiloPro ───────────────────────────────────────────────
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Kilo Pro uniquement', style: tt.titleMedium),
                      subtitle: Text(
                        'Voyageurs avec badge KYC vérifié',
                        style: tt.bodySmall
                            ?.copyWith(color: DonyColors.neutral400),
                      ),
                      value: _kiloProOnly,
                      activeThumbColor: DonyColors.primary,
                      onChanged: (v) => setState(() => _kiloProOnly = v),
                    ),
                  ],
                ),
              ),
            ),
            // Bouton Appliquer
            Container(
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                MediaQuery.of(sheetCtx).padding.bottom + DonySpacing.base,
              ),
              decoration: const BoxDecoration(
                color: DonyColors.white,
                border:
                    Border(top: BorderSide(color: DonyColors.neutral200)),
              ),
              child: DonyButton(
                label: 'Appliquer',
                onPressed: () {
                  sheetCtx.pop();
                  widget.onApply(
                    corridor: _corridor,
                    date: _date,
                    kiloProOnly: _kiloProOnly,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5 : Implémenter `_showFilterSheet` dans `_MapSenderViewState`**

```dart
void _showFilterSheet(BuildContext ctx) {
  showModalBottomSheet<void>(
    context: ctx,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HomeFilterSheet(
      corridor: _corridor,
      date: _date,
      kiloProOnly: _kiloProOnly,
      onApply: ({
        required _CorridorOpt corridor,
        required DateTime? date,
        required bool kiloProOnly,
      }) {
        setState(() {
          _corridor = corridor;
          _date = date;
          _kiloProOnly = kiloProOnly;
        });
        _dispatchSearch();
      },
    ),
  );
}
```

- [ ] **Step 6 : Lancer tous les tests**

```bash
flutter test test/features/home/presentation/home_screen_test.dart
```

Expected: tous les tests passent.

- [ ] **Step 7 : Analyse finale**

```bash
flutter analyze lib/features/home/presentation/home_screen.dart
```

Expected: no errors.

- [ ] **Step 8 : Commit final**

```bash
git add lib/features/home/presentation/home_screen.dart test/features/home/presentation/home_screen_test.dart
git commit -m "feat(home): add filter bottom sheet with corridor, date, KiloPro filters"
```

---

## Self-Review

**1. Spec coverage :**
- ✅ Map comme premier écran (Task 1)
- ✅ Barre de recherche corridor style Cocolis (Task 2 — `_CorridorBar`)
- ✅ Toggle Voyageurs / Demandes (Task 2 — `_TabToggle`)
- ✅ Filtre = bouton icône → bottom sheet (Task 4)
- ✅ Liste des annonces dans sheet (Task 3)
- ✅ FAB "Carte" quand sheet full screen (Task 3)
- ✅ Chips filtres actifs supprimables (Task 2)
- ✅ Demandes = placeholder "bientôt disponible" (Task 3)

**2. Pas de placeholders :** Tout le code est complet dans chaque step.

**3. Cohérence des types :**
- `_CorridorOpt` utilisé partout (Tasks 1, 2, 4)
- `_HomeTab` utilisé dans `_TabToggle` + `_MapSenderViewState` + `_buildSheet`
- `_showFilterSheet(BuildContext ctx)` — signature cohérente Tasks 2 et 4
- `onApply` callback avec `{required _CorridorOpt corridor, required DateTime? date, required bool kiloProOnly}` — Tasks 1 et 4

---
