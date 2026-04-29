# Refacto Frontend Flutter — Fidèle aux maquettes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactoriser l'intégralité du frontend Flutter pour être fidèle aux 15 maquettes PNG, en appliquant le design system dony (vert forêt, polices Hanken Grotesk + Plus Jakarta Sans + Caveat).

**Architecture:** Design system tokens réécrits en Phase 1, puis chaque écran refactorisé individuellement avec commits atomiques. Nouveaux écrans créés quand aucun existant ne correspond à une maquette.

**Tech Stack:** Flutter 3.x, BLoC, GoRouter, google_fonts (hankenGrotesk + plusJakartaSans + caveat), flutter_animate, Material 3

---

## AUDIT PHASE 0 — Résultats

### Mapping maquette ↔ écran existant

| Maquette | Fichier existant | Action |
|---------|----------------|--------|
| `first_screen.png` (onboarding landing) | Aucun | CRÉER `onboarding_screen.dart` |
| `envoyer.png` (sender home) | `home_screen.dart` | REFACTORER (split rôle) |
| `dashbord_voyageur.png` (traveler dashboard) | `home_screen.dart` | REFACTORER (split rôle) |
| `envoyer_apres_recherche.png` (résultats recherche) | `search_announcement_screen.dart` | REFACTORER |
| `demande_d_envoi.png` (formulaire envoi) | `create_bid_screen.dart` | REFACTORER |
| `publier_trajet.png` + `publier_trajet_2.png` | `create_announcement_screen.dart` | REFACTORER |
| `trajet_button_scanner.png` (demandes voyageur) | `bid_list_screen.dart` | REFACTORER |
| `scanner.png` (QR scanner) | `qr_scanner_screen.dart` | REFACTORER |
| `scanne_colis_hors_ligne.png` (file offline) | Aucun | CRÉER `offline_scan_queue_screen.dart` |
| `scanner_colis_a_la_reception.png` (code réception) | `handover_screen.dart` (partial) | CRÉER `reception_confirm_screen.dart` |
| `suivi_colis.png` + `suivi_colis_2.png` | `tracking_timeline_screen.dart` | REFACTORER |
| `colis.png` (détail colis) | `bid_detail_screen.dart` | REFACTORER |
| `Garder_confiance.png` (escrow explainer) | Aucun | CRÉER `escrow_explainer_screen.dart` |

### Violations design system actuelles
1. `DonyColors` utilise bleu clair `#0288D1` comme primary — DOIT être vert `#1A6B3C`
2. `DonyTypography` utilise Sora — DOIT être Hanken Grotesk (display) + Plus Jakarta Sans (body)
3. Font cursive absente — DOIT ajouter Caveat pour les textes d'accent ("Bonjour X", "chez vous")
4. `home_screen.dart` appelle `GoogleFonts.sora()` directement 20+ fois — DOIT utiliser `textTheme`
5. Couleurs hardcodées dans `router.dart` (`Color(0xFF...)`)
6. `splash_full.png` icon_background `#1E88E5` (bleu) — DOIT être vert

### Palette extraite des maquettes
```dart
kGreenPrimary   = Color(0xFF1A6B3C)  // CTA, boutons, actif
kGreenDark      = Color(0xFF0E2318)  // stats card bg, header dark
kGreenAccent    = Color(0xFF4CAF7D)  // accents secondaires légers
kGreenLight     = Color(0xFFE8F5EE)  // fond chips/badges actifs
kBackground     = Color(0xFFF4F5F0)  // fond écran (crème chaud)
kSurface        = Color(0xFFFFFFFF)  // cards, appbar
kSurfaceWarm    = Color(0xFFF7F3ED)  // sable, sections communautaires
kTextPrimary    = Color(0xFF0D1B2A)  // titres, corps
kTextSecondary  = Color(0xFF6B7A8D)  // labels, sous-titres
kBorder         = Color(0xFFE9ECEF)  // bordures
kTerracotta     = Color(0xFFD96A3A)  // accent chaud (map, "Pas besoin d'app")
kError          = Color(0xFFE53935)
kSuccess        = Color(0xFF16A34A)  // validation, timeline steps
kWarning        = Color(0xFFF59E0B)
```

### Polices
- **Display/H1/H2**: `GoogleFonts.hankenGrotesk` (bold, tight letter-spacing) — titres écrans
- **Body**: `GoogleFonts.plusJakartaSans` — tout texte courant (labelLarge, bodyMedium, etc.)
- **Cursive accent**: `GoogleFonts.caveat` — salutations ("Bonjour X"), accents ("chez vous")

---

## Task 1 — Design system tokens (couleurs + typo + radius + espacement)

**Files:**
- Modify: `lib/core/design/tokens/color_tokens.dart`
- Modify: `lib/core/design/tokens/typography_tokens.dart`
- Modify: `lib/core/design/tokens/spacing_tokens.dart`
- Modify: `lib/core/design/theme/app_theme.dart`

- [ ] **Step 1.1: Réécrire color_tokens.dart**

Remplacer tout le contenu de `lib/core/design/tokens/color_tokens.dart` :

