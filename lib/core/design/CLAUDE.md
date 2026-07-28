# Design System — dony

**Source de vérité:** `lib/core/design/` — toujours importer depuis ici.

```dart
import 'package:dony/core/design/design_system.dart';
```

---

## Tokens

### Couleurs — `DonyColors`

**Rôles sémantiques (à préférer dans tous les widgets) :**

| Token | Valeur | Usage |
|-------|--------|-------|
| `DonyColors.primary`       | `#0B5FFF` (blue500) | CTA, liens, focus, actifs ★ |
| `DonyColors.primaryHover`  | `#0A4DD9` (blue600) | Hover sur primary |
| `DonyColors.primaryPress`  | `#083CAB` (blue700) | Pressed/active |
| `DonyColors.primarySoft`   | `#EDF2FF` (blue50)  | Fond chips/badges actifs |
| `DonyColors.accent`        | `#D96A3A` (terra500) | Accent ★ — highlights chauds |
| `DonyColors.accentSoft`    | `#FCF0E9` (terra50) | Fond accent |
| `DonyColors.bgApp`         | `#FAFAF8` (neutral50) | Fond d'écran ★ |
| `DonyColors.surface`       | `#FFFFFF` | Cards, champs, AppBar |
| `DonyColors.surfaceWarm`   | `#F7F3ED` (sand100) | Sections communautaires |
| `DonyColors.textPrimary`   | `#0A2540` (ink800)  | Texte principal ★ |
| `DonyColors.textMuted`     | `#54504A` (neutral600) | Labels, sous-titres |
| `DonyColors.textSubtle`    | `#797367` (neutral500) | Hint, placeholders |
| `DonyColors.textOnBrand`   | `#FFFFFF` | Texte blanc sur fond bleu |
| `DonyColors.borderDefault` | `#E8E5DF` (neutral200) | Bordures cards/inputs |
| `DonyColors.borderFocus`   | `#0B5FFF` (blue500) | Bordure focus input |
| `DonyColors.success`       | `#0E8A5F` | Confirmations |
| `DonyColors.warning`       | `#E8A23B` | Avertissements |
| `DonyColors.error`         | `#D9342B` | Erreurs |
| `DonyColors.shadow`        | `#1A0A2540` | Ombre cards (ink800 @ 10%) |

**Palettes primitives (pour const contexts et dégradés) :**
`DonyColors.blue{50-900}`, `DonyColors.terra{50-900}`, `DonyColors.neutral{0-900}`, `DonyColors.sand{50-500}`, `DonyColors.ink{50-900}`

**Aliases legacy** (deprecated, seront supprimés en Phase 5) :
`green400 → blue500`, `grey200 → neutral200`, `bg → neutral50`, `white → neutral0`

### Espacement — `DonySpacing`

```dart
DonySpacing.xs   = 4    // gaps internes icon+text
DonySpacing.sm   = 8    // padding chip/badge
DonySpacing.md   = 12   // padding input vertical
DonySpacing.base = 16   // padding card, padding horizontal écran
DonySpacing.lg   = 20   // padding horizontal screens
DonySpacing.xl   = 24   // entre sections
DonySpacing.xxl  = 32   // entre grandes sections
DonySpacing.huge = 48   // espaces hero/onboarding
```

### Rayons — `DonyRadius`

```dart
DonyRadius.card  = 16  // cards ★
DonyRadius.lg    = 14  // boutons ★
DonyRadius.sheet = 24  // sheets/modals ★
DonyRadius.sm    = 8   // snackbars
DonyRadius.xl    = 20  // chips/pills
DonyRadius.md    = 12  // inputs
DonyRadius.full  = 999 // badges (pill)
```

---

## Couleurs en contexte `build()`

Dans tout widget avec `BuildContext`, utiliser le ColorScheme pour les couleurs sémantiques :

```dart
final cs = Theme.of(context).colorScheme;

cs.primary          // bleu #0B5FFF
cs.onPrimary        // texte sur primary (blanc)
cs.secondary        // terracotta #D96A3A
cs.surface          // fond card/page (blanc)
cs.onSurface        // texte principal (ink800)
cs.onSurfaceVariant // texte secondaire (neutral600)
cs.outline          // bordures (neutral200)
cs.error            // rouge erreur #D9342B
```

Pour les couleurs de statut (non Material) :

```dart
cs.success      // via extension DonyStatusColors
cs.warning
cs.info
cs.errorLight
```

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

---

## Typographie — `DonyTypography`

Le système typographique combine deux familles :
- **Hanken Grotesk** — display et headlines (titres, AppBar, hero)
- **Plus Jakarta Sans** — body et labels (corps, métadonnées, boutons)

