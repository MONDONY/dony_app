# Glassmorphism — Design dony app

**Date :** 2026-05-09
**Status :** Spec — en attente review utilisateur
**Spec 2/3** d'un chantier design system : dark mode → **glassmorphism** → mascottes
**Dépend de :** Spec 1 (dark mode foundations) — l'adaptatif glass lit `Theme.of(context).brightness` mis en place par la spec 1

---

## Contexte

L'utilisateur veut intégrer l'esthétique glassmorphism (fond translucide flouté + bordure fine) au design system dony de manière **cohérente et réutilisable**, pas en bidouillant chaque écran.

État actuel pertinent :
- Aucun token glass dans `lib/core/design/tokens/`
- `lib/app/main_shell.dart` lignes 120-127 contient déjà un blur **hardcodé** sur le bottom nav (`BackdropFilter(sigmaX: 24, sigmaY: 24)` + `Color(0xB8FFFFFF)`). Cette implémentation devra être migrée vers le widget standardisé.
- Tous les autres composants Dony* sont opaques.

Décisions cadrées avec l'utilisateur (questions/réponses précédentes) :
- Code dans `lib/core/design/` existant (cohérent avec le DS actuel)
- Approche : **variante via paramètre** sur composants existants (pas de duplication `DonyGlassCard`)
- Scope : 7 composants en une seule passe (`DonyCard`, `DonyAppBar`, `DonyBottomSheet`, `DonyDialog`, `DonyButton`, `DonyChip`, `DonyBottomNav`)
- `DonyButton.glass` = nouvelle valeur d'enum `DonyButtonVariant` (autonome, pas de combinaison avec primary/secondary/etc.)
- `DonyBottomNav` extrait depuis `main_shell.dart` en widget public
- Inclure : config Impeller + tests + golden tests + mise à jour `CLAUDE.md`

---

## Objectifs