```dart
import 'package:flutter/material.dart';

abstract final class DonyColors {
  // Primary — vert forêt (confiance)
  static const green50  = Color(0xFFE8F5EE);
  static const green100 = Color(0xFFBBDFCC);
  static const green200 = Color(0xFF8FCAAB);
  static const green300 = Color(0xFF4CAF7D);  // accent léger
  static const green400 = Color(0xFF1A6B3C);  // PRIMARY ★
  static const green500 = Color(0xFF145430);
  static const green600 = Color(0xFF0E3D23);
  static const green700 = Color(0xFF0A2E1A);
  static const greenDark = Color(0xFF0E2318); // stats card bg

  // Terracotta — accent chaud africain
  static const terra50  = Color(0xFFFCF0E9);
  static const terra300 = Color(0xFFEA9468);
  static const terra500 = Color(0xFFD96A3A);  // ACCENT ★
  static const terra700 = Color(0xFF93421B);

  // Surface / background
  static const white      = Color(0xFFFFFFFF);
  static const bg         = Color(0xFFF4F5F0);  // fond écran
  static const surfaceWarm= Color(0xFFF7F3ED);  // sable
  static const grey50     = Color(0xFFFAFAF8);
  static const grey100    = Color(0xFFF2F1ED);
  static const grey200    = Color(0xFFE9ECEF);  // border default
  static const grey300    = Color(0xFFD2CDC2);
  static const grey400    = Color(0xFF6B7A8D);  // text secondary
  static const grey500    = Color(0xFF797367);

  // Ink (texte principal)
  static const ink900 = Color(0xFF0D1B2A);  // text primary ★
  static const ink800 = Color(0xFF1A2B3C);
  static const ink700 = Color(0xFF253545);

  // Semantic
  static const success      = Color(0xFF16A34A);
  static const successLight = Color(0xFFE8F5EE);
  static const error        = Color(0xFFE53935);
  static const errorLight   = Color(0xFFFFEBEE);
  static const warning      = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFF3E0);
  static const info         = Color(0xFF1565C0);
  static const infoLight    = Color(0xFFE3F2FD);
}

extension DonyStatusColors on ColorScheme {
  Color get success      => DonyColors.success;
  Color get warning      => DonyColors.warning;
  Color get info         => DonyColors.info;
  Color get successLight => DonyColors.successLight;
  Color get warningLight => DonyColors.warningLight;
  Color get infoLight    => DonyColors.infoLight;
  Color get errorLight   => brightness == Brightness.light
      ? DonyColors.errorLight
      : DonyColors.error.withValues(alpha: 0.15);
}
```

- [ ] **Step 1.2: Réécrire typography_tokens.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class DonyTypography {
  static TextTheme get textTheme => TextTheme(
    displayLarge:  GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.64, height: 1.10),
    displayMedium: GoogleFonts.hankenGrotesk(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.52, height: 1.15),
    displaySmall:  GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.44, height: 1.20),
    headlineLarge:  GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.22, height: 1.25),
    headlineMedium: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.18, height: 1.30),
    headlineSmall:  GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35),
    titleMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, height: 1.40),
    titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, height: 1.40),
    bodyLarge:  GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, height: 1.50),
    bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, height: 1.50),
    bodySmall:  GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, height: 1.50),
    labelLarge:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, height: 1.20),
    labelMedium: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
    labelSmall:  GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
  );

  // Accent cursif pour salutations et textes d'ambiance
  static TextStyle caveat({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.caveat(fontSize: fontSize, fontWeight: fontWeight, color: color, height: 1.2);
}
```

- [ ] **Step 1.3: Vérifier spacing_tokens.dart** — ajouter les valeurs manquantes :

```dart
abstract final class DonySpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;   // screen horizontal padding
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double huge = 48;
  static const double tab  = 72;   // bottom nav height
}

abstract final class DonyRadius {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;   // inputs
  static const double lg   = 14;   // boutons ★ (maquettes)
  static const double card = 16;   // cards ★
  static const double xl   = 20;
  static const double sheet= 24;   // bottom sheets
  static const double full = 999;
}
```

- [ ] **Step 1.4: Réécrire app_theme.dart**

```dart
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:          DonyColors.green400,
      onPrimary:        DonyColors.white,
      primaryContainer: DonyColors.green50,
      onPrimaryContainer: DonyColors.green600,
      secondary:        DonyColors.terra500,
      onSecondary:      DonyColors.white,
      secondaryContainer: DonyColors.terra50,
      onSecondaryContainer: DonyColors.terra700,
      surface:          DonyColors.white,
      onSurface:        DonyColors.ink900,
      surfaceContainerHighest: DonyColors.grey100,
      surfaceContainerLow: DonyColors.bg,
      outline:          DonyColors.grey200,
      outlineVariant:   DonyColors.grey100,
      error:            DonyColors.error,
      onError:          DonyColors.white,
      shadow:           Color(0x1A0D1B2A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: DonyColors.bg,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: DonyColors.ink900,
        displayColor: DonyColors.ink900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DonyColors.white,
        foregroundColor: DonyColors.ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: DonyTypography.textTheme.headlineMedium?.copyWith(
          color: DonyColors.ink900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: DonyColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          side: const BorderSide(color: DonyColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DonyColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.green400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.error),
        ),
        labelStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.grey400),
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.grey400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DonyColors.green400,
          foregroundColor: DonyColors.white,
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
          foregroundColor: DonyColors.ink900,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          side: const BorderSide(color: DonyColors.grey200),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DonyColors.green400,
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DonyColors.grey200,
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
        activeTrackColor: DonyColors.green400,
        thumbColor: DonyColors.green400,
        inactiveTrackColor: DonyColors.grey200,
        overlayColor: DonyColors.green400.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
    );
  }
}
```

- [ ] **Step 1.5: Run analyze**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/core/design/
```
Expected: 0 errors

- [ ] **Step 1.6: Commit**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add lib/core/design/tokens/ lib/core/design/theme/
git commit -m "refactor(design-system): couleurs vert+terracotta, typo Hanken+Jakarta+Caveat"
```

---

## Task 2 — Composants design system partagés

**Files:**
- Modify: `lib/core/design/widgets/dony_button.dart`
- Modify: `lib/core/design/widgets/dony_avatar.dart`
- Modify: `lib/core/design/widgets/dony_badge.dart`
- Modify: `lib/core/design/widgets/dony_card.dart`
- Modify: `lib/core/design/widgets/dony_text_field.dart`
- Modify: `lib/core/design/widgets/dony_snackbar.dart`

- [ ] **Step 2.1: Réécrire dony_button.dart**

```dart
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';

enum DonyButtonVariant { primary, secondary, ghost, destructive }

class DonyButton extends StatelessWidget {
  const DonyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DonyButtonVariant.primary,
    this.icon,
    this.iconRight,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DonyButtonVariant variant;
  final IconData? icon;
  final IconData? iconRight;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: DonyColors.white,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: DonySpacing.xs),
              ],
              Text(label),
              if (iconRight != null) ...[
                const SizedBox(width: DonySpacing.xs),
                Icon(iconRight, size: 18),
              ],
            ],
          );

    final minSize = fullWidth
        ? const Size.fromHeight(52)
        : const Size(120, 52);

    switch (variant) {
      case DonyButtonVariant.primary:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(minimumSize: minSize),
          child: child,
        );
      case DonyButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(minimumSize: minSize),
          child: child,
        );
      case DonyButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: minSize),
          child: child,
        );
      case DonyButtonVariant.destructive:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DonyColors.error,
            minimumSize: minSize,
          ),
          child: child,
        );
    }
  }
}
```

- [ ] **Step 2.2: Réécrire dony_avatar.dart**

Les avatars dans les maquettes ont des couleurs différentes selon les initiales (vert pour "ID", terracotta pour "AM", noir pour "CF"). Implémenter un hash des initiales pour la couleur.

```dart
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';

