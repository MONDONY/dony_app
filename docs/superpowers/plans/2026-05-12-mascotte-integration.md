# Mascotte Integration v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les 11 anciens assets mascotte par 8 nouveaux, créer un widget `DonyMascotteAnimated` avec presets style Alan, et étendre la mascotte à tous les empty states + écrans de succès.

**Architecture:** Le widget `DonyMascotte` est refactorisé (nouveau enum 8 types, nouveau dossier `assets/mascotte/`). Un nouveau wrapper `DonyMascotteAnimated` ajoute des presets d'animation `flutter_animate` par type — sans modifier les BLoCs ni la logique métier. Les empty states existants reçoivent un `mascotte:` param.

**Tech Stack:** Flutter, flutter_animate, design system dony (`DonyMascotte`, `DonyEmptyState`, `DonySpacing`, `DonyRadius`, ColorScheme)

---

## Fichiers modifiés / créés

| Fichier | Action |
|---|---|
| `pubspec.yaml` | `assets/mascottes/` → `assets/mascotte/` |
| `lib/core/design/widgets/dony_mascotte.dart` | Refaire enum 8 types + ajouter `DonyMascotteAnimated` |
| `lib/core/design/design_system.dart` | Exporter `DonyMascotteAnimated` |
| `lib/core/design/CLAUDE.md` | Mettre à jour la table de mapping |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | `.salue` → `.joyeux` + `DonyMascotteAnimated` |
| `lib/features/tracking/presentation/screens/qr_scanner_screen.dart` | `.colisLivre`→`.securise`, `.pouceLeve`→`.confiant` |
| `lib/features/messaging/presentation/conversation_list_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/matching/presentation/screens/bid_list_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/notifications/presentation/notification_bottom_sheet.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/ratings/presentation/screens/my_reviews_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/favorite_travelers/presentation/screens/favorite_travelers_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/cancellation/presentation/screens/rematch_search_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/recipients/presentation/screens/recipients_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `lib/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart` | Ajouter `mascotte: DonyMascotteType.assis` |
| `test/core/widgets/dony_mascotte_test.dart` | Nouveau — tests widget enum + animated |

---

## Task 1 — pubspec.yaml : changer le dossier assets

**Fichiers :**
- Modifier : `pubspec.yaml`

- [ ] **Étape 1 : Mettre à jour la déclaration d'assets**

Dans `pubspec.yaml`, trouver la ligne (environ ligne 134) :
```yaml
    - assets/mascottes/
```
La remplacer par :
```yaml
    - assets/mascotte/
```

- [ ] **Étape 2 : Vérifier que les images existent**

```bash
ls /home/a-diakite/Desktop/MyProject/my_app/dony_app/assets/mascotte/
```
Résultat attendu : `joyeux.png  en_course.png  tenant_le_colis.png  donne_un_colis.png  assis.png  confiant.png  Scan.png  sécurisé.png`

- [ ] **Étape 3 : Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add pubspec.yaml
git commit -m "chore: switch mascotte assets folder to assets/mascotte/"
```

---

## Task 2 — dony_mascotte.dart : refactorer l'enum + créer DonyMascotteAnimated

**Fichiers :**
- Modifier : `lib/core/design/widgets/dony_mascotte.dart`

- [ ] **Étape 1 : Écrire le test en premier**

Créer `test/core/widgets/dony_mascotte_test.dart` :

