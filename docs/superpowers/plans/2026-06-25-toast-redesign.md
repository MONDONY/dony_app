# DonySnackbar v2 — Redesign & Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesigner DonySnackbar (fond coloré + dégradé + icône cercle + dedup), corriger le bug de toasts multiples, et migrer 35 appels bruts vers DonySnackbar.

**Architecture:** Un seul fichier core modifié (`dony_snackbar.dart`) avec dedup statique + visuel amélioré. 35 call-sites dans 20 fichiers remplacent leurs `ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(...))` bruts par `DonySnackbar.show()`. `ErrorPresenter` inchangé.

**Tech Stack:** Flutter (SnackBar, ScaffoldMessenger, BoxDecoration, LinearGradient), flutter_test (widget tests)

## Global Constraints

- Branche: `feature/toast-redesign` — ne jamais committer sur `main`
- Pas de `Co-Authored-By: Claude` dans les commits
- `flutter analyze` zéro warning nouveau
- Coverage ≥ 90% (les tests widget DonySnackbar couvrent le nouveau code)
- BLoC only — pas de `setState`
- Soft delete only, pas de DELETE physique (non applicable ici)
- Utiliser `DonySpacing`, `DonyRadius`, `DonyColors` du design system

---

## File Map

| Fichier | Action |
|---------|--------|
| `lib/core/design/widgets/dony_snackbar.dart` | **Modifier** — redesign visuel + dedup |
| `test/core/design/widgets/dony_snackbar_test.dart` | **Créer** — widget tests |
| `lib/features/matching/presentation/screens/create_announcement_screen.dart` | **Modifier** — lignes 406, 561 |
| `lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart` | **Modifier** — ligne 736 |
| `lib/features/matching/presentation/widgets/bid_detail/traveler_options_sheet.dart` | **Modifier** — ligne 294 |
| `lib/features/matching/presentation/widgets/block_user_action.dart` | **Modifier** — ligne 103 |
| `lib/features/package_request/presentation/screens/sender/complete_details_screen.dart` | **Modifier** — lignes 119, 132 |
| `lib/features/package_request/presentation/screens/sender/package_request_detail_screen.dart` | **Modifier** — lignes 74, 1095 |
| `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart` | **Modifier** — ligne 142 |
| `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart` | **Modifier** — lignes 47, 53, 59 |
| `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart` | **Modifier** — ligne 56 |
| `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart` | **Modifier** — ligne 50 |
| `lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart` | **Modifier** — lignes 816, 823 |
| `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart` | **Modifier** — ligne 313 |
| `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart` | **Modifier** — lignes 159, 185 |
| `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart` | **Modifier** — lignes 94, 122, 133 |
| `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart` | **Modifier** — lignes 82, 115, 134 |
| `lib/features/settings/presentation/screens/change_pin_screen.dart` | **Modifier** — ligne 88 |
| `lib/features/payments/cash/presentation/screens/commission_method_screen.dart` | **Modifier** — lignes 137, 167 |
| `lib/features/tracking/presentation/screens/qr_scanner_screen.dart` | **Modifier** — ligne 363 |
| `lib/features/stripe_account/presentation/screens/account_rejected_screen.dart` | **Modifier** — ligne 49 |
| `lib/features/home/presentation/home_screen.dart` | **Modifier** — ligne 497 |
| `lib/features/home/presentation/map_traveler_view.dart` | **Modifier** — ligne 92 |
| `lib/features/messaging/presentation/conversation_list_screen.dart` | **Modifier** — ligne 474 |
| `lib/features/messaging/presentation/chat_screen.dart` | **Modifier** — ligne 288 |
| `lib/features/messaging/presentation/archived_conversations_screen.dart` | **Modifier** — ligne 67 |

---

## Task 1: Redesign DonySnackbar + dedup + tests

**Files:**
- Modify: `lib/core/design/widgets/dony_snackbar.dart`
- Create: `test/core/design/widgets/dony_snackbar_test.dart`

**Interfaces:**
- Produces: `DonySnackbar.show(BuildContext, {required String message, String? title, IconData? icon, DonySnackbarType type, Duration duration, String? actionLabel, VoidCallback? onAction})`
- Produces: `DonySnackbar._isDuplicate(String key, DateTime now) → bool` (private, testé indirectement)

- [ ] **Step 1: Écrire les tests widget qui échouent**

