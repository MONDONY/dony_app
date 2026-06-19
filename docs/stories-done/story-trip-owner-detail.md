# Story — Écran détail trajet propriétaire (Flutter)
**Date:** 2026-06-19 | **Status:** ✅ Complète | **Branche:** `feature/trip-owner-detail` (PR #109)

## Résumé

La carte de trajet du voyageur connecté (« Votre trajet ») était auparavant non
cliquable, et le détail d'un trajet côté propriétaire s'ouvrait dans un bottom
sheet. Cette story :

1. Rend la carte « Votre trajet » **visuellement distincte** (bordure 1.5 px
   primary + chevron + pill « Votre trajet ») et **cliquable**.
2. Remplace le bottom sheet par un **écran plein écran** dédié
   (`TripOwnerDetailScreen`), accessible depuis le feed Accueil **et** depuis
   l'onglet Activités → Trajets.
3. Ajoute une **grille d'actions** propriétaire (Demandes / Colis / Modifier /
   Supprimer) et une **section des colis embarqués** avec **filtre rapide par
   statut**.

## Fichiers créés / modifiés

**Créés**
- `lib/features/matching/presentation/screens/trip_owner_detail_screen.dart` — écran plein écran.
- `lib/features/matching/presentation/widgets/owner_action_grid.dart` — grille d'actions 2×2.
- `lib/features/matching/presentation/widgets/trip_parcels_section.dart` — section colis embarqués + filtre statut.
- `lib/features/matching/presentation/widgets/announcement_detail_body.dart` — corps de détail partagé (extrait, voir ci-dessous).
- Tests : `trip_owner_detail_screen_test.dart`, `owner_action_grid_test.dart`, `trip_parcels_section_test.dart`, `announcement_detail_body_test.dart`.
- `docs/superpowers/specs/2026-06-19-trip-owner-detail-screen-design.md` + `docs/superpowers/plans/2026-06-19-trip-owner-detail-screen.md`.

**Modifiés**
- `lib/app/router.dart` — route `/announcements/:id/trip` ; param `title` relayé à `/announcements/:id/bids`.
- `lib/features/matching/presentation/widgets/traveler_card.dart` — variante visuelle « Votre trajet ».
- `lib/features/home/presentation/home_screen.dart` — 3 sites `TravelerCard` + near-me poussent l'écran détail (refresh au retour).
- `lib/features/matching/presentation/screens/announcement_list_screen.dart` — Activités → Trajets : tap d'une `TripCard` pousse l'écran détail (au lieu du bottom sheet).
- `lib/features/matching/presentation/screens/bid_list_screen.dart` — param `title` (« Demandes » par défaut, « Colis » depuis le bouton Colis).
- `lib/features/matching/bloc/bid_list_filter_cubit.dart` — helper partagé `isPendingBid`.
- `lib/core/services/analytics_events.dart` — events `trip_owner_detail_opened`, `trip_parcels_viewed`, `trip_parcels_filtered`.
- `CLAUDE.md` — table des events analytics.

**Supprimé**
- `announcement_detail_bottom_sheet.dart` (+ son test) — devenu code mort après le passage à l'écran plein écran. Son corps a d'abord été extrait dans `AnnouncementDetailBody` (renommage `R065` dans git).

## Comment ça fonctionne

### Flux utilisateur (étape par étape)

1. **Repérage** — Dans le feed Accueil ou dans Activités → Trajets, la carte du
   trajet de l'utilisateur connecté affiche une bordure primary, un chevron et
   une pill « Votre trajet » (sur la ligne des kg dispo). C'est la seule carte
   cliquable parmi les trajets affichés.
2. **Ouverture** — Tap → `context.push('/announcements/:id/trip', extra: a)`.
   L'`extra` (`AnnouncementModel`) permet un premier rendu instantané pendant
   que le détail complet se recharge.
3. **Détail** — L'écran affiche, dans l'ordre : `AnnouncementDetailBody` (hero,
   capacité/prix, stats colis, lieux de remise, fenêtre, paiements, contenus
   accepté/refusé), la grille d'actions, puis la section des colis embarqués.
