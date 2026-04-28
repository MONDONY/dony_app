# Design System Refactoring — Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded Flutter widgets and deprecated design tokens in 17+ feature screens with the official dony design system components.

**Architecture:** Each screen imports `package:dony/core/design/design_system.dart` and uses `Theme.of(context).colorScheme` for colors, `Theme.of(context).textTheme` for typography, and `DonySpacing`/`DonyRadius` constants for layout. Dedicated dony widgets (`DonyAppBar`, `DonyButton`, `DonyDialog`, `DonySnackbar`, `DonyBottomSheet`) replace Flutter primitives.

**Tech Stack:** Flutter 3.x, Material 3, `flutter_animate`, `google_fonts` (reference only — never inline), `go_router` (context.pop, not Navigator.pop)

---

## Replacement Reference Guide

Always have this open when implementing. These are the only valid replacements.

### Colors

Inside `build(BuildContext context)`, always use:
```dart
final cs = Theme.of(context).colorScheme;
```

| Deprecated / Hardcoded | Replacement |
|---|---|
| `DonyColors.green400` / `DonyColors.primary` | `cs.primary` |
| `DonyColors.grey50` / `DonyColors.bgApp` | remove — theme sets `scaffoldBackgroundColor` automatically |
| `DonyColors.grey200` / `DonyColors.borderDefault` | `cs.outline` |
| `DonyColors.grey300` / `DonyColors.neutral300` | `DonyColors.neutral300` (const OK) |
| `DonyColors.grey400` / `DonyColors.textSubtle` | `cs.onSurfaceVariant` |
| `DonyColors.white` / `Colors.white` | `cs.surface` |
| `DonyColors.ink900` / `DonyColors.textPrimary` | `cs.onSurface` |
| `Colors.red.shade600` / `Colors.red.shade700` | `cs.error` |

**Exception:** `DonyColors.X` is valid in `const` contexts where `cs` is unavailable (e.g., `const TextStyle(color: DonyColors.primarySoft)`).

### Typography

```dart
final tt = Theme.of(context).textTheme;
```

| Hardcoded `GoogleFonts` spec | `textTheme` slot |
|---|---|
| `fontSize: 32, w800, letterSpacing: -0.5` | `tt.displayLarge` |
| `fontSize: 28, w800, letterSpacing: -0.5` | `tt.displayLarge` |
| `fontSize: 22, w700` | `tt.headlineLarge` |
| `fontSize: 18, w700` | `tt.headlineMedium` |
| `fontSize: 17, w700` | `tt.headlineMedium` |
| `fontSize: 15–16, w700` | `tt.titleLarge` |
| `fontSize: 14, w600` | `tt.titleMedium` |
| `fontSize: 16, w400` | `tt.bodyLarge` |
| `fontSize: 14, w400` | `tt.bodyMedium` |
| `fontSize: 12–13, w400` | `tt.bodySmall` |
| `fontSize: 14, w700` | `tt.labelLarge` |
| `fontSize: 11, w600, letterSpacing: 0.8` | `tt.labelMedium` |
| `fontSize: 10, w600` | `tt.labelSmall` |

For color overrides: `tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)`

**Never** use `GoogleFonts.X(...)` inline in widgets. The theme already wires Hanken Grotesk + Plus Jakarta Sans via `DonyTypography`.

### Spacing

```dart
// Replace:          EdgeInsets.all(24)  →  EdgeInsets.all(DonySpacing.xl)
// Replace:          SizedBox(height: 16) →  SizedBox(height: DonySpacing.base)
DonySpacing.xs   = 4
DonySpacing.sm   = 8
DonySpacing.md   = 12
DonySpacing.base = 16
DonySpacing.lg   = 20
DonySpacing.xl   = 24
DonySpacing.xxl  = 32
DonySpacing.huge = 48
```

### Radius

```dart
DonyRadius.xs   = 4    // inner elements
DonyRadius.sm   = 8    // snackbars
DonyRadius.md   = 12   // inputs ★
DonyRadius.lg   = 14   // buttons ★
DonyRadius.card = 16   // cards ★
DonyRadius.xl   = 20   // chips/pills
DonyRadius.sheet= 24   // bottom sheets
DonyRadius.full = 999  // badges (pill)
```

### Component Replacements

**Scaffold background:** Remove `backgroundColor:` entirely — `AppTheme` sets `scaffoldBackgroundColor: DonyColors.bgApp` globally. **Exception:** SplashScreen intentionally uses blue background — keep as-is.

