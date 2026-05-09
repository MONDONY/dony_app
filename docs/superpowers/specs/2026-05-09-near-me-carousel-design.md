# Spec — Affichage du NearMeCarousel sur le home (mode "Près de moi")

**Date :** 2026-05-09
**Status :** Validé

## Contexte

Le widget `NearMeCarousel` (`lib/features/matching/presentation/widgets/near_me_carousel.dart`) existe dans la codebase mais n'est jamais instancié dans l'UI. Le seul import depuis `home_screen.dart` ne sert qu'à utiliser la fonction top-level `buildDistanceBadge`.

Aujourd'hui, quand l'utilisateur active le filtre "Près de moi", l'UI ne change pas — c'est uniquement la requête backend qui filtre par rayon. Les annonces matchantes restent affichées dans la liste verticale du `DraggableScrollableSheet`.

L'objectif est d'activer ce carousel de façon conditionnelle pour offrir une UX façon Google Maps / Airbnb quand "Près de moi" est actif.

## Objectifs

- Quand `_isNearMeActive == true`, afficher le `NearMeCarousel` à la place du `DraggableScrollableSheet`
- Synchroniser bidirectionnellement la map et le carousel via l'`id` d'annonce sélectionnée
- Conserver la cohérence avec le chantier double-bid (chip + redirection vers `/bids/{id}` si bid existant)

## Hors scope

- Modification du widget `AnnouncementMapView` (utilise déjà `selectedAnnouncementId` / `onAnnouncementSelected`)
- Refonte des autres surfaces (route_bottom_sheet, same_address_sheet)
- Modification du `dony_avatar.dart` (chantier annexe en cours)

## Architecture

### Placement dans le `Stack` du `_MapSenderView.build`

```
Stack
├─ Positioned.fill : AnnouncementMapView          (toujours)
├─ Positioned (top) : top overlay (chips, tabs)   (toujours)
├─ if (!_isNearMeActive) DraggableScrollableSheet (mode liste)
├─ if (_isNearMeActive) Positioned (bottom)
│     SizedBox(height: ~280)
│       └─ NearMeCarousel
└─ AnimatedPositioned : FAB Carte
```

### State

Réutilise les variables existantes du `_MapSenderViewState` :
- `_isNearMeActive: bool`
- `_userPosition: LatLng?`
- `_nearMeRadiusKm: double?`
- `_selectedAnnouncementId: String?` (déjà présent, sert maintenant aussi de canal de sync map↔carousel)
- `_sheetController: DraggableScrollableController` (déjà présent)

### Flow de synchronisation

**Map → carousel :**
1. L'utilisateur tape un marker
2. `AnnouncementMapView.onAnnouncementSelected(id)` est appelé
3. Le state du home met à jour `_selectedAnnouncementId`
4. Le `NearMeCarousel` reçoit le nouveau `selectedAnnouncementId` via props
5. Son `didUpdateWidget` (déjà implémenté) anime le `PageController` vers la bonne page