1. Définir des tokens glass (blur, opacités, bordures, radius) cohérents avec les autres tokens du DS
2. Créer `DonyGlassContainer` — primitive réutilisable encapsulant `BackdropFilter + ClipRRect + Container`
3. Ajouter une variante / paramètre glass à 7 composants existants
4. Extraire `_DonyBottomNav` (actuellement privé dans `main_shell.dart`) en widget public `DonyBottomNav` et le faire passer par `DonyGlassContainer`
5. Adapter automatiquement light / dark via `Theme.of(context).brightness` (s'appuie sur spec 1)
6. Vérifier l'activation Impeller (Android) pour les performances
7. Documenter (`GLASSMORPHISM.md` + section dans `CLAUDE.md` du DS)
8. Tests + goldens light/dark

## Hors scope

- Mode dark fondations (spec 1)
- Mascottes (spec 3)
- Animations d'entrée glass (slide-in, fade-in personnalisés)
- Web target — `BackdropFilter` a des limitations sur web, on cible mobile (Android + iOS)
- Adaptation glass des écrans `features/*` qui n'utilisent pas les composants DS (au cas par cas plus tard)

---

## Architecture

### 1. Tokens glass — `lib/core/design/tokens/glass_tokens.dart` (nouveau)

```dart
import 'package:flutter/material.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';

/// Niveaux de flou recommandés pour BackdropFilter.
abstract final class DonyGlassBlur {
  static const double light  = 10;   // usage subtil (chips, petites surfaces)
  static const double medium = 15;   // défaut (cards, dialogs)
  static const double heavy  = 25;   // hero sections, full-screen overlays

  static const double maxAllowed = 50; // garde-fou — au-delà, perf et rendu hasardeux
}

/// Opacités glass selon le mode.
abstract final class DonyGlassOpacity {
  static const double bgLight  = 0.15; // fond glass en light mode
  static const double bgDark   = 0.10; // fond glass en dark mode
  static const double border   = 0.20; // bordure 1px
}

/// Rayons par défaut pour DonyGlassContainer.
abstract final class DonyGlassRadius {
  static const double base = 20;
}

/// Couleurs glass dérivées et brightness-aware.
extension DonyGlassColors on ColorScheme {
  Color get glassBackground => Colors.white.withValues(
        alpha: brightness == Brightness.light
            ? DonyGlassOpacity.bgLight
            : DonyGlassOpacity.bgDark,
      );

  Color get glassBorder => Colors.white.withValues(
        alpha: DonyGlassOpacity.border,
      );
}
```

### 2. Widget cœur — `lib/core/design/widgets/dony_glass_container.dart` (nouveau)

```dart
import 'dart:ui';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Conteneur glassmorphism standardisé dony.
///
/// Encapsule [BackdropFilter] + [ClipRRect] + fond/bordure semi-transparents,
/// avec adaptation automatique light/dark via [Theme.brightness].
///
/// Exemple — carte glass au-dessus d'un fond coloré :
/// ```dart
/// DonyGlassContainer(
///   padding: const EdgeInsets.all(DonySpacing.base),
///   child: Text('Hello, glass'),
/// )
/// ```
///
/// Exemple — surface plus floutée pour overlay hero :
/// ```dart
/// DonyGlassContainer(
///   sigmaX: DonyGlassBlur.heavy,
///   sigmaY: DonyGlassBlur.heavy,
///   borderRadius: 32,
///   child: ...,
/// )
/// ```
class DonyGlassContainer extends StatelessWidget {
  const DonyGlassContainer({
    super.key,
    required this.child,
    this.sigmaX = DonyGlassBlur.medium,
    this.sigmaY = DonyGlassBlur.medium,
    this.backgroundColor,
    this.borderColor,
    this.showBorder = true,
    this.borderRadius = DonyGlassRadius.base,
    this.padding,
    this.margin,
  })  : assert(sigmaX >= 0 && sigmaX <= DonyGlassBlur.maxAllowed,
            'sigmaX doit être dans [0, ${DonyGlassBlur.maxAllowed}]'),
        assert(sigmaY >= 0 && sigmaY <= DonyGlassBlur.maxAllowed,
            'sigmaY doit être dans [0, ${DonyGlassBlur.maxAllowed}]');

  final Widget child;
  final double sigmaX;
  final double sigmaY;
  /// Override du fond. Si null, utilise [DonyGlassColors.glassBackground].
  final Color? backgroundColor;
  /// Override de la bordure. Si null, utilise [DonyGlassColors.glassBorder].
  final Color? borderColor;
  final bool showBorder;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.glassBackground;
    final border = borderColor ?? cs.glassBorder;

    if (kDebugMode && (sigmaX > 25 || sigmaY > 25)) {
      debugPrint('[DonyGlassContainer] blur élevé (sigma > 25) — vérifier perf');
    }

    final core = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder ? Border.all(color: border, width: 1) : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    return margin != null ? Padding(padding: margin!, child: core) : core;
  }
}
```

**Points clés :**
- `ClipRRect` toujours présent (règle 1 du brief utilisateur — éviter débordements)
- `BackdropFilter` à l'intérieur du clip, sinon le flou déborde
- Border width fixe à 1px (règle 1 du brief)
- Adaptatif via `Theme.brightness`, override possible via `backgroundColor` / `borderColor`
- Assertions sur sigmas (règle 5 du brief)
- Warning debug si sigma > 25 (signal de perf)

### 3. Variantes sur composants existants

#### 3.1 `DonyCard` — `lib/core/design/widgets/dony_card.dart` (modifié)

```dart
enum DonyCardVariant { flat, glass }