**AppBar:**
```dart
// BEFORE
AppBar(
  title: Text('Titre', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
  backgroundColor: DonyColors.white,
  elevation: 0,
  bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
)

// AFTER
DonyAppBar(title: 'Titre')
```

For screens with tabs, pass `appBarBottom: TabBar(...)` to `DonyPageScaffold` or `DonyAppBar`.

**Button:**
```dart
// BEFORE
SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    onPressed: isLoading ? null : _submit,
    style: ElevatedButton.styleFrom(
      backgroundColor: DonyColors.green400,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    child: isLoading ? CircularProgressIndicator(...) : Text('Envoyer'),
  ),
)

// AFTER
DonyButton(
  label: 'Envoyer',
  onPressed: _submit,
  isLoading: isLoading,
)
```

**Snackbar:**
```dart
// BEFORE
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
);

// AFTER
DonySnackbar.show(context, message: message, type: DonySnackbarType.error);

// Success variant:
DonySnackbar.show(context, message: 'Trajet créé !', type: DonySnackbarType.success);
```

**Dialog:**
```dart
// BEFORE
showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text('Supprimer ?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17)),
    content: Text('Cette action est irréversible.', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: DonyColors.grey400)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler')),
      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: TextStyle(color: DonyColors.error))),
    ],
  ),
)

// AFTER
DonyDialog.show(
  context,
  title: 'Supprimer ?',
  message: 'Cette action est irréversible.',
  confirmLabel: 'Supprimer',
  variant: DonyDialogVariant.destructive,
)
```

**Bottom Sheet:**
```dart
// BEFORE
showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (_) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, color: DonyColors.grey200),
      ...content,
    ]),
  ),
)

// AFTER
DonyBottomSheet.show(
  context,
  title: 'Titre optionnel',
  child: Column(children: [...content]),
)
```

**Navigator.pop → context.pop:**
```dart
// BEFORE
Navigator.pop(context);
Navigator.pop(context, result);

// AFTER
context.pop();
context.pop(result);
```

---

## Files Map

### Task 1 — Auth screens (5 files)
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- Modify: `lib/features/auth/presentation/screens/pin_setup_screen.dart`
- Modify: `lib/features/auth/presentation/screens/role_selection_screen.dart`
- Modify: `lib/features/auth/presentation/screens/local_auth_screen.dart`

### Task 2 — KYC screens (3 files)
- Modify: `lib/features/kyc/presentation/screens/kyc_onboarding_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_status_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_webview_screen.dart`

### Task 3 — Matching Part 1 (3 files)
- Modify: `lib/features/matching/presentation/screens/announcement_list_screen.dart`
- Modify: `lib/features/matching/presentation/screens/shipment_list_screen.dart`
- Modify: `lib/features/matching/presentation/screens/matching_management_screen.dart`

### Task 4 — Matching Part 2 (3 files)
- Modify: `lib/features/matching/presentation/screens/announcement_detail_screen.dart`
- Modify: `lib/features/matching/presentation/screens/traveler_profile_screen.dart`
- Modify: `lib/features/matching/presentation/screens/handover_screen.dart`

### Task 5 — Cancellation + Notifications + Profile (5 files)
- Modify: `lib/features/cancellation/presentation/screens/cancellation_screen.dart`
- Modify: `lib/features/cancellation/presentation/screens/rematch_search_screen.dart`
- Modify: `lib/features/notifications/presentation/inbox_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/features/profile/presentation/edit_profile_screen.dart`

### Task 6 — Payments + Tracking (4 files)
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Modify: `lib/features/payments/presentation/screens/payout_onboarding_screen.dart`
- Modify: `lib/features/tracking/presentation/screens/tracking_search_screen.dart`
- Modify: `lib/features/tracking/presentation/widgets/qr_code_card.dart`

---

## Task 1: Auth Screens

**Files:**
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- Modify: `lib/features/auth/presentation/screens/pin_setup_screen.dart`
- Modify: `lib/features/auth/presentation/screens/role_selection_screen.dart`
- Modify: `lib/features/auth/presentation/screens/local_auth_screen.dart`

### phone_auth_screen.dart

- [ ] **Step 1.1: Remove google_fonts import and add textTheme/colorScheme locals**

