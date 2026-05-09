# Dark mode foundations — Design dony app

**Date :** 2026-05-09
**Status :** Spec — en attente review utilisateur
**Spec 1/3** d'un chantier design system : dark mode → glassmorphism → mascottes

---

## Contexte

L'application `dony_app` ne supporte actuellement que le thème light. `AppTheme` ne définit que `Brightness.light`, `MaterialApp` n'a pas de `darkTheme`, et le `ColorScheme.fromSeed` du fichier `lib/core/design/theme/app_theme.dart` ne couvre que le mode clair.

L'utilisateur veut un dark mode **complet et fonctionnel** :
- Switch automatique via `ThemeMode.system`
- Tous les widgets `Dony*` du design system rendent correctement en dark
- Aucune couleur hardcodée qui casse en dark mode

Cette spec est le **prérequis** des deux specs suivantes (glassmorphism, mascottes), puisque le glass adaptatif lit `Theme.of(context).brightness` et que les mascottes peuvent nécessiter un fond adapté au mode courant.

---

## Objectifs

1. Définir une palette dark cohérente avec l'identité dony (bleu primary, terracotta accent, neutrals chauds)
2. Implémenter `AppTheme.dark` complet (`ColorScheme.dark`, `textTheme`, surfaces, bordures, components themes)
3. Auditer les ~21 widgets `Dony*` et corriger ceux qui hardcodent des couleurs sémantiques (utiliser `Theme.of(context).colorScheme` à la place)
4. Garantir non-régression visuelle en light via golden tests light + dark
5. Documenter la règle de discipline pour les futurs widgets dans `CLAUDE.md`

## Hors scope (autres specs)

- Glassmorphism (spec 2) — seulement les tokens dark seront utilisés par le glass
- Mascottes (spec 3)
- UI de switch manuel light/dark dans les paramètres utilisateur — `ThemeMode.system` suffit pour le MVP
- Audit/correction des écrans `features/*` (ils utilisent déjà majoritairement `Theme.of`, le scope ici est limité au design system)

---

## Architecture

### 1. Palette dark — `lib/core/design/tokens/color_tokens.dart` (étendu)

Pas de fichier séparé : on étend `DonyColors` avec une section dark, et on rend les "rôles sémantiques" mode-agnostic via une nouvelle extension `DonyColorsContext` sur `BuildContext`.

#### Palette primitive dark (nouvelles constantes)

```dart
// ═══════════════════════════════════════════════════════════════
// DARK MODE — Palette dérivée
// ═══════════════════════════════════════════════════════════════

// Bleu primary recalibré (le #0B5FFF est trop saturé sur fond sombre)
static const blueDark500 = Color(0xFF4D8AFF);  // PRIMARY DARK ★
static const blueDark600 = Color(0xFF6699FF);  // Hover dark
static const blueDark700 = Color(0xFF3D7AEF);  // Press dark
static const blueDark50  = Color(0xFF1A2B47);  // PrimarySoft dark (fond chip actif)

// Terra accent recalibré
static const terraDark500 = Color(0xFFE8865B);  // ACCENT DARK ★
static const terraDark50  = Color(0xFF2E1F18);  // Fond accent dark

// Neutrals dark (chauds, cohérents avec sand)
static const neutralDark0   = Color(0xFF0A0E14);  // BG APP DARK ★
static const neutralDark50  = Color(0xFF11161E);
static const neutralDark100 = Color(0xFF161B23);  // SURFACE DARK ★
static const neutralDark200 = Color(0xFF222932);
static const neutralDark300 = Color(0xFF2D333D);  // BORDER DARK ★
static const neutralDark400 = Color(0xFF7E7972);  // text subtle dark
static const neutralDark500 = Color(0xFFB5AFA5);  // text muted dark
static const neutralDark600 = Color(0xFFD8D2C7);  // text high
static const neutralDark700 = Color(0xFFF5F0E8);  // TEXT PRIMARY DARK ★

// Sand dark (surfaces communautaires)
static const sandDark100 = Color(0xFF1F1A14);   // SURFACE WARM DARK ★

// États sémantiques dark (plus clairs pour contraste sur fond sombre)
static const successDark500 = Color(0xFF2DA677);
static const successDark50  = Color(0xFF0F2B1F);
static const warningDark500 = Color(0xFFF0B84A);
static const warningDark50  = Color(0xFF2B2014);
static const dangerDark500  = Color(0xFFEF5048);
static const dangerDark50   = Color(0xFF2B1715);
static const infoDark500    = Color(0xFF3FA0E5);
static const infoDark50     = Color(0xFF0F1F2D);

static const shadowDark = Color(0x66000000);  // black @ 40%
```