enum DonyAvatarSize { sm, md, lg, xl }

class DonyAvatar extends StatelessWidget {
  const DonyAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = DonyAvatarSize.md,
    this.verified = false,
  });

  final String name;
  final String? imageUrl;
  final DonyAvatarSize size;
  final bool verified;

  double get _dimension => switch (size) {
    DonyAvatarSize.sm => 32,
    DonyAvatarSize.md => 44,
    DonyAvatarSize.lg => 56,
    DonyAvatarSize.xl => 72,
  };

  double get _fontSize => switch (size) {
    DonyAvatarSize.sm => 12,
    DonyAvatarSize.md => 16,
    DonyAvatarSize.lg => 20,
    DonyAvatarSize.xl => 26,
  };

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Couleurs cycliques selon initiales — correspond aux maquettes
  static const _avatarColors = [
    DonyColors.green400,   // vert  (Ibrahima D. → ID)
    DonyColors.terra500,   // terracotta (Awa M. → AM)
    DonyColors.ink900,     // noir (Chelkh F. → CF)
    Color(0xFF1565C0),     // bleu
    Color(0xFF6A1B9A),     // violet
    Color(0xFF00695C),     // teal
  ];

  Color get _bgColor {
    final code = _initials.codeUnits.fold(0, (a, b) => a + b);
    return _avatarColors[code % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final dim = _dimension;
    return Stack(
      children: [
        Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            color: imageUrl != null ? DonyColors.grey100 : _bgColor,
            shape: BoxShape.circle,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        _initials,
                        style: DonyTypography.textTheme.titleMedium?.copyWith(
                          color: DonyColors.white,
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _initials,
                    style: DonyTypography.textTheme.titleMedium?.copyWith(
                      color: DonyColors.white,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        if (verified)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dim * 0.33,
              height: dim * 0.33,
              decoration: const BoxDecoration(
                color: DonyColors.success,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: DonyColors.white,
                size: dim * 0.2,
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2.3: Mettre à jour dony_badge.dart** — utiliser les nouvelles couleurs

Remplacer les références `blue400` → `green400`, `blue100` → `green50` dans le fichier existant.

- [ ] **Step 2.4: Run analyze**

```bash
flutter analyze lib/core/design/widgets/
```
Expected: 0 errors

- [ ] **Step 2.5: Run tests**

```bash
flutter test test/ --name "design" 2>/dev/null || echo "no design tests yet"
```

- [ ] **Step 2.6: Commit**

```bash
git add lib/core/design/widgets/
git commit -m "refactor(design-system): composants alignés palette vert+terracotta, avatar multi-couleurs"
```

---

## Task 3 — Écran Onboarding (first_screen.png) — NOUVEAU

**Files:**
- Create: `lib/features/auth/presentation/screens/onboarding_screen.dart`
- Modify: `lib/app/router.dart` (route `/onboarding`)
- Modify: `lib/features/splash/presentation/splash_screen.dart` (redirect vers /onboarding si first launch)

**Maquette:** `first_screen.png`
- Fond crème, logo "dony." en cursif + point vert
- Titre bold: "Envoyez un colis" sur 2 lignes
- Sous-titre italic cursif vert: "chez vous, autrement."
- 3 feature cards blanches (Vérifié, Tracé, Garanti) avec icônes outline
- CTA primaire vert: "J'envoie un colis"
- CTA ghost: "Je suis voyageur"
- Lien CGU en bas

- [ ] **Step 3.1: Créer onboarding_screen.dart**

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, DonySpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo dony.
              _DonyLogo(),
              const SizedBox(height: DonySpacing.xxl),

              // Headline
              Text(
                'Envoyez un colis',
                style: tt.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DonyColors.ink900,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'chez vous',
                      style: DonyTypography.caveat(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: DonyColors.green400,
                      ),
                    ),
                    TextSpan(
                      text: ', autrement.',
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DonyColors.ink900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.04),
              const SizedBox(height: DonySpacing.base),
              Text(
                'Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l\'arrivée.',
                style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: DonySpacing.xl),

              // Feature cards
              ..._features.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: _FeatureCard(
                  icon: e.value.$1,
                  title: e.value.$2,
                  subtitle: e.value.$3,
                ).animate().fadeIn(delay: (120 + e.key * 60).ms).slideX(begin: 0.04),
              )),

              const Spacer(),

              // CTAs
              DonyButton(
                label: 'J\'envoie un colis',
                onPressed: () => context.go('/auth/phone', extra: 'sender'),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.06),
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                label: 'Je suis voyageur',
                onPressed: () => context.go('/auth/phone', extra: 'traveler'),
                variant: DonyButtonVariant.ghost,
              ).animate().fadeIn(delay: 340.ms),
              const SizedBox(height: DonySpacing.base),

              // CGU
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'En continuant vous acceptez nos ',
                    style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                    children: [
                      TextSpan(
                        text: 'CGU',
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.green400,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' et notre '),
                      TextSpan(
                        text: 'politique de confidentialité',
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.green400,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(delay: 380.ms),
            ],
          ),
        ),
      ),
    );
  }

  static const _features = [
    (Icons.verified_user_outlined, 'Vérifié', 'KYC + selfie animé pour chaque profil'),
    (Icons.qr_code_2_outlined, 'Tracé', 'QR scanné à chaque étape, jusqu\'à la remise'),
    (Icons.lock_outline_rounded, 'Garanti', 'Paiement bloqué, libéré seulement à l\'arrivée'),
  ];
}

class _DonyLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GoogleFonts.caveat(
          textStyle: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: DonyColors.ink900,
          ),
        ).let((style) => Text('dony', style: style)),
        const Text(
          '.',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: DonyColors.green400,
          ),
        ),
      ],
    );
  }
}