In `_PhoneAuthScreenState.build()`, add at top:
```dart
final cs = Theme.of(context).colorScheme;
final tt = Theme.of(context).textTheme;
```

Remove the import `import 'package:google_fonts/google_fonts.dart';`.

- [ ] **Step 1.2: Replace BottomSheet with DonyBottomSheet**

Replace `_showCodePicker()` body:

```dart
void _showCodePicker() {
  DonyBottomSheet.show<void>(
    context,
    title: 'Indicatif pays',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: _codes.map((c) => ListTile(
        leading: Text(c.$2, style: const TextStyle(fontSize: 22)),
        title: Text(
          '${c.$3} (${c.$1})',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: _selectedCode == c.$1
            ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: () {
          setState(() {
            _selectedCode = c.$1;
            _selectedFlag = c.$2;
          });
          context.pop();
        },
      )).toList(),
    ),
  );
}
```

- [ ] **Step 1.3: Replace Scaffold backgroundColor**

Remove `backgroundColor: Colors.white` from `Scaffold(...)`.

- [ ] **Step 1.4: Replace typography in build()**

Replace `GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, ...)` → `tt.displayLarge`.

Replace `GoogleFonts.plusJakartaSans(fontSize: 14, color: DonyColors.grey400, ...)` → `tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)`.

Replace the phone label `GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, ...)` → `tt.labelMedium`.

Replace picker code text `GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15, ...)` → `tt.titleLarge`.

Replace footer legal `GoogleFonts.plusJakartaSans(fontSize: 12, ...)` → `tt.bodySmall`.

Replace footer links style `GoogleFonts.plusJakartaSans(fontSize: 12, color: DonyColors.green400, fontWeight: FontWeight.w600)` → `tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)`.

- [ ] **Step 1.5: Replace deprecated colors**

`DonyColors.grey200` → `cs.outline`

`DonyColors.grey400` → `cs.onSurfaceVariant`

`DonyColors.green400` (trailing icon, button) → `cs.primary`

`DonyColors.ink900` → `cs.onSurface`

`Colors.white` (button fg, spinner) → `cs.onPrimary`

- [ ] **Step 1.6: Replace ElevatedButton → DonyButton**

```dart
// BEFORE
SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    onPressed: isLoading ? null : _submit,
    style: ElevatedButton.styleFrom(
      backgroundColor: DonyColors.green400,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    child: isLoading ? CircularProgressIndicator(...) : Text('Recevoir le code', ...),
  ),
)

// AFTER
DonyButton(
  label: 'Recevoir le code',
  onPressed: _submit,
  isLoading: isLoading,
)
```

- [ ] **Step 1.7: Replace ScaffoldMessenger snackbar**

```dart
// BEFORE
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(state.message), backgroundColor: Colors.red.shade700),
);

// AFTER
DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
```

- [ ] **Step 1.8: Replace hardcoded spacing**

`EdgeInsets.symmetric(horizontal: 24)` → `EdgeInsets.symmetric(horizontal: DonySpacing.xl)`

`SizedBox(height: 48)` → `SizedBox(height: DonySpacing.huge)`

`SizedBox(height: 40)` → `SizedBox(height: DonySpacing.xxl + DonySpacing.sm)` (40 ≈ closest is xxl=32 or use 40)

`SizedBox(height: 36)` → `SizedBox(height: DonySpacing.xxl + DonySpacing.xs)` or `SizedBox(height: 36)` if no clean token

`SizedBox(height: 16)` → `SizedBox(height: DonySpacing.base)`

`SizedBox(height: 8)` → `SizedBox(height: DonySpacing.sm)`

`SizedBox(height: 10)` → `SizedBox(height: DonySpacing.md - 2)` — use literal 10 if no clean token

`SizedBox(width: 8)` → `SizedBox(width: DonySpacing.sm)`

`SizedBox(width: 4)` → `SizedBox(width: DonySpacing.xs)`

Phone container border radius: `BorderRadius.circular(12)` → `BorderRadius.circular(DonyRadius.md)`

- [ ] **Step 1.9: Replace phone field container border decoration**

The phone field border `Border.all(color: DonyColors.grey200)` → `Border.all(color: cs.outline)`.

Container `color: Colors.white` → remove or use `cs.surface`.

- [ ] **Step 1.10: Verify otp_verification_screen.dart**

Apply same patterns: remove `GoogleFonts`, replace `DonyColors.grey*` → `cs.*`, `ElevatedButton` → `DonyButton`, snackbar → `DonySnackbar.show`, spacing → `DonySpacing.*`.

