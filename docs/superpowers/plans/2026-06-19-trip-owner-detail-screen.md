# Écran détail trajet (propriétaire) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Carte « Votre trajet » cliquable (variante visuelle Option A) ouvrant un écran
plein écran (Layout 2) : grille d'actions (Demandes/Colis/Modifier/Supprimer) + tous les
détails du trajet + liste des colis embarqués + bouton signaler bug.

**Architecture:** Réutilise le contenu détail du `AnnouncementDetailBottomSheet` via un
widget partagé `AnnouncementDetailBody`. Nouvel écran routé `/announcements/:id/trip`.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, GetIt, AnnouncementBloc, BidBloc,
CancellationBloc.

---

## Task 1 — Extraire `AnnouncementDetailBody` (partagé sheet + écran)

**Files:**
- Create: `lib/features/matching/presentation/widgets/announcement_detail_body.dart`
- Modify: `lib/features/matching/presentation/widgets/announcement_detail_bottom_sheet.dart`
- Test: `test/features/matching/presentation/widgets/announcement_detail_body_test.dart`

**Étapes:**
- Déplacer `_buildContent(context, cs, tt, AnnouncementDetailLoaded state)` du sheet vers un
  `StatelessWidget` public `AnnouncementDetailBody({required AnnouncementModel a})` dans le
  nouveau fichier. Déplacer aussi les helpers privés utilisés UNIQUEMENT par ce contenu :
  `_StatusBadge`, `_SurplusSplitRow`, `_InfoPill`, `_ParcelStatsRow`, `_ParcelStatCell`,
  `_HeroChip`, `_BSectionTitle`, `_BSectionRow`, `_BChip`, `_handoverRangeLabel`. Les rendre
  privés au nouveau fichier (rester `_`).
- Dans le sheet, `_AnnouncementDetailContent._buildContent` devient
  `AnnouncementDetailBody(a: state.announcement)`. Les boutons d'action du sheet
  (`stickyBottom`, `_IconActionBtn`, `_confirmDelete`, `_onDeleteBlocked`) RESTENT dans le
  sheet (non déplacés).
- Comportement INCHANGÉ : aucune régression visuelle du sheet.
- Test : pump `AnnouncementDetailBody(a: <modèle factice ACTIVE avec pickup/handover/paiements/
  contenu>)` → trouve le corridor `Paris → Dakar`, un `_StatusBadge` (texte `ACTIF`),
  les sections présentes. Pump un modèle minimal (sans pickup/handover) → sections masquées.
- Lancer `flutter analyze` (0 erreur) + `flutter test` du fichier. Commit.

---

## Task 2 — Variante carte « Votre trajet » (Option A)

**Files:**
- Modify: `lib/features/matching/presentation/widgets/traveler_card.dart`
- Test: `test/features/matching/presentation/widgets/traveler_card_test.dart` (créer si absent)

**Étapes:**
- Bordure : ligne ~103-106, étendre la logique. Quand `isOwnAnnouncement && !hasExistingBid`
  → `color: cs.primary, width: 1.5`. (hasExistingBid garde priorité.)
- Corridor : passer un `bool showChevron` à `_RouteHeader`; quand true, ajouter après le
  `_FlagEndpoint(arrFlag)` un `SizedBox(width: DonySpacing.xs)` + `DonyIcon('chevron-right',
  size: 18, color: cs.primary)`. Le feed passe `showChevron: isOwnAnnouncement`.
- kg-row (lignes ~214-228) : envelopper dans un `Row` qui contient le bloc kg existant, puis,
  si `isOwnAnnouncement`, `const Spacer()` + un pill `_OwnTripPill()` :
  ```dart
  Row(children: [
    const DonyEmoji.parcel(size: 13),
    const SizedBox(width: DonySpacing.xxs),
    Text(... 'X kg dispo' / 'Kg libre' ...),
    if (isOwnAnnouncement) ...[ const Spacer(), const _OwnTripPill() ],
  ])
  ```
- `_OwnTripPill` : container bg `cs.primary`, radius full, padding sm/xxs, contenu
  `Row[ point ●(4px blanc) , SizedBox xxs, Text('Votre trajet', labelSmall, color: cs.onPrimary,
  w700) ]`. Key `Key('own-trip-pill')`.
- SUPPRIMER l'ancien label plat (lignes 233-236).
- Tests : (a) `isOwnAnnouncement: true` → trouve `Key('own-trip-pill')` + texte `Votre trajet` +
  l'icône chevron ; bordure primaire. (b) `isOwnAnnouncement: false` → pas de pill, label absent,
  inchangé. (c) onTap fourni → tap déclenche le callback.
- `flutter analyze` + tests. Commit.

---

## Task 3 — Route + `TripOwnerDetailScreen` (scaffold + hero + détails)