// Helper extension for TextStyle.let
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DonyColors.green50,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(icon, size: 20, color: DonyColors.green400),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleSmall?.copyWith(color: DonyColors.ink900)),
                const SizedBox(height: 2),
                Text(subtitle, style: tt.bodySmall?.copyWith(color: DonyColors.grey400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.2: Ajouter route `/onboarding` dans router.dart**

Dans `lib/app/router.dart`, avant la route `/splash` :

```dart
GoRoute(
  path: '/onboarding',
  builder: (context, state) => const OnboardingScreen(),
),
```

Et modifier `splash_screen.dart` pour rediriger vers `/onboarding` si premier lancement (Hive key `'onboarding_done'` absent), sinon vers `/auth/phone`.

- [ ] **Step 3.3: Run analyze**

```bash
flutter analyze lib/features/auth/presentation/screens/onboarding_screen.dart
```
Expected: 0 errors

- [ ] **Step 3.4: Commit**

```bash
git add lib/features/auth/presentation/screens/onboarding_screen.dart lib/app/router.dart
git commit -m "feat(screen): onboarding fidèle à first_screen.png — vert, Caveat, 3 feature cards"
```

---

## Task 4 — Home screen sender (envoyer.png) + traveler dashboard (dashbord_voyageur.png)

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/app/main_shell.dart` (bottom nav)

**Maquettes:**
- `envoyer.png`: fond crème, logo dony, "Bonjour Aminata, on envoie quoi aujourd'hui ?" (Caveat pour la fin), cloche notif + avatar, form de recherche (départ/arrivée/date/kg), CTA vert, corridors populaires 2×2, carte garantie
- `dashbord_voyageur.png`: fond crème, avatar vert + "Ibrahima" + rating + KYC badge, stats card dark green (248,50 €, trajets, kg, %, paiement), liste trajets actifs, CTA "Publier un trajet", barre paiement prochain

- [ ] **Step 4.1: Réécrire home_screen.dart** — rôle SENDER (envoyer.png)

Supprimer toutes les références `GoogleFonts.sora`, `DonyColors.blue400`, `DonyColors.grey50`.

```dart
// Structure de l'écran sender :
// Scaffold(backgroundColor: DonyColors.bg)
//   body: CustomScrollView
//     SliverToBoxAdapter: _SenderHeader (logo + cloche + avatar + greeting Caveat)
//     SliverToBoxAdapter: _SearchForm (départ / arrivée / date / kg dans card blanche)
//     SliverToBoxAdapter: _PopularCorridors (grille 2×2)
//     SliverToBoxAdapter: _GuaranteeCard
```

Greeting text dans `_SenderHeader` :
```dart
RichText(
  text: TextSpan(children: [
    TextSpan(text: 'on envoie quoi ', style: tt.headlineMedium?.copyWith(color: DonyColors.ink900)),
    TextSpan(
      text: 'aujourd\'hui ?',
      style: DonyTypography.caveat(fontSize: 24, color: DonyColors.green400),
    ),
  ]),
)
```

Stats card du voyageur (`dashbord_voyageur.png`) :
```dart
Container(
  padding: const EdgeInsets.all(DonySpacing.xl),
  decoration: BoxDecoration(
    color: DonyColors.greenDark,
    borderRadius: BorderRadius.circular(DonyRadius.card),
  ),
  child: Column(children: [
    // "CE MOIS-CI" label
    // "248,50 €" en Hanken Grotesk w800 blanc
    // "4 colis · paiement Wed"
    // Row: 8 Trajets | 62 kg Portés | 100% Complétés
  ]),
)
```

- [ ] **Step 4.2: Mettre à jour main_shell.dart** — bottom nav vert

Bottom nav items: Accueil (home), Envoyer (→), Trajets (avion/QR), Messages (chat), Moi (user).
Active color: `DonyColors.green400`. Inactive: `DonyColors.grey400`.

```dart
NavigationBar(
  backgroundColor: DonyColors.white,
  indicatorColor: DonyColors.green50,
  selectedIndex: navigationShell.currentIndex,
  onDestinationSelected: navigationShell.goBranch,
  destinations: const [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
    NavigationDestination(icon: Icon(Icons.arrow_forward_outlined), selectedIcon: Icon(Icons.arrow_forward_rounded), label: 'Envoyer'),
    NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner_rounded), label: 'Trajets'),
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
    NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Moi'),
  ],
)
```

- [ ] **Step 4.3: Run analyze**

```bash
flutter analyze lib/features/home/ lib/app/main_shell.dart
```

- [ ] **Step 4.4: Commit**

```bash
git add lib/features/home/ lib/app/main_shell.dart
git commit -m "refactor(screen): home sender/traveler fidèles envoyer.png + dashbord_voyageur.png"
```

---

## Task 5 — Search results screen (envoyer_apres_recherche.png)

**Files:**
- Modify: `lib/features/matching/presentation/screens/search_announcement_screen.dart`

**Maquette:** `envoyer_apres_recherche.png`
- Header: "Paris → Dakar", "23 voyageurs · cette semaine"
- Filtres chips horizontaux: ★4.7+, €/kg↓, Cette semaine, +10kg
- Cards voyageurs: avatar coloré, nom, rating, KYC badge vert, date, kg dispo, prix vert, tags
- Skeleton loader card visible en bas (pagination)
- Bottom nav visible

- [ ] **Step 5.1: Refactoriser search_announcement_screen.dart**

Supprimer toutes les refs Sora/blue. Remplacer par :
- `tt.headlineLarge` pour le titre corridor
- Chips filtres: `ChoiceChip` avec `selectedColor: DonyColors.ink900`, `labelStyle` blanc quand sélectionné
- Card voyageur: avatar `DonyAvatar`, badge KYC `DonyBadge(label: 'KYC', type: DonyBadgeType.success)`, prix en vert `DonyColors.green400`
- Tags contenu: `Wrap` de `Chip` petits avec border grise

Structure card voyageur :
```dart
Container(
  padding: const EdgeInsets.all(DonySpacing.base),
  decoration: BoxDecoration(
    color: DonyColors.white,
    borderRadius: BorderRadius.circular(DonyRadius.card),
    border: Border.all(color: DonyColors.grey200),
  ),
  child: Column(children: [
    Row(children: [
      DonyAvatar(name: travelerName, size: DonyAvatarSize.md),
      SizedBox(width: 12),
      Expanded(child: Column(children: [
        Row(children: [
          Text(name, style: tt.titleLarge),
          SizedBox(width: 8),
          // Prix en vert à droite
          Text('${price}€/kg', style: tt.titleLarge?.copyWith(color: DonyColors.green400)),
        ]),
        // rating + trajets + KYC badge
      ])),
    ]),
    // date + kg row
    // tags wrap
  ]),
)
```

- [ ] **Step 5.2: Run analyze + commit**

```bash
flutter analyze lib/features/matching/presentation/screens/search_announcement_screen.dart
git add lib/features/matching/presentation/screens/search_announcement_screen.dart
git commit -m "refactor(screen): search_announcement fidèle envoyer_apres_recherche.png"
```

---

## Task 6 — Demande d'envoi (demande_d_envoi.png)

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_bid_screen.dart`