#### Shortcuts sémantiques restent `static const` (light)

Les shortcuts `DonyColors.primary`, `DonyColors.bgApp`, etc. restent inchangés et continuent de pointer sur les valeurs light. **Raison :** ils sont utilisés dans des contextes `const` (`const Color`) où on ne peut pas accéder à `BuildContext`. Les widgets passent par `Theme.of(context).colorScheme` pour l'adaptatif.

#### Extension brightness-aware sur `ColorScheme`

L'extension `DonyStatusColors` existante est étendue pour être **complètement** brightness-aware (actuellement seul `errorLight` l'est) :

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

### 2. `AppTheme.dark` — `lib/core/design/theme/app_theme.dart` (modifié)

```dart
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? DonyColors.primary : DonyColors.blueDark500,
      onPrimary: DonyColors.neutral0,
      primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
      onPrimaryContainer: isLight ? DonyColors.primary : DonyColors.blueDark500,
      secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
      onSecondary: DonyColors.neutral0,
      secondaryContainer: isLight ? DonyColors.accentSoft : DonyColors.terraDark50,
      onSecondaryContainer: isLight ? DonyColors.accent : DonyColors.terraDark500,
      surface: isLight ? DonyColors.surface : DonyColors.neutralDark100,
      onSurface: isLight ? DonyColors.textPrimary : DonyColors.neutralDark700,
      onSurfaceVariant: isLight ? DonyColors.textMuted : DonyColors.neutralDark500,
      outline: isLight ? DonyColors.borderDefault : DonyColors.neutralDark300,
      outlineVariant: isLight ? DonyColors.borderStrong : DonyColors.neutralDark200,
      error: isLight ? DonyColors.error : DonyColors.dangerDark500,
      onError: DonyColors.neutral0,
      shadow: isLight ? DonyColors.shadow : DonyColors.shadowDark,
      scrim: Colors.black54,
      inverseSurface: isLight ? DonyColors.ink800 : DonyColors.neutral0,
      onInverseSurface: isLight ? DonyColors.neutral0 : DonyColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? DonyColors.bgApp : DonyColors.neutralDark0,
      // ... le reste (textTheme, AppBarTheme, CardTheme, FilledButtonTheme, etc.)
      //     est dérivé de colorScheme et fonctionne en light + dark sans dupliquer
    );
  }
}
```

**Tous les `*Theme` (AppBar, Card, FilledButton, OutlinedButton, InputDecoration, Snackbar, Dialog, BottomSheet) sont rebâtis pour utiliser `colorScheme.X` au lieu de `DonyColors.X` hardcodé.**

### 3. Activation dans `MaterialApp` — `lib/app/app.dart` (modifié)

```dart
MaterialApp.router(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system,  // suit le réglage OS
  // ...
)
```

### 4. Audit + correction des widgets DS

#### Méthode

Pour chaque widget `lib/core/design/widgets/dony_*.dart`, identifier les usages de `DonyColors.X` qui sont **sémantiques** (texte, surface, bordure, primary, etc.) et les remplacer par `Theme.of(context).colorScheme.X` ou via l'extension `DonyStatusColors`.

Les usages **primitifs** (palette `DonyColors.blue500`, `DonyColors.terra500`, etc.) dans des contextes `const` ou pour des dégradés/illustrations restent autorisés.

#### Tableau d'audit (21 fichiers)