Also replace any `Navigator.pop(context)` → `context.pop()`.

- [ ] **Step 1.11: Verify pin_setup_screen.dart**

Apply same patterns. Watch for any `DonyColors.green400` used on PinTheme → `DonyColors.primary`.

- [ ] **Step 1.12: Verify role_selection_screen.dart and local_auth_screen.dart**

Apply same patterns. For `role_selection_screen.dart`: it likely has cards with role options — replace `GestureDetector + Container` cards with `DonyCard` where possible.

- [ ] **Step 1.13: Run analyze to check for remaining violations**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/auth/
```

Expected: 0 errors. Fix any remaining issues (unused imports, etc.)

- [ ] **Step 1.14: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add lib/features/auth/presentation/screens/
git commit -m "refactor(auth): replace hardcoded styles with design system tokens"
```

---

## Task 2: KYC Screens

**Files:**
- Modify: `lib/features/kyc/presentation/screens/kyc_onboarding_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_status_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_webview_screen.dart`

### kyc_onboarding_screen.dart

The file currently uses `_kGreen = DonyColors.green400`, `_kGreenLight = DonyColors.green100`, `_kBg = DonyColors.grey50`.

- [ ] **Step 2.1: Remove static const aliases and add context-based tokens**

Remove:
```dart
static const _kGreen = DonyColors.green400;
static const _kGreenLight = DonyColors.green100;
static const _kBg = DonyColors.grey50;
```

At the top of `build()`:
```dart
final cs = Theme.of(context).colorScheme;
final tt = Theme.of(context).textTheme;
```

- [ ] **Step 2.2: Replace Scaffold backgroundColor**

Remove `backgroundColor: _kBg` / `backgroundColor: DonyColors.grey50` from `Scaffold`.

- [ ] **Step 2.3: Replace all `_kGreen` usages**

`color: _kGreen` → `color: cs.primary`

`backgroundColor: _kGreenLight` / `color: _kGreenLight` → `color: cs.primaryContainer`

- [ ] **Step 2.4: Replace typography**

Any `GoogleFonts.plusJakartaSans(...)` in helper widget methods (`_buildHeader`, `_buildSteps`, `_buildButton`) must be converted to `textTheme` calls. Since these are instance methods, they need `BuildContext` — either pass context as a parameter or inline the `textTheme` lookups when the widget tree provides context.

Pattern: the `_buildHeader()`, `_buildSteps()`, `_buildButton()` methods that don't receive `BuildContext` must be refactored to receive it:

```dart
// BEFORE
Widget _buildHeader() {
  return Column(children: [
    Text('Vérifiez votre identité', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700)),
    ...
  ]);
}

// AFTER  
Widget _buildHeader(BuildContext context) {
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  return Column(children: [
    Text('Vérifiez votre identité', style: tt.headlineLarge),
    ...
  ]);
}
```

Then update call sites: `_buildHeader(context)`, `_buildSteps(context)`, `_buildButton(context, state)`.

- [ ] **Step 2.5: Replace SnackBar → DonySnackbar**

```dart
// BEFORE
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(state.message), backgroundColor: Colors.red.shade600),
);

// AFTER
DonySnackbar.show(context, message: state.message, type: DonySnackbarType.error);
```

- [ ] **Step 2.6: Replace ElevatedButton → DonyButton**

Same pattern as Task 1 Step 1.6.

- [ ] **Step 2.7: Replace hardcoded spacing**

`EdgeInsets.symmetric(horizontal: 24)` → `EdgeInsets.symmetric(horizontal: DonySpacing.xl)`

`SizedBox(height: 48)` → `SizedBox(height: DonySpacing.huge)`

`SizedBox(height: 32)` → `SizedBox(height: DonySpacing.xxl)`

- [ ] **Step 2.8: Apply same patterns to kyc_status_screen.dart and kyc_webview_screen.dart**

`kyc_status_screen.dart`: Replace `DonyColors.green*` → `cs.primary`, `DonyColors.grey*` → `cs.outline` / `cs.onSurfaceVariant`, `GoogleFonts.X(...)` → `tt.X`.

`kyc_webview_screen.dart`: Typically uses `AppBar` — replace with `DonyAppBar(title: 'Vérification identité')`. Replace any hardcoded colors.