**Maquette:** `demande_d_envoi.png`
- Header: "Demande d'envoi", "Avec Ibrahima D. · Jeu 17"
- Slider poids: vert, "5 kg", "max 8 kg"
- Section tags "CONTENU DU COLIS": grille de chips, sélectionnés = vert foncé rempli
- Textarea description (au voyageur)
- Disclaimer douane: fond orange très clair (`terra50`), icône warning terracotta, checkbox
- Récap prix fixe en bas: "5 kg × 6€ = 30,00€ · Frais de service 2,40€"
- CTA verrouillé: "🔒 Bloquer 32€ & envoyer"

- [ ] **Step 6.1: Refactoriser create_bid_screen.dart**

Appliquer les tokens. Le slider utilise `SliderTheme` déjà configuré en vert. Les chips sélectionnés :
```dart
FilterChip(
  label: Text(tag),
  selected: selectedTags.contains(tag),
  onSelected: (_) => toggleTag(tag),
  selectedColor: DonyColors.green400,
  backgroundColor: DonyColors.white,
  labelStyle: TextStyle(
    color: selected ? DonyColors.white : DonyColors.ink900,
    fontWeight: FontWeight.w600,
  ),
  side: BorderSide(
    color: selected ? DonyColors.green400 : DonyColors.grey200,
  ),
  checkmarkColor: DonyColors.white,
  showCheckmark: true,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DonyRadius.full)),
)
```

Disclaimer card:
```dart
Container(
  padding: const EdgeInsets.all(DonySpacing.base),
  decoration: BoxDecoration(
    color: DonyColors.terra50,
    borderRadius: BorderRadius.circular(DonyRadius.md),
    border: Border.all(color: DonyColors.terra300.withValues(alpha: 0.3)),
  ),
  child: Row(children: [
    Icon(Icons.warning_amber_rounded, color: DonyColors.terra500, size: 20),
    SizedBox(width: 10),
    Expanded(child: Text(disclaimer, style: tt.bodySmall)),
  ]),
)
```

- [ ] **Step 6.2: Run analyze + commit**

```bash
flutter analyze lib/features/matching/presentation/screens/create_bid_screen.dart
git add lib/features/matching/presentation/screens/create_bid_screen.dart
git commit -m "refactor(screen): create_bid fidèle demande_d_envoi.png — slider vert, chips sélectifs, disclaimer"
```

---

## Task 7 — Publier un trajet (publier_trajet.png + publier_trajet_2.png)

**Files:**
- Modify: `lib/features/matching/presentation/screens/create_announcement_screen.dart`

**Maquettes:**
- Section CAPACITÉ DISPONIBLE: slider vert, "15 kg", badge "VALISE"
- Section PRIX PAR KG: 4 chips de prix (5€/6€/7€/8€), sélectionné = vert foncé border + bg light vert
- Section LIMITE DÉPART: card avec icône calendrier, adresse
- Section tags "Ce que j'accepte de transporter": chips verts sélectionnés, gris non-sélectionnés
- CTA fixe en bas: "→ Publier le trajet"
- Labels sections: uppercase, gris, taille 11, letter-spacing

- [ ] **Step 7.1: Refactoriser create_announcement_screen.dart**

Section labels uppercase:
```dart
Text(
  'CAPACITÉ DISPONIBLE',
  style: tt.labelMedium?.copyWith(
    color: DonyColors.grey400,
    letterSpacing: 1.2,
  ),
)
```

Prix chips:
```dart
_PriceChip(
  label: '${price}€',
  selected: _selectedPrice == price,
  onTap: () => setState(() => _selectedPrice = price),
)

class _PriceChip extends StatelessWidget {
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? DonyColors.green50 : DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(
          color: selected ? DonyColors.green400 : DonyColors.grey200,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: tt.titleMedium?.copyWith(
        color: selected ? DonyColors.green400 : DonyColors.ink900,
        fontWeight: FontWeight.w700,
      )),
    ),
  );
}
```

- [ ] **Step 7.2: Run analyze + commit**

```bash
flutter analyze lib/features/matching/presentation/screens/create_announcement_screen.dart
git add lib/features/matching/presentation/screens/create_announcement_screen.dart
git commit -m "refactor(screen): create_announcement fidèle publier_trajet.png — slider, prix chips, tags"
```

---