```dart
// Display / Headlines → Hanken Grotesk
Theme.of(context).textTheme.displayLarge    // 32px w800 — splash, hero
Theme.of(context).textTheme.headlineLarge   // 22px w700 — titre section/AppBar
Theme.of(context).textTheme.headlineMedium  // 18px w700 — sous-titres

// Titres intermédiaires → Hanken Grotesk
Theme.of(context).textTheme.titleLarge      // 15px w700 — titre card, nom utilisateur
Theme.of(context).textTheme.titleMedium     // 14px w600 — métadonnées card

// Corps → Plus Jakarta Sans
Theme.of(context).textTheme.bodyLarge       // 16px w400 — texte principal
Theme.of(context).textTheme.bodyMedium      // 14px w400 — descriptions secondaires
Theme.of(context).textTheme.bodySmall       // 12px w400 — timestamps, notes

// Labels → Plus Jakarta Sans
Theme.of(context).textTheme.labelLarge      // 14px w700 — texte bouton
Theme.of(context).textTheme.labelMedium     // 11px w600 — badges, chips (uppercase)
Theme.of(context).textTheme.labelSmall      // 10px w600 — bottom nav, mini labels
```

### Accents cursifs — `DonyTypography.caveat()`

Pour les accents décoratifs (ex: slogans, textes manuscrits sur cartes hero) :

```dart
Text(
  'Envoyé avec soin',
  style: DonyTypography.caveat(fontSize: 18, color: DonyColors.terra500),
)
```

---

## Composants

### `DonyButton`

```dart
DonyButton(
  label: 'Envoyer un colis',
  onPressed: () {},
  variant: DonyButtonVariant.primary,   // primary | secondary | ghost | destructive
  icon: Icons.send,                     // optionnel
  isLoading: false,                     // optionnel
)
```

Hauteur fixe 52px (défini dans `AppTheme` via `FilledButton.styleFrom`). Toujours pleine largeur. Rayon : `DonyRadius.lg` (14).

### `DonyTextField`

```dart
DonyTextField(
  label: 'Email',
  hint: 'exemple@email.com',
  prefixIcon: Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
  onChanged: (v) {},
  validator: (v) => v!.isEmpty ? 'Requis' : null,
)
```

Rayon interne : `DonyRadius.md` (12).

### `DonyCard`

```dart
DonyCard(
  onTap: () {},          // optionnel — ajoute InkWell
  padding: EdgeInsets.all(DonySpacing.base),  // optionnel
  child: ...,
)
```

Rayon : `DonyRadius.card` (16). Élévation 0, bordure `DonyColors.grey200`.

### `DonyBadge`

```dart
DonyBadge(
  label: 'TRAJET',
  type: DonyBadgeType.info,    // info | success | warning | error
  icon: Icons.flight,          // optionnel
)
```

### `DonyAvatar`

```dart
DonyAvatar(
  name: 'Ibrahima Diallo',   // initiales extraites automatiquement
  imageUrl: user.photoUrl,   // optionnel
  size: DonyAvatarSize.md,   // sm=32 | md=44 | lg=56 | xl=72
  verified: false,           // optionnel — badge check vert
)
```

### `DonySnackbar`

```dart
DonySnackbar.show(
  context,
  message: 'Colis envoyé !',
  type: DonySnackbarType.success,  // info | success | warning | error
);
```

### `DonyMascotteAnimated` (à utiliser pour tout nouvel usage)

Widget animé avec presets flutter_animate par type. Chaque type a une animation d'entrée distincte (< 500 ms).

```dart
// Entrée standard
DonyMascotteAnimated(
  type: DonyMascotteType.joyeux,
  size: DonyMascotteSize.lg,   // sm=64 | md=96 | lg=160 | xl=240
)

// Succès avec halo ambient (écrans confirmation/KYC)
DonyMascotteAnimated(
  type: DonyMascotteType.securise,
  withGlow: true,
)
```

**Mapping des mascottes (assets/mascotte/) :**

La mascotte est une valise personnifiée. `confiant` et `enCourse` partagent
délibérément `travel.png` : c'est leur animation qui les distingue.

