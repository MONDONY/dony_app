# Plan 1 — Dark Mode Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement complete dark mode support in the dony Flutter app — palette dark, AppTheme.dark, audit + correction of 21 design system widgets, brightness-aware extensions, golden tests light + dark.

**Architecture:** Extend `DonyColors` with a dark palette. Refactor `AppTheme` to a single `_build(brightness)` factory producing both light and dark themes. Wire `darkTheme: AppTheme.dark` and `themeMode: ThemeMode.system` in `MaterialApp.router`. Audit each widget in `lib/core/design/widgets/` and replace hardcoded `DonyColors.X` semantic tokens with `Theme.of(context).colorScheme.X` accesses or brightness-aware extensions.

**Tech Stack:** Flutter 3.x, Material 3, `flutter_test`, `golden_toolkit` (already used in repo for goldens).

**Spec reference:** `docs/superpowers/specs/2026-05-09-dark-mode-foundations-design.md`

---

## File Structure

**Create:**
- `lib/core/design/DARK_MODE.md` — author guide for dark-aware widgets

**Modify:**
- `lib/core/design/tokens/color_tokens.dart` — add dark palette + brightness-aware extensions
- `lib/core/design/theme/app_theme.dart` — refactor to `_build(brightness)`, expose `light` and `dark`
- `lib/app/app.dart` — add `darkTheme` + `themeMode: system`
- `lib/core/design/CLAUDE.md` — add Dark mode section
- 21 widgets in `lib/core/design/widgets/dony_*.dart` — audit and migrate

**Test:**
- `test/core/design/theme/app_theme_test.dart` (new)
- `test/core/design/widgets/golden/` (new directory for goldens)
- `test/core/design/widgets/dony_*_test.dart` (extend existing tests with dark variants)

---

## Phase 1 — Tokens dark

### Task 1: Add dark palette constants to `color_tokens.dart`

**Files:**
- Modify: `lib/core/design/tokens/color_tokens.dart`

- [ ] **Step 1: Open the file and locate the bottom of the `DonyColors` class** (just before the closing `}` around line 161, after `static const shadow = Color(0x1A0A2540);`)

- [ ] **Step 2: Insert the dark palette before the closing brace**

```dart
  // ═══════════════════════════════════════════════════════════════
  // DARK MODE — Palette dérivée
  // Recalibrée pour contraste WCAG AA sur fond sombre
  // ═══════════════════════════════════════════════════════════════

  // Bleu primary recalibré (le #0B5FFF est trop saturé sur fond sombre)
  static const blueDark500 = Color(0xFF4D8AFF); // PRIMARY DARK ★
  static const blueDark600 = Color(0xFF6699FF); // Hover dark
  static const blueDark700 = Color(0xFF3D7AEF); // Press dark
  static const blueDark50  = Color(0xFF1A2B47); // PrimarySoft dark

  // Terra accent recalibré
  static const terraDark500 = Color(0xFFE8865B); // ACCENT DARK ★
  static const terraDark50  = Color(0xFF2E1F18); // Fond accent dark
  static const terraDark700 = Color(0xFFB95524);

  // Neutrals dark (chauds, cohérents avec sand)
  static const neutralDark0   = Color(0xFF0A0E14); // BG APP DARK ★
  static const neutralDark50  = Color(0xFF11161E);
  static const neutralDark100 = Color(0xFF161B23); // SURFACE DARK ★
  static const neutralDark200 = Color(0xFF222932);
  static const neutralDark300 = Color(0xFF2D333D); // BORDER DARK ★
  static const neutralDark400 = Color(0xFF7E7972); // text subtle dark
  static const neutralDark500 = Color(0xFFB5AFA5); // text muted dark
  static const neutralDark600 = Color(0xFFD8D2C7); // text high
  static const neutralDark700 = Color(0xFFF5F0E8); // TEXT PRIMARY DARK ★

  // Sand dark
  static const sandDark100 = Color(0xFF1F1A14); // SURFACE WARM DARK ★

  // États sémantiques dark
  static const successDark500 = Color(0xFF2DA677);
  static const successDark50  = Color(0xFF0F2B1F);
  static const warningDark500 = Color(0xFFF0B84A);
  static const warningDark50  = Color(0xFF2B2014);
  static const dangerDark500  = Color(0xFFEF5048);
  static const dangerDark50   = Color(0xFF2B1715);
  static const infoDark500    = Color(0xFF3FA0E5);
  static const infoDark50     = Color(0xFF0F1F2D);

  static const shadowDark = Color(0x66000000); // black @ 40%
```

- [ ] **Step 3: Run flutter analyze**

Run: `cd /home/a-diakite/Desktop/MyProject/my_app/dony_app && flutter analyze lib/core/design/tokens/color_tokens.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add lib/core/design/tokens/color_tokens.dart
git commit -m "feat(design): add dark palette constants to DonyColors"
```

---

### Task 2: Make `DonyStatusColors` extension fully brightness-aware

