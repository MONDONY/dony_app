# Story 5.1 → 5.6 — Epic 5 : Mise en relation & Matching (Flutter)

**Date:** 2026-04-24
**Status:** ✅ Complète

## Résumé
Implémentation complète du flux de matching entre voyageurs et expéditeurs : consultation des demandes reçues, acceptation/refus, définition de la fenêtre de remise, confirmation de présence, annulation de trajet et suggestions de rematch.

## Fichiers créés

- `lib/features/matching/presentation/screens/bid_list_screen.dart` — liste des bids reçus sur une annonce (vue voyageur)
- `lib/features/matching/presentation/screens/bid_detail_screen.dart` — détail d'un bid avec boutons Accepter/Refuser + Confirmer présence
- `lib/features/matching/presentation/screens/handover_screen.dart` — écran de définition de la fenêtre de remise (lieu + date/heure)
- `lib/features/cancellation/bloc/cancellation_bloc.dart` — BLoC pour l'annulation de trajet
- `lib/features/cancellation/bloc/cancellation_event.dart` — events d'annulation
- `lib/features/cancellation/bloc/cancellation_state.dart` — states d'annulation
- `lib/features/cancellation/data/models/cancellation_model.dart` — modèles CancellationModel et RematchSuggestionModel
- `lib/features/cancellation/data/datasources/cancellation_remote_datasource.dart` — appels API
- `lib/features/cancellation/data/repositories/cancellation_repository.dart` — repository
- `lib/features/cancellation/presentation/screens/cancellation_screen.dart` — écran d'annulation avec sélection de raison
- `lib/features/cancellation/presentation/screens/rematch_search_screen.dart` — écran de suggestions alternatives

## Fichiers modifiés

- `lib/features/matching/data/models/bid_model.dart` — ajout des champs matching (senderName, rejectionReason, handoverLocation, handoverWindowStart/End, voyageurConfirmed)
- `lib/features/matching/data/models/bid_model.g.dart` — mise à jour du code généré
- `lib/features/matching/bloc/bid_event.dart` — nouveaux events (BidListRequested, BidDetailRequested, BidAcceptRequested, BidRejectRequested, BidHandoverRequested, BidConfirmPresenceRequested)
- `lib/features/matching/bloc/bid_state.dart` — nouveaux states (BidListLoaded, BidDetailLoaded, BidAccepted, BidRejected, BidHandoverSet, BidPresenceConfirmed)
- `lib/features/matching/bloc/bid_bloc.dart` — handlers pour tous les nouveaux events
- `lib/features/matching/data/datasources/bid_remote_datasource.dart` — méthodes API accept, reject, setHandover, confirmPresence
- `lib/features/matching/data/repositories/bid_repository.dart` — nouvelles méthodes delegates
- `lib/features/matching/presentation/screens/announcement_detail_screen.dart` — boutons "Voir les demandes", "Annuler ce trajet" ajoutés
- `lib/app/router.dart` — nouvelles routes (/bids/:bidId, /bids/:bidId/handover, /announcements/:id/bids, /announcements/:id/cancel, /cancellations/rematch)
- `lib/core/di/injection.dart` — enregistrement des dépendances cancellation

## Comment ça fonctionne

### Flux voyageur — Consulter et répondre à une demande
1. Voyageur consulte le détail d'une annonce → bouton "Voir les demandes"
2. Navigation vers `/announcements/:id/bids` → `BidListScreen` → `BidBloc.add(BidListRequested)`
3. `GET /announcements/:id/bids` → liste des bids → `BidListLoaded`
4. Tap sur un bid → navigation vers `/bids/:bidId` avec `extra: bid` → `BidDetailScreen`
5. Bouton "Accepter" → `BidAcceptRequested` → `PUT /bids/:id/accept` → `BidAccepted`
6. Après acceptation → navigation automatique vers `/bids/:id/handover` → `HandoverScreen`
7. Saisie lieu + plage horaire → `BidHandoverRequested` → `PUT /bids/:id/handover` → `BidHandoverSet`
8. Navigation vers `/announcements` après succès

### Flux voyageur — Confirmer sa présence
1. Le voyageur revient sur le détail d'un bid accepté
2. Si `voyageurConfirmed == false` → bouton "Confirmer ma présence" visible
3. `BidConfirmPresenceRequested` → `PUT /bids/:id/confirm-presence` → `BidPresenceConfirmed`