class DonyCard extends StatelessWidget {
  const DonyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.variant = DonyCardVariant.flat,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final DonyCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(DonySpacing.base),
      child: child,
    );

    if (variant == DonyCardVariant.glass) {
      final glass = DonyGlassContainer(
        borderRadius: DonyRadius.card.toDouble(),
        padding: padding ?? const EdgeInsets.all(DonySpacing.base),
        child: child,
      );
      if (onTap == null) return glass;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onTap!(); },
          borderRadius: BorderRadius.circular(DonyRadius.card.toDouble()),
          child: glass,
        ),
      );
    }

    // ... variant.flat — comportement existant inchangé
  }
}
```

#### 3.2 `DonyAppBar` / `DonySliverAppBar` — `lib/core/design/widgets/dony_app_bar.dart` (modifié)

Ajout d'un paramètre `bool glass = false`. En mode glass :
- `backgroundColor: Colors.transparent` sur le `AppBar`
- `flexibleSpace: DonyGlassContainer(borderRadius: 0, showBorder: false, ...)` qui couvre toute la barre
- Bordure inférieure remplacée par une fine ligne `cs.outline.withValues(alpha: 0.3)` ou supprimée
- `extendBodyBehindAppBar: true` doit être activé sur le `Scaffold` parent (documenté dans usage)

#### 3.3 `DonyBottomSheet.show()` — `lib/core/design/widgets/dony_bottom_sheet.dart` (modifié)

Ajout d'un paramètre `bool glass = false`. En mode glass :
- `backgroundColor: Colors.transparent` (déjà le cas)
- Le `_DonyBottomSheetContent` est wrappé dans un `DonyGlassContainer` avec le radius `DonyRadius.sheet`
- Le shape Material du sheet est désactivé (pas de double background)

#### 3.4 `DonyDialog` — `lib/core/design/widgets/dony_dialog.dart` (modifié)

Ajout d'un paramètre `bool glass = false` à `DonyDialog.show()`. En mode glass :
- `Dialog.backgroundColor: Colors.transparent`
- Le contenu (`_DonyDialogWidget`) est wrappé dans `DonyGlassContainer(borderRadius: DonyRadius.xl)`
- La règle `cs.surface` du fond actuel (ligne 87) ne s'applique plus en glass

#### 3.5 `DonyButton` — `lib/core/design/widgets/dony_button.dart` (modifié)

Ajout d'une nouvelle valeur d'enum :

```dart
enum DonyButtonVariant { primary, secondary, ghost, destructive, glass }
```

Pour `DonyButtonVariant.glass` :
- Fond transparent
- `DonyGlassContainer` avec `borderRadius: DonyRadius.lg.toDouble()` (= 14)
- Texte `cs.onSurface` (haute opacité, lisibilité priorité)
- Pas d'élévation, ripple via `InkWell` à l'intérieur du clip
- Disabled state : `Opacity(0.5)` autour du tout

Le spinner color (ligne 46-51 du fichier actuel) gagne une branche : `glass => cs.primary`

#### 3.6 `DonyChip` — `lib/core/design/widgets/dony_chip.dart` (modifié)

Ajout d'un paramètre `bool glass = false`. En mode glass :
- Le fond du chip devient un `DonyGlassContainer` avec `borderRadius: DonyRadius.xl.toDouble()` (= 20, déjà le radius des chips)
- `sigmaX/Y: DonyGlassBlur.light` (10) — surface trop petite pour `medium`
- Selected/unselected modulé via `backgroundColor` override : `cs.primary.withValues(alpha: 0.25)` quand sélectionné

#### 3.7 `DonyBottomNav` — `lib/core/design/widgets/dony_bottom_nav.dart` (nouveau, extrait)

**Action :** déplacer `class _DonyBottomNav` (lignes 78-189 environ de `lib/app/main_shell.dart`) vers `lib/core/design/widgets/dony_bottom_nav.dart`, le rendre public (`class DonyBottomNav`), et :

1. Remplacer le blur hardcodé (`BackdropFilter` lignes 120-127 du fichier actuel) par un `DonyGlassContainer` :
   - `sigmaX/Y: DonyGlassBlur.heavy` (25, équivalent du 24 actuel)
   - `borderRadius: 0` (le nav touche les bords bas)
   - `showBorder: false` — la bordure top est gérée séparément
   - `backgroundColor` override possible si on veut garder une teinte spécifique
2. Ajouter un paramètre `bool glass = true` (par défaut true puisque l'effet existe déjà)
3. Si `glass: false`, fallback `Container(color: cs.surface)` pour les contextes où on ne veut pas le blur
4. La bordure top actuelle (`Border(top: BorderSide(...))`) devient adaptative via `cs.outline.withValues(alpha: ...)`
5. Le bug actuel : `Color(0xB8FFFFFF)` est hardcodé — en dark mode ça produit un fond blanc 72% sur fond noir, illisible. Ce bug est **résolu par la migration**.

`main_shell.dart` est mis à jour pour importer et utiliser `DonyBottomNav` à la place de `_DonyBottomNav`. Les widgets internes `_NavItem`, `_LiveBadge`, etc. dépendent de `AuthBloc` et `ActiveRoleCubit` — ils restent dans le fichier extrait (pas privatisés à `dony_bottom_nav.dart`) pour préserver l'encapsulation.

### 4. Configuration Impeller — `android/app/src/main/AndroidManifest.xml` (modifié)

Vérifier la présence de la meta-data Impeller. Depuis Flutter 3.10, Impeller est activé par défaut sur Android, mais on rend l'intention explicite :

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="true" />
```

À placer dans le `<application>`, après les meta-data Firebase existantes.

iOS : Impeller activé par défaut, aucune action.

### 5. Documentation

#### 5.1 `lib/core/design/GLASSMORPHISM.md` (nouveau)

Guide d'usage complet :