**Files:**
- Modify: `lib/core/design/tokens/color_tokens.dart:164-174`
- Test: `test/core/design/tokens/color_tokens_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/core/design/tokens/color_tokens_test.dart`:

```dart
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyStatusColors brightness-aware', () {
    const lightCs = ColorScheme.light();
    const darkCs = ColorScheme.dark();

    test('success switches between light and dark variants', () {
      expect(lightCs.success, DonyColors.success500);
      expect(darkCs.success, DonyColors.successDark500);
    });

    test('warning switches between light and dark variants', () {
      expect(lightCs.warning, DonyColors.warning500);
      expect(darkCs.warning, DonyColors.warningDark500);
    });

    test('info switches between light and dark variants', () {
      expect(lightCs.info, DonyColors.info500);
      expect(darkCs.info, DonyColors.infoDark500);
    });

    test('successLight switches between light and dark variants', () {
      expect(lightCs.successLight, DonyColors.success50);
      expect(darkCs.successLight, DonyColors.successDark50);
    });

    test('warningLight switches between light and dark variants', () {
      expect(lightCs.warningLight, DonyColors.warning50);
      expect(darkCs.warningLight, DonyColors.warningDark50);
    });

    test('infoLight switches between light and dark variants', () {
      expect(lightCs.infoLight, DonyColors.info50);
      expect(darkCs.infoLight, DonyColors.infoDark50);
    });

    test('errorLight switches between light and dark variants', () {
      expect(lightCs.errorLight, DonyColors.danger50);
      expect(darkCs.errorLight, DonyColors.dangerDark50);
    });

    test('surfaceWarm switches between light and dark variants', () {
      expect(lightCs.surfaceWarm, DonyColors.sand100);
      expect(darkCs.surfaceWarm, DonyColors.sandDark100);
    });
  });
}
```

- [ ] **Step 2: Run test, expect failures**

Run: `cd /home/a-diakite/Desktop/MyProject/my_app/dony_app && flutter test test/core/design/tokens/color_tokens_test.dart`
Expected: FAIL — `surfaceWarm` getter not found, dark variants return light values, etc.

- [ ] **Step 3: Replace the `DonyStatusColors` extension at the bottom of `color_tokens.dart`**

Replace lines 164-174 (the existing `extension DonyStatusColors on ColorScheme`) with:

```dart
extension DonyStatusColors on ColorScheme {
  Color get success => brightness == Brightness.light
      ? DonyColors.success500
      : DonyColors.successDark500;

  Color get warning => brightness == Brightness.light
      ? DonyColors.warning500
      : DonyColors.warningDark500;

  Color get info => brightness == Brightness.light
      ? DonyColors.info500
      : DonyColors.infoDark500;

  Color get successLight => brightness == Brightness.light
      ? DonyColors.success50
      : DonyColors.successDark50;

  Color get warningLight => brightness == Brightness.light
      ? DonyColors.warning50
      : DonyColors.warningDark50;

  Color get infoLight => brightness == Brightness.light
      ? DonyColors.info50
      : DonyColors.infoDark50;

  Color get errorLight => brightness == Brightness.light
      ? DonyColors.danger50
      : DonyColors.dangerDark50;

  Color get surfaceWarm => brightness == Brightness.light
      ? DonyColors.sand100
      : DonyColors.sandDark100;
}
```

- [ ] **Step 4: Run test, expect pass**

Run: `flutter test test/core/design/tokens/color_tokens_test.dart`
Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/design/tokens/color_tokens.dart test/core/design/tokens/color_tokens_test.dart
git commit -m "feat(design): make DonyStatusColors fully brightness-aware"
```

---

## Phase 2 — AppTheme.dark + wiring

### Task 3: Refactor `AppTheme` to support brightness parameter

**Files:**
- Modify: `lib/core/design/theme/app_theme.dart`
- Test: `test/core/design/theme/app_theme_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/core/design/theme/app_theme_test.dart`:

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('light has Brightness.light', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    test('dark has Brightness.dark', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('light vs dark have different surfaces', () {
      expect(
        AppTheme.light.colorScheme.surface,
        isNot(AppTheme.dark.colorScheme.surface),
      );
    });

    test('dark uses recalibrated primary blue', () {
      expect(AppTheme.dark.colorScheme.primary, DonyColors.blueDark500);
      expect(AppTheme.light.colorScheme.primary, DonyColors.primary);
    });

    test('dark scaffold background is neutralDark0', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, DonyColors.neutralDark0);
    });

    test('dark text color uses neutralDark700', () {
      expect(AppTheme.dark.colorScheme.onSurface, DonyColors.neutralDark700);
    });
  });
}
```

- [ ] **Step 2: Run test, expect failures**

Run: `flutter test test/core/design/theme/app_theme_test.dart`
Expected: FAIL — `AppTheme.dark` does not exist.

- [ ] **Step 3: Replace the entire content of `lib/core/design/theme/app_theme.dart`**