Créer `test/core/design/widgets/dony_snackbar_test.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(VoidCallback onPress, {String message = 'Test msg', DonySnackbarType type = DonySnackbarType.info}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => DonySnackbar.show(ctx, message: message, type: type),
          child: const Text('Show'),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // Clear static dedup map between tests
    DonySnackbar.clearDedup();
  });

  group('DonySnackbar.show', () {
    testWidgets('affiche le message', (tester) async {
      await tester.pumpWidget(_wrap(() {}));
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Test msg'), findsOneWidget);
    });

    testWidgets('affiche le titre quand fourni', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DonySnackbar.show(
                ctx,
                message: 'Le message',
                title: 'Mon titre',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Mon titre'), findsOneWidget);
      expect(find.text('Le message'), findsOneWidget);
    });

    testWidgets('affiche bouton action quand actionLabel fourni', (tester) async {
      bool called = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DonySnackbar.show(
                ctx,
                message: 'msg',
                actionLabel: 'Annuler',
                onAction: () => called = true,
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Annuler'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      expect(called, isTrue);
    });

    testWidgets('dedup: deuxième appel identique en < 400ms ignoré', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    DonySnackbar.show(ctx, message: 'msg dupe', type: DonySnackbarType.error);
                    DonySnackbar.show(ctx, message: 'msg dupe', type: DonySnackbarType.error);
                  },
                  child: const Text('ShowDouble'),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ShowDouble'));
      await tester.pump();
      // Un seul snackbar visible (texte trouvé une seule fois)
      expect(find.text('msg dupe'), findsOneWidget);
    });

    testWidgets('types différents ne se dédupliquent pas', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                DonySnackbar.show(ctx, message: 'msg', type: DonySnackbarType.error);
                DonySnackbar.show(ctx, message: 'msg', type: DonySnackbarType.success);
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      // success remplace error (hideCurrentSnackBar) — le dernier est visible
      expect(find.text('msg'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Vérifier que les tests échouent**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/core/design/widgets/dony_snackbar_test.dart
```
Attendu : erreur `clearDedup` non défini + tests FAIL.

- [ ] **Step 3: Réécrire `dony_snackbar.dart`**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum DonySnackbarType { info, success, warning, error }

abstract final class DonySnackbar {
  static final Map<String, DateTime> _lastShown = {};

  /// Vide le cache de déduplication. Utile dans les tests.
  @visibleForTesting
  static void clearDedup() => _lastShown.clear();

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData? icon,
    DonySnackbarType type = DonySnackbarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final dedupKey = '${type.name}:$message';
    final now = DateTime.now();
    _lastShown.removeWhere(
      (_, dt) => now.difference(dt) > const Duration(seconds: 5),
    );
    if (_isDuplicate(dedupKey, now)) return;
    _lastShown[dedupKey] = now;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (bg, fg, defaultIcon) = switch (type) {
      DonySnackbarType.info => (
          cs.inverseSurface,
          cs.onInverseSurface,
          Icons.info_outline,
        ),
      DonySnackbarType.success => (
          cs.success,
          DonyColors.white,
          Icons.check_circle_outline,
        ),
      DonySnackbarType.warning => (
          cs.warning,
          DonyColors.white,
          Icons.warning_amber_rounded,
        ),
      DonySnackbarType.error => (
          cs.error,
          cs.onError,
          Icons.error_outline,
        ),
    };

    final resolvedIcon = icon ?? defaultIcon;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6],
                    ),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(resolvedIcon, color: fg, size: 18),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null && title.isNotEmpty) ...[
                          Text(
                            title,
                            style: tt.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          message,
                          style: tt.bodySmall?.copyWith(
                            color: title != null
                                ? fg.withValues(alpha: 0.85)
                                : fg,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: bg,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          margin: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.base,
            DonySpacing.lg,
          ),
          dismissDirection: DismissDirection.horizontal,
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: fg,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }

  static bool _isDuplicate(String key, DateTime now) {
    final last = _lastShown[key];
    if (last == null) return false;
    return now.difference(last) < const Duration(milliseconds: 400);
  }
}
```

- [ ] **Step 4: Lancer les tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test test/core/design/widgets/dony_snackbar_test.dart
```
Attendu : tous PASS.