```dart
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyMascotteType.assetPath', () {
    test('joyeux pointe vers le bon fichier', () {
      expect(DonyMascotteType.joyeux.assetPath, 'assets/mascotte/joyeux.png');
    });
    test('confiant pointe vers le bon fichier', () {
      expect(DonyMascotteType.confiant.assetPath, 'assets/mascotte/confiant.png');
    });
    test('securise pointe vers le bon fichier', () {
      expect(DonyMascotteType.securise.assetPath, 'assets/mascotte/sécurisé.png');
    });
    test('tenantColis pointe vers le bon fichier', () {
      expect(DonyMascotteType.tenantColis.assetPath, 'assets/mascotte/tenant_le_colis.png');
    });
    test('donneColis pointe vers le bon fichier', () {
      expect(DonyMascotteType.donneColis.assetPath, 'assets/mascotte/donne_un_colis.png');
    });
    test('enCourse pointe vers le bon fichier', () {
      expect(DonyMascotteType.enCourse.assetPath, 'assets/mascotte/en_course.png');
    });
    test('assis pointe vers le bon fichier', () {
      expect(DonyMascotteType.assis.assetPath, 'assets/mascotte/assis.png');
    });
    test('scan pointe vers le bon fichier', () {
      expect(DonyMascotteType.scan.assetPath, 'assets/mascotte/Scan.png');
    });
  });

  group('DonyMascotte widget', () {
    testWidgets('rend une Image.asset avec le bon chemin', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonyMascotte(type: DonyMascotteType.joyeux),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as AssetImage;
      expect(provider.assetName, 'assets/mascotte/joyeux.png');
    });

    testWidgets('taille customDimension override DonyMascotteSize', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonyMascotte(
              type: DonyMascotteType.assis,
              customDimension: 120,
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 120.0);
      expect(image.height, 120.0);
    });
  });

  group('DonyMascotteAnimated widget', () {
    testWidgets('rend un DonyMascotte enfant', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonyMascotteAnimated(type: DonyMascotteType.joyeux),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DonyMascotte), findsOneWidget);
    });

    testWidgets('DonyMascotteAnimated.scan rend un DonyMascotte', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonyMascotteAnimated(type: DonyMascotteType.scan),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DonyMascotte), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/core/widgets/dony_mascotte_test.dart
```
Résultat attendu : FAIL — types `joyeux`, `confiant`, etc. non définis + classe `DonyMascotteAnimated` inexistante.

- [ ] **Étape 3 : Réécrire dony_mascotte.dart**

Remplacer intégralement le contenu de `lib/core/design/widgets/dony_mascotte.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum DonyMascotteType {
  joyeux,
  confiant,
  securise,
  tenantColis,
  donneColis,
  enCourse,
  assis,
  scan;

  String get assetPath => switch (this) {
        joyeux      => 'assets/mascotte/joyeux.png',
        confiant    => 'assets/mascotte/confiant.png',
        securise    => 'assets/mascotte/sécurisé.png',
        tenantColis => 'assets/mascotte/tenant_le_colis.png',
        donneColis  => 'assets/mascotte/donne_un_colis.png',
        enCourse    => 'assets/mascotte/en_course.png',
        assis       => 'assets/mascotte/assis.png',
        scan        => 'assets/mascotte/Scan.png',
      };

  String get semanticLabel => switch (this) {
        joyeux      => 'Mascotte joyeuse',
        confiant    => 'Mascotte confiante',
        securise    => 'Colis sécurisé',
        tenantColis => 'Mascotte tenant un colis',
        donneColis  => 'Mascotte donnant un colis',
        enCourse    => 'Colis en transit',
        assis       => 'Mascotte assise',
        scan        => 'Mascotte scannant',
      };
}

enum DonyMascotteSize {
  sm(64),
  md(96),
  lg(160),
  xl(240);

  const DonyMascotteSize(this.dimension);
  final double dimension;
}

class DonyMascotte extends StatelessWidget {
  const DonyMascotte({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;
  final double? customDimension;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dim = customDimension ?? size.dimension;

    final image = Image.asset(
      type.assetPath,
      width: dim,
      height: dim,
      fit: fit,
      semanticLabel: type.semanticLabel,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// Wrapper animé style Alan — bonne animation au bon moment.
///
/// Presets par type :
/// - joyeux   : fadeIn + easeOutBack scale (entrée accueil)
/// - confiant : fadeIn + slideY + shimmer (validation étape)
/// - securise : fadeIn + easeOutBack scale + ambient glow optionnel (succès)
/// - tenantColis : fadeIn + slideY doux (sender flow)
/// - donneColis  : fadeIn + slideY depuis le haut (voyageur accepte)
/// - enCourse    : fadeIn + slideX depuis la gauche (en transit)
/// - assis       : fadeIn calm + scale (empty states)
/// - scan        : pulse repeat (scanning actif)
class DonyMascotteAnimated extends StatelessWidget {
  const DonyMascotteAnimated({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.withGlow = false,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;
  final double? customDimension;
  final BoxFit fit;

  /// Ajoute un orbe ambient derrière la mascotte (idéal sur les écrans de succès).
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = customDimension ?? size.dimension;

    final mascotte = DonyMascotte(
      type: type,
      size: size,
      customDimension: customDimension,
      fit: fit,
    );

    final animated = _animate(mascotte);

    if (!withGlow) return animated;

    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: dim * 1.5,
            height: dim * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cs.primary.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic),
          animated,
        ],
      ),
    );
  }

  Widget _animate(DonyMascotte mascotte) => switch (type) {
        DonyMascotteType.joyeux => mascotte
            .animate()
            .fadeIn(duration: 400.ms)
            .scaleXY(
              begin: 0.85,
              duration: 500.ms,
              curve: Curves.easeOutBack,
            ),
        DonyMascotteType.confiant => mascotte
            .animate()
            .fadeIn(duration: 250.ms)
            .slideY(
              begin: 0.06,
              duration: 350.ms,
              curve: Curves.easeOutCubic,
            )
            .shimmer(
              delay: 300.ms,
              duration: 600.ms,
              color: Colors.white24,
            ),
        DonyMascotteType.securise => mascotte
            .animate()
            .fadeIn(duration: 300.ms)
            .scaleXY(
              begin: 0.88,
              duration: 480.ms,
              curve: Curves.easeOutBack,
            ),
        DonyMascotteType.tenantColis => mascotte
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(
              begin: 0.08,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
        DonyMascotteType.donneColis => mascotte
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(
              begin: -0.06,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
        DonyMascotteType.enCourse => mascotte
            .animate()
            .fadeIn(duration: 250.ms)
            .slideX(
              begin: -0.10,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            ),
        DonyMascotteType.assis => mascotte
            .animate()
            .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
            .scaleXY(
              begin: 0.92,
              duration: 450.ms,
              curve: Curves.easeOutCubic,
            ),
        DonyMascotteType.scan => mascotte
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.97,
              end: 1.03,
              duration: 900.ms,
              curve: Curves.easeInOut,
            ),
      };
}
```