```dart
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final cs = ColorScheme(
      brightness: brightness,
      primary: isLight ? DonyColors.primary : DonyColors.blueDark500,
      onPrimary: DonyColors.textOnBrand,
      primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
      onPrimaryContainer: isLight ? DonyColors.primaryHover : DonyColors.blueDark500,
      secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
      onSecondary: DonyColors.textOnBrand,
      secondaryContainer: isLight ? DonyColors.accentSoft : DonyColors.terraDark50,
      onSecondaryContainer: isLight ? DonyColors.terra700 : DonyColors.terraDark500,
      surface: isLight ? DonyColors.surface : DonyColors.neutralDark100,
      onSurface: isLight ? DonyColors.textPrimary : DonyColors.neutralDark700,
      onSurfaceVariant: isLight ? DonyColors.textMuted : DonyColors.neutralDark500,
      surfaceContainerHighest: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      surfaceContainerLow: isLight ? DonyColors.bgApp : DonyColors.neutralDark50,
      outline: isLight ? DonyColors.borderDefault : DonyColors.neutralDark300,
      outlineVariant: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      error: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      onError: DonyColors.textOnBrand,
      errorContainer: isLight ? DonyColors.danger50 : DonyColors.dangerDark50,
      onErrorContainer: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      shadow: isLight ? DonyColors.shadow : DonyColors.shadowDark,
      inverseSurface: isLight ? DonyColors.ink800 : DonyColors.neutral0,
      onInverseSurface: isLight ? DonyColors.neutral0 : DonyColors.textPrimary,
    );

    final scaffoldBg = isLight ? DonyColors.bgApp : DonyColors.neutralDark0;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: DonyTypography.textTheme.headlineMedium?.copyWith(
          color: cs.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          side: BorderSide(color: cs.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
        labelStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(
          color: isLight ? DonyColors.neutral400 : DonyColors.neutralDark400,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          textStyle: DonyTypography.textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          side: BorderSide(color: cs.outline),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outline,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        inactiveTrackColor: cs.outline,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

Run: `flutter test test/core/design/theme/app_theme_test.dart`
Expected: All 6 tests PASS.

- [ ] **Step 5: Run flutter analyze on the file**

Run: `flutter analyze lib/core/design/theme/app_theme.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/core/design/theme/app_theme.dart test/core/design/theme/app_theme_test.dart
git commit -m "feat(design): add AppTheme.dark via _build(brightness) factory"
```

---

### Task 4: Wire `darkTheme` and `themeMode: system` in `MaterialApp`

**Files:**
- Modify: `lib/app/app.dart:123-137`

- [ ] **Step 1: Locate the `MaterialApp.router` widget at line 123 of `lib/app/app.dart`**

- [ ] **Step 2: Replace the `MaterialApp.router` block to add `darkTheme` and `themeMode`**

Replace lines 123-137 with:

```dart
          child: MaterialApp.router(
            title: 'dony',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
              Locale('en', 'US'),
            ],
          ),
```

- [ ] **Step 3: Run flutter analyze on the file**

Run: `flutter analyze lib/app/app.dart`
Expected: No issues found.

- [ ] **Step 4: Run the existing app smoke test (if present) or build to verify no regression**

Run: `flutter test test/widget_test.dart 2>/dev/null || flutter analyze lib/app/`
Expected: All passes / no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/app/app.dart
git commit -m "feat(app): enable dark mode via MaterialApp themeMode.system"
```

---

## Phase 3 — Audit DS widgets (3 batches)

> **Audit method (apply for each widget below):**
> 1. Read the widget file
> 2. For each `DonyColors.X` occurrence, classify it:
>    - **Semantic** (text, surface, border, primary, error) → migrate to `Theme.of(context).colorScheme.X` or `cs.X` if `cs` already exists. Use `DonyStatusColors` extension for `success/warning/info/successLight/warningLight/infoLight/errorLight/surfaceWarm`.
>    - **Primitive** (palette `blue500`, `terra500`, etc., used in const contexts or for illustrations/gradients) → keep as-is.
>    - **Hardcoded color in disabled/illustrative state** (e.g., `DonyColors.white` for icon on a colored bg) → keep, but document with a comment if needed.
> 3. Add a `cs` local at the top of `build()` if absent: `final cs = Theme.of(context).colorScheme;`
> 4. Run the existing widget tests for that file. If all pass, commit. If they fail, fix the test or the code.

### Task 5: Audit batch A — simple widgets (7 files)

**Files:**
- Modify: `lib/core/design/widgets/dony_app_bar.dart`
- Modify: `lib/core/design/widgets/dony_chip.dart`
- Modify: `lib/core/design/widgets/dony_checkbox.dart`
- Modify: `lib/core/design/widgets/dony_dialog.dart`
- Modify: `lib/core/design/widgets/dony_section_header.dart`
- Modify: `lib/core/design/widgets/dony_snackbar.dart`
- Modify: `lib/core/design/widgets/dony_icon_container.dart`

#### `dony_app_bar.dart`