4. **Actions** :
   - **Demandes** → écran « À traiter » (`PendingBidsScreen`). Désactivé s'il
     n'y a aucune demande en attente ; le badge affiche le nombre en attente.
   - **Colis** → écran des colis (`BidListScreen`, titré « Colis »). Désactivé
     s'il n'y a aucun colis embarqué.
   - **Modifier** → `CreateAnnouncementBottomSheet`. Désactivé (grisé + tooltip)
     tant qu'une demande existe (`bidsCount > 0`).
   - **Supprimer** (si supprimable) ou **Annuler** (si ACTIVE non supprimable).
     Suppression bloquée par un colis accepté → dialog → annulation du voyage
     (`CancellationBottomSheet`).
5. **Section colis** — Liste des colis réellement embarqués. Un filtre rapide
   par statut (chips « Tous » + statuts présents) apparaît dès qu'il y a ≥ 2
   statuts distincts. Tap sur un colis → `/bids/:bidId`.
6. **Retour** — `context.pop(true)` après suppression/annulation/édition signale
   un changement ; l'écran appelant rafraîchit sa liste (`_dispatchSearch` côté
   Accueil, `AnnouncementListRequested` côté Activités).

### BLoC : events, states, transitions

L'écran ne possède pas de BLoC dédié ; il **compose** trois BLoCs fournis par la
route via `MultiBlocProvider` :

- **`AnnouncementBloc`** — `AnnouncementDetailRequested(id)` au montage →
  `AnnouncementDetailLoaded(announcement)`. `AnnouncementDeleteRequested(id)` →
  `AnnouncementDeleted` (pop true) / `AnnouncementDeleteBlockedByAcceptedBid`
  (dialog annulation) / `AnnouncementNotFound` (pop true) / `AnnouncementError`.