- [ ] **Step 5: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/core/design/widgets/dony_snackbar.dart
```
Attendu : `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/core/design/widgets/dony_snackbar.dart test/core/design/widgets/dony_snackbar_test.dart
git commit -m "feat(toast): redesign DonySnackbar v2 — fond coloré + icône cercle + dégradé + dedup 400ms"
```

---

## Task 2: Migration matching/ (4 fichiers)

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_announcement_screen.dart` (lignes ~406, ~561)
- Modify: `lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart` (ligne ~736)
- Modify: `lib/features/matching/presentation/widgets/bid_detail/traveler_options_sheet.dart` (ligne ~294)
- Modify: `lib/features/matching/presentation/widgets/block_user_action.dart` (ligne ~103)

**Interfaces:**
- Consumes: `DonySnackbar.show()` de Task 1

Règle de migration universelle :
```dart
// AVANT (toute variante)
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('message'), backgroundColor: kError),
);
// ou
ScaffoldMessenger.of(ctx).showSnackBar(
  const SnackBar(content: Text('message')),
);

// APRÈS
DonySnackbar.show(context, message: 'message', type: DonySnackbarType.error);
// (adapter type selon contexte : error/success/warning/info)
```

- [ ] **Step 1: Migrer `create_announcement_screen.dart`**

Chercher `ScaffoldMessenger` dans le fichier. Remplacer :
- Appel erreur (~ligne 406) → `DonySnackbar.show(context, message: <msg>, type: DonySnackbarType.error)`
- Appel succès (~ligne 561, "Trajet publié !" / "Trajet modifié !") → `DonySnackbar.show(context, message: <msg>, type: DonySnackbarType.success)`

S'assurer que l'import `dony_snackbar.dart` est présent (via `design_system.dart` si déjà importé, sinon ajouter `import 'package:dony/core/design/widgets/dony_snackbar.dart';`).

- [ ] **Step 2: Migrer `bid_detail_action_bars.dart`**

Chercher `ScaffoldMessenger` (~ligne 736). Remplacer :
- "Signalement envoyé. Merci !" → `DonySnackbar.show(context, message: 'Signalement envoyé. Merci !', type: DonySnackbarType.success)`

- [ ] **Step 3: Migrer `traveler_options_sheet.dart`**

Chercher `ScaffoldMessenger` (~ligne 294). Remplacer :
- "Signalement envoyé. Merci !" → `DonySnackbar.show(context, message: 'Signalement envoyé. Merci !', type: DonySnackbarType.success)`

- [ ] **Step 4: Migrer `block_user_action.dart`**

Chercher `ScaffoldMessenger` (~ligne 103). Remplacer :
- "[displayName] a été bloqué(e)" → `DonySnackbar.show(context, message: '${displayName} a été bloqué(e)', type: DonySnackbarType.info)`

- [ ] **Step 5: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/features/matching/
```
Attendu : `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/features/matching/
git commit -m "refactor(toast): migrer matching/ vers DonySnackbar"
```

---

## Task 3: Migration package_request/screens (8 fichiers)

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/complete_details_screen.dart` (lignes ~119, ~132)
- Modify: `lib/features/package_request/presentation/screens/sender/package_request_detail_screen.dart` (lignes ~74, ~1095)
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart` (ligne ~142)
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart` (lignes ~47, ~53, ~59)
- Modify: `lib/features/package_request/presentation/screens/sender/create_wizard/steps/step_3_recap_budget.dart` (ligne ~56)
- Modify: `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart` (ligne ~50)
- Modify: `lib/features/package_request/presentation/screens/traveler/package_request_public_detail_screen.dart` (lignes ~816, ~823)
- Modify: `lib/features/package_request/presentation/screens/traveler/link_trip_screen.dart` (ligne ~313)

**Interfaces:**
- Consumes: `DonySnackbar.show()` de Task 1

Mapping des remplacements :

| Fichier | Message | Type |
|---------|---------|------|
| `complete_details_screen.dart:119` | 'Détails enregistrés' | `success` |
| `complete_details_screen.dart:132` | `state.errorMessage \|\| 'Erreur'` | `error` |
| `package_request_detail_screen.dart:74` | `e.toString()` | `error` |
| `package_request_detail_screen.dart:1095` | `e.toString()` | `error` |
| `package_request_create_screen.dart:142` | 'Demande modifiée' / 'Demande publiée...' | `success` |
| `step_1_trajet_colis.dart:47` | 'Choisis une date souhaitée' | `warning` |
| `step_1_trajet_colis.dart:53` | 'Renseigne les deux villes' | `warning` |
| `step_1_trajet_colis.dart:59` | 'Les villes doivent être différentes' | `warning` |
| `step_3_recap_budget.dart:56` | 'Indique un budget pour continuer (prix ferme requis).' | `warning` |
| `negotiation_thread_screen.dart:50` | 'Négociation rejetée' | `warning` |
| `package_request_public_detail_screen.dart:816` | 'Offre confirmée' | `success` |
| `package_request_public_detail_screen.dart:823` | `state.error.message` | `error` |
| `link_trip_screen.dart:313` | message dynamique | `error` |