**Carousel → map :**
1. L'utilisateur swipe le carousel
2. `NearMeCarousel.onCardChanged(id)` est appelé
3. Le state du home met à jour `_selectedAnnouncementId`
4. La map reçoit le nouveau `selectedAnnouncementId` et highlight + recentre le marker (comportement existant d'`AnnouncementMapView`)

**Garde-fou anti-boucle :** le `setState((_selectedAnnouncementId = id))` ne déclenche pas de nouveau dispatch côté map ou carousel — chaque widget compare au précédent dans `didUpdateWidget` avant d'agir.

## Composants modifiés

### 1. `lib/features/matching/presentation/widgets/near_me_carousel.dart`

**Refactor pour permettre l'affichage en flottant fixe (hors sheet draggable) :**
- Retirer `CustomScrollView` et `SliverFillRemaining`
- Remplacer par une `Column` directe (PageView avec hauteur explicite + bouton "Voir tout")
- Retirer le paramètre `scrollController` (devenu obsolète)
- L'état empty reste géré : `if (announcements.isEmpty) return _EmptyState();`

**Conserver :**
- `selectedAnnouncementId`, `onCardChanged` (sync map↔carousel)
- `onSeeAll` (bouton "Voir les N annonces")
- `onTapCard` (callback de tap, déjà utilisé pour la logique double-bid)
- Le `BlocBuilder<BidBloc>` autour de `TravelerCard` (chantier double-bid)
- L'animation `flutter_animate` sur les cards

### 2. `lib/features/home/presentation/home_screen.dart`

**Dans `_MapSenderView.build` (autour de la ligne 577) :**

Remplacer le `DraggableScrollableSheet` inconditionnel par un branchement sur `_isNearMeActive` :

```dart
if (!_isNearMeActive)
  DraggableScrollableSheet(...)         // existant
else
  Positioned(
    left: 0, right: 0, bottom: 0,
    child: SafeArea(
      child: SizedBox(
        height: 280,
        child: NearMeCarousel(
          announcements: announcements,
          userPosition: _userPosition != null
              ? (lat: _userPosition!.latitude, lng: _userPosition!.longitude)
              : null,
          selectedAnnouncementId: _selectedAnnouncementId,
          onCardChanged: (id) =>
              setState(() => _selectedAnnouncementId = id),
          onSeeAll: _exitNearMeAndShowList,
          onTapCard: (a) => _onTravelerCardTap(context, a),
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
    ),
  ),
```

**Nouvelles méthodes privées :**

```dart
void _exitNearMeAndShowList() {
  _deactivateNearMe();
  // Anime le sheet à plein écran après le rebuild
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _sheetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  });
}

void _onTravelerCardTap(BuildContext context, AnnouncementModel a) {
  final bidState = context.read<BidBloc>().state;
  final existingBid = bidState.activeBidsByAnnouncement()[a.id];
  if (existingBid != null) {
    context.push('/bids/${existingBid.id}', extra: existingBid);
  } else {
    showTravelerAnnouncementSheet(context, announcement: a);
  }
}
```

`_deactivateNearMe()` existe déjà — il met à zéro `_isNearMeActive`, `_nearMeRadiusKm`, `_userPosition` et déclenche `_dispatchSearch()`.

## Animation

- **Activation Près de moi :** la liste du sheet se cache (le sheet disparaît du Stack), le carousel apparaît avec `fadeIn(250ms) + slideY(begin: 0.1, easeOutCubic)`
- **Désactivation Près de moi (via tap "Voir tout" ou via le chip "Près de moi") :** le carousel disparaît (rebuild sans le `Positioned`), le `DraggableScrollableSheet` réapparaît à snap 1.0 (animé via `_sheetController.animateTo`)

Conforme aux HIG du `CLAUDE.md` : durées 250–280ms, easeOutCubic.

## Tests

### Étendre `test/features/home/presentation/home_screen_test.dart`

- `quand _isNearMeActive=false, le DraggableScrollableSheet est rendu` (régression)
- `quand _isNearMeActive=true, le NearMeCarousel est rendu et le sheet est absent` (avec `BidBloc` mocké en `BidInitial`)

Note : `_isNearMeActive` n'est pas un paramètre public. Le test l'active en simulant le tap sur le chip "Près de moi" du `_HomeFilterChipsRow`, comme un utilisateur réel. Cela évite tout `@visibleForTesting` invasif et teste le flow complet (chip tap → activation du mode → rendu du carousel). Mock du `Geolocator` requis (le chip déclenche `_activateNearMe()` qui appelle `Geolocator.getCurrentPosition`).

### Créer `test/features/matching/presentation/widgets/near_me_carousel_test.dart`

Tests unitaires du widget en isolation (avec `BlocProvider<BidBloc>` + `BlocProvider<AuthBloc>` + `MaterialApp` minimaux) :

1. `affiche un PageView avec autant de pages que d'annonces`
2. `affiche le bouton "Voir les N annonces" avec le compteur`
3. `affiche l'empty state quand announcements est vide`
4. `selectedAnnouncementId initialise le PageController sur la bonne page`
5. `onCardChanged est appelé avec le bon id quand on swipe`
6. `tap sur une card sans bid existant invoque onTapCard avec l'annonce`
7. `tap sur une card avec bid PENDING invoque le navigation vers /bids/{id}` (vérification via mock GoRouter ou en interceptant le push)
8. `tap sur "Voir tout" invoque onSeeAll`

## Décisions techniques

### Pourquoi un Positioned + SizedBox plutôt qu'un Bottom Sheet draggable ?

**Choisi :** flottant fixe à hauteur 280px.

**Alternatives écartées :**
- *Bottom sheet draggable séparé pour le carousel :* duplique l'état avec celui du sheet liste, complexifie la gestion des snap-points, et le carousel n'a pas besoin d'être redimensionnable (sa hauteur est déterminée par le contenu : card + bouton).
- *Modal bottom sheet :* aurait empêché l'interaction avec la map en arrière-plan, ce qui casse le principe de la sync.

### Pourquoi désactiver Près de moi sur "Voir tout" plutôt que le garder actif ?

**Choisi :** désactiver Près de moi + ouvrir le sheet à 1.0 (validé par l'utilisateur).

**Alternative écartée :** garder le filtre rayon actif et ouvrir le sheet par-dessus le carousel. Plus cohérent côté filtre mais state dupliqué (deux UI montrent les mêmes données filtrées) et UX confuse à la fermeture du sheet.

### Pourquoi un refactor de near_me_carousel.dart plutôt qu'une utilisation telle quelle ?

Le widget est conçu pour vivre dans un parent scrollable (`CustomScrollView + SliverFillRemaining`). Le placer dans un `Positioned` fixe demanderait soit de wrapper artificiellement avec un faux scroll controller, soit de refactorer pour qu'il soit un widget non-scrollable. Le refactor est minimal (suppression de 2 wrappers + retrait du paramètre `scrollController`) et le widget n'a pas d'autres consommateurs.

## Critères d'acceptation

- [ ] Quand "Près de moi" est désactivé : UI inchangée (DraggableScrollableSheet visible, comportement actuel)
- [ ] Quand "Près de moi" est activé : carousel visible en bas, sheet caché, animation fadeIn+slideY
- [ ] Tap sur un marker de la map → le carousel saute à cette annonce (animé)
- [ ] Swipe sur le carousel → le marker correspondant est highlighté sur la map (animé)
- [ ] Tap sur une card sans bid existant → ouvre `showTravelerAnnouncementSheet`
- [ ] Tap sur une card avec bid actif → `context.push('/bids/{id}', extra: existingBid)` (cohérence chantier double-bid)
- [ ] Tap sur "Voir les N annonces" → désactive Près de moi + sheet ouvert à 1.0
- [ ] Empty state : si rayon trop petit ou aucune annonce, le carousel affiche "Aucun voyageur à proximité"
- [ ] Tous les tests passent (existants + nouveaux), couverture ≥ 90 % sur les fichiers touchés