- **`BidBloc`** — `BidListRequested(id)` → `BidListLoaded(bids)`. Source de
  vérité des compteurs « demandes à traiter » et « colis embarqués » :
  - `pendingCount = bids.where(isPendingBid).length` (PENDING / PAYMENT_ESCROWED).
  - `colisCount = bids.where(isAcceptedTabBid).length`.
  `OwnerActionGrid` lit ce BLoC via `context.watch` → les tuiles Demandes/Colis
  se réactivent automatiquement dès que la liste arrive (repli sur le modèle
  tant que `BidListLoaded` n'est pas émis).
- **`CancellationBloc`** — fourni pour `CancellationBottomSheet`.

`_isOwner` lit l'`AuthBloc` global (`AuthAuthenticated.user.id == a.travelerId`)
dans un `try/catch` ; en l'absence d'utilisateur, l'écran masque toutes les
actions (sécurité non-propriétaire — `OwnerActionGrid` retourne `SizedBox.shrink`).

### Écrans et widgets clés

- **`TripOwnerDetailScreen`** — `DonyAppBar(title: 'Trajet')` + `DonyFeedbackButton`
  (capture via `RepaintBoundary`). `BlocConsumer<AnnouncementBloc>` :
  listener gère pop/dialog/erreur, builder rend le corps. Émet
  `trip_owner_detail_opened` (propriété `status`) au montage.
- **`OwnerActionGrid`** — grille 2 colonnes. Helper top-level `_tile(...)` :
  quand `onTap == null` et `disabledMessage` fourni → tuile grisée (opacity 0.4)
  + `Tooltip`, non tappable. Gating : `canEdit = ACTIVE && bidsCount == 0` ;
  `canDelete = (ACTIVE && bidsCount == 0) || CANCELLED`.
- **`TripParcelsSection`** — `BlocBuilder<BidBloc>`. Filtre `isAcceptedTabBid`.
  Filtre statut local via `ValueNotifier<String?>` (pas de `setState`) +
  `StatusChipsRow<String?>` (réutilisé d'`activity_header_widgets`). Repli sur
  « Tous » si le statut filtré disparaît après rechargement. `_statusMeta`
  (libellé FR + couleur) partagé entre la chip de ligne et la chip de filtre.
- **`AnnouncementDetailBody`** — présentation pure du détail trajet, partagée à
  l'origine entre le bottom sheet et l'écran ; depuis la suppression du sheet,
  consommée uniquement par l'écran.
- **`TravelerCard` / `_RouteHeader`** — variante « Votre trajet » :
  `isOwnAnnouncement && !hasExistingBid` → bordure `cs.primary` 1.5 px, chevron,
  pill `Key('own-trip-pill')` sur la ligne des kg.
- **`BidListScreen`** — param `title` (« Demandes » défaut / « Colis »). La liste
  principale = colis acceptés (`isAcceptedTabBid`) ; bouton app bar « À traiter »
  → `PendingBidsScreen`.

### Appels API

- `GET /announcements/{id}` — détail (via `AnnouncementDetailRequested`).
- `GET /announcements/{id}/bids` — bids du trajet (via `BidListRequested`).
- `GET /announcements/my` — expose `pendingBidCount` et `confirmedParcelCount`
  (repli des compteurs de la grille quand le BidBloc n'a pas encore répondu).
- Suppression : `AnnouncementDeleteRequested` → endpoint de soft delete annonce.
- Erreurs : `ErrorPresenter` (RFC 7807 côté back).

### Pièges et points d'attention

- **Compteurs de la grille** : `AnnouncementModel.pendingBidCount` vaut `0` si
  l'endpoint ne l'expose pas (ex. detail/search). D'où le `context.watch<BidBloc>`
  comme source de vérité réelle, avec repli sur le modèle. Tant que le BidBloc
  n'est pas chargé, Demandes/Colis peuvent apparaître désactivés une fraction de
  seconde puis se réactiver.
- **Titre « Colis »** : appliqué **uniquement** quand l'écran `BidListScreen` est
  ouvert depuis le bouton Colis (via `extra: {'title': 'Colis'}`). Les autres
  entrées (notification `BID_CREATED`, détail annonce) gardent « Demandes ».
- **Bottom sheet supprimé** : ne plus référencer `announcement_detail_bottom_sheet`.
  Toute la logique d'action vit désormais dans `OwnerActionGrid`.
- **Refresh au retour** : tout `context.push` vers l'écran détail doit être
  `await` + reload conditionnel (cf. règle « Rafraîchissement des données après
  navigation » du CLAUDE.md).
- **Boutons en bottom sheet** : `CreateAnnouncementBottomSheet` /
  `CancellationBottomSheet` suivent la règle `stickyBottom`.

## Critères d'acceptation couverts

- [x] Carte « Votre trajet » visuellement distincte des cartes des autres voyageurs.
- [x] Carte « Votre trajet » cliquable → écran plein écran (pas bottom sheet) avec bouton retour.
- [x] Écran contient : Modifier, Supprimer (ou Annuler), Demandes, infos colis embarqués, bouton signalement de bug.
- [x] Tous les détails du trajet affichés.
- [x] Accès identique depuis Accueil et depuis Activités → Trajets (bottom sheet remplacé).
- [x] Demandes → écran « À traiter », désactivé si aucune demande en attente.
- [x] Colis → écran des colis, désactivé si aucun colis embarqué.
- [x] Filtre rapide par statut dans la section colis.
- [x] BLoC (no `setState`), GoRouter (no `Navigator.push`).
- [x] Analytics : nouveaux events déclarés + tirés, aucune PII.
- [x] Tous les tests passent (suite complète verte, 4192 passés) ; analyze 0 erreur/warning.

## Décisions techniques

- **Pas de BLoC dédié** : l'écran compose `AnnouncementBloc` + `BidBloc` +
  `CancellationBloc` déjà existants → zéro duplication d'état.
- **Extraction `AnnouncementDetailBody`** : anti-duplication entre l'ancien
  bottom sheet et le nouvel écran ; le sheet a ensuite été supprimé (code mort).
- **Compteurs réactifs via `context.watch<BidBloc>`** plutôt que le seul modèle :
  robuste quel que soit l'endpoint qui a chargé l'annonce.
- **Filtre statut en `ValueNotifier`** (pas de Cubit dédié) : état purement local
  d'UI, conforme à la règle « jamais `setState` » sans surcharger la DI.
- **Réutilisation `StatusChipsRow`** (du header Activités) pour la cohérence
  visuelle des chips de filtre.
- **Titre paramétrable** de `BidListScreen` via `extra` : « Colis » depuis le
  bouton Colis, « Demandes » ailleurs — un seul écran, deux intitulés selon le
  contexte d'entrée.