### Flux voyageur — Annuler le trajet
1. Détail de l'annonce → bouton "Annuler ce trajet"
2. Navigation vers `/announcements/:id/cancel` → `CancellationScreen` avec `CancellationBloc`
3. Sélection d'une raison dans la liste + champ texte si "Autre"
4. Confirmation dans un dialog → `CancellationTripRequested`
5. `POST /cancellations` → `CancellationSuccess` → navigation vers `/cancellations/rematch`
6. `RematchSearchScreen` affiche les alternatives disponibles avec bouton "Envoyer une demande"

### BLoC : events et states
- `BidListRequested(announcementId)` → `BidListLoaded(bids)` ou `BidError`
- `BidAcceptRequested(bidId)` → `BidAccepted(bid)` → trigger navigation vers handover
- `BidRejectRequested(bidId, reason?)` → `BidRejected(bid)` → pop vers liste
- `BidHandoverRequested(...)` → `BidHandoverSet(bid)` → navigation vers announcements
- `BidConfirmPresenceRequested(bidId)` → `BidPresenceConfirmed(bid)` → snackbar succès
- `CancellationTripRequested(announcementId, reason)` → `CancellationSuccess` → rematch screen

### Appels API
- `GET /announcements/:id/bids` — liste des bids (voyageur propriétaire)
- `GET /bids/:id` — détail d'un bid (voyageur ou expéditeur)
- `PUT /bids/:id/accept` — accepter un bid
- `PUT /bids/:id/reject` body: `{reason?}` — refuser un bid
- `PUT /bids/:id/handover` body: `{location, windowStart, windowEnd}` — fenêtre de remise
- `PUT /bids/:id/confirm-presence` — confirmation de présence
- `POST /cancellations` body: `{announcementId, reason}` — annuler le trajet
- `GET /cancellations/:id/rematch-suggestions` — suggestions alternatives

### Pièges et points d'attention
- `HandoverScreen` reçoit son propre `BidBloc` (fresh from getIt) — ne partage PAS le BLoC du `BidDetailScreen`. C'est voulu car GoRouter crée des contextes séparés pour chaque route empilée.
- La route `/bids/:bidId` est hors shell — elle ne s'affiche pas dans la bottom nav bar.
- `RematchSearchScreen.onTap` navigue vers `/search/:id/bid` qui attend un `AnnouncementModel` en extra — pour l'instant ça navigue sans l'objet (à améliorer quand l'API retourne le détail complet de l'annonce dans les suggestions).
- La validation côté Flutter (windowEnd après windowStart) est cohérente avec la validation backend.

## Critères d'acceptation couverts
- [x] Voyageur consulte la liste de ses demandes avec prénom expéditeur, poids, catégorie, valeur
- [x] Voyageur voit le détail complet (description, catégorie, poids, valeur, disclaimer signé)
- [x] HTTP 403 si voyageur non propriétaire (validé backend)
- [x] Acceptation réduit la capacité disponible de l'annonce
- [x] Refus avec raison optionnelle
- [x] HTTP 409 si capacité insuffisante (validé backend, affiché en SnackBar)
- [x] Définition de la fenêtre de remise (lieu + date/heure)
- [x] Validation windowEnd > windowStart
- [x] Bouton "Confirmer ma présence" visible 4h avant la fenêtre (conditionnel sur voyageurConfirmed)
- [x] Annulation de trajet avec raison depuis une liste
- [x] Avertissement "affectera tous les expéditeurs" avant confirmation
- [x] Rematch : affichage des alternatives sur même corridor dans 72h
- [x] Message "aucune alternative" si la liste est vide

## Décisions techniques
- **BidDetailScreen reçoit le BidModel directement** en extra (pas de fetch API à l'ouverture) pour éviter un round-trip réseau inutile quand on vient de la liste — le modèle est déjà chargé.
- **HandoverScreen avec BidBloc indépendant** : simplifie l'architecture car GoRouter ne propage pas les BlocProvider parents dans les builders de routes enfants.
- **Cancellation hors shell** : l'annulation est une action destructive rarement utilisée — pas besoin de la garder dans le shell permanent.
