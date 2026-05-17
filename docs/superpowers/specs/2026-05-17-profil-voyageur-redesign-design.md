# Spec : Profil Voyageur — Restructuration & Header enrichi
**Date :** 2026-05-17 | **Status :** ✅ Approuvé

---

## Contexte

Le screen `ProfileScreen` affiche un contenu différent selon `activeRole`. La section `ActiveRole.traveler` est actuellement une liste plate de 9 tiles sans organisation, contrairement à la section sender qui a des sections labellisées. Ce spec couvre :

1. Restructuration de la section voyageur en 6 sections logiques
2. Renommage + badge "Colis sur mes trajets"
3. Ajout des tiles manquantes (profil public, avis, support)
4. Enrichissement du collapsed state du SliverAppBar (no-regression badge doré)

---

## Périmètre

**Fichier principal :** `lib/features/profile/presentation/profile_screen.dart`

**Hors périmètre :**
- Section sender — inchangée
- `ProfileHeader` widget — le header expanded reste strictement identique
- Routes backend — toutes les routes cibles existent déjà
- `PackageRequestsSearch` screen — navigué tel quel pour ce sprint

---

## 1. Structure sections voyageur

### Avant (liste plate, 9 tiles, 0 section)

```
DonyListSection([
  Mes trajets
  Recevoir mes paiements
  Carte commission cash
  Passer en compte PRO
  Demandes d'envoi à transporter
  Mes négociations
  Paiements & factures
  Documents KYC
  Parrainages
])
```

### Après (6 sections avec `_SectionLabel`)

#### MON ACTIVITÉ
| Tile | Badge | Route |
|------|-------|-------|
| ✈ Mes trajets | `upcomingAnnouncements > 0` → "X à venir" | `/announcements` |
| 📦 Colis sur mes trajets | `upcomingAnnouncements > 0` → "X matchs" (voir §2) | `/package-requests/search` |
| 🤝 Mes négociations | — | `/negotiations` |

#### REVENUS & PAIEMENTS
| Tile | Route |
|------|-------|
| 💳 Recevoir mes paiements | `/payments/onboarding` |
| 💵 Carte commission cash | `/payments/commission-method` |
| 🧾 Paiements & factures | `ComingSoonBottomSheet` |

#### COMPTE PRO
| Tile | Condition | Route |
|------|-----------|-------|
| 💼 Mon profil PRO | `isProAccount == true` → label "Mon profil PRO" + `Icon(verified, success)` | `UpgradeProBottomSheet` |
| 💼 Passer en compte PRO | `isProAccount == false` → label "Passer en compte PRO" | `UpgradeProBottomSheet` |

#### IDENTITÉ & CONFIANCE
| Tile | Nouveau | Route |
|------|---------|-------|
| 🪪 Documents KYC | — | `KycOnboardingBottomSheet` / `KycStatusBottomSheet` |
| 👤 Mon profil public | ✅ nouveau | `/profile/public` |
| ⭐ Mes avis reçus | ✅ nouveau | `/profile/reviews` |

#### FIDÉLITÉ
| Tile | Badge | Route |
|------|-------|-------|
| 👥 Parrainages | "0 invité" (statique MVP) | `/profile/referral` |

#### SUPPORT  *(section entièrement nouvelle)*
| Tile | Nouveau | Route |
|------|---------|-------|
| ⚖ Mes litiges | ✅ nouveau | `/disputes` |
| 💬 Contacter le support | ✅ nouveau | `/profile/help/contact` |
| ❓ FAQ & aide | ✅ nouveau | `/profile/help/faq` |

---

## 2. "Colis sur mes trajets" — logique badge

Le tile remplace "Demandes d'envoi à transporter". Route inchangée : `/package-requests/search`.