- **Quand utiliser** — sur fonds colorés, hero sections, overlays. **Pas** sur fond blanc plat (rendu insipide).
- **Quand éviter** — texte petit (<12px) sur surface très chargée (lisibilité), 3+ couches glass empilées (perf).
- **Patterns recommandés** :
  - 3 exemples : carte hero, AppBar transparent au-dessus d'image, bottom sheet glass sur fond coloré
- **Performance** — préférer `DonyGlassBlur.light` sur grandes surfaces (bottom nav full-width). Limiter à 2 couches glass simultanées. Vérifier le rendu sur device bas de gamme (RAM ≤ 4 Go).
- **Accessibilité** — texte sur glass doit rester contraste WCAG AA (4.5:1) ; tester sur fonds clairs ET sombres ; déconseiller glass sur fond multicolore avec petit texte.
- **Override couleurs** — quand utiliser `backgroundColor: cs.primary.withValues(alpha: 0.25)` pour un glass teinté.
- **Impeller** — note sur la dépendance, lien vers la doc Flutter.

#### 5.2 `lib/core/design/CLAUDE.md` (modifié)

Ajout d'une section **Glass** :
- Tableau de référence : composant → comment activer la variante glass
- Lien vers `GLASSMORPHISM.md` pour les détails
- Mise à jour de la liste des composants pour mentionner les variantes

### 6. Tests

Cible **≥ 90 %** sur les fichiers touchés.

#### 6.1 Widget tests — `DonyGlassContainer`

```dart
group('DonyGlassContainer', () {
  testWidgets('rend le child', (tester) async { /* ... */ });

  testWidgets('applique BackdropFilter avec sigma demandé', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonyGlassContainer(sigmaX: 20, sigmaY: 18, child: const Text('x')),
    ));
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect((filter.filter as ImageFilter).toString(), contains('20')); // approximatif
  });

  testWidgets('utilise opacité bgLight en mode light', (tester) async {/* ... */});
  testWidgets('utilise opacité bgDark en mode dark', (tester) async {/* ... */});

  test('assert sur sigma négatif ou >50', () {
    expect(() => DonyGlassContainer(sigmaX: -1, child: const SizedBox()),
        throwsAssertionError);
    expect(() => DonyGlassContainer(sigmaX: 60, child: const SizedBox()),
        throwsAssertionError);
  });

  testWidgets('respecte showBorder false', (tester) async { /* ... */ });
  testWidgets('respecte borderRadius custom', (tester) async { /* ... */ });
});
```

#### 6.2 Tests par variante

Pour chaque composant modifié (Card, AppBar, BottomSheet, Dialog, Button, Chip, BottomNav) :
- Test que la variante / le param glass instancie bien un `DonyGlassContainer`
- Test que l'API existante (variant flat, glass=false) reste inchangée — non-régression

#### 6.3 Golden tests light + dark

Pour chaque variante glass :
- Golden light : composant glass au-dessus d'un fond gradient bleu→terra
- Golden dark : même setup avec `theme: AppTheme.dark`

Fichiers : `test/core/design/widgets/golden/glass_card_light.png`, `glass_card_dark.png`, etc.

#### 6.4 Test extraction `DonyBottomNav`

