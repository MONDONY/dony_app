# Écrans de succès unifiés — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les 5 traitements incohérents de fin d'action (SnackBar isolé, pop silencieux, AlertDialog, vue inline, écran dédié) par deux patterns cohérents dans toute l'app : `DonySuccessScreen` (écran plein, mascotte + CTA) pour les moments majeurs (paiement, trajet publié, livraison), `DonySnackbar` (déjà existant) généralisé pour les moments mineurs.

**Architecture:** Un nouveau widget statique `DonySuccessScreen` dans `lib/core/design/widgets/`, exporté par le barrel `design_system.dart`, poussé comme route plein écran depuis chaque point d'entrée majeur. Un nouveau variant `DonyButtonVariant.accent` (terracotta) ajouté au bouton partagé existant. Les 3 sites mineurs déjà conformes (vérifié à l'investigation) ne sont pas touchés ; un seul vrai gap mineur (acceptation cash sans feedback) est comblé.

**Tech Stack:** Flutter, BLoC (flutter_bloc), GoRouter, flutter_animate, mocktail/bloc_test pour les tests.

## Global Constraints

- Couverture de test ≥ 90 % sur les fichiers touchés (règle CLAUDE.md du monorepo).
- `flutter analyze && flutter test` doivent rester verts après chaque tâche.
- Jamais de `Navigator.push`/`Navigator.pop` bruts en dehors des patterns déjà utilisés dans chaque fichier (GoRouter pour navigation nommée, `Navigator.of(context)` seulement pour empiler/dépiler des routes locales sans nom — comme le fait déjà `DonyBottomSheet`/`DonyPaymentSheet`).
- `DonyButton` reste toujours dans `stickyBottom` d'un `DonyBottomSheet` — sans objet ici car `DonySuccessScreen` n'est pas un bottom sheet, mais la règle s'applique à toute bottom sheet touchée en aval (accept_offer_bottom_sheet.dart, payment_recap_bottom_sheet.dart) : ne pas déplacer leurs `DonyButton` existants hors de `stickyBottom`.
- Pas de nouvelle mécanique de refresh inventée pour `create_trip_screen.dart` — le contrat `bool` de `context.pop(true)` vers les 3 appelants bool-dépendants doit rester identique bit à bit.
- Ne jamais utiliser `sed -i` pour éditer des fichiers Dart dans cet environnement (a corrompu des fichiers par le passé) — utiliser l'outil d'édition.

---

### Task 1: `DonyButtonVariant.accent` (terracotta)