| Fichier | Occurrences | Sémantiques à migrer | Action |
|---|---|---|---|
| `dony_app_bar.dart` | 1 | À auditer | Remplacer par `cs.surface` |
| `dony_avatar.dart` | 10 | Élevé | Audit complet, extraire couleurs en `cs.*` |
| `dony_badge.dart` | 4 | Moyen | `cs.primaryContainer`, `cs.onSurface` |
| `dony_bottom_sheet.dart` | 4 | Moyen | `cs.surface`, `cs.onSurfaceVariant` |
| `dony_button.dart` | 6 | Moyen — variantes | Garder `DonyColors.white` pour `onPrimary` const, migrer le reste |
| `dony_checkbox.dart` | 3 | Faible | `cs.primary`, `cs.outline` |
| `dony_chip.dart` | 3 | Faible | `cs.primaryContainer`, `cs.outline` |
| `dony_dialog.dart` | 1 | Faible | `cs.surface` |
| `dony_empty_state.dart` | 8 | Élevé | Ligne 97 `DonyColors.neutral400` → `cs.onSurfaceVariant`, etc. |
| `dony_icon_container.dart` | 2 | Faible | À auditer |
| `dony_info_row.dart` | 6 | Moyen | Texte muted/subtle → `cs.onSurfaceVariant` |
| `dony_list_tile.dart` | 5 | Moyen | Surface, divider, leading icon |
| `dony_page_scaffold.dart` | 4 | Moyen | `cs.surface`, `scaffoldBackgroundColor` |
| `dony_radio_group.dart` | 8 | Élevé | Border, fill, label colors |
| `dony_search_field.dart` | 4 | Moyen | `cs.surfaceContainerHighest`, `cs.onSurfaceVariant` |
| `dony_section_header.dart` | 1 | Faible | `cs.onSurface` |
| `dony_snackbar.dart` | 2 | Faible | `cs.inverseSurface` |
| `dony_status_banner.dart` | 14 | Très élevé | Plus gros chantier — migrer toute la logique success/warning/error vers `DonyStatusColors` |
| `dony_step_indicator.dart` | 6 | Moyen | Active/inactive colors |
| `dony_text_field.dart` | * | Hérité InputDecorationTheme | À vérifier |
| `dony_trip_card.dart` | 9 | Élevé | Border, surface, accents |
| `dony_user_card.dart` | 4 | Moyen | Surface, divider |

**Stratégie :** un commit par fichier (ou par paquet de 3-4 fichiers du même domaine), pour faciliter le review.

### 5. Tests

Cible **≥ 90 %** sur les fichiers touchés (CLAUDE.md).

#### Widget tests dark — un par widget DS

```dart
testWidgets('DonyEmptyState rend correctement en dark', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(
      body: DonyEmptyState(title: 'Vide', description: '...'),
    ),
  ));

  // Vérifier que les couleurs viennent du ColorScheme dark, pas hardcodées
  final textWidget = tester.widget<Text>(find.text('Vide'));
  expect(textWidget.style?.color, isNot(DonyColors.textPrimary));
});
```

#### Golden tests light + dark

```dart
group('DonyCard goldens', () {
  testGoldens('light', (tester) async {
    await tester.pumpWidgetBuilder(
      const DonyCard(child: Text('Hello')),
      wrapper: materialAppWrapper(theme: AppTheme.light),
    );
    await screenMatchesGolden(tester, 'dony_card_light');
  });

  testGoldens('dark', (tester) async {
    await tester.pumpWidgetBuilder(
      const DonyCard(child: Text('Hello')),
      wrapper: materialAppWrapper(theme: AppTheme.dark),
    );
    await screenMatchesGolden(tester, 'dony_card_dark');
  });
});
```

#### Couverture des AppTheme

Test que `AppTheme.dark.brightness == Brightness.dark`, que `colorScheme.surface != AppTheme.light.colorScheme.surface`, etc.

### 6. Documentation

#### `lib/core/design/CLAUDE.md` (modifié)

Ajout d'une section **Dark mode** :
- Tokens dark disponibles
- Règle d'or : tout widget DS doit lire ses couleurs sémantiques via `Theme.of(context).colorScheme.X`, **jamais** `DonyColors.surface` ou `DonyColors.textPrimary` directement (ces tokens sont light-only)
- Quand utiliser `DonyColors.blue500` (primitif, mode-agnostic) vs `cs.primary` (sémantique, brightness-aware)
- Liste des extensions brightness-aware (`cs.success`, `cs.surfaceWarm`, etc.)

#### `lib/core/design/DARK_MODE.md` (nouveau)

Guide d'auteur de widget pour rester dark-aware :
- Checklist : 6 questions à se poser avant de hardcoder une couleur
- Exemples de patterns corrects vs incorrects
- Comment tester un widget en dark localement (snippet de wrapper de test)

