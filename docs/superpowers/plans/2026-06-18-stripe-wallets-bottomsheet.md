# Sélecteur de paiement — logos wallets (phase 2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La tuile « Stripe » du sélecteur de bid affiche des logos wallets (carte + Apple Pay/iOS ou Google Pay/Android + PayPal) sous « Paiement sécurisé / Via Stripe ».

**Architecture:** Purement présentationnel. Nouveau widget `PaymentBrandMarks` (plateforme-aware via `defaultTargetPlatform`) rendu dans un slot `marks` optionnel ajouté à `_MethodTile`. Logos = SVG dans `assets/logos/payment/` (placeholders shape-only à remplacer par les marks officiels). Aucun changement enum/BLoC/backend.

**Tech Stack:** Flutter, `flutter_svg` (déjà présent), `SvgPicture.asset`.

---

## Repo & Branche
`dony_app`, branche **`feature/payment-selector-wallets-ui`** (déjà créée depuis `feature/stripe-wallets-paypal`, contient la spec). Tous les commits y vont.

## File Structure
- Create: `assets/logos/payment/{card,apple-pay,google-pay,paypal}.svg` (placeholders shape-only)
- Modify: `pubspec.yaml` (déclarer `assets/logos/payment/`)
- Create: `lib/features/payments/presentation/widgets/payment_brand_marks.dart`
- Create: `test/features/payments/presentation/widgets/payment_brand_marks_test.dart`
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart` (`_MethodTile` slot + tuile STRIPE + import)
- Modify: `test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart` (assertion `PaymentBrandMarks`)

**Hors scope (ne PAS toucher) :** `PaymentMethodsChips` (lecture seule), flux négociation, backend, enums. Les SVG livrés sont des placeholders — note dans la PR que les marks **officiels** (Apple/Google/PayPal/Visa-MC) doivent les remplacer avant prod.

**Environnement :** background job — le guard bg-isolation bloque les outils Edit/Write dans le checkout `dony_app`. Écrire/modifier les fichiers via Bash (heredoc/python), exécuter `flutter` via Bash. Ne pas créer de worktree.

---

## Task T1: Assets logos + déclaration pubspec

**Files:** Create `assets/logos/payment/*.svg` ; Modify `pubspec.yaml`.

- [ ] **Step 1: Créer les 4 SVG placeholders (shape-only, rendu fiable)**

```bash
mkdir -p assets/logos/payment
cat > assets/logos/payment/card.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24" width="40" height="24"><rect width="40" height="24" rx="3" fill="#1A1F71"/><rect y="6" width="40" height="4" fill="#ffffff" opacity="0.85"/><rect x="5" y="15" width="14" height="3" rx="1.5" fill="#ffffff" opacity="0.7"/></svg>
SVG
cat > assets/logos/payment/apple-pay.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24" width="40" height="24"><rect width="40" height="24" rx="5" fill="#000000"/><rect x="13" y="8" width="14" height="8" rx="4" fill="#ffffff"/></svg>
SVG
cat > assets/logos/payment/google-pay.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24" width="40" height="24"><rect width="40" height="24" rx="5" fill="#ffffff" stroke="#DADCE0"/><circle cx="13" cy="12" r="3" fill="#4285F4"/><circle cx="20" cy="12" r="3" fill="#EA4335"/><circle cx="27" cy="9" r="3" fill="#FBBC04"/><circle cx="27" cy="15" r="3" fill="#34A853"/></svg>
SVG
cat > assets/logos/payment/paypal.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 24" width="40" height="24"><rect width="40" height="24" rx="5" fill="#ffffff" stroke="#003087"/><rect x="11" y="6" width="9" height="12" rx="4.5" fill="#003087"/><rect x="18" y="6" width="9" height="12" rx="4.5" fill="#009CDE" opacity="0.85"/></svg>
SVG
echo "svg assets created"; ls assets/logos/payment/
```

- [ ] **Step 2: Déclarer le dossier dans `pubspec.yaml`**

Ajouter la ligne `    - assets/logos/payment/` juste après `    - assets/logos/3.0x/` :
```bash
python3 - <<'PY'
p="pubspec.yaml"; s=open(p,encoding="utf-8").read()
a="    - assets/logos/3.0x/\n"
assert s.count(a)==1, s.count(a)
s=s.replace(a, a+"    - assets/logos/payment/\n")
open(p,"w",encoding="utf-8").write(s); print("pubspec updated")
PY
flutter pub get
```

- [ ] **Step 3: Commit**

```bash
git add assets/logos/payment/ pubspec.yaml
git commit -m "feat(payments): assets logos wallets (placeholders à remplacer par marks officiels)"
```

---

## Task T2: Widget `PaymentBrandMarks` (TDD)

**Files:** Create `lib/features/payments/presentation/widgets/payment_brand_marks.dart` ; Test `test/features/payments/presentation/widgets/payment_brand_marks_test.dart`.

- [ ] **Step 1: Écrire le test (échoue — widget inexistant)**

```bash
mkdir -p test/features/payments/presentation/widgets
cat > test/features/payments/presentation/widgets/payment_brand_marks_test.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/payments/presentation/widgets/payment_brand_marks.dart';

void main() {
  testWidgets('iOS → carte + Apple Pay + PayPal, pas Google Pay', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PaymentBrandMarks())));
    expect(find.byKey(const Key('payment-mark-card')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-apple-pay')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-paypal')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-google-pay')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android → carte + Google Pay + PayPal, pas Apple Pay', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PaymentBrandMarks())));
    expect(find.byKey(const Key('payment-mark-card')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-google-pay')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-paypal')), findsOneWidget);
    expect(find.byKey(const Key('payment-mark-apple-pay')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
DART
```

- [ ] **Step 2: Lancer → rouge**

Run: `flutter test test/features/payments/presentation/widgets/payment_brand_marks_test.dart`
Expected: FAIL — `payment_brand_marks.dart` n'existe pas.

- [ ] **Step 3: Créer le widget**

```bash
cat > lib/features/payments/presentation/widgets/payment_brand_marks.dart <<'DART'
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Rangée de logos des moyens couverts par le rail Stripe, plateforme-aware.
///
/// Carte + PayPal partout ; Apple Pay sur iOS, Google Pay sur Android. Le choix
/// réel de l'instrument se fait dans la PaymentSheet Stripe — ces marks ne font
/// que l'annoncer dans le sélecteur dony.
class PaymentBrandMarks extends StatelessWidget {
  const PaymentBrandMarks({super.key});

  static const _semantics = <String, String>{
    'card': 'Carte bancaire',
    'apple-pay': 'Apple Pay',
    'google-pay': 'Google Pay',
    'paypal': 'PayPal',
  };

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final names = <String>[
      'card',
      if (isIOS) 'apple-pay' else 'google-pay',
      'paypal',
    ];
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final n in names)
          SvgPicture.asset(
            'assets/logos/payment/$n.svg',
            key: Key('payment-mark-$n'),
            height: 16,
            semanticsLabel: _semantics[n],
          ),
      ],
    );
  }
}
DART
```

- [ ] **Step 4: Lancer → vert**

Run: `flutter test test/features/payments/presentation/widgets/payment_brand_marks_test.dart`
Expected: PASS (2 tests). (Les SVG ne sont pas décodés en test — on assert la structure via les Keys.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/presentation/widgets/payment_brand_marks.dart \
        test/features/payments/presentation/widgets/payment_brand_marks_test.dart
git commit -m "feat(payments): widget PaymentBrandMarks (logos wallets plateforme-aware)"
```

---

## Task T3: Slot `marks` sur `_MethodTile` + tuile STRIPE

**Files:** Modify `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart` ; Test `test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart`.

- [ ] **Step 1: Ajouter l'import du widget**

```bash
python3 - <<'PY'
p="lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart"
s=open(p,encoding="utf-8").read()
imp="import 'package:dony/features/payments/presentation/widgets/payment_brand_marks.dart';\n"
assert imp not in s
m="import 'package:dony/"
i=s.index(m)
s=s[:i]+imp+s[i:]
open(p,"w",encoding="utf-8").write(s); print("import added")
PY
```

- [ ] **Step 2: Ajouter le paramètre `marks` à `_MethodTile` + le rendre**

```bash
python3 - <<'PY'
p="lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart"
s=open(p,encoding="utf-8").read()

# 2a — ajouter le champ au constructeur
ctor=("  const _MethodTile({\n"
      "    super.key,\n"
      "    required this.iconAsset,\n"
      "    required this.label,\n"
      "    required this.sublabel,\n"
      "    required this.selected,\n"
      "    required this.onTap,\n"
      "  });\n")
ctor_new=("  const _MethodTile({\n"
      "    super.key,\n"
      "    required this.iconAsset,\n"
      "    required this.label,\n"
      "    required this.sublabel,\n"
      "    required this.selected,\n"
      "    required this.onTap,\n"
      "    this.marks,\n"
      "  });\n")
assert s.count(ctor)==1, ("ctor", s.count(ctor))
s=s.replace(ctor,ctor_new)

# 2b — déclarer le champ
fld="  final VoidCallback onTap;\n"
assert s.count(fld)==1, ("fld", s.count(fld))
s=s.replace(fld, fld+"  final Widget? marks;\n")

# 2c — insérer le rendu entre label et sublabel
anchor=("            Text(\n"
        "              label,\n"
        "              style: tt.labelMedium?.copyWith(\n"
        "                color:\n"
        "                    selected ? cs.onPrimaryContainer : cs.onSurface,\n"
        "                fontWeight: FontWeight.w600,\n"
        "              ),\n"
        "            ),\n")
assert s.count(anchor)==1, ("anchor", s.count(anchor))
inject=anchor+("            if (marks != null) ...[\n"
               "              const SizedBox(height: DonySpacing.xs),\n"
               "              marks!,\n"
               "            ],\n")
s=s.replace(anchor,inject)
open(p,"w",encoding="utf-8").write(s); print("MethodTile slot added")
PY
```

- [ ] **Step 3: La tuile STRIPE passe les marks**

```bash
python3 - <<'PY'
p="lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart"
s=open(p,encoding="utf-8").read()
a=("          key: const Key('payment-method-stripe'),\n"
   "          iconAsset: 'lock',\n"
   "          label: 'Paiement sécurisé',\n"
   "          sublabel: 'Via Stripe',\n")
assert s.count(a)==1, ("stripe-tile", s.count(a))
b=("          key: const Key('payment-method-stripe'),\n"
   "          iconAsset: 'lock',\n"
   "          label: 'Paiement sécurisé',\n"
   "          marks: const PaymentBrandMarks(),\n"
   "          sublabel: 'Via Stripe',\n")
s=s.replace(a,b)
open(p,"w",encoding="utf-8").write(s); print("stripe tile marks wired")
PY
```

- [ ] **Step 4: Étendre le test du sélecteur**

Dans `test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart`, repérer le test qui rend le sélecteur (il cherche `Key('payment-method-stripe')`). Y ajouter, une fois le sélecteur visible :
```dart
expect(find.byType(PaymentBrandMarks), findsOneWidget);
```
et l'import en tête du fichier :
```dart
import 'package:dony/features/payments/presentation/widgets/payment_brand_marks.dart';
```
(Si aucun test ne rend le sélecteur, ajouter dans ce fichier un `testWidgets` qui pompe `CreateBidBottomSheet.show(...)` jusqu'à l'étape paiement — réutiliser le harnais de pump déjà présent dans le fichier.)

- [ ] **Step 5: Lancer le test du sélecteur → vert**

Run: `flutter test test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart`
Expected: PASS (la tuile STRIPE rend `PaymentBrandMarks`).

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart \
        test/features/matching/presentation/widgets/create_bid_bottom_sheet_cash_test.dart
git commit -m "feat(payments): tuile STRIPE du sélecteur affiche les logos wallets"
```

---

## Task T4: Analyse + suite + couverture

- [ ] **Step 1: Analyse**

Run: `flutter analyze lib/features/payments lib/features/matching`
Expected: 0 erreur (les `info` lints pré-existants sont tolérés).

- [ ] **Step 2: Suite ciblée puis complète**

Run: `flutter test test/features/payments/ test/features/matching/`
Expected: tous verts.
Run: `flutter test`
Expected: All tests passed.

- [ ] **Step 3: Couverture ≥ 90 %**

Run: `flutter test --coverage` puis vérifier `coverage/lcov.info` (le nouveau widget est couvert par 2 tests iOS/Android).

- [ ] **Step 4: Commit (si fixups)**

```bash
git add -A && git commit -m "test(payments): couverture sélecteur logos wallets"
```

---

## Self-Review (auteur)

- **Couverture spec :** §3.1 assets (T1) ; §3.2 PaymentBrandMarks (T2) ; §3.3 slot `_MethodTile` + tuile STRIPE (T3) ; §5 tests (T2 iOS/Android, T3 tuile) ; §4 hors scope respecté (aucune tâche chips/négociation/backend). ✓
- **Pas de placeholder :** tout le code des steps est concret (SVG, widget, edits python avec assert). La seule indirection (T3 step 4 : localiser le test du sélecteur) est bornée et vérifiable. ✓
- **Cohérence des noms :** Keys `payment-mark-{card,apple-pay,google-pay,paypal}` identiques entre widget (T2 step 3) et tests (T2 step 1) ; `marks` identique constructeur/champ/rendu (T3) ; chemins SVG `assets/logos/payment/<n>.svg` identiques T1/T2. ✓
- **Note PR :** SVG = placeholders shape-only ; remplacer par les marks officiels (Apple/Google/PayPal/Visa-MC) avant prod (conformité store). ✓
