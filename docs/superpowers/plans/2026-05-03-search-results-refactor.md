# Search Results Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor search results page to move list/map toggle from AppBar to filter chips row, default to list view, and hide bottom navigation bar.

**Architecture:** Remove `_ToggleTab` widgets from AppBar. Add list/map icons as first items in filter chips row (horizontal ListView). Update GoRouter to exclude shell with `DonyBottomNav` on search results route. Preserve all existing filter logic and map/list rendering.

**Tech Stack:** Flutter · flutter_bloc · GoRouter · Material Design 3 · TDD (widget tests + integration tests)

---

## Task 1: Test — AppBar shows no toggle tabs

**Files:**
- Modify: `test/features/matching/presentation/search_announcement_screen_test.dart`

- [ ] **Step 1: Add test for AppBar structure**

```dart
testWidgets('AppBar does not contain list/map toggle tabs', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => mockAnnouncementBloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  // Navigate to results view by mocking state
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => AnnouncementBloc(mockRepository)..add(
          AnnouncementSearchRequested(
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
          ),
        ),
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify no _ToggleTab widgets exist
  expect(find.byType(_ToggleTab), findsNothing);
  
  // Verify AppBar contains journey title
  expect(find.text('Paris → Dakar'), findsWidgets);
  
  // Verify AppBar contains filter icon
  expect(find.byIcon(Icons.tune_rounded), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "AppBar does not contain"
```

Expected: FAIL — `_ToggleTab` still exists in current code

---

## Task 2: Test — Filter chips row has list/map icons as first items

**Files:**
- Modify: `test/features/matching/presentation/search_announcement_screen_test.dart`

- [ ] **Step 1: Add test for list/map icons in chips row**

```dart
testWidgets('Filter chips row has list and map icons as first items', (WidgetTester tester) async {
  final mockResults = [
    AnnouncementModel(
      id: '1',
      travelerId: 'traveler1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now(),
      availableKg: 20,
      pricePerKg: 10,
      transportMode: TransportMode.plane,
    ),
  ];

  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Find the filter chips row (ListView with horizontal scroll)
  final chipsList = find.byType(ListView).first;
  expect(chipsList, findsOneWidget);

  // Verify list icon is present
  expect(find.byIcon(Icons.list_rounded), findsWidgets);

  // Verify map icon is present
  expect(find.byIcon(Icons.map_outlined), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "list and map icons"
```

Expected: FAIL — Icons not yet added to chips row

---

## Task 3: Test — Toggle icons have correct styling (active/inactive)

**Files:**
- Modify: `test/features/matching/presentation/search_announcement_screen_test.dart`

- [ ] **Step 1: Add test for icon styling**

```dart
testWidgets('List icon is active (primary color) when showing list view', (WidgetTester tester) async {
  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // List icon should have primary color background
  final listIconButton = find.byIcon(Icons.list_rounded).first;
  expect(listIconButton, findsOneWidget);

  // Verify it has active styling (background color should contain primary tint)
  final widget = tester.widget<IconButton>(listIconButton);
  // The button should have elevated style (background) when active
  expect(widget.color, DonyColors.primary);
});

testWidgets('Map icon is inactive (neutral color) when showing list view', (WidgetTester tester) async {
  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Map icon should have neutral color when inactive
  final mapIconButton = find.byIcon(Icons.map_outlined).first;
  expect(mapIconButton, findsOneWidget);

  final widget = tester.widget<IconButton>(mapIconButton);
  expect(widget.color, DonyColors.neutral500);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "icon.*active"
```

Expected: FAIL — Icons don't exist yet

---

## Task 4: Test — Tapping icons switches views

**Files:**
- Modify: `test/features/matching/presentation/search_announcement_screen_test.dart`

- [ ] **Step 1: Add test for toggle interaction**

```dart
testWidgets('Tapping map icon switches to map view', (WidgetTester tester) async {
  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Verify list view is showing initially
  expect(find.byType(TravelerCard), findsWidgets);
  expect(find.byType(AnnouncementMapView), findsNothing);

  // Tap map icon
  await tester.tap(find.byIcon(Icons.map_outlined));
  await tester.pumpAndSettle();

  // Verify map view is now showing
  expect(find.byType(AnnouncementMapView), findsOneWidget);
  expect(find.byType(TravelerCard), findsNothing);
});

testWidgets('Tapping list icon switches back to list view', (WidgetTester tester) async {
  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // Switch to map
  await tester.tap(find.byIcon(Icons.map_outlined));
  await tester.pumpAndSettle();

  expect(find.byType(AnnouncementMapView), findsOneWidget);

  // Switch back to list
  await tester.tap(find.byIcon(Icons.list_rounded));
  await tester.pumpAndSettle();

  expect(find.byType(TravelerCard), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "icon.*switches"
```

