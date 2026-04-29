# Phase 5 — Assets, AppAssets & Screen Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance asset declarations, centralize asset paths with helper methods, and fix the 3 analyze warnings in test files.

**Architecture:** Two focused changes: (1) extend `app_assets.dart` with onboarding/empty-state/placeholder constants and helper methods so future screens reference typed constants instead of string literals; (2) fix the 3 analyze warnings (unnecessary casts and unused imports) in test files. No screen rewrites needed — SplashScreen, OnboardingScreen, HomeScreen, and router.dart are fully implemented and production-ready.

**Tech Stack:** Flutter/Dart, existing design system (`DonyColors`, `DonySpacing`, etc.), `google_fonts`, `flutter_animate`

---

## Pre-flight: What Is Already Done

Before touching any code, confirm these files exist and are complete:

| File | Status |
|------|--------|
| `lib/features/splash/presentation/splash_screen.dart` | ✅ Complete — health check, navigation, error handling, loading dots |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | ✅ Complete — single-page with 3 feature cards, CTA buttons |
| `lib/features/home/presentation/home_screen.dart` | ✅ Complete — role-based traveler/sender views |
| `lib/app/router.dart` | ✅ Complete — all routes, StatefulShellRoute, GoRouter |
| `lib/main.dart` | ✅ Complete — Firebase, Stripe, Sentry, Hive bootstrap |
| `pubspec.yaml` flutter.assets | ✅ Adequate — `assets/images/` and `assets/logos/` cover all 9 existing files |