- [ ] **Étape 4 : Lancer les tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/core/widgets/dony_mascotte_test.dart
```
Résultat attendu : tous PASS.

- [ ] **Étape 5 : Commit**

```bash
git add lib/core/design/widgets/dony_mascotte.dart test/core/widgets/dony_mascotte_test.dart
git commit -m "feat: refactor DonyMascotteType vers 8 nouveaux assets + widget DonyMascotteAnimated"
```

---

## Task 3 — design_system.dart + CLAUDE.md : exporter le nouveau widget

**Fichiers :**
- Modifier : `lib/core/design/design_system.dart`
- Modifier : `lib/core/design/CLAUDE.md`

- [ ] **Étape 1 : Ajouter l'export dans design_system.dart**

Dans `lib/core/design/design_system.dart`, trouver la ligne :
```dart
export 'package:dony/core/design/widgets/dony_mascotte.dart';
```
La remplacer par (même ligne — `DonyMascotteAnimated` est dans le même fichier) :
```dart
export 'package:dony/core/design/widgets/dony_mascotte.dart';
```
*(Aucune modification nécessaire : `DonyMascotteAnimated` est défini dans le même fichier que `DonyMascotte`, donc déjà exporté.)*

Vérifier que `DonyMascotteAnimated` est bien accessible depuis le design system :
```bash
grep -n "DonyMascotteAnimated\|dony_mascotte" /home/a-diakite/Desktop/MyProject/my_app/dony_app/lib/core/design/design_system.dart
```

- [ ] **Étape 2 : Mettre à jour la table de mapping dans CLAUDE.md**

Dans `lib/core/design/CLAUDE.md`, trouver la section `### DonyMascotte` (vers ligne 254).