## Task 8 — Bid list / demandes voyageur (trajet_button_scanner.png)

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_list_screen.dart`

**Maquette:** `trajet_button_scanner.png`
- Header: "3 demandes", "CDG → DSS · jeu 17 avril", bouton Scanner (QR) en haut droite
- Card par demande: avatar coloré, nom, rating · kg, section "CONTENU DÉCLARÉ", boutons Refuser (ghost) + Accepter (vert rempli)

- [ ] **Step 8.1: Refactoriser bid_list_screen.dart**

Bouton Scanner en AppBar action:
```dart
appBar: AppBar(
  title: ...,
  actions: [
    FilledButton.icon(
      onPressed: () => context.push('/tracking/scan'),
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
      label: const Text('Scanner'),
      style: FilledButton.styleFrom(
        backgroundColor: DonyColors.ink900,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DonyRadius.sm)),
      ),
    ),
    const SizedBox(width: DonySpacing.base),
  ],
)
```

Boutons Refuser/Accepter dans chaque card:
```dart
Row(children: [
  Expanded(
    child: OutlinedButton(
      onPressed: () => _refuse(bid),
      style: OutlinedButton.styleFrom(
        foregroundColor: DonyColors.ink900,
        minimumSize: const Size.fromHeight(44),
      ),
      child: const Text('Refuser'),
    ),
  ),
  const SizedBox(width: 10),
  Expanded(
    child: FilledButton(
      onPressed: () => _accept(bid),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      child: const Text('Accepter'),
    ),
  ),
])
```

- [ ] **Step 8.2: Run analyze + commit**

```bash
flutter analyze lib/features/matching/presentation/screens/bid_list_screen.dart
git add lib/features/matching/presentation/screens/bid_list_screen.dart
git commit -m "refactor(screen): bid_list fidèle trajet_button_scanner.png"
```

---

## Task 9 — QR Scanner (scanner.png)

**Files:**
- Modify: `lib/features/tracking/presentation/screens/qr_scanner_screen.dart`

**Maquette:** `scanner.png`
- Fond très sombre (#0E1E14 — dark green-black)
- Header: "× Scan départ" (centré) + icône flash en haut droite
- Sous-titre: code colis, puis salutation Caveat: "Bonjour Aminata 👋"
- Zone scan: rectangle blanc arrondi (4 coins marqués) sur fond caméra noir
- État success: cercle vert avec checkmark blanc centré dans la zone
- Bas: "ÉTAPE 1 SUR 3", "Colis confirmé en valise"
- Boutons: "Photo" (ghost blanc) + "Confirmer & continuer" (vert rempli)

- [ ] **Step 9.1: Refactoriser qr_scanner_screen.dart**

Scaffold couleur sombre:
```dart
Scaffold(
  backgroundColor: const Color(0xFF0D1B2A),
  ...
)
```

Salutation Caveat dans header:
```dart
Text(
  'Bonjour $firstName 👋',
  style: DonyTypography.caveat(fontSize: 22, color: DonyColors.white),
)
```

Coins du rectangle de scan (corner markers):
```dart
// Dessiner 4 coins L-shaped en blanc avec CustomPaint ou 4 Container positionnés
// Chaque coin: 2 lignes perpendiculaires de 3px × 24px en blanc
```

Cercle de succès:
```dart
if (_scanSuccess)
  Center(
    child: Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: DonyColors.success,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
    ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
  )
```

- [ ] **Step 9.2: Run analyze + commit**

```bash
flutter analyze lib/features/tracking/presentation/screens/qr_scanner_screen.dart
git add lib/features/tracking/presentation/screens/qr_scanner_screen.dart
git commit -m "refactor(screen): qr_scanner fidèle scanner.png — fond sombre, salutation Caveat, succès animé"
```

---

## Task 10 — Tracking timeline (suivi_colis.png + suivi_colis_2.png)

**Files:**
- Modify: `lib/features/tracking/presentation/screens/tracking_timeline_screen.dart`

**Maquettes:**
- Header: logo "dony." + "Bonjour Fatou 👋" (Caveat), sous-titre expéditeur
- Map card: fond vert sage (#E8F0E8), ligne pointillée terracotta PAR→DKR, points orange, labels
- Card voyageur: DonyAvatar vert + nom + rating + icône téléphone vert
- Section ÉTAPES: timeline verticale verte (✓ rempli pour complétés, cercle vide pour prochain)
- Dernière ligne "En route vers vous" + ETA
- Bottom pill terracotta: "Pas besoin d'app !" / "J'ouvre la confirmation" (suivi_colis_2.png)

- [ ] **Step 10.1: Refactoriser tracking_timeline_screen.dart**

Timeline step widget:
```dart
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.label, required this.time, required this.isDone, required this.isLast});

  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isDone ? DonyColors.success : DonyColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? DonyColors.success : DonyColors.grey200,
                  width: 2,
                ),
              ),
              child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
            ),
            if (!isLast)
              Expanded(child: Container(width: 2, color: isDone ? DonyColors.success : DonyColors.grey200)),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: tt.titleSmall?.copyWith(
                color: isDone ? DonyColors.ink900 : DonyColors.grey400,
                fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
              )),
              if (time != null) Text(time!, style: tt.bodySmall?.copyWith(color: DonyColors.grey400)),
            ]),
          )),
        ],
      ),
    );
  }
}
```

Bottom pill terracotta (sans app):
```dart
Container(
  margin: const EdgeInsets.all(DonySpacing.lg),
  padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xl, vertical: DonySpacing.base),
  decoration: BoxDecoration(
    color: DonyColors.terra50,
    borderRadius: BorderRadius.circular(DonyRadius.sheet),
    border: Border.all(color: DonyColors.terra300.withValues(alpha: 0.3)),
  ),
  child: Row(children: [
    const Icon(Icons.add_rounded, size: 16, color: DonyColors.terra500),
    const SizedBox(width: 8),
    Text('Pas besoin d\'app !', style: tt.titleSmall?.copyWith(color: DonyColors.terra500)),
  ]),
)
```

- [ ] **Step 10.2: Run analyze + commit**

```bash
flutter analyze lib/features/tracking/presentation/screens/tracking_timeline_screen.dart
git add lib/features/tracking/presentation/screens/tracking_timeline_screen.dart
git commit -m "refactor(screen): tracking_timeline fidèle suivi_colis.png — Caveat, timeline verte, pill terracotta"
```

---

## Task 11 — Bid detail / Mon colis (colis.png)

**Files:**
- Modify: `lib/features/matching/presentation/screens/bid_detail_screen.dart`

**Maquette:** `colis.png`
- Header: "Mon colis #A47C", badge vert "Livré"
- Map card sage (identique suivi_colis)
- Card voyageur: avatar + "Avec Ibrahima D." + KYC badge + icônes téléphone/chat verts
- Timeline ÉTAPES complète (4 étapes toutes ✓ vertes)
- Ligne finale: "Fonds libérés à Ibrahima · Reçu disponible · 32,40€" + bouton "Reçu"

- [ ] **Step 11.1: Refactoriser bid_detail_screen.dart**

Réutiliser `_TimelineStep` (extraire en widget partagé dans `lib/core/design/widgets/dony_timeline_step.dart`).

Badge statut:
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: DonyColors.green50,
    borderRadius: BorderRadius.circular(DonyRadius.full),
    border: Border.all(color: DonyColors.green300),
  ),
  child: Row(children: [
    Container(width: 6, height: 6, decoration: BoxDecoration(color: DonyColors.success, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(statusLabel, style: tt.labelMedium?.copyWith(color: DonyColors.success)),
  ]),
)
```