**Do NOT recreate or rewrite any of the above.** Only Tasks 1–3 below are required.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/core/constants/app_assets.dart` | Modify | Add onboarding, empty-state, placeholder constants + 4 helper methods |
| `test/features/tracking/data/offline_sync_service_test.dart` | Modify | Remove 3 unnecessary casts (lines 57, 72, 81) |
| `test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart` | Modify | Remove 2 unused imports (`get_it`, `path`) |

---

## Task 1: Enhance app_assets.dart

**Files:**
- Modify: `lib/core/constants/app_assets.dart`

Current file has: `logo`, `logoWhite`, `logoSvg`, `logoWhiteSvg`, `logoMark`, `patternWax`.

We add: onboarding constants, empty-state constants, placeholder constants, and 4 typed helper methods. All new PNG paths reference the `assets/images/` directory (already declared in pubspec.yaml via the directory glob), so no pubspec change is needed.

- [ ] **Step 1: Write the test**

Create `test/core/constants/app_assets_test.dart`:

```dart
import 'package:dony/core/constants/app_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppAssets', () {
    group('getLogoForBackground', () {
      test('returns logoWhiteSvg for dark background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: true),
          AppAssets.logoWhiteSvg,
        );
      });

      test('returns logoSvg for light background', () {
        expect(
          AppAssets.getLogoForBackground(isDarkBackground: false),
          AppAssets.logoSvg,
        );
      });
    });

    group('getOnboardingImage', () {
      test('returns step 1 image', () {
        expect(AppAssets.getOnboardingImage(step: 1), AppAssets.onboarding1);
      });
      test('returns step 2 image', () {
        expect(AppAssets.getOnboardingImage(step: 2), AppAssets.onboarding2);
      });
      test('returns step 3 image', () {
        expect(AppAssets.getOnboardingImage(step: 3), AppAssets.onboarding3);
      });
      test('returns step 1 for out-of-range step', () {
        expect(AppAssets.getOnboardingImage(step: 99), AppAssets.onboarding1);
      });
    });

    group('getEmptyState', () {
      test('returns trips image for trips context', () {
        expect(AppAssets.getEmptyState(context: 'trips'), AppAssets.emptyStateTrips);
      });
      test('returns profile image for profile context', () {
        expect(AppAssets.getEmptyState(context: 'profile'), AppAssets.emptyStateProfile);
      });
      test('returns trips image as default for unknown context', () {
        expect(AppAssets.getEmptyState(context: 'unknown'), AppAssets.emptyStateTrips);
      });
    });

    group('getPlaceholder', () {
      test('returns driver placeholder', () {
        expect(AppAssets.getPlaceholder(type: 'driver'), AppAssets.placeholderDriver);
      });
      test('returns avatar placeholder', () {
        expect(AppAssets.getPlaceholder(type: 'avatar'), AppAssets.placeholderAvatar);
      });
      test('returns avatar for unknown type', () {
        expect(AppAssets.getPlaceholder(type: 'unknown'), AppAssets.placeholderAvatar);
      });
    });

    test('all constants are non-empty strings', () {
      final constants = [
        AppAssets.logo,
        AppAssets.logoWhite,
        AppAssets.logoSvg,
        AppAssets.logoWhiteSvg,
        AppAssets.logoMark,
        AppAssets.patternWax,
        AppAssets.onboarding1,
        AppAssets.onboarding2,
        AppAssets.onboarding3,
        AppAssets.emptyStateTrips,
        AppAssets.emptyStateProfile,
        AppAssets.placeholderDriver,
        AppAssets.placeholderAvatar,
      ];
      for (final c in constants) {
        expect(c, isNotEmpty, reason: 'Constant must not be empty');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/core/constants/app_assets_test.dart
```

Expected: FAIL with compilation error — `onboarding1`, `getOnboardingImage`, etc. not defined.

- [ ] **Step 3: Update app_assets.dart**

Replace the full content of `lib/core/constants/app_assets.dart`:

```dart
abstract final class AppAssets {
  // ── PNG images (existing) ────────────────────────────────────────────────
  static const logo = 'assets/images/logo_dony.png';
  static const logoWhite = 'assets/images/icon_foreground.png';

  // ── Logos SVG ────────────────────────────────────────────────────────────
  static const logoSvg      = 'assets/logos/logo-dony.svg';
  static const logoWhiteSvg = 'assets/logos/logo-dony-white.svg';
  static const logoMark     = 'assets/logos/logo-mark.svg';
  static const patternWax   = 'assets/logos/pattern-wax.svg';

  // ── Onboarding ───────────────────────────────────────────────────────────
  static const onboarding1 = 'assets/images/onboarding-1-trips.png';
  static const onboarding2 = 'assets/images/onboarding-2-sharing.png';
  static const onboarding3 = 'assets/images/onboarding-3-security.png';

  // ── Empty states ─────────────────────────────────────────────────────────
  static const emptyStateTrips   = 'assets/images/empty-state-trips.png';
  static const emptyStateProfile = 'assets/images/empty-state-profile.png';

  // ── Placeholders ─────────────────────────────────────────────────────────
  static const placeholderDriver = 'assets/images/placeholder-driver.png';
  static const placeholderAvatar = 'assets/images/placeholder-avatar.png';

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String getLogoForBackground({required bool isDarkBackground}) =>
      isDarkBackground ? logoWhiteSvg : logoSvg;

  static String getOnboardingImage({required int step}) {
    switch (step) {
      case 1:
        return onboarding1;
      case 2:
        return onboarding2;
      case 3:
        return onboarding3;
      default:
        return onboarding1;
    }
  }

  static String getEmptyState({required String context}) {
    switch (context) {
      case 'trips':
        return emptyStateTrips;
      case 'profile':
        return emptyStateProfile;
      default:
        return emptyStateTrips;
    }
  }

  static String getPlaceholder({required String type}) {
    switch (type) {
      case 'driver':
        return placeholderDriver;
      case 'avatar':
        return placeholderAvatar;
      default:
        return placeholderAvatar;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/core/constants/app_assets_test.dart
```

Expected: All 10 tests PASS.

- [ ] **Step 5: Run full test suite to check no regressions**

```bash
flutter test
```

Expected: All tests pass (same count as before, ~515+).

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/app_assets.dart test/core/constants/app_assets_test.dart
git commit -m "feat(assets): enhance AppAssets with onboarding/empty-state constants and helper methods"
```

---

## Task 2: Fix analyze warnings — unnecessary casts

**Files:**
- Modify: `test/features/tracking/data/offline_sync_service_test.dart` (lines 57, 72, 81)

`flutter analyze` reports: `Unnecessary cast` at lines 57, 72, 81.

- [ ] **Step 1: Read the file around those lines**

```bash
sed -n '50,90p' test/features/tracking/data/offline_sync_service_test.dart
```

- [ ] **Step 2: Remove the unnecessary casts**

For each of lines 57, 72, 81: find a pattern like `(something as SomeType)` where `something` is already of type `SomeType` (e.g., `(result as List<X>)` where `result` is already typed). Remove the `as SomeType` cast, keeping the value.

Example: if line 57 is:
```dart
final list = (result as List<OfflineScanEntry>);
```
Change to:
```dart
final list = result;
```

Apply the same fix pattern to lines 72 and 81.

- [ ] **Step 3: Run the affected tests**

```bash
flutter test test/features/tracking/data/offline_sync_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 4: Verify warnings gone**

```bash
flutter analyze 2>&1 | grep offline_sync_service_test
```

Expected: No output (no warnings for that file).

- [ ] **Step 5: Commit**

```bash
git add test/features/tracking/data/offline_sync_service_test.dart
git commit -m "fix(test): remove unnecessary casts in offline_sync_service_test"
```

---

## Task 3: Fix analyze warnings — unused imports

**Files:**
- Modify: `test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart`

`flutter analyze` reports: unused imports `get_it` and `path` at lines ~9 and ~12.

- [ ] **Step 1: Read the imports section**

```bash
head -20 test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart
```

- [ ] **Step 2: Remove the two unused import lines**

Delete:
```dart
import 'package:get_it/get_it.dart';
```
and:
```dart
import 'package:path/path.dart';
```

- [ ] **Step 3: Run the affected tests**

```bash
flutter test test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart
```

Expected: All tests PASS.

- [ ] **Step 4: Verify warnings gone**

```bash
flutter analyze 2>&1 | grep offline_scan_queue_screen_test
```

Expected: No output.

- [ ] **Step 5: Run full suite and analyze**

```bash
flutter test && flutter analyze 2>&1 | grep -E "^(error|warning)" | grep -v "test/"
```

Expected: All tests pass. No errors or warnings in `lib/` code.

- [ ] **Step 6: Commit**

```bash
git add test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart
git commit -m "fix(test): remove unused imports in offline_scan_queue_screen_test"
```

---

## Self-Review

### Spec coverage

| Spec requirement | Covered by |
|-----------------|-----------|
| 5A — Improve pubspec.yaml assets | Not needed — existing `assets/images/` and `assets/logos/` directory declarations already cover all 9 existing files. Adding paths for non-existent files would cause build failures. No change needed. |
| 5B — Create app_assets.dart with onboarding/empty-state/placeholder constants + helper methods | Task 1 |
| 5C — SplashScreen (2.5 sec, navigate to /home) | Already fully implemented — no work needed |
| 5C — OnboardingScreen (3 feature cards, CTA) | Already fully implemented — no work needed |
| 5C — HomeScreen (role-based, traveler/sender) | Already fully implemented — no work needed |
| 5C — main.dart with GoRouter routes | Already fully implemented — no work needed |

### Placeholder scan
No placeholders, TBDs, or "see above" references in this plan.

### Type consistency
`AppAssets` class uses `abstract final class` pattern (matching the existing style). All helper method return types are `String`, matching the constant types.