- [ ] **Step 1: Replace `DonyColors.borderDefault` at line 130 with `Theme.of(context).colorScheme.outline`**

In `DonySliverAppBar.build`, locate line `child: Container(color: DonyColors.borderDefault, height: 1),` and replace with:

```dart
child: Container(color: Theme.of(context).colorScheme.outline, height: 1),
```

#### `dony_chip.dart`

- [ ] **Step 2: Migrate semantic colors at lines 41-43**

The current code is:
```dart
final bg = selected ? cs.primaryContainer : DonyColors.surface;
final fg = selected ? cs.primary : DonyColors.textMuted;
final border = selected ? cs.primary : DonyColors.borderDefault;
```

Replace with:
```dart
final bg = selected ? cs.primaryContainer : cs.surface;
final fg = selected ? cs.primary : cs.onSurfaceVariant;
final border = selected ? cs.primary : cs.outline;
```

#### `dony_checkbox.dart`

- [ ] **Step 3: Migrate the 3 semantic occurrences**

Read the file: `cat lib/core/design/widgets/dony_checkbox.dart`

For each `DonyColors.primary` → `cs.primary`. For each `DonyColors.borderDefault` → `cs.outline`. Add `final cs = Theme.of(context).colorScheme;` at the top of `build()` if missing.

#### `dony_dialog.dart`

- [ ] **Step 4: Replace `DonyColors.textMuted` at line 121 with `cs.onSurfaceVariant`**

The current line in `_DonyDialogWidget.build` is:
```dart
style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
```

Replace with:
```dart
style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
```

#### `dony_section_header.dart`

- [ ] **Step 5: Migrate the 1 occurrence**

Read the file. The single `DonyColors.X` should map to a semantic color from `cs.*`. If it's a text muted (likely `DonyColors.textMuted`), use `cs.onSurfaceVariant`.

#### `dony_snackbar.dart`

- [ ] **Step 6: Migrate the 2 occurrences**

The snackbar uses `cs.inverseSurface` / `cs.onInverseSurface` patterns. If hardcoded `DonyColors.surface` or `DonyColors.textPrimary` is found, replace with the corresponding `cs.*`.

#### `dony_icon_container.dart`

- [ ] **Step 7: Migrate the 2 occurrences**

Read the file and apply the same pattern: semantic colors → `cs.*`.

#### Run all tests for batch A

- [ ] **Step 8: Run tests**

