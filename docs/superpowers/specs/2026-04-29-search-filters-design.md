# Design — Recherche & Filtres `SearchAnnouncementScreen`

**Date :** 2026-04-29  
**Fichier cible :** `lib/features/matching/presentation/screens/search_announcement_screen.dart`  
**Status :** Approuvé

---

## Contexte

L'écran de recherche `SearchAnnouncementScreen` permet aux expéditeurs de trouver des voyageurs disponibles. Il alterne entre une vue formulaire (_FilterFormView) et une vue résultats (_ResultsView). Le design visuel est validé et ne doit pas être modifié. Les 9 sections suivantes concernent uniquement la logique de filtrage et l'interactivité.

---

## Architecture — Deux niveaux de filtrage

### Niveau 1 — API (appel réseau)
Déclenché par : changement ville départ, changement ville arrivée, toggle chip rapide (Kilo Pro / Note ≥ 4.5 / Week-end / Prix ≤ X€/kg), bouton "Rechercher", bouton "Appliquer" du bottom sheet.

### Niveau 2 — Client (filtrage instantané)
Déclenché par : toggle des 4 chips résultats (★ 4.7+ / €/kg ↓ / Cette semaine / +10 kg). Logique ET. Sans appel réseau.

---

## Section 1 — Remonter les filtres résultats dans le parent

**Problème actuel :** `_ratingActive`, `_priceActive`, `_weekActive`, `_weightActive` sont dans `_ResultsViewState`. Ils sont perdus quand l'utilisateur revient au formulaire.

**Solution :** Déplacer ces 4 `ValueNotifier<bool>` dans `_SearchAnnouncementScreenState`.
- Les passer en paramètre à `_ResultsView`
- Les inclure dans `Listenable.merge()` du parent
- Les disposer dans `dispose()` du parent

**Impact :** Les filtres résultats survivent à la navigation formulaire ↔ résultats.

---

## Section 2 — Auto-search sur certains champs

| Champ | Déclencheur | Action |
|-------|------------|--------|
| Ville départ | `onChanged` | `_search()` immédiat |
| Ville arrivée | `onChanged` | `_search()` immédiat |
| Date | sélection date picker | `_searchDirty = true` (bouton obligatoire) |
| Poids | confirmation bottom sheet | `_searchDirty = true` (bouton obligatoire) |
| Slider prix | `onChangeEnd` | `_searchDirty = true` (bouton obligatoire) |
| Chip Kilo Pro | `onChanged` | `_search()` immédiat |
| Chip Note ≥ 4.5 | `onChanged` | `_search()` immédiat |
| Chip Week-end | `onChanged` | `_search()` immédiat |
| Chip Prix ≤ X€ | `onChanged` | `_search()` immédiat |

**Comportement clé :** Si `_showResultsNotifier.value == true` quand une ville change → rester sur l'écran résultats et recharger (ne pas revenir au formulaire).

---

## Section 3 — `_search()` complète

```dart
void _search() {
  context.read<AnnouncementBloc>().add(AnnouncementSearchRequested(
    departureCity: _departureCityShort,
    arrivalCity: _arrivalCityShort,
    departureDateFrom: _dateNotifier.value,
    minAvailableKg: _weightKgNotifier.value > 1 ? _weightKgNotifier.value : null,
    maxPricePerKg: _priceFilterNotifier.value ? _maxPricePerKgNotifier.value : null,
    kiloProOnly: _kiloProOnlyNotifier.value,
    minRating: _ratingFilterNotifier.value ? 4.5 : null,
    weekendOnly: _weekendFilterNotifier.value,
    sortBy: _priceFilterNotifier.value ? 'price' : 'date',
    sortDir: 'asc',
  ));
  _searchDirty = false;
  _showResultsNotifier.value = true;
}
```

**Champs à ajouter dans `AnnouncementSearchRequested`** (tous nullable) :
- `double? maxPricePerKg`
- `bool? kiloProOnly`
- `double? minRating`
- `bool? weekendOnly`

`announcement_bloc.dart` à mettre à jour pour forwarder ces champs au repository.

---

## Section 4 — Flag dirty pour le bouton Rechercher

```dart
bool _searchDirty = true; // dans _SearchAnnouncementScreenState
```

- **Passe à `true`** : quand date, poids ou slider prix changent
- **Passe à `false`** : après chaque appel à `_search()`

**Libellés du bouton (BlocBuilder) :**
- `AnnouncementLoading` → spinner
- `!_searchDirty + AnnouncementSearchLoaded` → "Voir X trajet(s)"
- Sinon → "Rechercher"

---

## Section 5 — Filtrage client réactif (4 chips résultats)

```dart
List<AnnouncementModel> _applyFilters(List<AnnouncementModel> results) {
  var filtered = results;
  if (_ratingActive.value) {
    filtered = filtered.where((a) => (a.traveler?.averageRating ?? 0) >= 4.7).toList();
  }
  if (_weekActive.value) {
    final limit = DateTime.now().add(const Duration(days: 7));
    filtered = filtered.where((a) => a.departureDate.isBefore(limit)).toList();
  }
  if (_weightActive.value) {
    filtered = filtered.where((a) => a.availableKg >= 10).toList();
  }
  if (_priceActive.value) {
    filtered = List.from(filtered)..sort((a, b) => a.pricePerKg.compareTo(b.pricePerKg));
  }
  return filtered;
}
```

`ListenableBuilder` sur les 4 notifiers entoure le `BlocBuilder`. Si `filtered.isEmpty` → `_EmptyView(onBack: widget.onBack)`.