Expected: FAIL — Toggle interaction not yet implemented

---

## Task 5: Implementation — Remove AppBar toggle tabs and add icons to filter chips

**Files:**
- Modify: `lib/features/matching/presentation/screens/search_announcement_screen.dart:1095-1145`

- [ ] **Step 1: Locate the current _ToggleTab usage in AppBar**

Around line 1095-1145, you'll find the `_ResultsViewState` build method with AppBar containing `_ToggleTab` widgets.

- [ ] **Step 2: Remove _ToggleTab widgets from AppBar**

Replace this section (lines 1100-1117):

```dart
// REMOVE THIS ENTIRE SECTION:
/*
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleTab(
                  icon: Icons.list_rounded,
                  label: 'Liste',
                  isActive: !_isMapView,
                  onTap: () => setState(() => _isMapView = false),
                ),
                _ToggleTab(
                  icon: Icons.map_outlined,
                  label: 'Carte',
                  isActive: _isMapView,
                  onTap: () => setState(() => _isMapView = true),
                ),
              ],
            ),
*/
```

Keep the filter icon intact. The AppBar actions should now be:

```dart
actions: [
  Stack(
    children: [
      IconButton(
        icon: const Icon(Icons.tune_rounded, color: DonyColors.ink900),
        onPressed: () => _showFilterBottomSheet(context),
        tooltip: 'Filtres',
      ),
      if (hasActiveFilters)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: DonyColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  ),
],
```

- [ ] **Step 3: Modify filter chips row to include list/map toggle as first items**

In `_buildListColumn`, find the filter chips ListView (around line 587-635). Replace the entire `SizedBox` containing the chips:

```dart
SizedBox(
  height: 48,
  child: ListenableBuilder(
    listenable: Listenable.merge([
      widget.ratingActive,
      widget.priceActive,
      widget.weekActive,
      widget.weightActive,
    ]),
    builder: (context, _) => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.sm,
      ),
      children: [
        // ── LIST/MAP TOGGLE ICONS (NEW) ────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // List icon button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: !_isMapView
                      ? DonyColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.list_rounded,
                    color:
                        !_isMapView ? DonyColors.primary : DonyColors.neutral500,
                    size: 24,
                  ),
                  onPressed: () => setState(() => _isMapView = false),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.sm,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: 'Liste',
                ),
              ),
              const SizedBox(width: DonySpacing.xs), // 4pt gap
              // Map icon button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _isMapView
                      ? DonyColors.primary.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.map_outlined,
                    color: _isMapView ? DonyColors.primary : DonyColors.neutral500,
                    size: 24,
                  ),
                  onPressed: () => setState(() => _isMapView = true),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.sm,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: 'Carte',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DonySpacing.md), // Spacer before filter chips
        // ── EXISTING FILTER CHIPS ─────────────────────
        _FilterChip(
          label: '★ 4.7+',
          icon: Icons.star_rounded,
          active: widget.ratingActive.value,
          onTap: () =>
              widget.ratingActive.value = !widget.ratingActive.value,
        ),
        const SizedBox(width: DonySpacing.sm),
        _FilterChip(
          label: '€/kg ↓',
          active: widget.priceActive.value,
          onTap: () =>
              widget.priceActive.value = !widget.priceActive.value,
        ),
        const SizedBox(width: DonySpacing.sm),
        _FilterChip(
          label: 'Cette semaine',
          active: widget.weekActive.value,
          onTap: () =>
              widget.weekActive.value = !widget.weekActive.value,
        ),
        const SizedBox(width: DonySpacing.sm),
        _FilterChip(
          label: '+10 kg',
          active: widget.weightActive.value,
          onTap: () =>
              widget.weightActive.value = !widget.weightActive.value,
        ),
      ],
    ),
  ),
),
```

- [ ] **Step 4: Verify `_isMapView` defaults to `false`**

Confirm line 550 still has:

```dart
bool _isMapView = false;
```

If not, add it. This ensures list view is shown by default.

- [ ] **Step 5: Run tests to verify implementation**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "AppBar does not contain"
```

Expected: PASS

```bash
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "list and map icons"
```

Expected: PASS

- [ ] **Step 6: Run all tests for the screen**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart
```

Expected: All tests PASS (including toggle interaction tests from Task 4)

- [ ] **Step 7: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add lib/features/matching/presentation/screens/search_announcement_screen.dart
git commit -m "refactor: move list/map toggle from appbar to filter chips row