| Type | Asset | Animation | Usage recommandé |
|------|-------|-----------|------------------|
| `joyeux` | `hello.png` | scaleXY easeOutBack | Auth, accueil, parrainage |
| `bienvenue` | `welcome.png` | scaleXY easeOutBack | Onboarding, premier lancement |
| `confiant` | `travel.png` | slideY + shimmer | OTP / étapes de vérification |
| `securise` | `success.png` | scaleXY easeOutBack | PIN setup, escrow, KYC validé |
| `succes` | `success_celebration.png` | scaleXY easeOutBack ample | Succès terminal (`DonySuccessScreen`) |
| `enCourse` | `travel.png` | slideX | Tracking en transit |
| `assis` | `search.png` | fadeIn + scaleXY | `DonyEmptyState` vide (aucun contenu) |
| `aucunResultat` | `no_result.png` | fadeIn + scaleXY | Recherche ou filtres sans résultat |
| `attente` | `waiting.png` | respiration répétée | Vérification en cours, statut pending |
| `erreur` | `error.png` | fadeIn + slideX | Erreur sans issue (pas de bouton d'action) |
| `erreurLegere` | `error_light.png` | fadeIn + slideY | Erreur récupérable (« Réessayer ») |

**Choisir entre `erreur` et `erreurLegere` :** si l'écran propose une action de
reprise, prendre `erreurLegere` (ton léger) ; sinon `erreur` (ton inquiet).

**Choisir entre `assis` et `aucunResultat` :** `assis` pour « il n'y a rien
encore » (liste vierge, premier lancement) — son illustration est neutre et
curieuse, pas découragée. `aucunResultat` pour « ta recherche n'a rien donné »,
là où l'utilisateur a saisi des critères.

**Tout nouveau type doit avoir son propre asset.** Le test
`dony_mascotte_test.dart` échoue si un type pointe vers un fichier absent, et
aussi si un fichier du dossier n'est référencé par aucun type : un asset
embarqué mais inutilisé pèse dans l'APK sans jamais s'afficher.

**Animations en boucle :** `DonyMascotteType.loops` marque les types qui
respirent en continu (aujourd'hui `attente` seul). `DonyMascotteAnimated` les
isole derrière un `RepaintBoundary` et coupe la boucle quand la réduction du
mouvement est active — `Animate.defaultDuration`, que l'app pose globalement,
n'agit ni sur les durées explicites ni sur un `repeat()`.

### `DonyMascotte` (widget statique — usage restreint)

À utiliser uniquement quand l'animation est indésirable (ex: liste dense).

```dart
DonyMascotte(
  type: DonyMascotteType.assis,
  size: DonyMascotteSize.lg,
  borderRadius: BorderRadius.circular(DonyRadius.card),  // optionnel
)
```

**Avec `DonyEmptyState` :**

```dart
DonyEmptyState(
  title: 'Aucune livraison',
  description: 'Vos livraisons terminées apparaîtront ici.',
  type: DonyEmptyStateType.empty,
  mascotte: DonyMascotteType.assis,  // DonyMascotteAnimated automatique
)
```

**Règles :**
- **Jamais** `Image.asset('assets/mascotte/...')` — toujours `DonyMascotteAnimated(type:)` ou `DonyMascotte(type:)`
- **Préférer** `DonyMascotteAnimated` pour tout nouvel usage
- `DonyEmptyState(mascotte:)` utilise `DonyMascotteAnimated` automatiquement
- Ne pas mettre `mascotte:` dans un `DonyEmptyState(type: loading)` (la branche loading l'ignore)
- `withGlow: true` réservé aux écrans de succès / confirmation finale

---

## Règles obligatoires

1. **Jamais** de `Color(0xFF...)` hardcodé — toujours `DonyColors.X` ou `cs.X`
2. **Jamais** de `GoogleFonts.hankenGrotesk(...)` ou `GoogleFonts.plusJakartaSans(...)` direct dans les widgets — `Theme.of(context).textTheme.X`
3. **Jamais** de `EdgeInsets.all(16)` en dur — `EdgeInsets.all(DonySpacing.base)`
4. **Jamais** de `BorderRadius.circular(16)` en dur pour les cards — `BorderRadius.circular(DonyRadius.card)`
5. **Jamais** de `BorderRadius.circular(14)` en dur pour les boutons — `BorderRadius.circular(DonyRadius.lg)`
6. **Jamais** de `BorderRadius.circular(24)` en dur pour les sheets — `BorderRadius.circular(DonyRadius.sheet)`
7. **Toujours** `Theme.of(context).colorScheme` dans `build()` pour les couleurs sémantiques
8. `DonyColors.X` uniquement pour les contextes `const` ou les couleurs primitives non-sémantiques
9. `DonyTypography.caveat()` uniquement pour les accents cursifs décoratifs — jamais sur le corps du texte
10. **Jamais** `Image.asset('assets/mascottes/...')` direct — utiliser `DonyMascotte(type:)`

---

## Template écran secondaire

```dart
Scaffold(
  appBar: AppBar(
    title: Text('Titre'),  // style vient de textTheme.headlineLarge via AppTheme (Hanken Grotesk)
    centerTitle: false,
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
    ),
    child: Column(children: [...]),
  ),
)
```

## Template écran principal

```dart
Scaffold(
  body: CustomScrollView(slivers: [
    SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Titre'),  // Hanken Grotesk via textTheme
        expandedTitleScale: 1.5,
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
      ),
      sliver: SliverList(...),
    ),
  ]),
)
```