---

## Section 6 — Sous-titre AppBar dynamique

Remplace `'23 voyageurs · cette semaine'` hardcodé :

- `AnnouncementLoading` → `'Recherche en cours...'`
- `AnnouncementSearchLoaded` → `'$n voyageur${n > 1 ? 's' : ''}'` (n = filtered.length)
- `AnnouncementError` → `'Erreur de chargement'` (couleur `DonyColors.error`)
- `overflow: TextOverflow.ellipsis, maxLines: 1`

---

## Section 7 — Badge point vert sur bouton tune

```dart
Stack(
  children: [
    IconButton(
      icon: const Icon(Icons.tune_rounded, color: DonyColors.ink900),
      onPressed: () => _showFilterBottomSheet(context),
      tooltip: 'Filtres',
    ),
    if (_hasActiveFilters)
      Positioned(
        top: 8, right: 8,
        child: Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
            color: DonyColors.green400,
            shape: BoxShape.circle,
          ),
        ),
      ),
  ],
)
```

Encapsulé dans `ListenableBuilder` sur les 4 notifiers. `_hasActiveFilters` = au moins 1 des 4 `ValueNotifier` est `true`.

---

## Section 8 — Bottom sheet filtres complet

`_showFilterBottomSheet(BuildContext context)` dans `_ResultsViewState`.

**Contenu :** `_LocationRow`, `_DateField`, `_WeightField`, `_QuickChip` ×4, Slider prix. Initialisés aux valeurs courantes via `ValueNotifier` locaux au bottom sheet.

**Callback `widget.onApply`** : mis à jour les notifiers du parent + appelle `_search()`. Puis `context.pop()`. Reste sur l'écran résultats.

**Règles dony bottom sheet :**
- `isScrollControlled: true`
- `backgroundColor: Colors.transparent`
- Handle : `Container(width: 40, height: 4, color: DonyColors.grey200, borderRadius: 2)`
- `borderRadius: vertical(top: Radius.circular(DonyRadius.sheet))`
- Hauteur max 92% (`maxChildSize: 0.92`)
- `SingleChildScrollView` à l'intérieur
- `padding bottom = MediaQuery.of(context).viewInsets.bottom`

---

## Section 9 — Skeleton card supprimé après chargement

Retirer le `+1` dans `itemCount`. Supprimer le bloc `if (i == state.results.length)`. La `_SkeletonCard` ne s'affiche plus une fois `AnnouncementSearchLoaded` reçu.

---

## Responsive design

| Breakpoint | Largeur | Règles spécifiques |
|------------|---------|-------------------|
| Petit téléphone | 360 dp | Padding `DonySpacing.base` dans bottom sheet |
| Standard Pixel 6 | 411 dp | Padding `DonySpacing.lg` |
| Grand téléphone | 430 dp | — |
| Tablette portrait | 600 dp | — |

- Row Date + Poids : `LayoutBuilder` → `Column` si largeur < 340 dp
- Slider prix : labels "5€" / "25€" visibles sur 360 dp
- AppBar sous-titre : `TextOverflow.ellipsis`, `maxLines: 1`

---

## Tests widget obligatoires

Fichier : `test/features/matching/presentation/search_announcement_screen_test.dart`

1. Filtre rating actif → liste filtrée à `averageRating >= 4.7`
2. Filtre semaine actif → `departureDate` dans 7 jours
3. Tri prix actif → résultats triés par `pricePerKg` croissant
4. Filtre ET combiné (rating + poids) → intersection correcte
5. Changement ville → `AnnouncementSearchRequested` émis automatiquement
6. Toggle chip rapide → `AnnouncementSearchRequested` émis automatiquement
7. Changement poids/slider → `AnnouncementSearchRequested` NON émis automatiquement
8. Badge point vert → visible si filtre actif, absent sinon
9. Skeleton → absent quand `AnnouncementSearchLoaded`
10. Filtres mémorisés → actifs après retour formulaire + nouvelle recherche
11. Responsive 360 dp, 411 dp, 600 dp → 0 overflow

Couverture : `flutter test --coverage` ≥ 90%.

---

## Fichiers à modifier

| Fichier | Modification |
|---------|-------------|
| `announcement_event.dart` | Ajouter 4 champs nullable dans `AnnouncementSearchRequested` |
| `announcement_bloc.dart` | Forwarder les 4 nouveaux champs au repository |
| `search_announcement_screen.dart` | Sections 1-9 |

## Fichiers interdits (ne pas toucher)

- `announcement_remote_datasource.dart`
- `announcement_repository.dart`
- `bid_list_screen.dart`
- `router.dart`

---

## Commits atomiques

```
Section 1 : feat(search): remonte filtres chips dans parent pour persistance
Section 2 : feat(search): auto-search sur changement ville et chips rapides
Section 3 : feat(search): inclure filtres rapides dans AnnouncementSearchRequested
Section 4 : feat(search): flag dirty pour bouton Rechercher cohérent
Section 5 : feat(search): filtrage client réactif ET sur 4 chips résultats
Section 6 : feat(search): sous-titre AppBar dynamique avec compte filtré
Section 7 : feat(search): badge point vert sur bouton tune si filtres actifs
Section 8 : feat(search): bottom sheet filtres complet avec callback onApply
Section 9 : feat(search): skeleton card masqué après chargement résultats
Tests     : test(search): widget tests + Playwright UI smoke tests
Final     : feat(search): recherche et filtres entièrement fonctionnels
```