Remplacer tout le bloc mapping (`**Mapping des mascottes disponibles :**` jusqu'à la fin du tableau) par :

```markdown
**Mapping des mascottes disponibles :**

| Type | Fichier | Contextes recommandés |
|------|---------|----------------------|
| `joyeux` | `joyeux.png` | Onboarding, accueil, succès général |
| `confiant` | `confiant.png` | Scan intermédiaire, offre acceptée, étape validée |
| `securise` | `sécurisé.png` | Livraison finale, KYC validé, paiement réussi |
| `tenantColis` | `tenant_le_colis.png` | Création colis, parcours expéditeur |
| `donneColis` | `donne_un_colis.png` | Voyageur accepte une offre |
| `enCourse` | `en_course.png` | Colis en transit, suivi actif |
| `assis` | `assis.png` | **Tous les empty states** (aucun élément, erreur) |
| `scan` | `Scan.png` | Moment actif du scan QR |

**Utiliser `DonyMascotteAnimated` pour tout nouvel usage — bonne animation automatique selon le type :**

```dart
DonyMascotteAnimated(
  type: DonyMascotteType.securise,
  size: DonyMascotteSize.lg,
  withGlow: true,  // pour les écrans de succès plein écran
)
```

**Avec `DonyEmptyState` :**

```dart
DonyEmptyState(
  title: 'Aucun message',
  description: 'Vos conversations apparaîtront ici.',
  mascotte: DonyMascotteType.assis,
)
```

**Règles :**
- **Jamais** `Image.asset('assets/mascotte/...')` — toujours `DonyMascotte(type:)` ou `DonyMascotteAnimated(type:)`
- `DonyMascotteAnimated` pour les nouveaux usages (animations intégrées)
- `DonyMascotte` seul pour les cas statiques existants
- `withGlow: true` uniquement sur les écrans de confirmation plein écran (`size: xl` ou `lg` centré)
- Ne pas mettre `mascotte:` dans un `DonyEmptyState(type: loading)` (ignoré)
```

- [ ] **Étape 3 : Vérifier que flutter analyze passe**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/core/design/
```
Résultat attendu : No issues found.

- [ ] **Étape 4 : Commit**

```bash
git add lib/core/design/CLAUDE.md
git commit -m "docs: mettre à jour le mapping mascotte dans le design system"
```

---

## Task 4 — onboarding_screen.dart : mascotte animée style Alan

**Fichiers :**
- Modifier : `lib/features/auth/presentation/screens/onboarding_screen.dart`

- [ ] **Étape 1 : Remplacer DonyMascotte par DonyMascotteAnimated**

Dans `lib/features/auth/presentation/screens/onboarding_screen.dart`, trouver (lignes 47-54) :

```dart
                      DonyMascotte(
                        type: DonyMascotteType.salue,
                        size: DonyMascotteSize.lg,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scaleXY(begin: 0.85, duration: 500.ms, curve: Curves.easeOutBack),
```

Remplacer par :

```dart
                      DonyMascotteAnimated(
                        type: DonyMascotteType.joyeux,
                        size: DonyMascotteSize.lg,
                      ),
```

*(L'animation fadeIn+scaleXY+easeOutBack est intégrée dans le preset `joyeux` — pas besoin de la chaîner manuellement. Le `borderRadius` est retiré car le style est maintenant flottant libre.)*

- [ ] **Étape 2 : Vérifier flutter analyze**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/auth/presentation/screens/onboarding_screen.dart
```
Résultat attendu : No issues found.

- [ ] **Étape 3 : Commit**

```bash
git add lib/features/auth/presentation/screens/onboarding_screen.dart
git commit -m "feat: onboarding utilise DonyMascotteAnimated joyeux"
```

---

## Task 5 — qr_scanner_screen.dart : mettre à jour les types + mascotte scan

**Fichiers :**
- Modifier : `lib/features/tracking/presentation/screens/qr_scanner_screen.dart`

- [ ] **Étape 1 : Mettre à jour les types dans _showSuccessDialog**

Dans `lib/features/tracking/presentation/screens/qr_scanner_screen.dart`, trouver (lignes 461-477) :

```dart
    final mascotteType =
        isFinal ? DonyMascotteType.colisLivre : DonyMascotteType.pouceLeve;
    final title = isFinal ? 'Colis livré !' : 'Scan enregistré !';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyMascotte(
              type: mascotteType,
              size: DonyMascotteSize.lg,
            ),
```

Remplacer par :

```dart
    final mascotteType =
        isFinal ? DonyMascotteType.securise : DonyMascotteType.confiant;
    final title = isFinal ? 'Colis livré !' : 'Scan enregistré !';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.sheet)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyMascotteAnimated(
              type: mascotteType,
              size: DonyMascotteSize.lg,
              withGlow: isFinal,
            ),
```

- [ ] **Étape 2 : Vérifier flutter analyze**

```bash
flutter analyze lib/features/tracking/presentation/screens/qr_scanner_screen.dart
```
Résultat attendu : No issues found.

- [ ] **Étape 3 : Commit**

```bash
git add lib/features/tracking/presentation/screens/qr_scanner_screen.dart
git commit -m "feat: qr_scanner utilise securise/confiant + DonyMascotteAnimated"
```

---

## Task 6 — Empty states : ajouter mascotte assis (batch)

**Fichiers :**
- Modifier : 8 écrans (voir ci-dessous)

Pour chaque fichier ci-dessous, la modification est identique : trouver le `DonyEmptyState` sans `mascotte:` de type `empty` (pas `error`, pas `loading`) et ajouter `mascotte: DonyMascotteType.assis,`.

### 6a — conversation_list_screen.dart

Dans `lib/features/messaging/presentation/conversation_list_screen.dart`, trouver (ligne ~55) :
```dart
              return const DonyEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Aucun message',
                description: 'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
              );
```
Remplacer par :
```dart
              return const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Aucun message',
                description: 'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
              );
```
*(Retirer `icon:` quand `mascotte:` est présent — DonyEmptyState affiche l'un ou l'autre, pas les deux.)*

- [ ] Modifier `conversation_list_screen.dart`

### 6b — bid_list_screen.dart

Dans `lib/features/matching/presentation/screens/bid_list_screen.dart`, trouver (ligne ~375) :
```dart
      return DonyEmptyState(
        title: emptyTitle,
        description: emptyDescription,
        icon: emptyIcon,
      ).animate().fadeIn(duration: 300.ms);
```
Remplacer par :
```dart
      return DonyEmptyState(
        mascotte: DonyMascotteType.assis,
        title: emptyTitle,
        description: emptyDescription,
      ).animate().fadeIn(duration: 300.ms);
```

- [ ] Modifier `bid_list_screen.dart`

### 6c — notification_bottom_sheet.dart

Dans `lib/features/notifications/presentation/notification_bottom_sheet.dart`, trouver (ligne ~148) :
```dart
            return const DonyEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Aucune notification',
              description: 'Vos notifications apparaîtront ici.',
            );
```
Remplacer par :
```dart
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune notification',
              description: 'Vos notifications apparaîtront ici.',
            );
```

- [ ] Modifier `notification_bottom_sheet.dart`

### 6d — my_reviews_screen.dart

Dans `lib/features/ratings/presentation/screens/my_reviews_screen.dart`, trouver (lignes 51-56) :
```dart
    return const DonyEmptyState(
      icon: Icons.star_border_rounded,
      title: "Tu n'as pas encore reçu d'avis",
      description:
          'Les notes et commentaires laissés par les voyageurs apparaîtront ici.',
    );
```
Remplacer par :
```dart
    return const DonyEmptyState(
      mascotte: DonyMascotteType.assis,
      title: "Tu n'as pas encore reçu d'avis",
      description:
          'Les notes et commentaires laissés par les voyageurs apparaîtront ici.',
    );
```

- [ ] Modifier `my_reviews_screen.dart`

### 6e — favorite_travelers_screen.dart

Dans `lib/features/favorite_travelers/presentation/screens/favorite_travelers_screen.dart`, trouver (lignes 40-45) :
```dart
            return const DonyEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Aucun voyageur favori',
              description:
                  'Les voyageurs avec qui tu as envoyé apparaîtront ici. Re-contacte-les facilement !',
            );
```
Remplacer par :
```dart
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun voyageur favori',
              description:
                  'Les voyageurs avec qui tu as envoyé apparaîtront ici. Re-contacte-les facilement !',
            );
```

- [ ] Modifier `favorite_travelers_screen.dart`

### 6f — rematch_search_screen.dart

Dans `lib/features/cancellation/presentation/screens/rematch_search_screen.dart`, trouver (lignes 40-45) :
```dart
              const DonyEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun voyageur disponible',
                description:
                    'Aucun voyageur alternatif disponible dans les 72h sur ce corridor.',
              )
```
Remplacer par :
```dart
              const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Aucun voyageur disponible',
                description:
                    'Aucun voyageur alternatif disponible dans les 72h sur ce corridor.',
              )
```

- [ ] Modifier `rematch_search_screen.dart`

### 6g — recipients_screen.dart

Dans `lib/features/recipients/presentation/screens/recipients_screen.dart`, trouver (lignes 48-54) :
```dart
            return DonyEmptyState(
              icon: Icons.contacts_outlined,
              title: 'Aucun destinataire enregistré',
              description:
                  'Ajoute tes proches en Afrique pour envoyer en 1 tap.',
              actionLabel: 'Ajouter mon premier destinataire',
              onAction: () => context.push('/profile/recipients/new'),
```
Remplacer par :
```dart
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun destinataire enregistré',
              description:
                  'Ajoute tes proches en Afrique pour envoyer en 1 tap.',
              actionLabel: 'Ajouter mon premier destinataire',
              onAction: () => context.push('/profile/recipients/new'),
```

- [ ] Modifier `recipients_screen.dart`

### 6h — pickup_addresses_screen.dart

Dans `lib/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart`, trouver (lignes 48-54) :
```dart
            return DonyEmptyState(
              icon: Icons.location_on_outlined,
              title: 'Aucune adresse enregistrée',
              description:
                  'Ajoute ta première adresse de pickup pour accélérer tes prochaines demandes.',
              actionLabel: 'Ajouter ma première adresse',
              onAction: () => context.push('/profile/addresses/new'),
```
Remplacer par :
```dart
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune adresse enregistrée',
              description:
                  'Ajoute ta première adresse de pickup pour accélérer tes prochaines demandes.',
              actionLabel: 'Ajouter ma première adresse',
              onAction: () => context.push('/profile/addresses/new'),
```

- [ ] Modifier `pickup_addresses_screen.dart`

- [ ] **Étape finale batch : vérifier analyze + commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/messaging/ lib/features/matching/ lib/features/notifications/ lib/features/ratings/ lib/features/favorite_travelers/ lib/features/cancellation/ lib/features/recipients/ lib/features/pickup_addresses/
```
Résultat attendu : No issues found.

```bash
git add lib/features/messaging/presentation/conversation_list_screen.dart \
        lib/features/matching/presentation/screens/bid_list_screen.dart \
        lib/features/notifications/presentation/notification_bottom_sheet.dart \
        lib/features/ratings/presentation/screens/my_reviews_screen.dart \
        lib/features/favorite_travelers/presentation/screens/favorite_travelers_screen.dart \
        lib/features/cancellation/presentation/screens/rematch_search_screen.dart \
        lib/features/recipients/presentation/screens/recipients_screen.dart \
        lib/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart
git commit -m "feat: ajouter mascotte assis sur tous les empty states"
```

---

## Task 7 — Tests finaux + couverture

- [ ] **Étape 1 : Lancer tous les tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test --coverage
```
Résultat attendu : tous les tests passent.

- [ ] **Étape 2 : Vérifier la couverture**

```bash
genhtml coverage/lcov.info -o coverage/html
```
Vérifier que `lib/core/design/widgets/dony_mascotte.dart` est ≥ 90 % couvert.
Si inférieur, ajouter des tests pour les types manquants dans `test/core/widgets/dony_mascotte_test.dart` (copier le pattern du test `joyeux` en changeant le type).

- [ ] **Étape 3 : Analyze global**

```bash
flutter analyze lib/
```
Résultat attendu : No issues found.

- [ ] **Étape 4 : Commit final si des tests ont été ajoutés**

```bash
git add test/core/widgets/dony_mascotte_test.dart
git commit -m "test: compléter la couverture DonyMascotteAnimated"
```