---

## Données / état

Pas d'état à persister. `ThemeMode.system` lit le réglage OS automatiquement. Pas de bloc, pas de stockage.

Si plus tard l'utilisateur veut un switch manuel (force light / force dark / system), ce sera une feature à part — non bloquante, à brancher sur `ThemeMode` via un Cubit.

---

## Risques

| Risque | Mitigation |
|---|---|
| Régression visuelle en light après refacto des widgets DS | Golden tests light avant/après, exécutés en CI |
| Contraste insuffisant en dark sur certaines combinaisons | Vérification manuelle WCAG AA pour chaque pair (texte, fond) ; ajustement palette si <4.5:1 |
| Widget feature `lib/features/*` qui hardcode `DonyColors.surface` casse en dark | Hors scope (fait par specs futures), mais on `grep` une fois en fin de spec pour avoir un compte des occurrences à traiter plus tard |
| `flutter_animate` ou autre lib externe avec couleurs codées en dur | Probablement pas un souci (ils respectent le theme), à vérifier si problème observé |

---

## Plan d'exécution (à découper en plan d'implémentation par writing-plans)

1. **Tokens dark** — étendre `color_tokens.dart` avec la palette dark, étendre `DonyStatusColors` brightness-aware
2. **AppTheme.dark** — refactor `_build(brightness)`, ajout `darkTheme` dans `app.dart`, `themeMode: system`
3. **Audit DS — batch 1** : widgets simples (chip, checkbox, dialog, section_header, snackbar, icon_container, app_bar)
4. **Audit DS — batch 2** : widgets moyens (badge, bottom_sheet, info_row, list_tile, page_scaffold, search_field, step_indicator, user_card, button)
5. **Audit DS — batch 3** : widgets complexes (avatar, empty_state, radio_group, status_banner, trip_card, text_field)
6. **Tests** : widget tests dark + golden tests light/dark pour chaque widget DS modifié
7. **Documentation** : mise à jour `CLAUDE.md` + création `DARK_MODE.md`
8. **Vérification finale** : `flutter analyze`, `flutter test --coverage`, vérification couverture ≥ 90 %

---

## Critères d'acceptation

- [ ] `AppTheme.dark` existe et est utilisable
- [ ] L'app respecte le réglage dark/light du système (`ThemeMode.system`)
- [ ] Tous les widgets `lib/core/design/widgets/dony_*.dart` rendent correctement en dark (validé par golden tests)
- [ ] Aucun widget DS n'utilise `DonyColors.surface`, `DonyColors.textPrimary`, `DonyColors.bgApp`, `DonyColors.borderDefault` en dur (sauf justification documentée en commentaire)
- [ ] Extension `DonyStatusColors` est brightness-aware sur **tous** ses getters
- [ ] `flutter test --coverage` passe à 0 rouge avec couverture ≥ 90 % sur `lib/core/design/`
- [ ] `lib/core/design/CLAUDE.md` mis à jour, `DARK_MODE.md` créé
- [ ] `flutter analyze` ne signale aucune nouvelle warning
- [ ] Vérification visuelle manuelle : 5 écrans représentatifs (splash, onboarding, hub, profile, tracking timeline) ouverts en dark mode et OK

---

## Décisions techniques notables

- **Pas de fichier `dark_color_tokens.dart` séparé** — tout reste dans `color_tokens.dart` pour garder une seule source. Les constantes dark sont préfixées (`blueDark500`, `neutralDark0`, etc.) pour éviter les collisions.
- **Pas de variable `DonyColors.primaryDark` shortcut** — on accède au dark uniquement via `Theme.of(context).colorScheme`. Ça discipline les widgets et évite la tentation de bypasser le theme.
- **`ThemeMode.system` sans switch manuel** — décision pragmatique pour le MVP. Un switch manuel viendra dans une feature dédiée plus tard.
- **Audit batch par batch (pas un seul commit)** — chaque batch de 3-7 widgets fait l'objet d'un commit dédié pour faciliter review et bisect en cas de bug.
- **Goldens activés** — bien que coûteux à maintenir, ils sont la seule manière fiable de prévenir les régressions visuelles light après refacto.