Run: `flutter test test/core/design/widgets/`
Expected: All tests PASS (no test should break — we're only changing color sources, not logic).

If a test compares against `DonyColors.surface` directly, update the test to use the corresponding `cs.surface` (test rendered widget colors, not constants).

- [ ] **Step 9: Run flutter analyze**

Run: `flutter analyze lib/core/design/widgets/`
Expected: No issues found.

- [ ] **Step 10: Commit batch A**

```bash
git add lib/core/design/widgets/dony_app_bar.dart \
        lib/core/design/widgets/dony_chip.dart \
        lib/core/design/widgets/dony_checkbox.dart \
        lib/core/design/widgets/dony_dialog.dart \
        lib/core/design/widgets/dony_section_header.dart \
        lib/core/design/widgets/dony_snackbar.dart \
        lib/core/design/widgets/dony_icon_container.dart
git commit -m "refactor(design): migrate batch A widgets to ColorScheme (dark-aware)"
```

---

### Task 6: Audit batch B — medium widgets (9 files)

**Files:**
- Modify: `lib/core/design/widgets/dony_badge.dart`
- Modify: `lib/core/design/widgets/dony_bottom_sheet.dart`
- Modify: `lib/core/design/widgets/dony_button.dart`
- Modify: `lib/core/design/widgets/dony_info_row.dart`
- Modify: `lib/core/design/widgets/dony_list_tile.dart`
- Modify: `lib/core/design/widgets/dony_page_scaffold.dart`
- Modify: `lib/core/design/widgets/dony_search_field.dart`
- Modify: `lib/core/design/widgets/dony_step_indicator.dart`
- Modify: `lib/core/design/widgets/dony_user_card.dart`

For each widget below, follow the audit method (read, classify, migrate, ensure `final cs = Theme.of(context).colorScheme;` is present at top of `build()`).

#### Migration mapping (apply to all files in this batch)

| Hardcoded `DonyColors.X` | Replace with |
|---|---|
| `DonyColors.surface` | `cs.surface` |
| `DonyColors.bgApp` | `Theme.of(context).scaffoldBackgroundColor` |
| `DonyColors.surfaceWarm` | `cs.surfaceWarm` (DonyStatusColors extension) |
| `DonyColors.textPrimary` | `cs.onSurface` |
| `DonyColors.textMuted` | `cs.onSurfaceVariant` |
| `DonyColors.textSubtle` | `cs.onSurfaceVariant` (or keep for placeholders only) |
| `DonyColors.borderDefault` | `cs.outline` |
| `DonyColors.borderStrong` | `cs.outlineVariant` |
| `DonyColors.borderFocus` | `cs.primary` |
| `DonyColors.primary` | `cs.primary` |
| `DonyColors.primarySoft` | `cs.primaryContainer` |
| `DonyColors.accent` | `cs.secondary` |
| `DonyColors.accentSoft` | `cs.secondaryContainer` |
| `DonyColors.error` (semantic) | `cs.error` |
| `DonyColors.errorLight` | `cs.errorLight` (extension) |
| `DonyColors.success` (semantic) | `cs.success` (extension) |
| `DonyColors.successLight` | `cs.successLight` (extension) |
| `DonyColors.warning`, `cs.warning` | `cs.warning` (extension) |
| `DonyColors.warningLight` | `cs.warningLight` (extension) |
| `DonyColors.info` (semantic) | `cs.info` (extension) |
| `DonyColors.infoLight` | `cs.infoLight` (extension) |
| `DonyColors.neutral400` (used as text) | `cs.onSurfaceVariant.withValues(alpha: 0.7)` |
| `DonyColors.neutral200` | `cs.outline` |
| `DonyColors.shadow` | `cs.shadow` |
| `DonyColors.white` (on colored bg) | KEEP (illustrative use) |
| Primitives `DonyColors.blue500`, `terra500`, etc. (gradients/illustrations) | KEEP |

- [ ] **Step 1: For each of the 9 files, read it and apply the mapping above**

Run for each file (replace `<file>`):
```bash
cat lib/core/design/widgets/<file>.dart
```

Then edit using the mapping. Pay attention to:
- `dony_button.dart` — has 4 button variants. The hardcoded `DonyColors.white` for spinner color in `primary` and `destructive` variants is correct (it's `onPrimary` semantically). Replace with `DonyColors.textOnBrand` or `Theme.of(context).colorScheme.onPrimary`.
- `dony_bottom_sheet.dart` — the `BottomSheetContent` has its own background. Migrate `DonyColors.surface` → `cs.surface`, the handle bar color → `cs.outline` or `cs.onSurfaceVariant.withValues(alpha: 0.4)`.
- `dony_search_field.dart` — uses `DonyColors.surface` and `DonyColors.textMuted` for icon and placeholder.
- `dony_page_scaffold.dart` — root scaffold, migrate to `Theme.of(context).scaffoldBackgroundColor`.

- [ ] **Step 2: After each file is modified, run flutter analyze on it**

Run: `flutter analyze lib/core/design/widgets/<file>.dart`
Expected: No issues.

- [ ] **Step 3: Run all DS widget tests**

Run: `flutter test test/core/design/widgets/`
Expected: All pass. Fix any test that asserts on a constant `DonyColors.X` by switching to `cs.X` or by pumping the widget within a `MaterialApp(theme: AppTheme.light)` and asserting the rendered color.

- [ ] **Step 4: Commit batch B**

```bash
git add lib/core/design/widgets/dony_badge.dart \
        lib/core/design/widgets/dony_bottom_sheet.dart \
        lib/core/design/widgets/dony_button.dart \
        lib/core/design/widgets/dony_info_row.dart \
        lib/core/design/widgets/dony_list_tile.dart \
        lib/core/design/widgets/dony_page_scaffold.dart \
        lib/core/design/widgets/dony_search_field.dart \
        lib/core/design/widgets/dony_step_indicator.dart \
        lib/core/design/widgets/dony_user_card.dart
git commit -m "refactor(design): migrate batch B widgets to ColorScheme (dark-aware)"
```

---

### Task 7: Audit batch C — complex widgets (6 files)

**Files:**
- Modify: `lib/core/design/widgets/dony_avatar.dart`
- Modify: `lib/core/design/widgets/dony_empty_state.dart`
- Modify: `lib/core/design/widgets/dony_radio_group.dart`
- Modify: `lib/core/design/widgets/dony_status_banner.dart`
- Modify: `lib/core/design/widgets/dony_text_field.dart`
- Modify: `lib/core/design/widgets/dony_trip_card.dart`

These files have the most occurrences (8-14 per file). Apply the migration mapping from Task 6.

#### Specific guidance per file

- [ ] **Step 1: `dony_avatar.dart` (10 occurrences)**

The avatar has fallback colors based on user role. The `verified` badge color is hardcoded green — keep `DonyColors.success500` here (intentional brand color, not surface-bound). Migrate background tint, text color, and border to `cs.*`.

- [ ] **Step 2: `dony_empty_state.dart` (8 occurrences)**

Specifically line 97 `color: DonyColors.neutral400` → `cs.onSurfaceVariant.withValues(alpha: 0.7)`. Line 46 `DonyColors.textMuted` → `cs.onSurfaceVariant`. The icon background tints (lines 54-69) use status semantic colors — already use `DonyColors.primarySoft` and `DonyColors.errorLight` which need to be replaced with `cs.primaryContainer` and `cs.errorLight` (extension).

- [ ] **Step 3: `dony_radio_group.dart` (8 occurrences)**

Active fill, border, label colors. Apply standard mapping.

- [ ] **Step 4: `dony_status_banner.dart` (14 occurrences) — biggest job**

This widget has 4 status types (success, warning, error, info) each with bg + fg + border. Migrate **all** to use the `DonyStatusColors` extension on ColorScheme. Each status branch should resolve to:

```dart
final (bg, fg) = switch (type) {
  DonyStatusBannerType.success => (cs.successLight, cs.success),
  DonyStatusBannerType.warning => (cs.warningLight, cs.warning),
  DonyStatusBannerType.error   => (cs.errorLight, cs.error),
  DonyStatusBannerType.info    => (cs.infoLight, cs.info),
};
```

Replace any hardcoded `DonyColors.success500`, `DonyColors.danger50`, etc. with the extension equivalents.

- [ ] **Step 5: `dony_text_field.dart`**

Most styling comes from `inputDecorationTheme` (already brightness-aware via Task 3). Audit for any hardcoded `DonyColors.X` in the widget itself (suffix icons, helper text). Migrate to `cs.*`.

- [ ] **Step 6: `dony_trip_card.dart` (9 occurrences)**

Card border, route arrow color, time/city text colors, accent highlights. Apply mapping. Note: if the card uses gradient colors (e.g., `LinearGradient([blue500, terra500])`), keep primitives.

- [ ] **Step 7: Run all DS widget tests**

Run: `flutter test test/core/design/widgets/`
Expected: All pass.

- [ ] **Step 8: Run flutter analyze on the whole DS**

Run: `flutter analyze lib/core/design/`
Expected: No issues.

- [ ] **Step 9: Commit batch C**

```bash
git add lib/core/design/widgets/dony_avatar.dart \
        lib/core/design/widgets/dony_empty_state.dart \
        lib/core/design/widgets/dony_radio_group.dart \
        lib/core/design/widgets/dony_status_banner.dart \
        lib/core/design/widgets/dony_text_field.dart \
        lib/core/design/widgets/dony_trip_card.dart
git commit -m "refactor(design): migrate batch C widgets to ColorScheme (dark-aware)"
```

---

## Phase 4 — Golden tests light + dark

### Task 8: Add golden tests for representative DS widgets

**Files:**
- Test: `test/core/design/widgets/golden/dony_widgets_golden_test.dart` (create)

> **Pre-requisite:** ensure `golden_toolkit` is in dev_dependencies. Run `grep golden_toolkit pubspec.yaml` — if absent, add it via `flutter pub add --dev golden_toolkit` then `flutter pub get`.

- [ ] **Step 1: Create the golden test file**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Widget _wrap(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Dony widgets — goldens', () {
    for (final brightness in Brightness.values) {
      final suffix = brightness == Brightness.light ? 'light' : 'dark';

      testGoldens('DonyCard — $suffix', (tester) async {
        await tester.pumpWidgetBuilder(
          _wrap(
            const DonyCard(child: Text('Carte de test')),
            brightness: brightness,
          ),
          surfaceSize: const Size(400, 200),
        );
        await screenMatchesGolden(tester, 'dony_card_$suffix');
      });

      testGoldens('DonyButton primary — $suffix', (tester) async {
        await tester.pumpWidgetBuilder(
          _wrap(
            DonyButton(label: 'Action', onPressed: () {}),
            brightness: brightness,
          ),
          surfaceSize: const Size(400, 100),
        );
        await screenMatchesGolden(tester, 'dony_button_primary_$suffix');
      });

      testGoldens('DonyEmptyState empty — $suffix', (tester) async {
        await tester.pumpWidgetBuilder(
          _wrap(
            const DonyEmptyState(
              title: 'Aucun élément',
              description: 'Reviens plus tard',
            ),
            brightness: brightness,
          ),
          surfaceSize: const Size(400, 400),
        );
        await screenMatchesGolden(tester, 'dony_empty_state_$suffix');
      });

      testGoldens('DonyChip selected — $suffix', (tester) async {
        await tester.pumpWidgetBuilder(
          _wrap(
            DonyChip(label: 'Paris', selected: true, onTap: () {}),
            brightness: brightness,
          ),
          surfaceSize: const Size(200, 100),
        );
        await screenMatchesGolden(tester, 'dony_chip_selected_$suffix');
      });

      testGoldens('DonyStatusBanner success — $suffix', (tester) async {
        await tester.pumpWidgetBuilder(
          _wrap(
            const DonyStatusBanner(
              type: DonyStatusBannerType.success,
              title: 'Succès',
              message: 'Opération réussie',
            ),
            brightness: brightness,
          ),
          surfaceSize: const Size(400, 150),
        );
        await screenMatchesGolden(tester, 'dony_status_banner_success_$suffix');
      });
    }
  });
}
```

- [ ] **Step 2: Generate goldens for the first time**

Run: `flutter test --update-goldens test/core/design/widgets/golden/dony_widgets_golden_test.dart`
Expected: 10 PNG files created in `test/core/design/widgets/golden/goldens/` (5 widgets × 2 brightnesses).

- [ ] **Step 3: Inspect the goldens manually**

Run: `ls test/core/design/widgets/golden/goldens/`
Expected: dony_card_light.png, dony_card_dark.png, dony_button_primary_light.png, dony_button_primary_dark.png, dony_empty_state_light.png, dony_empty_state_dark.png, dony_chip_selected_light.png, dony_chip_selected_dark.png, dony_status_banner_success_light.png, dony_status_banner_success_dark.png.

Open the PNGs and verify they look correct (light has light bg + dark text, dark has dark bg + light text, no clipping, no contrast issues).

- [ ] **Step 4: Run goldens in verification mode**

Run: `flutter test test/core/design/widgets/golden/dony_widgets_golden_test.dart`
Expected: All goldens PASS.

- [ ] **Step 5: Commit goldens**

```bash
git add test/core/design/widgets/golden/
git commit -m "test(design): add golden tests for DS widgets in light + dark"
```

---

## Phase 5 — Documentation

### Task 9: Update `CLAUDE.md` and create `DARK_MODE.md`

**Files:**
- Modify: `lib/core/design/CLAUDE.md`
- Create: `lib/core/design/DARK_MODE.md`

- [ ] **Step 1: Add Dark mode section to `lib/core/design/CLAUDE.md`**

Insert after the "Couleurs en contexte `build()`" section (around line 97):

```markdown

