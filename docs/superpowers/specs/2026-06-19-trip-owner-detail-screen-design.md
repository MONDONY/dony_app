# Écran détail trajet (propriétaire) — Design

**Date:** 2026-06-19 · **Status:** Spec validée

## Objectif
1. Différencier visuellement la carte de trajet du voyageur connecté.
2. Rendre cette carte cliquable → écran plein écran dédié (pas bottom sheet), avec back.
3. L'écran : voir demandes, modifier, supprimer (si possible), tous les détails du
   trajet, liste des colis déjà embarqués, bouton signaler un bug en haut.

## Décisions (mockups validés)
- **Carte = Option A** : bordure `1.5px cs.primary` + chevron `›` + pill « ● Votre trajet »
  (bg primary) aligné droite sur la même ligne que « X kg dispo ».
- **Écran = Layout 2** : grille d'actions 2×2 + tous les détails + section colis.

## Architecture
- Le contenu détail existe déjà dans `announcement_detail_bottom_sheet.dart`
  (`_buildContent` + helpers). On l'EXTRAIT dans `AnnouncementDetailBody` partagé,
  consommé par le sheet ET le nouvel écran (anti-duplication).
- Route `/announcements/:id/trip` (hors shell) → `TripOwnerDetailScreen`, providers
  AnnouncementBloc(..DetailRequested) + BidBloc(..BidListRequested) + CancellationBloc.
- Écran : `DonyAppBar(actions:[DonyFeedbackButton])` + RepaintBoundary > scroll :
  hero → grille 2×2 (Demandes/Colis/Modifier/Supprimer, gating canEdit/canDelete) →
  détails complets (AnnouncementDetailBody) → `TripParcelsSection` (colis embarqués).
- Carte : variante own (bordure+chevron+pill kg-row), onTap actif.
- Feed : 3 sites + near-me → push '/announcements/:id/trip', refresh au retour.

## Gating (identique au sheet)
- Demandes visible si ACTIVE. Modifier si `canEdit = ACTIVE && bidsCount==0`.
- Supprimer si `canDelete = (ACTIVE && bidsCount==0) || CANCELLED`, sinon Annuler.
- `AnnouncementDeleteBlockedByAcceptedBid` → dialog → CancellationBottomSheet.

## Colis (TripParcelsSection)
- `getBidsForAnnouncement` (BidListRequested) filtré `isAcceptedTabBid`
  (ACCEPTED/HANDED_OVER/IN_TRANSIT/COMPLETED). Chaque colis : contenu, poids, expéditeur,
  chip statut, photo si dispo. États loading/empty/list. Tap → /bids/:bidId.

## Analytics
- `trip_owner_detail_opened` (prop status), `trip_parcels_viewed` (prop count).
- MAJ table events CLAUDE.md. Aucune PII.

## Tests ≥ 90%
- TravelerCard own (pill kg-row + chevron + onTap), TripOwnerDetailScreen (rendu+gating+nav),
  TripParcelsSection (loading/empty/list), home_screen (isOwn→push), sheet non régressé.