- [ ] **Step 2.9: Run analyze**

```bash
flutter analyze lib/features/kyc/
```

Expected: 0 errors.

- [ ] **Step 2.10: Commit**

```bash
git add lib/features/kyc/presentation/screens/
git commit -m "refactor(kyc): replace hardcoded styles with design system tokens"
```

---

## Task 3: Matching Part 1 — List Screens

**Files:**
- Modify: `lib/features/matching/presentation/screens/announcement_list_screen.dart`
- Modify: `lib/features/matching/presentation/screens/shipment_list_screen.dart`
- Modify: `lib/features/matching/presentation/screens/matching_management_screen.dart`

### announcement_list_screen.dart

- [ ] **Step 3.1: Add cs/tt locals, remove google_fonts import**

At top of `build()`:
```dart
final cs = Theme.of(context).colorScheme;
final tt = Theme.of(context).textTheme;
```

Remove `import 'package:google_fonts/google_fonts.dart';`.

- [ ] **Step 3.2: Replace AppBar**

```dart
// BEFORE
appBar: AppBar(
  title: Text('Mes trajets', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
  backgroundColor: DonyColors.white,
  elevation: 0,
  ...
)

// AFTER
appBar: DonyAppBar(title: 'Mes trajets', showBackButton: false)
```

If it has tabs, pass them via `bottom`:
```dart
appBar: DonyAppBar(
  title: 'Mes trajets',
  showBackButton: false,
  bottom: TabBar(controller: _tabController, tabs: [...]),
),
```

- [ ] **Step 3.3: Replace Scaffold backgroundColor**

Remove `backgroundColor: DonyColors.grey50` from `Scaffold`.

- [ ] **Step 3.4: Replace AlertDialog → DonyDialog**

```dart
// BEFORE
Future<bool?> _confirmDeleteDialog(BuildContext ctx) {
  return showDialog<bool>(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Supprimer ce trajet ?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17)),
      content: Text('...', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: DonyColors.grey400)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text('Annuler', ...)),
        TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text('Supprimer', style: TextStyle(color: DonyColors.error))),
      ],
    ),
  );
}

// AFTER
Future<bool?> _confirmDeleteDialog(BuildContext ctx) {
  return DonyDialog.show(
    ctx,
    title: 'Supprimer ce trajet ?',
    message: 'Le trajet annulé et toutes les demandes associées seront définitivement retirés de la plateforme.',
    confirmLabel: 'Supprimer',
    variant: DonyDialogVariant.destructive,
    icon: Icons.delete_outline_rounded,
  );
}
```

- [ ] **Step 3.5: Replace all GoogleFonts typography in body**

Any `GoogleFonts.plusJakartaSans(...)` → appropriate `tt.X` slot from reference table.

- [ ] **Step 3.6: Replace all deprecated colors**

`DonyColors.grey50` → remove from Scaffold (theme handles it)
`DonyColors.grey400` → `cs.onSurfaceVariant`
`DonyColors.grey200` / `DonyColors.grey300` → `cs.outline`
`DonyColors.green400` → `cs.primary`
`DonyColors.white` → `cs.surface`
`DonyColors.error` → `cs.error`

- [ ] **Step 3.7: Replace hardcoded spacings and radii**

`EdgeInsets.*` literals → `DonySpacing.*`

`BorderRadius.circular(X)` → `DonyRadius.card/md/lg/xl` as appropriate.

- [ ] **Step 3.8: Apply same patterns to shipment_list_screen.dart**

Key points for `shipment_list_screen.dart`:
- Has a `SliverAppBar` with tabs — keep `SliverAppBar` structure but replace inline title style with `tt.headlineMedium`
- Has `TabBar` — tab label styles `GoogleFonts.X(...)` → `tt.labelLarge`
- Remove `backgroundColor: DonyColors.grey50` from Scaffold
- Replace status badge containers with `DonyBadge` where appropriate

- [ ] **Step 3.9: Apply same patterns to matching_management_screen.dart**

Common violations: `GoogleFonts` in card text, `DonyColors.green400` on CTA buttons, `AppBar` with manual style.

- [ ] **Step 3.10: Run analyze**

```bash
flutter analyze lib/features/matching/presentation/screens/announcement_list_screen.dart lib/features/matching/presentation/screens/shipment_list_screen.dart lib/features/matching/presentation/screens/matching_management_screen.dart
```

Expected: 0 errors.

