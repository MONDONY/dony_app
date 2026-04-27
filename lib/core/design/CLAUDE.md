# Design System — dony

**Source de vérité:** `lib/core/design/` — toujours importer depuis ici.

```dart
import 'package:dony/core/design/design_system.dart';
```

---

## Tokens

### Couleurs — `DonyColors`

| Token | Valeur | Usage |
|-------|--------|-------|
| `DonyColors.green400` | `#1A6B3C` | Primary ★ — CTA, liens, actifs |
| `DonyColors.green300` | `#4CAF7D` | Primary dark mode / accent secondaire |
| `DonyColors.green50`  | `#E8F5EE` | Fond chips/badges actifs |
| `DonyColors.green600` | `#0E3D23` | Gradients, headers sombres |
| `DonyColors.terra500` | `#D96A3A` | Accent ★ — accents chauds, highlights |
| `DonyColors.terra300` | `#EA9468` | Accent dark mode |
| `DonyColors.terra50`  | `#FCF0E9` | Fond accent |
| `DonyColors.bg`       | `#F4F5F0` | Surface light / fond d'écran |
| `DonyColors.white`    | `#FFFFFF` | Cards, champs, appbar |
| `DonyColors.ink900`   | `#0D1B2A` | Texte primaire (titres, corps) |
| `DonyColors.grey400`  | `#6B7A8D` | Texte secondaire (labels, sous-titres) |
| `DonyColors.grey300`  | `#D2CDC2` | Texte hint / placeholders |
| `DonyColors.grey200`  | `#E9ECEF` | Bordures cards et inputs |
| `DonyColors.success`  | `#16A34A` | Confirmations |
| `DonyColors.warning`  | `#F59E0B` | Avertissements |
| `DonyColors.error`    | `#E53935` | Erreurs light mode |
| `DonyColors.shadow`   | `#1A0D1B2A` | Ombre cards (ink900 @ 10%) |

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

cs.primary          // vert #1A6B3C (light) / #4CAF7D (dark)
cs.onPrimary        // texte sur primary
cs.secondary        // terracotta #D96A3A (light) / #E8956A (dark)
cs.surface          // fond page
cs.onSurface        // texte principal
cs.onSurfaceVariant // texte secondaire
cs.outline          // bordures
cs.error            // rouge erreur
```

Pour les couleurs de statut (non Material) :

```dart
cs.success      // via extension DonyStatusColors
cs.warning
cs.info
cs.errorLight
```

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