- Test que `DonyBottomNav(glass: true)` rend bien le `DonyGlassContainer`
- Test que `DonyBottomNav(glass: false)` rend un `Container(color: cs.surface)`
- Test que `main_shell.dart` continue de fonctionner (test d'intégration smoke : navigation entre les tabs)

---

## Données / état

Aucun. Les variantes glass sont des paramètres de widget purs. Pas de stockage, pas de bloc.

---

## Risques

| Risque | Mitigation |
|---|---|
| Perf dégradée sur Android low-end avec plusieurs couches glass | Documenter limite 2 couches max, sigma `light` (10) sur grandes surfaces, tests manuels sur device cible |
| Lisibilité du texte sur glass insuffisante en dark | Tests goldens dark, vérification WCAG AA manuelle, doc explicite "ne pas utiliser sur fond multicolore avec petit texte" |
| Régression sur le bottom nav existant pendant l'extraction | Tests d'intégration smoke (navigation entre tabs avant/après), golden tests light + dark pour valider visuellement |
| Le `Color(0xB8FFFFFF)` actuel produit un bug en dark mode | C'est un bug que la migration corrige. Vérifier en dark après migration. |
| `BackdropFilter` ne capture pas le contenu en dessous si l'écran a `extendBody: false` | Documenter `extendBody: true` requis sur les Scaffolds qui hébergent un bottom nav glass |
| Web target avec `BackdropFilter` rend mal | Hors scope, mais ajouter une note dans `GLASSMORPHISM.md` |

---

## Plan d'exécution (à découper par writing-plans)

1. **Tokens glass** — créer `glass_tokens.dart`, étendre `ColorScheme` avec extension `DonyGlassColors`
2. **Widget cœur** — créer `dony_glass_container.dart` + tests unitaires + 2 goldens (light/dark)
3. **Variantes — batch A (simples)** : Card, Dialog, Chip
4. **Variantes — batch B (modaux)** : BottomSheet, AppBar
5. **Variantes — batch C (button)** : Button avec nouvelle valeur d'enum (changement plus invasif)
6. **Extraction BottomNav** — créer `dony_bottom_nav.dart` à partir de `main_shell.dart`, remplacer le BackdropFilter hardcodé par `DonyGlassContainer`, mettre à jour `main_shell.dart`
7. **Impeller** — vérifier / ajouter la meta-data dans `AndroidManifest.xml`
8. **Documentation** — créer `GLASSMORPHISM.md`, mettre à jour `CLAUDE.md` du DS
9. **Tests + goldens** — pour chaque variante, ajouter widget test + golden light + golden dark
10. **Vérification finale** — `flutter analyze`, `flutter test --coverage`, vérification visuelle manuelle de 3 écrans (un avec carte glass, un avec AppBar glass, l'écran main avec bottom nav)

---

## Critères d'acceptation

- [ ] `DonyGlassContainer` existe et expose les paramètres décrits (sigma, bg, border, radius, padding, margin, showBorder)
- [ ] Les 7 composants (`DonyCard`, `DonyAppBar`/`DonySliverAppBar`, `DonyBottomSheet`, `DonyDialog`, `DonyButton`, `DonyChip`, `DonyBottomNav`) ont leur variante / paramètre glass fonctionnels
- [ ] L'API existante (variantes/params actuels) **non modifiée** — tous les usages courants compilent sans changement
- [ ] `DonyBottomNav` extrait, `main_shell.dart` utilise le nouveau widget public, le blur hardcodé est supprimé
- [ ] Le bug de fond hardcodé `Color(0xB8FFFFFF)` du bottom nav est résolu (test goldens dark)
- [ ] Toutes les variantes glass s'adaptent au mode light / dark via `Theme.brightness`
- [ ] AndroidManifest contient la meta-data Impeller
- [ ] `GLASSMORPHISM.md` existe avec les 3 exemples d'usage demandés
- [ ] `lib/core/design/CLAUDE.md` contient une section Glass
- [ ] `flutter test --coverage` passe à 0 rouge avec couverture ≥ 90 % sur les fichiers touchés
- [ ] Goldens light + dark générés et validés pour chaque variante glass
- [ ] `flutter analyze` ne signale aucune nouvelle warning
- [ ] Vérification manuelle : 3 écrans représentatifs en light + dark fonctionnent et rendent correctement

---

## Décisions techniques notables

- **Variantes via paramètre, pas de duplication `DonyGlassCard`** — décision utilisateur, évite la maintenance double et garde une seule API par composant.
- **`DonyButton.glass` est une valeur d'enum, pas un paramètre orthogonal** — décision utilisateur. Évite l'explosion combinatoire (`primary + glass = ?` ambigu) et clarifie l'intention visuelle.
- **`DonyBottomNav` extrait en widget public** — cohérent avec les autres widgets DS, réutilisable hors `main_shell`. Au passage, la migration corrige le bug de fond hardcodé en dark mode.
- **Glass tokens dans un fichier séparé `glass_tokens.dart`** — assez de tokens spécifiques (blur, opacités, radius) pour mériter un fichier dédié. L'extension `DonyGlassColors` y vit aussi pour rester proche des constantes.
- **Pas de `backgroundColor` semantic dans les tokens** — on garde `Colors.white.withValues(alpha: ...)` car c'est l'approche universelle du glassmorphism (le flou capture les couleurs en dessous, le blanc/noir n'est qu'une teinte d'overlay).
- **Goldens activés** — les régressions visuelles glass sont quasi-impossibles à voir sans goldens (les diffs de blur et d'opacité sont subtils).
- **Warning debug si sigma > 25** — pas une assertion (légitime parfois), juste un signal pour le développeur.
- **Migration du blur hardcodé du bottom nav** — pas un nouveau feature mais une harmonisation. Important : on ne touche qu'au comment, pas au quoi (le bottom nav reste glass, juste via le widget standardisé).