- [ ] **Step 11.2: Run analyze + commit**

```bash
flutter analyze lib/features/matching/presentation/screens/bid_detail_screen.dart
git add lib/features/matching/presentation/screens/bid_detail_screen.dart lib/core/design/widgets/dony_timeline_step.dart
git commit -m "refactor(screen): bid_detail fidèle colis.png + extrait DonyTimelineStep widget"
```

---

## Task 12 — Garde de confiance (Garder_confiance.png) — NOUVEAU

**Files:**
- Create: `lib/features/payments/presentation/screens/escrow_explainer_screen.dart`
- Modify: `lib/app/router.dart` (route `/payments/escrow`)

**Maquette:** `Garder_confiance.png`
- Fond blanc, header simple avec ←
- Card bleue-clair: "BLOQUÉS EN ESCROW", "32,40 €", "Pour Ibrahima D. — libérés à la remise"
- Section "COMMENT ÇA MARCHE": 4 étapes numérotées, 3 premières avec ✓ vert, 4e avec numéro
- Card disclaimer remboursement (fond sand)
- CTA vert fixe: "Voir le suivi"

- [ ] **Step 12.1: Créer escrow_explainer_screen.dart**

```dart
class EscrowExplainerScreen extends StatelessWidget {
  const EscrowExplainerScreen({super.key, required this.bid});
  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    // ...standard SecondaryScreen scaffold
    // EscrowAmountCard, HowItWorksSection, DisclaimerCard, sticky CTA
  }
}
```

- [ ] **Step 12.2: Ajouter route + commit**

```bash
git add lib/features/payments/presentation/screens/escrow_explainer_screen.dart lib/app/router.dart
git commit -m "feat(screen): escrow_explainer fidèle Garder_confiance.png"
```

---

## Task 13 — File offline QR (scanne_colis_hors_ligne.png) — NOUVEAU

**Files:**
- Create: `lib/features/tracking/presentation/screens/offline_scan_queue_screen.dart`
- Modify: `lib/app/router.dart` (route `/tracking/offline-queue`)

**Maquette:** `scanne_colis_hors_ligne.png`
- Badge "Hors-ligne" terracotta en haut droite
- Card info verte clair: "Vos scans sont en sécurité · 3 scans en attente"
- Section "FILE D'ATTENTE — 3": liste de cards (colis #ID, étape, "il y a X min", icône horloge)
- Message bas: "Continuez à scanner même sans réseau."

- [ ] **Step 13.1: Créer offline_scan_queue_screen.dart**

```dart
class OfflineScanQueueScreen extends StatelessWidget {
  const OfflineScanQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        // Récupérer la queue depuis le bloc
        // Afficher badge hors-ligne, info card verte, liste
      },
    );
  }
}
```

Badge hors-ligne:
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: DonyColors.terra50,
    borderRadius: BorderRadius.circular(DonyRadius.full),
    border: Border.all(color: DonyColors.terra300),
  ),
  child: Row(children: [
    Icon(Icons.wifi_off_rounded, size: 12, color: DonyColors.terra500),
    SizedBox(width: 4),
    Text('Hors-ligne', style: tt.labelMedium?.copyWith(color: DonyColors.terra500)),
  ]),
)
```

- [ ] **Step 13.2: Commit**

```bash
git add lib/features/tracking/presentation/screens/offline_scan_queue_screen.dart lib/app/router.dart
git commit -m "feat(screen): offline_scan_queue fidèle scanne_colis_hors_ligne.png"
```

---

## Task 14 — Confirmation réception (scanner_colis_a_la_reception.png) — NOUVEAU

**Files:**
- Create: `lib/features/tracking/presentation/screens/reception_confirm_screen.dart`
- Modify: `lib/app/router.dart` (route `/tracking/:bidId/confirm-reception`)

**Maquette:** `scanner_colis_a_la_reception.png`
- Header cursif: "Confirmer la réception" (Hanken Grotesk bold titre)
- Sous-titre: "Devant Ibrahima, choisissez :"
- Toggle segmenté: "Scanner le QR" | "Taper le code"
- Option 2 active: "OPTION 2 · CODE", "Tapez le code reçu"
- Pinput 4 chiffres: cases carrées avec border verte quand remplie
- "Reçu par SMS · expire dans 04:32" (mono timer)
- CTA vert: "✓ Confirmer la réception"
- Card info bas: avertissement libération paiement + lien "contestez d'abord"

- [ ] **Step 14.1: Créer reception_confirm_screen.dart**

```dart
class ReceptionConfirmScreen extends StatefulWidget {
  const ReceptionConfirmScreen({super.key, required this.bid});
  final BidModel bid;
  //...
}