---

## Dark mode

L'app supporte le dark mode via `ThemeMode.system` — adaptation automatique au réglage OS.

### Règle d'or

**Tout widget DS doit lire ses couleurs sémantiques via `Theme.of(context).colorScheme.X`, JAMAIS via `DonyColors.surface`, `DonyColors.textPrimary`, `DonyColors.bgApp`, `DonyColors.borderDefault` directement.** Ces tokens sont light-only.

| Hardcodé (interdit) | À utiliser à la place |
|---|---|
| `DonyColors.surface` | `cs.surface` |
| `DonyColors.bgApp` | `Theme.of(context).scaffoldBackgroundColor` |
| `DonyColors.textPrimary` | `cs.onSurface` |
| `DonyColors.textMuted` | `cs.onSurfaceVariant` |
| `DonyColors.borderDefault` | `cs.outline` |
| `DonyColors.primary` | `cs.primary` |
| `DonyColors.success`, `successLight` | `cs.success`, `cs.successLight` (extension) |

`DonyColors.blue500`, `DonyColors.terra500`, etc. (palette primitive) restent autorisés en contexte `const` ou pour des dégradés — ils ne sont pas brightness-aware par design.

### Extension `DonyStatusColors`

Pour les couleurs de statut (success / warning / info / error light variants + surfaceWarm), passer par l'extension :