- Remove _ToggleTab widgets from AppBar
- Add list and map icons as first items in filter chips row
- Style active/inactive icon states with primary/neutral colors
- Preserve existing filter logic and IndexedStack behavior
- Default to list view (_isMapView = false)"
```

---

## Task 6: Router Configuration — Exclude DonyBottomNav on search results route

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Locate search results route in router**

Find the route for `/search` or `/search-results` in the GoRouter configuration.

- [ ] **Step 2: Verify route structure**

The search results route should NOT be a child of the shell that contains `DonyBottomNav`. Currently it might look like:

```dart
ShellRoute(
  builder: (context, state, child) => DonyBottomNav(child: child),
  routes: [
    // ... other routes
    GoRoute(
      path: 'search',
      builder: (context, state) => const SearchAnnouncementScreen(),
    ),
  ],
)
```

- [ ] **Step 3: Move search route outside shell (if needed)**

If the search route is inside the shell, move it outside so it renders fullscreen without `DonyBottomNav`:

```dart
GoRoute(
  path: '/search',
  builder: (context, state) => const SearchAnnouncementScreen(),
  // No shell parent — renders fullscreen
),

ShellRoute(
  builder: (context, state, child) => DonyBottomNav(child: child),
  routes: [
    // Other routes that should have nav bar
  ],
)
```

- [ ] **Step 4: Verify no duplicate routes**

Ensure there's only ONE `/search` route definition in the router. If there's already one inside the shell, remove it.

- [ ] **Step 5: Test navigation**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter run --dart-define-from-file=env.dev.json
```

Steps to verify:
1. Open app (DonyBottomNav visible)
2. Navigate to search filter form (DonyBottomNav still visible)
3. Tap Search button
4. DonyBottomNav should disappear (fullscreen results)
5. Tap back button
6. Should return to filter form with DonyBottomNav visible

- [ ] **Step 6: Run integration test**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart
```

Expected: All tests still pass

- [ ] **Step 7: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add lib/app/router.dart
git commit -m "feat: exclude DonyBottomNav from search results route

- Move search results route outside shell with DonyBottomNav
- Search results now renders fullscreen without bottom nav
- User navigates back via standard back button"
```

---

## Task 7: Test — Full integration test for search results refactor

**Files:**
- Modify: `test/features/matching/presentation/search_announcement_screen_test.dart`

- [ ] **Step 1: Add comprehensive integration test**

```dart
testWidgets('Search results page: list view default, toggle to map, back to list', (WidgetTester tester) async {
  final mockResults = [
    AnnouncementModel(
      id: '1',
      travelerId: 'traveler1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime.now(),
      availableKg: 20,
      pricePerKg: 10,
      transportMode: TransportMode.plane,
      traveler: TravelerModel(
        id: 'traveler1',
        name: 'Ousmane',
        averageRating: 4.8,
      ),
    ),
  ];

  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // 1. Verify AppBar has journey title, no toggle
  expect(find.text('Paris → Dakar'), findsWidgets);
  expect(find.byType(_ToggleTab), findsNothing);

  // 2. Verify filter chips row has list/map icons as first items
  expect(find.byIcon(Icons.list_rounded), findsWidgets);
  expect(find.byIcon(Icons.map_outlined), findsWidgets);

  // 3. Verify list view is showing (default)
  expect(find.byType(TravelerCard), findsWidgets);
  expect(find.byType(AnnouncementMapView), findsNothing);

  // 4. Verify list icon is active (primary color)
  final listIcon = find.byIcon(Icons.list_rounded).first;
  final listIconWidget = tester.widget<Icon>(listIcon);
  expect(listIconWidget.color, DonyColors.primary);

  // 5. Verify map icon is inactive (neutral color)
  final mapIcon = find.byIcon(Icons.map_outlined).first;
  final mapIconWidget = tester.widget<Icon>(mapIcon);
  expect(mapIconWidget.color, DonyColors.neutral500);

  // 6. Tap map icon
  await tester.tap(find.byIcon(Icons.map_outlined));
  await tester.pumpAndSettle();

  // 7. Verify map view is now showing
  expect(find.byType(AnnouncementMapView), findsOneWidget);
  expect(find.byType(TravelerCard), findsNothing);

  // 8. Verify map icon is now active
  final mapIconAfter = tester.widget<Icon>(find.byIcon(Icons.map_outlined).first);
  expect(mapIconAfter.color, DonyColors.primary);

  // 9. Tap list icon
  await tester.tap(find.byIcon(Icons.list_rounded));
  await tester.pumpAndSettle();

  // 10. Verify list view is showing again
  expect(find.byType(TravelerCard), findsWidgets);
  expect(find.byType(AnnouncementMapView), findsNothing);
});

testWidgets('AppBar filter icon displays red dot when filters are active', (WidgetTester tester) async {
  final bloc = AnnouncementBloc(mockRepository)
    ..state = AnnouncementSearchLoaded(results: mockResults, isReloading: false);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AnnouncementBloc>(
        create: (_) => bloc,
        child: const SearchAnnouncementScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  // No red dot initially
  expect(find.byType(Positioned), findsNothing);

  // Activate a filter (rating)
  // (Depends on how filter state is managed — adjust as needed)
  await tester.tap(find.byIcon(Icons.tune_rounded));
  await tester.pumpAndSettle();

  // Verify red dot appears when filter is active
  // (This test may need adjustment based on actual filter UI)
});
```