**Files:**
- Create: `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart`
- Modify: `lib/app/router.dart` (après le bloc `/announcements/:id/bids/pending`, ~ligne 627)
- Test: `test/features/matching/presentation/screens/trip_owner_detail_screen_test.dart`

**Route (router.dart):**
```dart
GoRoute(
  path: '/announcements/:id/trip',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    final extra = state.extra is AnnouncementModel ? state.extra as AnnouncementModel : null;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AnnouncementBloc>()..add(AnnouncementDetailRequested(id))),
        BlocProvider(create: (_) => getIt<BidBloc>()..add(BidListRequested(id))),
        BlocProvider(create: (_) => getIt<CancellationBloc>()),
      ],
      child: TripOwnerDetailScreen(announcementId: id, initial: extra),
    );
  },
),
```
(Ajouter les imports nécessaires en tête de router.dart.)

**Écran (TripOwnerDetailScreen) :**
- `StatefulWidget` avec `final String announcementId; final AnnouncementModel? initial;`.
- `_boundaryKey = GlobalKey()`. `initState` : `addPostFrameCallback` →
  `unawaited(getIt<AnalyticsService>().logEvent(AnalyticsEvents.tripOwnerDetailOpened,
  properties: {'status': <status courant>}))` (Task 7 fournit l'event).
- `build` :
  ```dart
  Scaffold(
    backgroundColor: cs (scaffold bg),
    appBar: DonyAppBar(title: 'Trajet', actions: [DonyFeedbackButton(repaintBoundaryKey: _boundaryKey)]),
    body: RepaintBoundary(key: _boundaryKey,
      child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: gérer AnnouncementDeleted (snackbar + context.pop(true)),
                  AnnouncementNotFound (snackbar + pop),
                  AnnouncementDeleteBlockedByAcceptedBid (dialog → CancellationBottomSheet),
                  AnnouncementError (ErrorPresenter.show),
        builder: (context, state) {
          final a = state is AnnouncementDetailLoaded ? state.announcement : initial;
          if (a == null) return loader centré;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + safeBottom),
            child: Column(children: [
              // hero + détails complets via AnnouncementDetailBody
              AnnouncementDetailBody(a: a),
              const SizedBox(height: DonySpacing.lg),
              // grille actions (Task 4) — insérée APRÈS le hero idéalement ;
              // pour cette task : placer OwnerActionGrid sous AnnouncementDetailBody
              // (Task 4 ajoute le widget). Pour l'instant placeholder SizedBox.
              const SizedBox(height: DonySpacing.lg),
              // section colis (Task 5)
            ]),
          );
        },
      ),
    ),
  )
  ```
  NOTE : pour rester bite-sized, Task 3 rend hero+détails (AnnouncementDetailBody) + AppBar+bug.
  La grille (Task 4) et la section colis (Task 5) sont ajoutées ensuite à la `Column`.
- Test : pump l'écran avec un AnnouncementBloc mocké émettant `AnnouncementDetailLoaded` →
  trouve `DonyAppBar` titre `Trajet`, le bouton bug (`DonyFeedbackButton`), le corridor.
  État loading → spinner. (Utiliser `mockAnnouncementBloc` + `BidBloc` mock émettant
  `BidListLoaded([])`.)
- `flutter analyze` + tests. Commit.

---

## Task 4 — Grille d'actions `OwnerActionGrid` (gating)

**Files:**
- Create: `lib/features/matching/presentation/widgets/owner_action_grid.dart`
- Modify: `trip_owner_detail_screen.dart` (insérer `OwnerActionGrid` après le hero)
- Test: `test/features/matching/presentation/widgets/owner_action_grid_test.dart`

**`OwnerActionGrid({required AnnouncementModel a, required bool isOwner, required GlobalKey scrollToColisKey})` :**
- Calculs (identiques au sheet) :
  ```dart
  final canEdit = a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0;
  final isCancelled = a.status == 'CANCELLED';
  final canDelete = (a.status == 'ACTIVE' && (a.bidsCount ?? 0) == 0) || isCancelled;
  ```
- Si `!isOwner` → `SizedBox.shrink()` (sécurité non-propriétaire).
- Grille 2×2 (Wrap ou GridView shrinkWrap) de tuiles `_ActionTile` (carte cs.surface, border,
  radius card, icône + label + badge compteur optionnel) :
  - **Demandes** (si ACTIVE) : iconAsset `package`, badge `a.bidsCount`, onTap →
    `context.push('/announcements/${a.id}/bids')`.
  - **Colis** : iconAsset `box`, badge `a.confirmedParcelCount`, onTap → `Scrollable.ensureVisible(
    scrollToColisKey.currentContext!)` (scroll vers la section colis).
  - **Modifier** : iconAsset `square-pen`. Si `canEdit` → onTap
    `CreateAnnouncementBottomSheet.show(context, announcement: a)` puis
    `context.read<AnnouncementBloc>().add(AnnouncementDetailRequested(a.id))`. Sinon tuile
    `opacity .4`, onTap null, tooltip `'Modifiable tant qu'aucune demande'`.
  - **Supprimer** (si `canDelete`) : iconAsset `trash-2`, couleur error. onTap → `DonyDialog.show`
    destructive (réutiliser le wording `_confirmDelete`) → si confirmé
    `context.read<AnnouncementBloc>().add(AnnouncementDeleteRequested(a.id))`.
  - Sinon, si `a.status == 'ACTIVE'` → tuile **Annuler** : iconAsset `circle-x`, couleur error,
    onTap → `CancellationBottomSheet.show(context, announcementId: a.id)`.
- Tests : (a) ACTIVE bidsCount=0 → 4 tuiles, Modifier actif, Supprimer présent.
  (b) ACTIVE bidsCount=2 → Modifier désactivé (opacity), tuile Annuler au lieu de Supprimer,
  Demandes badge `2`. (c) tap Demandes → vérifier navigation (mock GoRouter/observer).
  (d) `isOwner:false` → grille absente.
- `flutter analyze` + tests. Commit.

---

## Task 5 — Section `TripParcelsSection` (colis embarqués)

**Files:**
- Create: `lib/features/matching/presentation/widgets/trip_parcels_section.dart`
- Modify: `trip_owner_detail_screen.dart` (insérer `TripParcelsSection` en bas, avec la
  `scrollToColisKey`)
- Test: `test/features/matching/presentation/widgets/trip_parcels_section_test.dart`

**`TripParcelsSection({Key? key})` (consomme le `BidBloc` du provider de la route) :**
- Titre section `Colis dans le trajet`.
- `BlocBuilder<BidBloc, BidState>` :
  - `BidListLoaded` : filtrer `bids.where(isAcceptedTabBid)` (importer depuis
    `bid_list_filter_cubit.dart`). Si vide → `DonyEmptyState(iconAsset:'package', title:'Aucun
    colis embarqué', message:'Les colis acceptés apparaîtront ici.')`. Sinon liste de
    `_ColisRow(bid)` : ligne carte avec contenu (`contentCategory`/`description`), poids
    (`weightKg` kg), expéditeur (`senderName`), chip statut, miniature `photos.first` si dispo.
    onTap → `context.push('/bids/${bid.id}')`.
  - loading/initial → spinner.
- Au premier `BidListLoaded` non vide : `unawaited(logEvent(AnalyticsEvents.tripParcelsViewed,
  properties: {'count': filtered.length}))` (déclenché une fois via un flag local).
- Tests : (a) `BidListLoaded([])` → empty state. (b) `BidListLoaded([accepted, pending])` →
  affiche seulement le colis accepté (1 `_ColisRow`). (c) loading → spinner.
- `flutter analyze` + tests. Commit.

---

## Task 6 — Wiring feed (`home_screen.dart`)

**Files:**
- Modify: `lib/features/home/presentation/home_screen.dart`
- Test: `test/features/home/presentation/home_screen_*` (ajouter un test ciblé si faisable,
  sinon test widget minimal du tap own-card)

**Étapes:**
- Aux 3 sites `TravelerCard` (interleaved ~:1648, single ~:1881) et au handler near-me
  `_onTravelerCardTap` (~:593) : pour `isOwn`, remplacer `onTap: null` par :
  ```dart
  onTap: () async {
    final changed = await context.push<bool>('/announcements/${a.id}/trip', extra: a);
    if ((changed ?? false) && context.mounted) {
      // recharger le feed (même event que le pull-to-refresh existant)
      <reload feed bloc event>;
    }
  },
  ```
  Passer aussi `showChevron`/variante via `isOwnAnnouncement: isOwn` (déjà transmis).
- Identifier l'event de reload du feed déjà utilisé (pull-to-refresh) et le réutiliser.
- Test : monter le feed avec une annonce dont `travelerId == currentUserId`, taper la carte,
  vérifier la navigation vers `/announcements/:id/trip` (mock observer).
- `flutter analyze` + tests. Commit.

---

## Task 7 — Analytics + doc

**Files:**
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `dony_app/CLAUDE.md` (table des events)
- (les `logEvent` sont déjà câblés dans Tasks 3 & 5)

**Étapes:**
- Ajouter dans `AnalyticsEvents` :
  ```dart
  static const tripOwnerDetailOpened = 'trip_owner_detail_opened';
  static const tripParcelsViewed = 'trip_parcels_viewed';
  ```
- Ajouter 2 lignes à la table des events du `CLAUDE.md` (déclencheurs : ouverture écran détail
  trajet propriétaire / chargement section colis).
- Vérifier : aucune PII (status, count uniquement).
- `flutter analyze`. Commit.

---

## Final — Revue + couverture
- `flutter analyze` global = 0 erreur.
- `flutter test --coverage` : tous verts, couverture ≥ 90 % sur les fichiers ajoutés.
- Revue finale (code reviewer) de l'ensemble du diff.