```dart
final cs = Theme.of(context).colorScheme;
cs.success      // brightness-aware
cs.successLight // brightness-aware
cs.warning
cs.warningLight
cs.info
cs.infoLight
cs.errorLight
cs.surfaceWarm  // sand100 ↔ sandDark100
```

Voir `DARK_MODE.md` pour le guide d'auteur complet.
```

- [ ] **Step 2: Create `lib/core/design/DARK_MODE.md`**

```markdown
# Dark mode — Guide d'auteur de widget

Ce document explique comment écrire des widgets compatibles dark mode dans le DS dony.

## Règle absolue

Lire toutes les couleurs sémantiques via `Theme.of(context).colorScheme.X`, jamais via les constantes `DonyColors.X`.

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  // ... utiliser cs.surface, cs.onSurface, cs.primary, etc.
}
```

## Checklist avant de hardcoder une couleur

Pose-toi ces 6 questions avant d'écrire `DonyColors.X` :

1. **Cette couleur représente-t-elle un rôle sémantique** (texte principal, fond, bordure, primary action) ? → utilise `cs.X`.
2. **Est-elle utilisée pour un état métier** (success, warning, error) ? → utilise l'extension `cs.success` / `cs.warning` / `cs.info` / `cs.errorLight`.
3. **Est-ce une couleur de surface communautaire** (sand) ? → utilise `cs.surfaceWarm` (extension).
4. **Est-ce une couleur de marque utilisée dans une illustration** (logo, gradient, icône hero) ? → primitive `DonyColors.blue500` OK, pas brightness-aware.
5. **Est-ce une couleur "on colored bg"** (texte blanc sur primary, blanc sur error) ? → primitive `DonyColors.textOnBrand` OK, mais préfère `cs.onPrimary` / `cs.onError`.
6. **Cette couleur peut-elle dépendre d'un contexte `const` ?** Si oui, primitive obligatoire (les `cs.X` ne sont pas const). Sinon, sémantique.

## Patterns corrects

### Card avec texte

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.surface,
    child: Text('Bonjour', style: TextStyle(color: cs.onSurface)),
  );
}
```