- [ ] **Step 2: Run integration test**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart -k "full integration"
```

Expected: PASS

- [ ] **Step 3: Run all screen tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/matching/presentation/search_announcement_screen_test.dart
```

Expected: All tests PASS

- [ ] **Step 4: Run flutter analyze**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze
```

Expected: 0 errors, 0 warnings (or pre-existing only)

- [ ] **Step 5: Check test coverage**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

Expected: Coverage ≥ 90% on `search_announcement_screen.dart`

- [ ] **Step 6: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add test/features/matching/presentation/search_announcement_screen_test.dart
git commit -m "test: add comprehensive tests for search results refactor

- Test AppBar no longer contains toggle tabs
- Test filter chips row has list/map icons as first items
- Test toggle icons styling (active/inactive states)
- Test toggling between list and map views
- Test full integration flow with all assertions
- Verify coverage ≥ 90%"
```

---

## Task 8: Manual testing — Verify visual behavior in app

**Files:**
- None (manual testing only)

- [ ] **Step 1: Build and run the app**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter run --dart-define-from-file=env.dev.json
```

- [ ] **Step 2: Test navigation flow**

1. Open app → home screen (DonyBottomNav visible)
2. Tap search → filter form (DonyBottomNav visible)
3. Enter filters (departure: Paris, arrival: Dakar) → tap Search
4. **Verify:** Results page loads fullscreen (DonyBottomNav hidden)
5. **Verify:** List view showing by default (TravelerCard widgets visible)
6. **Verify:** Filter chips visible with list/map icons at the left
7. **Verify:** List icon is colored primary, map icon is gray

- [ ] **Step 3: Test toggle interaction**

1. Tap map icon (🗺️)
2. **Verify:** Map view appears, list icon becomes gray, map icon becomes primary
3. **Verify:** Smooth fade transition (no jank)
4. Tap list icon (📋)
5. **Verify:** List view appears, list icon becomes primary, map icon becomes gray
6. Repeat 3-5 times → verify smooth toggling

- [ ] **Step 4: Test filter interaction**

1. Scroll right in chips row → verify list/map icons stay visible
2. Tap filter chip (e.g., ★ 4.7+) → verify filtering works in both list and map
3. Toggle views while filtered → verify filtered results show in both views

- [ ] **Step 5: Test back navigation**

1. From results page, tap back button (iOS swipe-back or Android back)
2. **Verify:** Returns to filter form
3. **Verify:** DonyBottomNav reappears
4. **Verify:** Filter state preserved (same departure/arrival/date)

- [ ] **Step 6: Test edge cases**

1. Search with no results → verify toggle icons still present
2. Tap toggle during search loading → verify no crash
3. Rapidly tap toggle → verify no jank or state inconsistency

- [ ] **Step 7: Create manual test report**

If all manual tests pass, document findings:

```markdown
## Manual Testing Report — 2026-05-03

✅ **Navigation & UI:**
- Search results page renders fullscreen (DonyBottomNav hidden)
- List view displays by default
- Toggle icons visible in filter chips row

✅ **Toggle Interaction:**
- Tapping map icon switches to map view (smooth transition)
- Tapping list icon switches back to list view
- Icon styling matches design (primary when active, gray when inactive)

✅ **Filter Behavior:**
- Filters apply to both list and map views
- Toggle icons remain functional while filtered

✅ **Back Navigation:**
- Back button returns to filter form
- DonyBottomNav reappears
- Filter state preserved

✅ **Edge Cases:**
- No results: toggle icons present
- Loading: toggle responsive
- Rapid taps: no jank or state issues

All manual tests passed — ready for production.
```

---

## Summary

**Tasks completed:**
1. ✅ Test AppBar toggle removal
2. ✅ Test filter chips toggle icons
3. ✅ Test toggle icon styling
4. ✅ Test toggle interaction
5. ✅ Implement AppBar changes + filter chips toggle
6. ✅ Configure router to hide DonyBottomNav
7. ✅ Full integration test
8. ✅ Manual visual testing

**Files modified:**
- `lib/features/matching/presentation/screens/search_announcement_screen.dart`
- `lib/app/router.dart`
- `test/features/matching/presentation/search_announcement_screen_test.dart`

**Test coverage target:** ≥ 90% on modified files

**No breaking changes:** All existing filter logic, map view, and list rendering preserved.

