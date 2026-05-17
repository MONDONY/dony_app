# Spec : Colis sur mes trajets
**Date :** 2026-05-17 | **Status :** ✅ Approuvé

---

## Contexte

Le tile "Colis sur mes trajets" (section MON ACTIVITÉ du profil voyageur) navigue actuellement vers `/package-requests/search`, l'écran de recherche générique de demandes d'envoi. Cette feature remplace cette destination par un nouvel écran dédié qui pré-filtre automatiquement les demandes d'envoi compatibles avec les trajets actifs du voyageur, et permet de faire une offre (via `MakeOfferBottomSheet` existant) avec les données du trajet pré-remplies.

---

## Périmètre

**Fichier principal (nouveau) :**
`lib/features/package_request/presentation/traveler/colis_match_screen.dart`

**Fichiers modifiés :**
- `lib/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart`
- `lib/features/package_request/presentation/traveler/package_request_public_detail_screen.dart`
- `lib/app/router.dart`
- `lib/features/profile/presentation/profile_screen.dart`

**Hors périmètre :**
- `PackageRequestSearchScreen` — inchangé (accès direct `/package-requests/search` non modifié)
- Flow de négociation après l'offre — inchangé (`NegotiationBloc`, `NegotiationThreadScreen`)
- `MakeOfferBottomSheet` logique métier — seul le paramètre `initialDate` est ajouté

---

## 1. Écran `ColisMatchScreen`

### Route
```
/package-requests/match
```
Remplace le lien `/package-requests/search` dans `profile_screen.dart` (tile "Colis sur mes trajets").

### BLoCs utilisés
| BLoC | Source | Rôle |
|------|--------|------|
| `AnnouncementBloc` | `BlocProvider(create: (_) => getIt<AnnouncementBloc>()..add(const AnnouncementListRequested()))` | Fournit la liste des trajets actifs du voyageur |
| `PackageRequestSearchBloc` | `BlocProvider(create: (_) => getIt<PackageRequestSearchBloc>())` | Effectue la recherche filtrée par trajet sélectionné |

Les deux BLoCs sont fournis dans un `MultiBlocProvider` au niveau du `build()` de `ColisMatchScreen`. L'`AnnouncementListRequested` est déclenché à la création pour charger les trajets immédiatement.

### Structure de l'écran

```
AppBar ("Colis sur mes trajets", badge "N compatibles")
├── ChipsBar  — sélecteur de trajet (chips horizontaux)
├── CapacityBanner  — "X kg restants · Y kg total"
└── ListView paginé  — cartes de demandes d'envoi
    └── [empty state si 0 résultats]
```

#### ChipsBar
- Génère un chip par annonce avec `status == 'ACTIVE' || status == 'FULL'`
- Label : `"✈ {departureCity}→{arrivalCity} · {departureDate dd MMM}"`
- Chip actif : fond `cs.primary`, texte blanc
- Chip inactif : fond `cs.surfaceVariant`
- Tap → met à jour `_selectedAnnouncementIndex` (local `ValueNotifier<int>`) → déclenche une nouvelle recherche

#### CapacityBanner
- Barre fine sous les chips
- Affiche `announcement.availableKg` et `announcement.totalKg`
- Couleur texte : `cs.primary` pour `availableKg`, `cs.onSurfaceVariant` pour le reste

#### Calcul des paramètres de recherche
Depuis l'annonce sélectionnée :
```dart
PackageRequestSearchRequested(
  departure: announcement.departureCity,
  arrival:   announcement.arrivalCity,
  dateFrom:  announcement.departureDate.subtract(const Duration(days: 7)),
  dateTo:    announcement.departureDate.add(const Duration(days: 7)),
)
```
La fenêtre de ±7 jours autour de la date de départ capture les demandes avec tolérance de date côté expéditeur.

#### Carte de résultat
Réutilise `PackageRequestListCard` (widget existant). Tap → navigation vers `/package-requests/{id}/public` avec extra :
```dart
{'announcement': _selectedAnnouncement}
```

### États vides