### Bordure adaptative

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: cs.outline),
    ),
    // ...
  );
}
```

### Statut succès

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    color: cs.successLight, // brightness-aware via extension
    child: Icon(Icons.check, color: cs.success),
  );
}
```

## Patterns incorrects

### ❌ Hardcoded surface

```dart
return Container(
  color: DonyColors.surface, // CASSE en dark — produit un fond blanc sur bg noir
  // ...
);
```

### ❌ Hardcoded text color

```dart
Text('...', style: TextStyle(color: DonyColors.textPrimary)) // CASSE en dark
```

### ❌ Mélange des deux

```dart
return Container(
  color: cs.surface,                       // ✅ adaptatif
  child: Text('...',
    style: TextStyle(color: DonyColors.textPrimary)), // ❌ hardcodé
);
```

## Tester localement en dark

Pour vérifier qu'un widget rend bien en dark sans changer le réglage du device :

```dart
testWidgets('mon widget rend en dark', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark, // force le dark
    home: Scaffold(body: MonWidget()),
  ));
  // ... assertions
});
```

Pour un golden test :

```dart
testGoldens('mon widget — dark', (tester) async {
  await tester.pumpWidgetBuilder(
    MonWidget(),
    wrapper: materialAppWrapper(theme: AppTheme.dark),
  );
  await screenMatchesGolden(tester, 'mon_widget_dark');
});
```

## Cas d'exception

Tu peux conserver une couleur primitive `DonyColors.X` si :

- C'est dans un contexte `const Color(...)` (impossible d'accéder au `BuildContext`)
- C'est une illustration (gradient, dégradé décoratif, icône avec couleur de marque)
- C'est sur un fond de couleur garantie (ex: `DonyColors.white` pour un texte sur un bouton primary à fond bleu — équivaut à `cs.onPrimary`)

Documente alors avec un commentaire :

```dart
// Couleur primitive intentionnelle : illustration de marque
gradient: LinearGradient(colors: [DonyColors.blue500, DonyColors.terra500]),
```
```

- [ ] **Step 3: Commit documentation**

```bash
git add lib/core/design/CLAUDE.md lib/core/design/DARK_MODE.md
git commit -m "docs(design): add dark mode guide and CLAUDE.md section"
```

---

## Phase 6 — Final verification

### Task 10: Full coverage check + manual smoke

**Files:** None (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: 0 failures.

- [ ] **Step 2: Generate coverage report**

Run: `flutter test --coverage`
Then: `genhtml coverage/lcov.info -o coverage/html 2>/dev/null || true`

- [ ] **Step 3: Check coverage of `lib/core/design/`**

Inspect `coverage/lcov.info` or `coverage/html/index.html` and verify:
- `lib/core/design/tokens/color_tokens.dart` — coverage ≥ 90 %
- `lib/core/design/theme/app_theme.dart` — coverage ≥ 90 %
- Each widget in `lib/core/design/widgets/` — coverage ≥ 90 %

If any file is below 90 %, add tests until threshold is met. Most coverage already exists from previous work — the goldens + brightness tests added by this plan should push it above the threshold.

- [ ] **Step 4: Run flutter analyze on the whole project**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Manual smoke test**

Build and run the app on a device/simulator:

```bash
flutter run --dart-define-from-file=env.dev.json
```

While the app is running, change the system theme on the device:
- Android: Settings → Display → Dark theme → ON
- iOS: Settings → Display & Brightness → Dark

Verify visually that the following 5 screens render correctly in dark mode:
1. Splash (`/`)
2. Onboarding (`/onboarding`)
3. Home/hub (after auth — `/home`)
4. Profile (`/profile`)
5. Tracking timeline (any active bid → tracking)

Look for:
- ✅ No white-on-white or black-on-black text
- ✅ Bordures visibles mais discrètes
- ✅ Boutons primary contrastés (texte blanc sur bleu clair)
- ✅ Status banners (succès, erreur) lisibles

If any screen has visible issues, identify the widget responsible and fix it (likely a missed `DonyColors.X` not migrated). Add a regression test.

- [ ] **Step 6: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(design): visual smoke fixes in dark mode" # or skip if nothing to commit
```

- [ ] **Step 7: Plan complete — verify branch state**

Run: `git log --oneline | head -10`
Expected: 9-10 new commits since the start of the plan, all on the working branch.

---

## Self-review checklist

- [ ] Spec coverage : tokens dark ✓, AppTheme.dark ✓, ThemeMode.system ✓, audit 21 widgets ✓ (batches A+B+C cover 22 widget files), goldens light+dark ✓, doc CLAUDE+DARK_MODE ✓, coverage ≥90% verified ✓
- [ ] No "TBD" / "TODO" placeholders in steps
- [ ] All identifiers used in later tasks match earlier definitions (`AppTheme.dark`, `DonyColors.blueDark500`, `cs.surfaceWarm`, etc.)
- [ ] Exact paths everywhere
- [ ] Exact commands with expected output
- [ ] One commit per logical unit (~9 commits total)