**Badge :** utilise `upcomingAnnouncements` (nombre d'annonces `ACTIVE` ou `FULL` déjà calculé dans le `build`) comme proxy du nb de matchs potentiels.
- `upcomingAnnouncements > 0` → badge bleu "X matchs"
- `upcomingAnnouncements == 0` → pas de badge

Ce proxy est acceptable pour le MVP car un voyageur sans trajet actif n'a aucun match pertinent à voir.

**Icône :** `Icons.inventory_2_outlined`, couleur `cs.primary`, bg `cs.primaryContainer`.

---

## 3. Header — no-regression + collapsed state enrichi

### Expanded — ajout icône settings

Dans `ProfileHeader`, le `Stack` existant reçoit un second `Positioned` en haut à droite, **au même niveau vertical que l'avatar** :

```dart
Positioned(
  top: 0,
  right: 0,
  child: IconButton(
    icon: const Icon(Icons.settings_outlined, color: DonyColors.textOnBrand),
    onPressed: onSettingsTap,
    tooltip: 'Paramètres',
  ),
),
```

**Paramètre ajouté à `ProfileHeader` :**
```dart
final VoidCallback? onSettingsTap;
```

**Appel dans `profile_screen.dart` :**
```dart
ProfileHeader(
  ...
  onSettingsTap: () => context.push('/settings'),
)
```

Le reste du header expanded est strictement inchangé :
- Ring `DonyColors.warning` autour de l'avatar si `activeRole == traveler` ✓
- `_KycBadge` dorée ("Profil pro vérifié") si `isProAccount` ✓
- `_KycBadge` bleue ("Identité vérifiée") si `isKycVerified && !isProAccount` ✓
- `_RolePillB` si `isTraveler && isSender` ✓
- `_GlassStats` ✓

### Collapsed state (actuellement : juste `displayName` en title)

Remplacer le `title` du SliverAppBar par une `Row` animée :

```
[DonyAvatar 24px, ring doré si traveler] [8px] [displayName w700] [8px] [Icon verified 13px, couleur dorée/bleue]
```

**Spécifications :**
- `DonyAvatar` : `size: DonyAvatarSize.sm` (24×24), `verified: false` (le check est montré par l'icône séparée), `ring color: DonyColors.warning` si traveler, `DonyColors.surface` sinon
- `displayName` : `tt.titleSmall.w700`, couleur = `titleColor` (déjà calculée via `progress`)
- `Icon(Icons.verified_rounded, size: 13)` : visible uniquement si `isKycVerified`
  - Couleur : `DonyColors.kycBadgeGold` si `isProAccount`, sinon `DonyColors.kycBadgeBlue`
- La `Row` entière a `opacity: progress.clamp(0.8, 1.0)` pour apparaître seulement en état collapsed

### Ce qui NE change PAS dans le header
- `pinned: true` (la barre reste visible au scroll) — inchangé
- `expandedHeight`, `_kContentHeight`, calcul de `progress` — inchangés
- `backgroundColor: headerBg` (transition vert → surface) — inchangée
- `RefreshIndicator`, `AlwaysScrollableScrollPhysics` — inchangés

---

## 4. Animations

Les nouvelles sections suivent le stagger existant :
- MON ACTIVITÉ : `delay: 200ms`
- REVENUS & PAIEMENTS : `delay: 240ms`
- COMPTE PRO : `delay: 260ms`
- IDENTITÉ & CONFIANCE : `delay: 280ms`
- FIDÉLITÉ : `delay: 300ms`
- SUPPORT : `delay: 320ms`

Chaque section : `.animate().fadeIn().slideY(begin: 0.04, curve: Curves.easeOutCubic)`

---

## 5. Tests à ajouter

**`test/features/profile/presentation/profile_screen_traveler_test.dart`**

| Test | Description |
|------|-------------|
| sections present | Le widget contient les 6 `_SectionLabel` |
| new tiles | "Mon profil public", "Mes avis reçus", "Mes litiges" apparaissent |
| renamed tile | "Colis sur mes trajets" apparaît, "Demandes d'envoi à transporter" absent |
| badge matchs | `upcomingAnnouncements = 2` → badge "2 matchs" visible |
| badge absent | `upcomingAnnouncements = 0` → pas de badge sur "Colis sur mes trajets" |
| sender not broken | Avec `activeRole = sender`, les tiles sender restent inchangées |
| collapsed badge | Scroll → collapsed AppBar → `Icon(verified_rounded)` visible si `isKycVerified` |

---

## 6. Checklist d'implémentation

- [ ] Section traveler dans `profile_screen.dart` remplacée par les 6 sections
- [ ] `title` du SliverAppBar remplacé par la Row avatar+nom+badge
- [ ] Icône `settings_outlined` ajoutée dans `ProfileHeader` (top-right, même niveau que la photo)
- [ ] Badge "Colis sur mes trajets" branché sur `upcomingAnnouncements`
- [ ] Navigation "Mon profil public" → `/profile/public` ✓
- [ ] Navigation "Mes avis reçus" → `/profile/reviews` ✓
- [ ] Navigation section SUPPORT → routes existantes ✓
- [ ] Tous les tests passent (`flutter test`)
- [ ] Couverture ≥ 90 %