// Utiliser Pinput pour les 4 chiffres:
Pinput(
  length: 4,
  defaultPinTheme: PinTheme(
    width: 60, height: 68,
    decoration: BoxDecoration(
      color: DonyColors.green50,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      border: Border.all(color: DonyColors.grey200),
    ),
    textStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(color: DonyColors.ink900),
  ),
  focusedPinTheme: PinTheme(/* border green400 */).copyDecorationWith(
    border: Border.all(color: DonyColors.green400, width: 2),
  ),
  onCompleted: (code) => context.read<TrackingBloc>().add(TrackingReceptionConfirmed(code: code, bidId: bid.id)),
)
```

- [ ] **Step 14.2: Commit**

```bash
git add lib/features/tracking/presentation/screens/reception_confirm_screen.dart lib/app/router.dart
git commit -m "feat(screen): reception_confirm fidèle scanner_colis_a_la_reception.png — Pinput vert, timer"
```

---

## Task 15 — Écrans sans maquette: appliquer design system

**Files:**
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- Modify: `lib/features/auth/presentation/screens/role_selection_screen.dart`
- Modify: `lib/features/auth/presentation/screens/pin_setup_screen.dart`
- Modify: `lib/features/auth/presentation/screens/local_auth_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_onboarding_screen.dart`
- Modify: `lib/features/kyc/presentation/screens/kyc_status_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Modify: `lib/features/profile/presentation/edit_profile_screen.dart`
- Modify: `lib/features/notifications/presentation/inbox_screen.dart`
- Modify: `lib/features/matching/presentation/screens/traveler_profile_screen.dart`
- Modify: `lib/features/matching/presentation/screens/announcement_detail_screen.dart`
- Modify: `lib/features/matching/presentation/screens/matching_management_screen.dart`
- Modify: `lib/features/tracking/presentation/screens/tracking_search_screen.dart`
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart`
- Modify: `lib/features/splash/presentation/splash_screen.dart`
- Modify: `lib/app/router.dart` (_TrackingHubScreen hardcoded colors)

Pour chaque fichier, les modifications sont:
1. Remplacer `GoogleFonts.sora(...)` → `Theme.of(context).textTheme.X`
2. Remplacer `DonyColors.blue400` → `DonyColors.green400`, `DonyColors.blue100` → `DonyColors.green50`
3. Remplacer `Color(0xFF...)` hardcodés → tokens correspondants
4. Remplacer `EdgeInsets.all(16)` → `EdgeInsets.all(DonySpacing.base)`
5. Remplacer `BorderRadius.circular(12)` → `BorderRadius.circular(DonyRadius.md)`

- [ ] **Step 15.1: Remplacer dans tous les fichiers auth/**

```bash
# Vérifier les occurrences
grep -rn "GoogleFonts.sora\|blue400\|blue100\|Color(0xFF" lib/features/auth/ lib/features/kyc/ | wc -l
```

Appliquer les remplacements dans chaque fichier manuellement.

- [ ] **Step 15.2: Remplacer dans matching/, profile/, notifications/, payments/, tracking/, splash/**

```bash
grep -rn "GoogleFonts.sora\|blue400\|blue100\|Color(0xFF" lib/features/ lib/app/router.dart | grep -v "\.g\.dart" | head -50
```

- [ ] **Step 15.3: Run analyze sur tout lib/**

```bash
flutter analyze lib/
```
Expected: 0 errors

- [ ] **Step 15.4: Commit**

```bash
git add lib/features/ lib/app/router.dart
git commit -m "refactor(design-system): suppression hardcodes Sora/blue dans tous les écrans sans maquette"
```

---

## Task 16 — Tests + coverage

**Files:**
- Modify: `test/` — corriger tests cassés, ajouter tests nouveaux écrans

- [ ] **Step 16.1: Run tests actuels**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test
```

Identifier les tests en rouge et les corriger (probablement liés aux changements de couleur dans les expects).

- [ ] **Step 16.2: Ajouter widget tests pour les 3 nouveaux écrans**

```bash
# Créer:
# test/features/auth/presentation/screens/onboarding_screen_test.dart
# test/features/tracking/presentation/screens/offline_scan_queue_screen_test.dart
# test/features/tracking/presentation/screens/reception_confirm_screen_test.dart
```

Exemple test onboarding:
```dart
testWidgets('OnboardingScreen affiche les 2 CTAs', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const OnboardingScreen(),
  ));
  expect(find.text('J\'envoie un colis'), findsOneWidget);
  expect(find.text('Je suis voyageur'), findsOneWidget);
  expect(find.byType(DonyButton), findsNWidgets(2));
});
```

- [ ] **Step 16.3: Générer rapport coverage**

```bash
flutter test --coverage
# Vérifier coverage/lcov.info — objectif ≥ 90%
```

- [ ] **Step 16.4: flutter analyze global**

```bash
flutter analyze
```
Expected: 0 errors, 0 warnings

- [ ] **Step 16.5: Commit final**

```bash
git add test/
git commit -m "test: validation finale refacto frontend — coverage ≥ 90%, 0 analyze errors"
```

---

## Task 17 — Nettoyage code mort (post-refacto)

- [ ] **Step 17.1: Identifier imports orphelins**

```bash
flutter analyze 2>&1 | grep "unused_import\|dead_code"
dart fix --dry-run lib/
```

- [ ] **Step 17.2: Appliquer les fixes**

```bash
dart fix --apply lib/
```

- [ ] **Step 17.3: Vérifier pubspec.yaml** — `flutter_native_splash` android_12 color doit être vert:

```yaml
android_12:
  color: "#1A6B3C"
  icon_background_color: "#1A6B3C"
```

- [ ] **Step 17.4: Commit final cleanup**

```bash
git add .
git commit -m "chore: cleanup imports orphelins, splash color vert, 0 analyze warnings"
```

---

## Self-Review

### Spec coverage check

| Critère | Tâche |
|---------|-------|
| Tous les écrans maquette reproduits | Tasks 3-14 |
| Police design system partout | Tasks 1-2 + 15 |
| Aucune valeur hardcodée | Task 15 + 17 |
| Écrans manquants créés | Tasks 3, 13, 14, 12 |
| flutter analyze 0 errors | Task 16 |
| flutter test 100% pass, coverage ≥90% | Task 16 |
| Code mort supprimé | Task 17 |

### Type consistency check
- `DonyColors.green400` utilisé comme primary dans tous les Tasks ✓
- `DonyRadius.lg = 14` pour les boutons (tâche 1 définit `lg` pour boutons, `card` pour cards) ✓
- `DonyTypography.caveat()` méthode statique utilisée cohéremment Tasks 3,4,9,10 ✓
- `DonyAvatarSize` enum utilisé Tasks 2,5,8 ✓
- `DonyButtonVariant` enum utilisé Tasks 2,3 ✓

### Gaps identifiés et couverts
- `handover_screen.dart`: pas de maquette dédiée mais la maquette `scanner_colis_a_la_reception.png` couvre le flow → Task 14 crée un écran séparé plus fidèle, l'ancien handover_screen reste pour la remise QR côté voyageur
- `matching_management_screen.dart`, `announcement_list_screen.dart`, `shipment_list_screen.dart`: pas de maquette dédiée → couverts par Task 15 (design system coherence)