- [ ] **Step 3.11: Commit**

```bash
git add lib/features/matching/presentation/screens/announcement_list_screen.dart lib/features/matching/presentation/screens/shipment_list_screen.dart lib/features/matching/presentation/screens/matching_management_screen.dart
git commit -m "refactor(matching): replace hardcoded styles in list screens"
```

---

## Task 4: Matching Part 2 — Detail Screens

**Files:**
- Modify: `lib/features/matching/presentation/screens/announcement_detail_screen.dart`
- Modify: `lib/features/matching/presentation/screens/traveler_profile_screen.dart`
- Modify: `lib/features/matching/presentation/screens/handover_screen.dart`

### announcement_detail_screen.dart

- [ ] **Step 4.1: Add cs/tt, remove google_fonts import**

- [ ] **Step 4.2: Replace AlertDialog → DonyDialog**

`_confirmDelete()` currently uses `showDialog<bool>(... AlertDialog(...))`. Replace:

```dart
Future<bool> _confirmDelete({bool isCancelled = false}) async {
  return await DonyDialog.show(
        context,
        title: 'Supprimer ce trajet ?',
        message: isCancelled
            ? 'Cette action est irréversible. Le trajet annulé et toutes les demandes associées seront définitivement retirés.'
            : 'Cette action est irréversible. Le trajet ne sera plus visible pour les expéditeurs.',
        confirmLabel: 'Supprimer',
        variant: DonyDialogVariant.destructive,
        icon: Icons.delete_outline_rounded,
      ) ??
      false;
}
```

- [ ] **Step 4.3: Replace AppBar → DonyAppBar**

The screen likely uses a custom `AppBar` with back arrow. Replace:
```dart
// BEFORE
AppBar(
  leading: GestureDetector(onTap: () => context.pop(), child: ...),
  title: Text('Détail trajet', style: GoogleFonts.plusJakartaSans(...)),
  backgroundColor: Colors.white,
  ...
)

// AFTER
DonyAppBar(title: 'Détail trajet')
```

- [ ] **Step 4.4: Replace all GoogleFonts + deprecated colors**

Same patterns as previous tasks.

- [ ] **Step 4.5: Replace ElevatedButton → DonyButton**

- [ ] **Step 4.6: Replace SnackBar → DonySnackbar**

- [ ] **Step 4.7: Apply same patterns to traveler_profile_screen.dart**

This screen shows a traveler's public profile. Typical violations:
- Avatar rendered with `CircleAvatar(backgroundImage: ...)` → consider using `DonyAvatar(name: '...', imageUrl: '...')`
- Hardcoded `Row` with profile stats using `GoogleFonts` → `tt.headlineLarge` / `tt.labelMedium`
- Rating display with star icons and `GoogleFonts` → `tt.titleLarge`

- [ ] **Step 4.8: Apply same patterns to handover_screen.dart**

This screen handles delivery handover. Watch for:
- Photo capture buttons using `ElevatedButton` → `DonyButton`
- Success/error states showing `SnackBar` → `DonySnackbar.show`
- Any confirmation dialogs → `DonyDialog.show`

- [ ] **Step 4.9: Run analyze**

```bash
flutter analyze lib/features/matching/presentation/screens/announcement_detail_screen.dart lib/features/matching/presentation/screens/traveler_profile_screen.dart lib/features/matching/presentation/screens/handover_screen.dart
```

- [ ] **Step 4.10: Commit**

```bash
git add lib/features/matching/presentation/screens/announcement_detail_screen.dart lib/features/matching/presentation/screens/traveler_profile_screen.dart lib/features/matching/presentation/screens/handover_screen.dart
git commit -m "refactor(matching): replace hardcoded styles in detail screens"
```

---

## Task 5: Cancellation + Notifications + Profile

**Files:**
- Modify: `lib/features/cancellation/presentation/screens/cancellation_screen.dart`
- Modify: `lib/features/cancellation/presentation/screens/rematch_search_screen.dart`
- Modify: `lib/features/notifications/presentation/inbox_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/features/profile/presentation/edit_profile_screen.dart`

### cancellation_screen.dart

- [ ] **Step 5.1: Add cs/tt, remove google_fonts import**

- [ ] **Step 5.2: Replace AppBar → DonyAppBar**

- [ ] **Step 5.3: Replace radio-style option selection with DonyRadioGroup**

If cancellation reasons are displayed as a custom `ListView` of tappable containers:

