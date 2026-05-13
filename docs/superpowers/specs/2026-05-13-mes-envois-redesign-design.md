# Spec — Redesign écran "Mes envois"

**Date :** 2026-05-13  
**Statut :** ✅ Approuvé  
**Fichier cible :** `dony_app/lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

---

## Contexte

L'écran actuel "Mes envois" affiche les demandes d'envoi de l'expéditeur avec un style plat (bordure verte gauche, chips de statut génériques, pas de progression visible). Le redesign apporte une hiérarchie visuelle plus forte et un stepper de progression qui rend l'avancement de chaque envoi immédiatement lisible.

---

## Décisions de design

| Sujet | Décision |
|-------|----------|
| Header | `const Color(0xFF0A2540)` — couleur brand ink-900 déjà utilisée dans `dony_glass.dart`. Titre + compteur d'actifs + tabs intégrés |
| Tabs | En cours / À venir / Passés — positionnés **dans** le header sombre |
| Stepper | 4 étapes : Publié · Accepté · En route · Livré — points espacés, label sous chaque point (Variante 2) |
| Photo | Aucune miniature sur la card |
| Prix | Non affiché sur la card — visible uniquement dans le détail |
| Statut | Dot coloré + texte en haut à gauche de chaque card |
| CTA | Contextuel selon statut : `Voir →` / `Modifier →` / `Détail →` |
| FAB | Bouton `+` flottant en bas à droite pour "Nouvelle demande" |

---

## Structure de l'écran

```
MyPackageRequestsScreen
├── Header (fond #0A2540)
│   ├── DonyAppBar (chevron retour, titre "Mes envois", compteur badge)
│   └── TabRow (En cours / À venir / Passés)
└── Body (fond F2F1EF)
    └── ListView.separated
        └── _RequestCard (par item)
            ├── StatusRow (dot + texte statut + ref ID)
            ├── RouteText (Départ → Arrivée)
            ├── ProgressStepper (4 étapes)
            ├── MetaChips (poids, catégorie, mode transport)
            └── FooterRow (date + CTA contextuel)
```

---

## Mapping tabs → statuts

| Tab | Statuts inclus |
|-----|---------------|
| **En cours** | `negotiating`, `accepted` |
| **À venir** | `open` |
| **Passés** | `completed`, `expired`, `cancelled` |

---

## Stepper — mapping statuts → étape active

| Statut `PackageRequestStatus` | Étape active |
|-------------------------------|-------------|
| `open` | Publié (étape 1) |
| `negotiating` | Accepté (étape 2) |
| `accepted` | En route (étape 3) |
| `completed` | Livré (étape 4) — toutes les étapes complètes |
| `expired` / `cancelled` | Stepper grisé — arrêt à l'étape atteinte |

**Couleurs des points :**
- Étape passée : `cs.primary` (#0B5FFF)
- Étape active : `cs.success` (#0E8A5F) avec glow ring
- Étape future : `cs.outlineVariant` (gris clair)

**Connecteurs :**
- Passé → passé : bleu `cs.primary`
- Passé → actif : bleu `cs.primary`
- Actif → futur : gris `cs.outlineVariant`

---

## Palette statuts (dot + texte)

| Statut | Couleur |
|--------|---------|
| `open` | `cs.primary` (#0B5FFF) |
| `negotiating` | `cs.warning` / orange (#D97706) |
| `accepted` | `cs.success` (#0E8A5F) |
| `completed` | `cs.success` (#0E8A5F) |
| `expired` / `cancelled` | `cs.onSurfaceVariant` (gris) |

---

## CTA contextuel

| Statut | Label CTA |
|--------|-----------|
| `open` | `Modifier →` |
| `negotiating` | `Voir →` |
| `accepted` | `Voir →` |
| `completed` | `Détail →` |
| `expired` / `cancelled` | `Détail →` (grisé) |

---

## Compteur dans le header

Badge discret en haut à droite du titre affichant le nombre d'items dans la tab active :
- "En cours" : count de `negotiating` + `accepted`
- "À venir" : count de `open`
- "Passés" : count de `completed` + `expired` + `cancelled`
- Masqué si count = 0

---

## État vide par tab

Si aucun envoi dans la tab active, afficher `DonyEmptyState` avec :
- Tab "En cours" → `mascotte: DonyMascotteType.assis` · titre : "Aucun envoi en cours" · CTA : "Publier une demande"
- Tab "À venir" → `mascotte: DonyMascotteType.assis` · titre : "Aucune demande ouverte"
- Tab "Passés" → `mascotte: DonyMascotteType.assis` · titre : "Aucun historique"

---

## Fichiers à modifier

| Fichier | Nature |
|---------|--------|
| `my_package_requests_screen.dart` | Refonte complète de l'UI — header, tabs, `_RequestCard`, stepper |

Aucun nouveau fichier à créer — le composant stepper est local à `_RequestCard` (widget privé `_ProgressStepper` dans le même fichier).

---

## Ce qui ne change pas

- BLoC `PackageRequestBloc` — aucune modification
- Repository — aucune modification
- Modèle `PackageRequest` — aucune modification
- Navigation (tap sur card → `PackageRequestDetailBottomSheet`) — conservée
- FAB "Nouvelle demande" — conservé, style inchangé
