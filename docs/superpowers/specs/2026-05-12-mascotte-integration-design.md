# Design — Intégration mascotte v2

**Date:** 2026-05-12 | **Status:** Approuvé

---

## Contexte

L'app dispose d'un widget `DonyMascotte` avec 11 types pointant vers `assets/mascottes/`. Le set graphique change : 8 nouvelles images dans `assets/mascotte/`. Objectif : migrer vers les nouveaux assets, créer un wrapper animé, et étendre la présence de la mascotte dans toute l'app comme Alan (bonne image + bonne animation au bon moment).

---

## Architecture

### 1. Mise à jour de l'enum `DonyMascotteType`

Remplacement des 11 anciens types par 8 nouveaux, alignés sur les nouvelles images :

| Type enum | Fichier asset | Sémantique |
|---|---|---|
| `joyeux` | `assets/mascotte/joyeux.png` | Accueil, salut, onboarding |
| `confiant` | `assets/mascotte/confiant.png` | Étape validée, scan intermédiaire, offre acceptée |
| `securise` | `assets/mascotte/sécurisé.png` | Livraison finale, KYC OK, paiement réussi |
| `tenantColis` | `assets/mascotte/tenant_le_colis.png` | Création colis, sender flow |
| `donneColis` | `assets/mascotte/donne_un_colis.png` | Voyageur accepte une offre |
| `enCourse` | `assets/mascotte/en_course.png` | Colis en transit, suivi actif |
| `assis` | `assets/mascotte/assis.png` | Empty states, erreurs, pas de données |
| `scan` | `assets/mascotte/Scan.png` | Moment du scan QR |

Suppressions : `salue`, `pouceLeve`, `colisLivre`, `dansAvion`, `surAvion`, `aMoto`, `aVoiture`, `courir`, `noData`, `perdu`.

### 2. Nouveau widget `DonyMascotteAnimated`

Wrapper autour de `DonyMascotte` ajoutant des **presets d'animation** via `flutter_animate` :

```
DonyMascotteAnimated(
  type: DonyMascotteType.securise,
  size: DonyMascotteSize.lg,
)
```

**Presets par type :**

| Type | Animation |
|---|---|
| `joyeux` | fadeIn(300ms) + scaleXY(begin: 0.85) — entrée douce onboarding |
| `confiant` | fadeIn(200ms) + slideY(begin: 0.06) + bounce léger |
| `securise` | fadeIn(250ms) + scaleXY(begin: 0.9) + shimmer subtil sur l'image |
| `tenantColis` | fadeIn(300ms) + slideY(begin: 0.08, curve: easeOutCubic) |
| `donneColis` | fadeIn(250ms) + slideY(begin: -0.06) — descend depuis le haut |
| `enCourse` | fadeIn(200ms) + slideX(begin: -0.1) — entre par la gauche |
| `assis` | fadeIn(400ms) + scaleXY(begin: 0.92, curve: easeOutCubic) — appear calme |
| `scan` | fadeIn(150ms) + pulse(interval: 1200ms) — respire pendant le scan |

Toutes les durées respectent les tokens d'animation existants (< 500ms, `easeOutCubic`).

### 3. Mise à jour `pubspec.yaml`

Remplacer `- assets/mascottes/` par `- assets/mascotte/`.

---

## Composants à créer / modifier

| Fichier | Action |
|---|---|
| `pubspec.yaml` | `mascottes/` → `mascotte/` |
| `lib/core/design/widgets/dony_mascotte.dart` | Refaire l'enum (8 types), garder `DonyMascotte` intact |
| `lib/core/design/widgets/dony_mascotte_animated.dart` | Nouveau widget avec presets flutter_animate |
| `lib/core/design/design_system.dart` | Exporter `DonyMascotteAnimated` |
| `lib/core/design/CLAUDE.md` | Mettre à jour la table de mapping |

---

## Écrans à mettre à jour

### Onboarding / Auth
- `onboarding_screen.dart` — remplacer `DonyMascotte(type: .salue)` → `DonyMascotteAnimated(type: .joyeux, size: .lg)`
- `phone_auth_screen.dart` — ajouter mascotte `joyeux` en haut si absent
- `otp_verification_screen.dart` — ajouter mascotte `confiant` en haut si absent
- `pin_setup_screen.dart` — ajouter mascotte `securise` à la confirmation

### Scan QR & Tracking
- `qr_scanner_screen.dart` — remplacer `.pouceLeve` → `.confiant` et `.colisLivre` → `.securise`, plus `.scan` pendant le scan actif

### Empty States
- Tous les `DonyEmptyState` avec `mascotte:` null → passer `.assis`
- Créer des empty states dans : matching (no announcements, no bids), messaging (no conversations), notifications (inbox vide)

### États succès / Confirmation
- Écran confirmation paiement → `DonyMascotteAnimated(type: .securise, size: .xl)`
- Écran KYC validé → `DonyMascotteAnimated(type: .securise, size: .lg)`
- Écran offre acceptée (voyageur) → `DonyMascotteAnimated(type: .donneColis, size: .lg)`

---

## Règles d'affichage

- **Flottante libre** — jamais dans un container/card, posée directement sur le fond d'écran
- Pas de `borderRadius` sauf exception justifiée (ex : onboarding hero arrondi)
- `DonyMascotteAnimated` pour tout nouvel usage — `DonyMascotte` reste disponible pour les cas statiques existants
- **Jamais** `Image.asset('assets/mascotte/...')` direct — toujours via le widget

---

## Tests

- Widget test `DonyMascotteAnimated` : vérifie que `Image.asset` charge le bon chemin pour chaque type
- Widget test `DonyMascotte` : vérifie la mise à jour de l'enum (chemins corrects)
- Pas de tests unitaires BLoC nécessaires (widget pur sans état)
- Couverture ≥ 90 % maintenue

---

## Ce qui n'est PAS dans ce scope

- Animations Lottie (PNG uniquement)
- DonyMascotteScene / sélection automatique par contexte métier (Approche 3)
- Modification des BLoCs — la mascotte est un widget de présentation pur
- Nouveaux assets graphiques — uniquement les 8 images existantes