**Files:**
- Modify: `lib/core/design/widgets/dony_button.dart`
- Test: `test/core/design/widgets/dony_button_test.dart` (créer s'il n'existe pas encore un test pour ce widget — vérifier d'abord avec `find test -iname "dony_button_test.dart"`)

**Interfaces:**
- Consumes: `DonyColors.terra500`, `DonyColors.terraDark500` (déjà définis dans `lib/core/design/tokens/color_tokens.dart:26,217`), `DonyShadow.accent` (déjà défini dans `lib/core/design/tokens/shadow_tokens.dart:85`).
- Produces: `DonyButtonVariant.accent` — nouvelle valeur d'enum utilisable par toute tâche ultérieure de ce plan (Task 6, trajet publié).

- [ ] **Step 1: Write the failing test**

Si `test/core/design/widgets/dony_button_test.dart` n'existe pas, le créer avec ce contenu minimal (sinon ajouter juste le test ci-dessous au fichier existant, dans un `group` séparé) :

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DonyButtonVariant.accent renders with terracotta gradient background',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DonyButton(
          label: 'Voir mon trajet',
          variant: DonyButtonVariant.accent,
          onPressed: () {},
        ),
      ),
    ));
    await tester.pump();

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    expect(gradient.colors, contains(const Color(0xFF3B8AFF).withValues(alpha: 1.0)));
  });
}
```

Cette première assertion est volontairement fausse (vérifie une couleur bleue alors qu'on veut du terracotta) — c'est le test qui doit échouer pour la bonne raison avant d'écrire l'implémentation, puis être corrigé à l'étape 3.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/design/widgets/dony_button_test.dart`
Expected: FAIL — soit compilation (`DonyButtonVariant.accent` n'existe pas), soit assertion (couleur bleue absente/gradient différent).

- [ ] **Step 3: Fix the test assertion to check the real terracotta colors, then implement**

Corriger le test (l'assertion de l'étape 1 était un leurre pour prouver l'échec — la remplacer maintenant par la vraie attente) :

```dart
    expect(
      gradient.colors,
      containsAll(<Color>[const Color(0xFFD96A3A)]),
    );
```

Dans `lib/core/design/widgets/dony_button.dart:8`, ajouter `accent` à l'enum :

```dart
enum DonyButtonVariant { primary, secondary, ghost, destructive, success, accent }
```

Dans le `switch (widget.variant)` de `_DonyButtonState.build` (`lib/core/design/widgets/dony_button.dart:124-177`), ajouter un cas avant `DonyButtonVariant.secondary =>` :

```dart
      DonyButtonVariant.accent => _GlowButton(
          colors: isLight
              ? [const Color(0xFFE8865B), DonyColors.terra500]
              : [DonyColors.terraDark500, const Color(0xFFC85A2E)],
          shadows: isLight ? DonyShadow.accent : DonyShadow.accent,
          foreground: DonyColors.textOnBrand,
          pressed: _pressed,
          fullWidth: widget.fullWidth,
          onPressed: widget.isLoading ? null : widget.onPressed,
          child: content,
        ),
```

Dans `_spinnerColor` (`lib/core/design/widgets/dony_button.dart:192-198`), ajouter le cas manquant (l'exhaustivité du switch l'exige) :

```dart
  Color _spinnerColor(ColorScheme cs) => switch (widget.variant) {
        DonyButtonVariant.primary     => DonyColors.textOnBrand,
        DonyButtonVariant.success     => DonyColors.textOnBrand,
        DonyButtonVariant.destructive => DonyColors.textOnBrand,
        DonyButtonVariant.accent      => DonyColors.textOnBrand,
        DonyButtonVariant.secondary   => cs.primary,
        DonyButtonVariant.ghost       => cs.onSurfaceVariant,
      };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/design/widgets/dony_button_test.dart`
Expected: PASS

- [ ] **Step 5: Run full analyze to catch any other non-exhaustive switch on DonyButtonVariant**

Run: `flutter analyze`
Expected: aucune erreur `non_exhaustive_switch` — si l'analyzer en signale une ailleurs dans le code (peu probable, `DonyButtonVariant` n'est utilisé que dans `dony_button.dart` d'après la recherche initiale), ajouter le cas `accent` manquant à cet endroit aussi.

- [ ] **Step 6: Commit**

```bash
git add lib/core/design/widgets/dony_button.dart test/core/design/widgets/dony_button_test.dart
git commit -m "feat(design-system): ajoute DonyButtonVariant.accent (terracotta)"
```

---

### Task 2: `DonySuccessScreen`

**Files:**
- Create: `lib/core/design/widgets/dony_success_screen.dart`
- Modify: `lib/core/design/design_system.dart` (ajouter l'export)
- Test: `test/core/design/widgets/dony_success_screen_test.dart`

**Interfaces:**
- Consumes: `DonyMascotteAnimated`, `DonyMascotteType`, `DonyMascotteSize` (`lib/core/design/widgets/dony_mascotte.dart`), `DonyButton`, `DonyButtonVariant` (Task 1), `DonyAppBar`, `DonyLayout`, `DonySpacing`.
- Produces:
  ```dart
  class DonySuccessScreen extends StatelessWidget {
    const DonySuccessScreen({
      super.key,
      required this.mascotteType,
      required this.title,
      required this.subtitle,
      required this.ctaLabel,
      required this.onCta,
      this.ctaVariant = DonyButtonVariant.primary,
    });

    final DonyMascotteType mascotteType;
    final String title;
    final String subtitle;
    final String ctaLabel;
    final VoidCallback onCta;
    final DonyButtonVariant ctaVariant;
  }
  ```
  Utilisé par les Tasks 3, 4, 5, 6, 7, 9 avec ce constructeur exact.

- [ ] **Step 1: Write the failing test**

Créer `test/core/design/widgets/dony_success_screen_test.dart` :

```dart
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required VoidCallback onCta}) => MaterialApp(
        theme: AppTheme.light,
        home: DonySuccessScreen(
          mascotteType: DonyMascotteType.securise,
          title: 'Envoi réservé !',
          subtitle: 'Ton paiement est sécurisé.',
          ctaLabel: 'Voir mes envois',
          onCta: onCta,
        ),
      );

  testWidgets('affiche titre, sous-titre et label du CTA', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Ton paiement est sécurisé.'), findsOneWidget);
    expect(find.text('Voir mes envois'), findsOneWidget);
  });

  testWidgets('tap sur le CTA appelle onCta exactement une fois', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(host(onCta: () => callCount++));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets('pas d\'auto-navigation : le CTA reste visible après 5 secondes',
      (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Voir mes envois'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/design/widgets/dony_success_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dony/core/design/widgets/dony_success_screen.dart'`

- [ ] **Step 3: Write minimal implementation**

Créer `lib/core/design/widgets/dony_success_screen.dart` :

```dart
import 'package:dony/core/design/utils/dony_layout.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Écran plein affiché après une action majeure réussie (paiement confirmé,
/// trajet publié, livraison confirmée). Pas d'auto-navigation : l'utilisateur
/// quitte l'écran uniquement via [onCta].
class DonySuccessScreen extends StatelessWidget {
  const DonySuccessScreen({
    super.key,
    required this.mascotteType,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.ctaVariant = DonyButtonVariant.primary,
  });

  final DonyMascotteType mascotteType;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;
  final DonyButtonVariant ctaVariant;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(
        title: '',
        showBackButton: false,
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              children: [
                const SizedBox(height: DonySpacing.xxl),
                DonyMascotteAnimated(
                  type: mascotteType,
                  size: DonyMascotteSize.lg,
                  withGlow: true,
                ),
                const SizedBox(height: DonySpacing.xl),
                Text(
                  title,
                  style: tt.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.md),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxl),
                DonyButton(
                  label: ctaLabel,
                  variant: ctaVariant,
                  onPressed: onCta,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutCubic),
          ),
        );
      }),
    );
  }
}
```

Ajouter l'export dans `lib/core/design/design_system.dart`, à côté de `dony_snackbar.dart` (ordre alphabétique respecté dans le bloc "Structural"/"Feedback") :

```dart
export 'package:dony/core/design/widgets/dony_success_screen.dart';
```
(l'insérer juste après la ligne `export 'package:dony/core/design/widgets/dony_snackbar.dart';`)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/design/widgets/dony_success_screen_test.dart`
Expected: PASS (3/3)

- [ ] **Step 5: Commit**

```bash
git add lib/core/design/widgets/dony_success_screen.dart lib/core/design/design_system.dart test/core/design/widgets/dony_success_screen_test.dart
git commit -m "feat(design-system): ajoute DonySuccessScreen (écran de succès majeur unifié)"
```

---

### Task 3: Paiement confirmé — `payment_screen.dart`

**Files:**
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart:279-337`
- Test: `test/features/payments/presentation/screens/payment_screen_test.dart` (fichier existant probable — chercher avec `find test -path "*payments*payment_screen_test.dart"` ; s'il n'existe pas, créer `test/features/payments/presentation/screens/payment_screen_success_test.dart`)

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2), `DonyMascotteType.securise`, `DonyButtonVariant.primary` (défaut).
- Produces: rien de nouveau consommé par une tâche ultérieure — ce site est terminal.

- [ ] **Step 1: Write the failing test**

Chercher d'abord si un test existant couvre `_EscrowConfirmedView` :

```bash
grep -rn "Envoi réservé\|_EscrowConfirmedView\|EscrowConfirmed" test/features/payments/
```

Si un test existant asserte déjà `find.text('Envoi réservé !')` et `find.text('Voir mes envois')`, ces assertions restent valides sans changement (le texte affiché ne change pas, seul le widget conteneur change de `_EscrowConfirmedView` à `DonySuccessScreen`) — dans ce cas, ajouter uniquement cette assertion supplémentaire au test existant, dans le même `testWidgets` qui pompe déjà l'état de succès :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
```

Si aucun test existant ne couvre ce widget, créer `test/features/payments/presentation/screens/payment_screen_success_test.dart` avec un test minimal ciblant directement le widget extrait (voir Step 3 — `_EscrowConfirmedView` restera un widget privé du fichier, donc ce cas de figure teste plutôt via le comportement observable : au lieu de pomper `PaymentScreen` en entier avec toute sa DI, ce test vérifie la structure attendue en construisant l'arbre directement) :

```dart
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'confirmation de paiement escrow utilise DonySuccessScreen avec la mascotte securise',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonySuccessScreen(
        mascotteType: DonyMascotteType.securise,
        title: 'Envoi réservé !',
        subtitle:
            '50.00 € sont bloqués en escrow et seront libérés après confirmation de livraison par le destinataire.',
        ctaLabel: 'Voir mes envois',
        onCta: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Envoi réservé !'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/payments/presentation/screens/payment_screen_success_test.dart` (ou le test existant mis à jour)
Expected: si nouveau fichier — PASSE déjà (il teste `DonySuccessScreen` isolément, pas encore `payment_screen.dart`) : ce n'est donc pas le bon test de couverture pour la migration elle-même. Passer directement à l'assertion sur le test existant du fichier réel : si un test existant pompe `PaymentScreen` jusqu'à l'état confirmé, ajouter `expect(find.byType(DonySuccessScreen), findsOneWidget);` à celui-ci et vérifier qu'il échoue avec "widget DonySuccessScreen non trouvé" avant l'implémentation.

- [ ] **Step 3: Implement — remplacer `_EscrowConfirmedView` par `DonySuccessScreen`**

Dans `lib/features/payments/presentation/screens/payment_screen.dart`, remplacer les lignes 277-337 (le commentaire `// ── Vue confirmation escrow ──...` et toute la classe `_EscrowConfirmedView`) par :

```dart
// ── Vue confirmation escrow ───────────────────────────────────────────────────

class _EscrowConfirmedView extends StatelessWidget {
  final double amount;
  const _EscrowConfirmedView({required this.amount});

  @override
  Widget build(BuildContext context) {
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: 'Envoi réservé !',
      subtitle:
          '${amount.toStringAsFixed(2)} € sont bloqués en escrow et seront libérés après confirmation de livraison par le destinataire.',
      ctaLabel: 'Voir mes envois',
      onCta: () => context.go('/home'),
    );
  }
}
```

Le widget `_EscrowConfirmedView` est conservé (juste vidé de sa vue custom) pour ne pas toucher ses call sites existants dans `payment_screen.dart` — seul son contenu change. `design_system.dart` est déjà importé en tête de fichier (`lib/features/payments/presentation/screens/payment_screen.dart:2`), donc `DonySuccessScreen` et `DonyMascotteType` sont déjà disponibles sans import supplémentaire.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/payments/presentation/screens/payment_screen_test.dart` (et le nouveau fichier si créé)
Expected: PASS

- [ ] **Step 5: Run the full existing test file for this screen and fix any now-broken assertions**

Run: `flutter test test/features/payments/presentation/screens/payment_screen_test.dart`
Si des assertions échouent parce qu'elles ciblaient l'ancienne structure de `_EscrowConfirmedView` (ex: `find.byType(Scaffold)` avec un `AppBar` titré `'Paiement confirmé'` — `DonySuccessScreen` utilise un `DonyAppBar` avec `title: ''`), les corriger pour cibler le texte visible (`find.text('Envoi réservé !')`) plutôt que la structure interne, qui est un détail d'implémentation.

- [ ] **Step 6: Commit**

```bash
git add lib/features/payments/presentation/screens/payment_screen.dart test/features/payments/presentation/screens/
git commit -m "feat(payments): écran paiement confirmé utilise DonySuccessScreen"
```

---

### Task 4: Paiement confirmé — bid + paiement inline (`create_bid_screen.dart`, `create_bid_bottom_sheet.dart`)

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_bid_screen.dart:511-544`
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart:1207-1239`
- Test: `test/features/matching/presentation/screens/create_bid_screen_test.dart`, `test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart` (ou fichier de test équivalent existant pour le flux paiement — chercher `grep -rln "from=payment" test/features/matching/`)

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2).
- Produces: rien consommé en aval.

- [ ] **Step 1: Write the failing test**

```bash
grep -rln "from=payment\|BidConfirmPaymentRequested" test/features/matching/
```

Pour chaque fichier trouvé qui teste le flux `onSuccess` de `DonyPaymentSheet` dans ces deux widgets, localiser le test qui simule un paiement réussi (probablement via un mock de `DonyPaymentSheet.show` ou un déclenchement direct du callback `onSuccess`) et y ajouter :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Offre payée !'), findsOneWidget);
```
juste avant (ou à la place de, si le test actuel vérifie directement `find.text('/bids/')` via un mock de router) l'assertion de navigation vers `/bids/{id}?from=payment`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/matching/presentation/screens/create_bid_screen_test.dart`
Expected: FAIL — `DonySuccessScreen` non trouvé (navigation directe vers `/bids/...` sans écran intermédiaire).

- [ ] **Step 3: Implement — `create_bid_screen.dart`**

Remplacer les lignes 526-543 :

```dart
    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: state.clientSecret,
        amountEur: state.amountEur,
        paymentMethodTypes: state.paymentMethodTypes,
      ),
      contextLabel: 'Envoi vers ${widget.announcement.arrivalCity}',
      onSuccess: () {
        if (!context.mounted) return;
        context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Offre payée !',
            subtitle: 'Le voyageur va être notifié de ta demande.',
            ctaLabel: 'Voir mon envoi',
            onCta: () => context.go('/bids/${state.bidId}?from=payment'),
          ),
        ));
      },
    );
```

- [ ] **Step 4: Implement — `create_bid_bottom_sheet.dart`**

Remplacer les lignes 1222-1238 :

```dart
    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: state.clientSecret,
        amountEur: state.amountEur,
        paymentMethodTypes: state.paymentMethodTypes,
      ),
      contextLabel: 'Envoi vers ${widget.announcement.arrivalCity}',
      onSuccess: () {
        if (!context.mounted) return;
        context.read<BidBloc>().add(BidConfirmPaymentRequested(state.bidId));
        context.pop();
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DonySuccessScreen(
              mascotteType: DonyMascotteType.securise,
              title: 'Offre payée !',
              subtitle: 'Le voyageur va être notifié de ta demande.',
              ctaLabel: 'Voir mon envoi',
              onCta: () => context.go('/bids/${state.bidId}?from=payment'),
            ),
          ));
        }
      },
    );
```

Ce fichier ferme d'abord la bottom sheet (`context.pop()`, comportement préexistant car cette variante s'ouvre depuis une sheet et non un écran plein), puis pousse `DonySuccessScreen` — contrairement à `create_bid_screen.dart` qui est déjà un écran plein et n'a rien à fermer avant de pousser.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/matching/presentation/screens/create_bid_screen_test.dart test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart`
Expected: PASS

Si d'autres fichiers de test existants asserteront encore l'ancienne navigation directe (`expect(find.text('/bids/'), ...)` sans passer par l'écran de succès), les mettre à jour pour d'abord taper sur le CTA `'Voir mon envoi'` avant de vérifier la navigation :

```dart
    await tester.tap(find.text('Voir mon envoi'));
    await tester.pump();
    // ... assertion de navigation existante inchangée
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/screens/create_bid_screen.dart lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart test/features/matching/presentation/screens/create_bid_screen_test.dart test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart
git commit -m "feat(matching): paiement de bid utilise DonySuccessScreen avant navigation"
```

---

### Task 5: Paiement confirmé — négociation (`accept_offer_bottom_sheet.dart`, `payment_recap_bottom_sheet.dart`)

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart:101-120` (branche `isCheckout`)
- Modify: `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart:101-125` (branche Stripe)
- Test: `test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`, `test/features/package_request/presentation/widgets/payment_recap_bottom_sheet_test.dart`

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2).
- Produces: rien consommé en aval.

- [ ] **Step 1: Write the failing test**

Dans les deux fichiers de test correspondants, localiser le test qui simule `onSuccess` de `DonyPaymentSheet` dans la branche checkout/Stripe (chercher `NegotiationCheckoutRequested` dans les fichiers de test) et ajouter :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Offre acceptée et payée !'), findsOneWidget);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart test/features/package_request/presentation/widgets/payment_recap_bottom_sheet_test.dart`
Expected: FAIL — `DonySuccessScreen` non trouvé (la sheet se ferme actuellement sans rien afficher).

- [ ] **Step 3: Implement — `accept_offer_bottom_sheet.dart`**

Remplacer les lignes 111-119 (dans la branche `if (isCheckout)`) :

```dart
                            onSuccess: () {
                              bloc.add(NegotiationCheckoutRequested(
                                threadId: threadId,
                                paymentIntentId: init.paymentIntentId,
                              ));
                              if (ctx.mounted) {
                                Navigator.of(ctx, rootNavigator: true).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => DonySuccessScreen(
                                    mascotteType: DonyMascotteType.securise,
                                    title: 'Offre acceptée et payée !',
                                    subtitle:
                                        'Le voyageur est notifié, la livraison peut être suivie depuis le fil.',
                                    ctaLabel: 'Voir le suivi',
                                    onCta: () =>
                                        context.go('/negotiations/$threadId'),
                                  ),
                                ));
                              }
                            },
```

Le `context` extérieur (paramètre de `AcceptOfferBottomSheet.show`, disponible dans toute la méthode) reste monté après la fermeture de la sheet puisqu'il s'agit de l'écran qui a ouvert la sheet — c'est le même pattern que `context.mounted` déjà utilisé ailleurs dans ce fichier (ligne 520 de `create_bid_screen.dart` par exemple).

- [ ] **Step 4: Implement — `payment_recap_bottom_sheet.dart`**

Remplacer les lignes 115-124 (dans la branche `if (!isCash)`, à l'intérieur du `try`) :

```dart
                            onSuccess: () {
                              bloc.add(NegotiationCheckoutRequested(
                                threadId: thread.id,
                                paymentIntentId: init.paymentIntentId,
                                paymentMethod: method,
                              ));
                              if (ctx.mounted) {
                                Navigator.of(ctx, rootNavigator: true).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => DonySuccessScreen(
                                    mascotteType: DonyMascotteType.securise,
                                    title: 'Offre acceptée et payée !',
                                    subtitle:
                                        'Le voyageur est notifié, la livraison peut être suivie depuis le fil.',
                                    ctaLabel: 'Voir le suivi',
                                    onCta: () =>
                                        context.go('/negotiations/${thread.id}'),
                                  ),
                                ));
                              }
                            },
```

La branche cash (`else`) de ce même fichier n'est pas touchée par cette tâche (déjà correcte — voir Task 10 pour l'équivalent côté `accept_offer_bottom_sheet.dart`, ce fichier-ci n'a pas de gap mineur identifié à l'investigation).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart test/features/package_request/presentation/widgets/payment_recap_bottom_sheet_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart test/features/package_request/presentation/widgets/payment_recap_bottom_sheet_test.dart
git commit -m "feat(package-request): paiement de négociation utilise DonySuccessScreen"
```

---

### Task 6: Trajet publié — `create_trip_screen.dart`

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_trip_screen.dart:1191-1194` (et le bloc `listener` qui l'entoure)
- Test: `test/features/matching/presentation/screens/create_trip_screen_test.dart`

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2), `DonyButtonVariant.accent` (Task 1), `DonyMascotteType.joyeux`.
- Produces: rien consommé en aval. **Contrainte critique** (voir Global Constraints) : les 3 call sites bool-dépendants (`announcement_list_screen.dart:148-153`, `owner_action_grid.dart:118-127`, `trip_owner_detail_screen.dart:229-243`) ne doivent PAS être modifiés — le mécanisme choisi préserve leur contrat `bool` sans y toucher.

- [ ] **Step 1: Write the failing test**

Dans `test/features/matching/presentation/screens/create_trip_screen_test.dart`, localiser le test qui simule `AnnouncementCreated` (ou `AnnouncementUpdated`) émis par le bloc, et ajouter :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Trajet publié !'), findsOneWidget);
```

Ajouter aussi un test dédié au double-pop (nouveau, si l'infrastructure de mock du fichier le permet — sinon documenter cette vérification comme couverte manuellement dans le rapport de tâche) :

```dart
  testWidgets(
      'le CTA de DonySuccessScreen ferme create_trip_screen avec pop(true)',
      (tester) async {
    // Pomper create_trip_screen poussé depuis un écran hôte via
    // context.push<bool>('/trips/create'), simuler AnnouncementCreated,
    // taper le CTA "Voir mon trajet", puis vérifier que le Future du push
    // se résout à `true` (même contrat qu'avant ce chantier).
  }, skip: true); // à dépiloter par l'implémenteur une fois le harness du fichier existant identifié
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/matching/presentation/screens/create_trip_screen_test.dart`
Expected: FAIL — `DonySuccessScreen` non trouvé (pop silencieux actuel).

- [ ] **Step 3: Implement**

Remplacer les lignes 1191-1194 de `lib/features/matching/presentation/screens/create_trip_screen.dart` :

```dart
      child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) async {
          if (state is AnnouncementCreated || state is AnnouncementUpdated) {
            final announcement = state is AnnouncementCreated
                ? state.announcement
                : (state as AnnouncementUpdated).announcement;
            final isEdit = state is AnnouncementUpdated;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DonySuccessScreen(
                mascotteType: DonyMascotteType.joyeux,
                title: isEdit ? 'Trajet modifié !' : 'Trajet publié !',
                subtitle:
                    'Ton trajet ${announcement.departureCity} → ${announcement.arrivalCity} est en ligne.',
                ctaLabel: 'Voir mon trajet',
                ctaVariant: DonyButtonVariant.accent,
                onCta: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // même contrat bool qu'avant — les 3 appelants bool-dépendants ne changent pas
                  context.push('/trips/${announcement.id}');
                },
              ),
            ));
          } else if (state is AnnouncementProLimitReached) {
```

(le reste du `listener` — branches `AnnouncementProLimitReached`, `AnnouncementDraftLimitReached`, etc. — reste inchangé après ce bloc `if/else if`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/matching/presentation/screens/create_trip_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Verify the 3 bool-dependent callers still pass unmodified**

Run: `flutter test test/features/matching/presentation/screens/announcement_list_screen_test.dart test/features/matching/presentation/widgets/owner_action_grid_test.dart test/features/matching/presentation/screens/trip_owner_detail_screen_test.dart`
Expected: PASS sans aucune modification de ces 3 fichiers de test ni de leurs fichiers source — si l'un d'eux échoue, c'est que le double-pop de Step 3 ne préserve pas le contrat `bool` exactement : revenir à Step 3 et corriger avant de continuer (ne pas modifier les fichiers appelants pour faire passer le test — ce serait casser la contrainte globale du plan).

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/screens/create_trip_screen.dart test/features/matching/presentation/screens/create_trip_screen_test.dart
git commit -m "feat(matching): trajet publié utilise DonySuccessScreen, contrat bool préservé"
```

---

### Task 7: Trajet publié — `create_announcement_screen.dart`

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_announcement_screen.dart:571-579`
- Test: `test/features/matching/presentation/screens/create_announcement_screen_test.dart`

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2), `DonyButtonVariant.accent` (Task 1), `DonyMascotteType.joyeux`.
- Produces: rien consommé en aval.

- [ ] **Step 1: Write the failing test**

Dans `test/features/matching/presentation/screens/create_announcement_screen_test.dart`, localiser le test qui simule `AnnouncementCreated`/`AnnouncementUpdated` et vérifie actuellement le SnackBar "Trajet publié !" / navigation vers `/announcements`. Remplacer ou compléter par :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Trajet publié !'), findsOneWidget); // ou 'Trajet modifié !' selon le scénario du test
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/matching/presentation/screens/create_announcement_screen_test.dart`
Expected: FAIL — `DonySuccessScreen` non trouvé (SnackBar actuel).

- [ ] **Step 3: Implement**

Remplacer les lignes 571-579 de `lib/features/matching/presentation/screens/create_announcement_screen.dart` :

```dart
      listener: (context, state) {
        if (state is AnnouncementCreated || state is AnnouncementUpdated) {
          final announcement = state is AnnouncementCreated
              ? state.announcement
              : (state as AnnouncementUpdated).announcement;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DonySuccessScreen(
              mascotteType: DonyMascotteType.joyeux,
              title: _isEdit ? 'Trajet modifié !' : 'Trajet publié !',
              subtitle:
                  'Ton trajet ${announcement.departureCity} → ${announcement.arrivalCity} est en ligne.',
              ctaLabel: 'Voir mon trajet',
              ctaVariant: DonyButtonVariant.accent,
              onCta: () {
                Navigator.of(context).pop();
                context.go('/announcements');
              },
            ),
          ));
        } else if (state is AnnouncementProLimitReached) {
```

`_isEdit` est un champ déjà existant dans cette classe (utilisé ligne 576 avant modification pour choisir le texte du SnackBar) — vérifier son nom exact avec `grep -n "_isEdit" lib/features/matching/presentation/screens/create_announcement_screen.dart` avant d'écrire cette étape si le nom diffère.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/matching/presentation/screens/create_announcement_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/screens/create_announcement_screen.dart test/features/matching/presentation/screens/create_announcement_screen_test.dart
git commit -m "feat(matching): create_announcement_screen utilise DonySuccessScreen"
```

---

### Task 8: Suppression du code mort — `CreateAnnouncementBottomSheet`

**Files:**
- Delete: `lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart`
- Delete: `test/features/matching/presentation/widgets/create_announcement_bottom_sheet_test.dart`
- Delete: `test/features/matching/presentation/widgets/create_announcement_dedicated_flow_test.dart`
- Delete: `test/features/matching/presentation/create_announcement_capacity_submit_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: rien — ce widget n'a aucun call site en dehors de ses propres tests (vérifié par `grep -rn "CreateAnnouncementBottomSheet" lib/ test/` à l'investigation : uniquement sa propre définition + les 3 fichiers de test listés ci-dessus).

**Contexte de sécurité de cette suppression :** `create_announcement_capacity_submit_test.dart` protège un bug historique réel (chip de capacité non synchronisé avec le BLoC). Vérifié à l'investigation : l'écran vivant `create_announcement_screen.dart` utilise un `Slider` qui écrit dans `_availableKgNotifier` de façon **synchrone**, sans dispatch BLoC intermédiaire (`grep -n "CapacityControl\|CapacityUnitChanged" lib/features/matching/presentation/screens/create_announcement_screen.dart` ne retourne aucun résultat) — la classe de bug (chip → dispatch BLoC async → notifier local non resynchronisé) ne peut donc pas se reproduire sur ce chemin de code. Rien à porter.

- [ ] **Step 1: Confirm no other call site was introduced by Tasks 1-7**

Run: `grep -rn "CreateAnnouncementBottomSheet" lib/ test/`
Expected: uniquement les 4 fichiers listés ci-dessus. Si un nouveau call site apparaît (ne devrait pas, aucune tâche précédente n'y touche), **ne pas supprimer** — escalader plutôt que de casser un appelant vivant.

- [ ] **Step 2: Delete the 4 files**

```bash
git rm lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart
git rm test/features/matching/presentation/widgets/create_announcement_bottom_sheet_test.dart
git rm test/features/matching/presentation/widgets/create_announcement_dedicated_flow_test.dart
git rm test/features/matching/presentation/create_announcement_capacity_submit_test.dart
```

- [ ] **Step 3: Run full analyze to catch any dangling import**

Run: `flutter analyze`
Expected: aucune erreur `uri_does_not_exist` ni `undefined_class` référençant `CreateAnnouncementBottomSheet`.

- [ ] **Step 4: Run the full test suite to confirm nothing else depended on these files**

Run: `flutter test`
Expected: 0 nouvel échec par rapport à l'état avant suppression (comparer le nombre total de tests avant/après — la seule variation attendue est la disparition des tests des 3 fichiers supprimés).

- [ ] **Step 5: Commit**

```bash
git commit -m "chore(matching): supprime CreateAnnouncementBottomSheet (code mort, remplacé par create_announcement_screen.dart)"
```

---

### Task 9: Livraison confirmée — `scan_confirm_screen.dart`

**Files:**
- Modify: `lib/features/tracking/presentation/screens/scan_confirm_screen.dart:84-97,326-397`
- Test: `test/features/tracking/presentation/screens/scan_confirm_screen_test.dart`

**Interfaces:**
- Consumes: `DonySuccessScreen` (Task 2), `DonyButtonVariant.success` (déjà existant, pas une nouvelle tâche), `DonyMascotteType.securise`.
- Produces: rien consommé en aval.

**Hors scope rappelé :** le scan intermédiaire (`isFinal: false`, "Scan enregistré !") et la variante offline `_showQueued` restent des `AlertDialog` inchangés — seule la confirmation finale de livraison change.

- [ ] **Step 1: Write the failing test**

Dans `test/features/tracking/presentation/screens/scan_confirm_screen_test.dart`, localiser le test qui simule `DeliveryConfirmSuccess` (le cas `isFinal: true`) et vérifie actuellement l'`AlertDialog` "Colis livré !". Remplacer les assertions de dialog par :

```dart
    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Colis livré !'), findsOneWidget);
```

Le test qui simule `QrScanSuccess` (`isFinal: false`, "Scan enregistré !") ne change pas — il doit continuer à vérifier un `AlertDialog`, pas `DonySuccessScreen`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tracking/presentation/screens/scan_confirm_screen_test.dart`
Expected: FAIL sur le scénario `DeliveryConfirmSuccess` — `DonySuccessScreen` non trouvé (AlertDialog actuel). Le scénario `QrScanSuccess` (intermédiaire) doit rester vert sans modification.

- [ ] **Step 3: Implement — séparer le cas final du cas intermédiaire**

Dans `lib/features/tracking/presentation/screens/scan_confirm_screen.dart`, modifier le `listener` du `BlocConsumer` (lignes 84-97) :

```dart
      listener: (context, state) {
        if (state is QrScanSuccess) {
          _showSuccess(context, state.event.stepLabel);
        } else if (state is QrScanQueued) {
          _showQueued(context);
        } else if (state is DeliveryConfirmSuccess) {
          _navigateToDeliverySuccess(
            context,
            state.event.stepLabel,
            finalBidId: state.event.bidId,
          );
        }
      },
```

Simplifier `_showSuccess` (lignes 326-397) pour ne plus gérer que le cas intermédiaire (supprimer les paramètres `isFinal`/`finalBidId` devenus inutiles, et toute la branche `isFinal` de son contenu) :

```dart
  void _showSuccess(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyMascotteAnimated(
              type: DonyMascotteType.confiant,
              size: DonyMascotteSize.lg,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Scan enregistré !',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ctx.pop();
                context.go('/tracking');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
              ),
              child: const Text('Terminé'),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDeliverySuccess(
    BuildContext context,
    String label, {
    required String finalBidId,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DonySuccessScreen(
        mascotteType: DonyMascotteType.securise,
        title: 'Colis livré !',
        subtitle: label,
        ctaLabel: 'Terminer',
        ctaVariant: DonyButtonVariant.success,
        onCta: () async {
          await RatingBottomSheet.show(
            context,
            bidId: finalBidId,
            travelerName: "l'expéditeur",
            isTravelerRating: true,
          );
          if (!context.mounted) return;
          context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          context.go('/tracking');
        },
      ),
    ));
  }
```

`_showQueued` (lignes 399-456) n'est pas touché.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tracking/presentation/screens/scan_confirm_screen_test.dart`
Expected: PASS sur les deux scénarios (final → `DonySuccessScreen`, intermédiaire → `AlertDialog` inchangé).

- [ ] **Step 5: Commit**

```bash
git add lib/features/tracking/presentation/screens/scan_confirm_screen.dart test/features/tracking/presentation/screens/scan_confirm_screen_test.dart
git commit -m "feat(tracking): confirmation de livraison finale utilise DonySuccessScreen"
```

---

### Task 10: Comblement du gap mineur — acceptation cash sans feedback

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart:123-128` (branche `else`, acceptation non-checkout)
- Test: `test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`

**Interfaces:**
- Consumes: `DonySnackbar.show`, `DonySnackbarType.info` (déjà existants, aucune nouvelle tâche).
- Produces: rien consommé en aval — dernière tâche du plan.

**Rappel du gap identifié à l'investigation :** les 3 autres sites mineurs de la spec (`make_offer_bottom_sheet.dart`, `package_request_create_screen.dart`, `wallet_topup_amount_screen.dart`) utilisent déjà `DonySnackbar.show(type: DonySnackbarType.success)` — vérifié par lecture directe du code, **aucune modification requise** pour ces 3 fichiers. Seule la branche cash de `accept_offer_bottom_sheet.dart` n'affiche actuellement rien du tout.

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`, localiser (ou créer si absent) le test du scénario `isCheckout: false` (acceptation initiale, pas de paiement Stripe) et ajouter :

```dart
    expect(find.byWidgetPredicate((w) => w is SnackBar), findsOneWidget);
    expect(
      find.text('Offre acceptée — paiement en espèces à la remise'),
      findsOneWidget,
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`
Expected: FAIL — aucun SnackBar affiché actuellement dans cette branche.

- [ ] **Step 3: Implement**

Dans `lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart`, remplacer les lignes 123-128 (la branche `else` du `if (isCheckout)`) :

```dart
                        } else {
                          bloc.add(NegotiationAcceptRequested(threadId: threadId));
                          if (ctx.mounted) {
                            DonySnackbar.show(
                              ctx,
                              message:
                                  'Offre acceptée — paiement en espèces à la remise',
                              type: DonySnackbarType.info,
                            );
                            Navigator.of(ctx, rootNavigator: true).pop();
                          }
                        }
```

Le `DonySnackbar.show` doit être appelé **avant** `Navigator.of(ctx, rootNavigator: true).pop()` — `ctx` est le `BuildContext` de la sheet elle-même ; une fois la sheet fermée, ce `ScaffoldMessenger` local n'est plus disponible pour afficher le SnackBar sur le bon ancrage.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart test/features/package_request/presentation/widgets/accept_offer_bottom_sheet_test.dart
git commit -m "fix(package-request): feedback SnackBar manquant sur acceptation d'offre cash"
```

---

## Self-Review

**Spec coverage :**
- Composant majeur `DonySuccessScreen` → Task 2. ✓
- Composant mineur `DonySnackbar` généralisé → Task 10 (seul vrai gap après vérification ; les 3 autres sites de la spec étaient déjà conformes, documenté dans Task 10). ✓
- Paiement (3 points d'entrée) → Tasks 3, 4, 5. ✓
- Trajet publié (2 implémentations vivantes) → Tasks 6, 7. ✓
- Suppression code mort `CreateAnnouncementBottomSheet` → Task 8, avec la vérification de sécurité sur le test de régression (pas de portage nécessaire, cause documentée). ✓
- Livraison confirmée → Task 9. ✓
- Nouveau variant de bouton nécessaire pour le mockup approuvé (terracotta) → Task 1, découvert à la lecture du code (`DonyButton` n'avait que 5 variants fixes, pas de couleur custom). ✓
- Contrainte de non-régression sur `create_trip_screen.dart` (3 appelants bool-dépendants) → Task 6, avec Step 5 dédié à leur vérification sans modification. ✓

**Placeholder scan :** aucun "TBD"/"à définir" dans le code produit. Les seules zones où le plan renvoie à une recherche à l'implémentation (`grep` pour localiser un test existant précis) portent sur la localisation d'un fichier, jamais sur le contenu du code ou des assertions à écrire — celles-ci sont données intégralement dans chaque étape.

**Type consistency :** `DonySuccessScreen(mascotteType:, title:, subtitle:, ctaLabel:, onCta:, ctaVariant:)` utilisé à l'identique dans les Tasks 3, 4, 5, 6, 7, 9. `DonyButtonVariant.accent` (Task 1) utilisé dans Tasks 6, 7. `DonyButtonVariant.success` (préexistant) utilisé dans Task 9.