```dart
// BEFORE
Column(
  children: reasons.map((reason) => GestureDetector(
    onTap: () => setState(() => _selected = reason),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: _selected == reason ? DonyColors.green400 : DonyColors.grey200),
        borderRadius: BorderRadius.circular(12),
        color: _selected == reason ? DonyColors.green100 : Colors.white,
      ),
      child: Text(reason, style: GoogleFonts.plusJakartaSans(...)),
    ),
  )).toList(),
)

// AFTER
DonyRadioGroup<String>(
  value: _selected,
  onChanged: (v) => setState(() => _selected = v),
  items: reasons.map((r) => DonyRadioItem(label: r, value: r)).toList(),
)
```

- [ ] **Step 5.4: Replace ElevatedButton → DonyButton (destructive for confirmation)**

```dart
DonyButton(
  label: 'Confirmer l\'annulation',
  onPressed: _confirmCancellation,
  variant: DonyButtonVariant.destructive,
  isLoading: state is CancellationLoading,
)
```

- [ ] **Step 5.5: Replace all GoogleFonts + deprecated colors**

- [ ] **Step 5.6: Apply same patterns to rematch_search_screen.dart**

This screen searches for a replacement traveler. Watch for:
- `DonySearchField` if there's a text search input
- Loading state with `CircularProgressIndicator` — keep but use `color: cs.primary`
- Empty state → consider `DonyEmptyState`

- [ ] **Step 5.7: Apply patterns to inbox_screen.dart**

Notifications inbox. Typical violations:
- `AppBar` with `GoogleFonts` title → `DonyAppBar(title: 'Notifications')`
- `ListTile` for notification items — can keep `ListTile` or use `DonyListTile`
- Unread badge → `DonyBadge`
- `DonyColors.green400` on unread indicator → `cs.primary`

- [ ] **Step 5.8: Apply patterns to profile_screen.dart**

Profile screen. Typical violations:
- Custom profile header with `GoogleFonts` name/subtitle → `tt.headlineLarge` / `tt.bodyMedium`
- `DonyAvatar` for user photo
- Settings list items → `DonyListTile` or keep `ListTile` with token colors
- Logout button → `DonyButton(variant: DonyButtonVariant.ghost)` or destructive

- [ ] **Step 5.9: Apply patterns to edit_profile_screen.dart**

Form screen. Key replacements:
- `AppBar` → `DonyAppBar(title: 'Modifier le profil')`
- `TextFormField` inputs → `DonyTextField`
- `ElevatedButton` submit → `DonyButton`
- `GoogleFonts` labels → `tt.*`

- [ ] **Step 5.10: Run analyze**

```bash
flutter analyze lib/features/cancellation/ lib/features/notifications/ lib/features/profile/
```

- [ ] **Step 5.11: Commit**

```bash
git add lib/features/cancellation/presentation/ lib/features/notifications/presentation/ lib/features/profile/presentation/
git commit -m "refactor(cancellation,notifications,profile): replace hardcoded styles with design system"
```

---

## Task 6: Payments + Tracking

**Files:**
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Modify: `lib/features/payments/presentation/screens/payout_onboarding_screen.dart`
- Modify: `lib/features/tracking/presentation/screens/tracking_search_screen.dart`
- Modify: `lib/features/tracking/presentation/widgets/qr_code_card.dart`

### payment_screen.dart

- [ ] **Step 6.1: Add cs/tt, remove google_fonts import**

- [ ] **Step 6.2: Replace _PaymentSummaryView typography and colors**

The `_PaymentSummaryView` private widget has the summary cards. Typical violations:
```dart
// BEFORE
Text('${bid.amount.toStringAsFixed(0)} €',
  style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800))

// AFTER
Text('${bid.amount.toStringAsFixed(0)} €',
  style: tt.displayLarge)
```

- [ ] **Step 6.3: Replace _EscrowConfirmedView typography**

```dart
// Success confirmation text
Text('Paiement sécurisé', style: tt.headlineLarge)
Text('Les fonds sont conservés...', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
```

- [ ] **Step 6.4: Replace ElevatedButton → DonyButton**

The "Confirmer le paiement" button. Note: this screen has biometric auth before proceeding, so `isLoading` state must still be wired.

- [ ] **Step 6.5: Replace SnackBar → DonySnackbar**

Payment error/success feedback.