- [ ] **Step 1: Migrer les 8 fichiers** (appliquer les remplacements du tableau ci-dessus)

Pour chaque fichier : chercher `ScaffoldMessenger`, remplacer par `DonySnackbar.show()` avec le type du tableau.

Note pour `package_request_detail_screen.dart` : `e.toString()` doit être remplacé par un message user-friendly :
```dart
// AVANT
content: Text(e.toString()), backgroundColor: DonyColors.danger500
// APRÈS
DonySnackbar.show(context, message: 'Une erreur est survenue. Veuillez réessayer.', type: DonySnackbarType.error)
```

- [ ] **Step 2: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/features/package_request/presentation/screens/
```
Attendu : `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/features/package_request/presentation/screens/
git commit -m "refactor(toast): migrer package_request/screens vers DonySnackbar"
```

---

## Task 4: Migration package_request/widgets (3 fichiers)

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart` (lignes ~159, ~185)
- Modify: `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart` (lignes ~94, ~122, ~133)
- Modify: `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart` (lignes ~82, ~115, ~134)

**Interfaces:**
- Consumes: `DonySnackbar.show()` de Task 1

Mapping :

| Fichier | Ligne | Message | Type |
|---------|-------|---------|------|
| `make_offer_bottom_sheet.dart` | ~159 | 'Sélectionnez votre date de voyage' | `warning` |
| `make_offer_bottom_sheet.dart` | ~185 | 'Offre envoyée' | `success` |
| `payment_recap_bottom_sheet.dart` | ~94 | 'Authentification requise pour effectuer le paiement' | `warning` |
| `payment_recap_bottom_sheet.dart` | ~122 | `e.error.code == FailureCode.Canceled ? 'Paiement annulé' : 'Erreur paiement : ${e.error.message ?? ""}'` | `warning` si Canceled, `error` sinon |
| `payment_recap_bottom_sheet.dart` | ~133 | 'Une erreur est survenue. Veuillez réessayer.' | `error` |
| `accept_offer_bottom_sheet.dart` | ~82 | 'Authentification requise pour effectuer le paiement' | `warning` |
| `accept_offer_bottom_sheet.dart` | ~115 | `e.error.code == FailureCode.Canceled ? 'Paiement annulé' : 'Erreur paiement : ${e.error.message ?? ""}'` | `warning` si Canceled, `error` sinon |
| `accept_offer_bottom_sheet.dart` | ~134 | 'Une erreur est survenue. Veuillez réessayer.' | `error` |

Pour les erreurs Stripe avec condition :
```dart
// AVANT
ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
  content: Text(e.error.code == FailureCode.Canceled
      ? 'Paiement annulé'
      : 'Erreur paiement : ${e.error.message ?? ""}'),
  backgroundColor: kError,
));

// APRÈS
DonySnackbar.show(
  ctx,
  message: e.error.code == FailureCode.Canceled
      ? 'Paiement annulé'
      : 'Erreur paiement : ${e.error.message ?? ""}',
  type: e.error.code == FailureCode.Canceled
      ? DonySnackbarType.warning
      : DonySnackbarType.error,
);
```

- [ ] **Step 1: Migrer les 3 fichiers widgets** (appliquer les remplacements du tableau)