| Condition | Affichage |
|-----------|-----------|
| Aucun trajet `ACTIVE`/`FULL` | Illustration ✈ + "Aucun trajet actif" + bouton "Publier un trajet" → `/announcements/create` |
| Trajet actif mais 0 résultats | Icône 📦 + "Aucun colis ne correspond à ce trajet pour l'instant." (pas de CTA) |
| Chargement | `CircularProgressIndicator` centré |
| Erreur | Icône + message + bouton "Réessayer" → relance la recherche |

---

## 2. Modification `MakeOfferBottomSheet`

### Changement unique
Ajout d'un paramètre optionnel à la méthode `show()` :

```dart
static Future<void> show(
  BuildContext context, {
  required String packageRequestId,
  double? targetPriceEur,
  required double weightKg,
  required String departureCity,
  required String arrivalCity,
  DateTime? initialDate,          // ← nouveau
}) async
```

### Usage interne
Le `TextEditingController` de la date utilise `initialDate` si fourni :
```dart
// Avant : DateTime.now().add(const Duration(days: 7))
// Après :
final _defaultDate = initialDate ?? DateTime.now().add(const Duration(days: 7));
```

### Rétrocompatibilité
Paramètre optionnel — tous les appels existants compilent sans modification.

---

## 3. Modification `PackageRequestPublicDetailScreen`

### Lecture des extras GoRouter
```dart
final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
final announcement = extra?['announcement'] as AnnouncementModel?;
```

### Appel modifié à `MakeOfferBottomSheet`
```dart
MakeOfferBottomSheet.show(
  context,
  packageRequestId: r.id,
  targetPriceEur:   r.targetPriceEur,
  weightKg:         announcement?.availableKg ?? r.weightKg,
  departureCity:    r.departureCity,
  arrivalCity:      r.arrivalCity,
  initialDate:      announcement?.departureDate,     // ← nouveau
);
```

`announcement` est `null` quand l'écran est ouvert directement (sans passer par `ColisMatchScreen`) — comportement identique à aujourd'hui.

---

## 4. Router

```dart
GoRoute(
  path: '/package-requests/match',
  builder: (context, state) => const ColisMatchScreen(),
),
```

---

## 5. Profile Screen

Dans la section voyageur, tile "Colis sur mes trajets" :
```dart
// Avant
onTap: () => context.push('/package-requests/search'),
// Après
onTap: () => context.push('/package-requests/match'),
```

---

## 6. Animations

- `ColisMatchScreen` : `.animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic)` sur la liste
- Chips : aucune animation (UI de contrôle)
- Changement de chip → indicateur de chargement immédiat (pas d'animation sur les résultats sortants)

---

## 7. Tests

**`test/features/package_request/presentation/traveler/colis_match_screen_test.dart`**

| Test | Description |
|------|-------------|
| chips from announcements | Chips générés depuis les annonces ACTIVE/FULL |
| active chip filters results | Sélection d'un chip déclenche recherche avec bon départ/arrivée |
| no active trips empty state | AnnouncementListLoaded([]) → état vide "Aucun trajet actif" |
| no results empty state | AnnouncementListLoaded([ann]) + PackageRequestSearchEmpty → "Aucun colis ne correspond" |
| tap card navigates | Tap sur une carte → push `/package-requests/{id}/public` avec extra `announcement` |
| capacity banner | Affiche `availableKg` et `totalKg` de l'annonce sélectionnée |

**`test/features/package_request/presentation/widgets/make_offer_bottom_sheet_test.dart`**

| Test | Description |
|------|-------------|
| initialDate pre-fills date field | `initialDate` fourni → champ date affiche la valeur correcte |
| no initialDate defaults to 7 days | `initialDate` absent → date par défaut = aujourd'hui + 7j |

---

## 8. Checklist d'implémentation

- [ ] `ColisMatchScreen` créé avec chips, capacity banner, liste paginée
- [ ] `PackageRequestSearchBloc` utilisé avec params calculés depuis l'annonce
- [ ] Deux états vides (pas de trajet / pas de résultats) implémentés
- [ ] `MakeOfferBottomSheet.show()` — paramètre `initialDate` ajouté
- [ ] `PackageRequestPublicDetailScreen` — lecture des extras + pré-remplissage
- [ ] Route `/package-requests/match` ajoutée dans `router.dart`
- [ ] `profile_screen.dart` — lien mis à jour
- [ ] Tous les tests passent (`flutter test`)
- [ ] Couverture ≥ 90 %