- [ ] **Step 6.6: Apply same patterns to payout_onboarding_screen.dart**

This onboarding screen for Stripe Connect payout. Key violations:
- Multi-step indicator (if using `DonyStepIndicator` — check if already there)
- Step title/description with `GoogleFonts` → `tt.headlineLarge` / `tt.bodyMedium`
- `ElevatedButton` CTA → `DonyButton`
- `DonyColors.green400` → `cs.primary`

- [ ] **Step 6.7: Apply patterns to tracking_search_screen.dart**

Tracking search. Key violations:
- `AppBar` or search field using `GoogleFonts`
- If has a `TextField` for tracking code → `DonyTextField`
- Status badges → `DonyBadge`

- [ ] **Step 6.8: Apply patterns to qr_code_card.dart**

This is a widget, not a screen. Key violations:
- Card decoration with hardcoded `BorderRadius.circular(16)` → `BorderRadius.circular(DonyRadius.card)`
- `Color(0xFF...)` hardcoded → appropriate `DonyColors` token
- `GoogleFonts` text styles → `tt.*`

- [ ] **Step 6.9: Run analyze for entire features directory**

```bash
flutter analyze lib/features/payments/ lib/features/tracking/
```

- [ ] **Step 6.10: Commit**

```bash
git add lib/features/payments/presentation/ lib/features/tracking/presentation/
git commit -m "refactor(payments,tracking): replace hardcoded styles with design system"
```

---

## Task 7: Final Validation

- [ ] **Step 7.1: Run full analyze**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/
```

Expected: 0 errors or warnings related to `GoogleFonts`, hardcoded `Colors.*`, `DonyColors.green*`, `DonyColors.grey*`, `ElevatedButton` with inline style, `Navigator.pop`.

Fix any remaining issue before continuing.

- [ ] **Step 7.2: Run tests**

```bash
flutter test --coverage
```

All existing tests must pass. If a test uses `googleFonts` somewhere and breaks, update it to use `textTheme` lookups.

- [ ] **Step 7.3: Check for any remaining GoogleFonts inline usage**

```bash
grep -rn "GoogleFonts\." lib/features/ --include="*.dart"
```

Expected: 0 results in feature files.

- [ ] **Step 7.4: Check for remaining deprecated tokens**

```bash
grep -rn "DonyColors\.green[0-9]\|DonyColors\.grey[0-9]\|Colors\.red\.shade" lib/features/ --include="*.dart"
```

Expected: 0 results.

- [ ] **Step 7.5: Check for remaining ElevatedButton with inline style**

```bash
grep -rn "ElevatedButton\.styleFrom" lib/features/ --include="*.dart"
```

Expected: 0 results.

- [ ] **Step 7.6: Final commit**

```bash
git add -p  # stage only remaining feature files
git commit -m "refactor(screens): complete design system Phase 4 migration"
```

---

## Self-Review Notes

**Spec coverage check:**
- [x] Colors → handled in every task
- [x] Typography → handled in every task
- [x] AppBar → handled per task
- [x] Buttons → handled per task
- [x] Dialogs → handled in Tasks 3, 4, 5
- [x] Bottom sheets → handled in Task 1
- [x] Snackbars → handled in every task
- [x] Spacing tokens → handled per task
- [x] Radius tokens → handled per task
- [x] Navigator.pop → replaced with context.pop throughout
- [x] Scaffold backgroundColor → removed (theme handles it)

**Type consistency:**
- `cs` = `Theme.of(context).colorScheme` everywhere
- `tt` = `Theme.of(context).textTheme` everywhere
- `DonySpacing.X` = static const doubles
- `DonyRadius.X` = static const doubles
- `DonyDialog.show()` returns `Future<bool?>`
- `DonySnackbar.show()` returns `void`
- `DonyBottomSheet.show<T>()` returns `Future<T?>`
- `DonyButton(isLoading: bool)` handles loading state internally

**Screens not in scope (already clean or handled separately):**
- `lib/features/splash/presentation/splash_screen.dart` — intentionally uses blue background, keep as-is
- `lib/features/auth/presentation/screens/onboarding_screen.dart` — not in git M list, check if clean
- `lib/features/matching/presentation/screens/bid_detail_screen.dart` — not in git M list
- `lib/features/matching/presentation/screens/create_announcement_screen.dart` — not in git M list
- `lib/features/tracking/presentation/screens/tracking_timeline_screen.dart` — not in git M list