- [ ] **Step 2: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/features/package_request/presentation/widgets/
```
Attendu : `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/features/package_request/presentation/widgets/
git commit -m "refactor(toast): migrer package_request/widgets vers DonySnackbar"
```

---

## Task 5: Migration payments + settings + tracking + stripe_account (4 fichiers)

**Files:**
- Modify: `lib/features/settings/presentation/screens/change_pin_screen.dart` (ligne ~88)
- Modify: `lib/features/payments/cash/presentation/screens/commission_method_screen.dart` (lignes ~137, ~167)
- Modify: `lib/features/tracking/presentation/screens/qr_scanner_screen.dart` (ligne ~363)
- Modify: `lib/features/stripe_account/presentation/screens/account_rejected_screen.dart` (ligne ~49)

**Interfaces:**
- Consumes: `DonySnackbar.show()` de Task 1

Mapping :

| Fichier | Ligne | Message | Type |
|---------|-------|---------|------|
| `change_pin_screen.dart` | ~88 | 'Code PIN modifié' | `success` |
| `commission_method_screen.dart` | ~137 | 'Authentification requise pour effectuer le paiement' | `warning` |
| `commission_method_screen.dart` | ~167 | `e.error.localizedMessage \|\| 'Erreur lors de l\'ajout de la carte.'` | `error` |
| `qr_scanner_screen.dart` | ~363 | 'Numéro introuvable. Vérifiez et réessayez.' | `error` |
| `account_rejected_screen.dart` | ~49 | `state.error.message` | `error` |

- [ ] **Step 1: Migrer les 4 fichiers** (appliquer les remplacements du tableau)

- [ ] **Step 2: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/features/settings/ lib/features/payments/ lib/features/tracking/ lib/features/stripe_account/
```
Attendu : `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/features/settings/ lib/features/payments/ lib/features/tracking/ lib/features/stripe_account/
git commit -m "refactor(toast): migrer settings/payments/tracking/stripe vers DonySnackbar"
```

---

## Task 6: Migration home + messaging (5 fichiers)

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart` (ligne ~497)
- Modify: `lib/features/home/presentation/map_traveler_view.dart` (ligne ~92)
- Modify: `lib/features/messaging/presentation/conversation_list_screen.dart` (ligne ~474)
- Modify: `lib/features/messaging/presentation/chat_screen.dart` (ligne ~288)
- Modify: `lib/features/messaging/presentation/archived_conversations_screen.dart` (ligne ~67)

**Interfaces:**
- Consumes: `DonySnackbar.show()` de Task 1

Mapping :

| Fichier | Ligne | Message | Type | Action |
|---------|-------|---------|------|--------|
| `home_screen.dart` | ~497 | 'Impossible de te localiser. Réessaie.' | `info` | — |
| `map_traveler_view.dart` | ~92 | 'Impossible de te localiser. Réessaie.' | `info` | — |
| `conversation_list_screen.dart` | ~474 | 'Conversation archivée' | `info` | `actionLabel: 'Annuler', onAction: <undo_fn>` |
| `chat_screen.dart` | ~288 | 'Conversation supprimée' | `info` | — |
| `archived_conversations_screen.dart` | ~67 | 'Conversation désarchivée' | `info` | — |

Pour `conversation_list_screen.dart` (avec undo action) :
```dart
// AVANT
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Conversation archivée'),
    action: SnackBarAction(label: 'Annuler', onPressed: undoFn),
    behavior: SnackBarBehavior.floating,
  ),
);

// APRÈS
DonySnackbar.show(
  context,
  message: 'Conversation archivée',
  type: DonySnackbarType.info,
  actionLabel: 'Annuler',
  onAction: undoFn,
);
```

- [ ] **Step 1: Migrer les 5 fichiers** (appliquer les remplacements du tableau)

- [ ] **Step 2: flutter analyze**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze lib/features/home/ lib/features/messaging/
```
Attendu : `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add lib/features/home/ lib/features/messaging/
git commit -m "refactor(toast): migrer home/messaging vers DonySnackbar"
```

---

## Task 7: Vérification finale

**Files:**
- Aucun fichier nouveau — vérification pure

- [ ] **Step 1: Grep zéro appels bruts restants**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
grep -r "ScaffoldMessenger.*showSnackBar" lib/ --include="*.dart" | grep -v "DonySnackbar" | grep -v "//"
```
Attendu : **zéro résultat** (aucun appel brut restant).

- [ ] **Step 2: flutter analyze global**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter analyze
```
Attendu : `No issues found!` (ou uniquement warnings pré-existants non liés).

- [ ] **Step 3: Tous les tests**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter test
```
Attendu : tous PASS.

- [ ] **Step 4: Commit final si tout passe**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
git add -A
git commit -m "chore(toast): vérification finale — zéro appel brut, analyze propre"
```

- [ ] **Step 5: Fermer le serveur visual companion**

```bash
/Users/aboubakardiakite/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3/skills/brainstorming/scripts/stop-server.sh /Users/aboubakardiakite/Desktop/dony/dony_app/.superpowers/brainstorm/38165-1782346354
```
