# Demandes « À traiter » — écran dédié + bouton compteur (Flutter)

**Date:** 2026-06-17 · **Statut:** validé (design)

## Problème

L'écran voyageur des demandes (`bid_list_screen.dart`) a **2 onglets** : « En attente » (PENDING + PAYMENT_ESCROWED, action Refuser/Accepter) et « Acceptées » (le reste, recherche + chips). Le voyageur veut un **seul écran** + un accès clair aux demandes à traiter, et un signalement (badge) à chaque nouvelle demande.

## Design validé (visuel companion)

1. **Écran principal `BidListScreen`** = l'ancien onglet « Acceptées » conservé tel quel : recherche + chips `Tous/Actifs/Clôturés` + liste avec badges de statut. Plus de `TabBar`/`TabController`.
2. **App bar** : un bouton **pill « À traiter »** (icône `inbox` + label + **badge compteur**) placé **à gauche** du bouton Scanner.
   - Compteur = nombre de bids PENDING + PAYMENT_ESCROWED.
   - **Masqué quand 0** demande à traiter (le badge est le signal d'une nouvelle demande).
3. **Tap** → nouvel écran **`PendingBidsScreen`** (route `/announcements/:id/bids/pending`), avec **back** + titre « À traiter (N) », listant les demandes en attente avec Refuser/Accepter et toute la logique d'acceptation (cash via `BidAcceptanceBloc`, carte via `BidBloc`, sheets wallet insuffisant / carte refusée, anti double-tap, dialog de refus, filtre `minBidPriceEur` + bandeau masquées).
4. **Bandeau sur la carte cash** : les bids cash (PENDING) reçoivent un bandeau d'info comme les bids carte (PAYMENT_ESCROWED), **visible avant d'ouvrir le détail**.
   - Carte (escrow) : `💳 Paiement reçu — en attente de votre réponse` (existant, inchangé).
   - Cash (PENDING) : `💵 Paiement en espèces — en attente de votre réponse` (nouveau ; même fin « en attente de votre réponse », même style `warningLight`, icône `banknote`).

## Architecture

- **Nouveau `lib/features/matching/presentation/widgets/bid_list/bid_card.dart`** — extraction de `BidCard` (ex-`_BidCard`, rendu public) + ses feuilles (`_HighlightedText`, `_MetaPill`, `_PendingActions`, `_PaymentHint` escrow+cash, `_StatusDot`). Importé par les deux écrans. Réduit `bid_list_screen.dart` (1400 → ~700 l).
- **Nouveau `lib/features/matching/presentation/screens/pending_bids_screen.dart`** — `PendingBidsScreen` (StatelessWidget, `MultiBlocProvider`: `BidBloc..BidListRequested`, `BidAcceptanceBloc`) + `_PendingBidsView` (StatefulWidget : `_processingBidIds`, accept/reject, sheets wallet/carte, reject dialog, filtre minBidPrice + bandeau masquées, swipe-delete défensif REJECTED). App bar back + titre « À traiter (N) ». Empty state si 0.
- **Modif `bid_list_screen.dart`** — supprime TabController/TabBar/`_PendingTab`/`_buildPendingTab` + sheets accept (déplacés). Body = liste « Acceptées » directe. `MultiBlocProvider` → `BidBloc` + `BidListFilterCubit` (drop `BidAcceptanceBloc`). App bar : titre « Demandes », actions `[pill À traiter si pending>0][Scanner]`.
- **Refresh** (règle CLAUDE.md) : tap pill → `await context.push('/announcements/$id/bids/pending')` puis `BidListRequested` au retour → badge + liste à jour.
- **Route** : ajout `/announcements/:id/bids/pending` → `PendingBidsScreen(announcementId)`.

## Analytics

- Nouvel event `pending_requests_opened` dans `AnalyticsEvents`, tiré à l'ouverture de `PendingBidsScreen` (`addPostFrameCallback` dans `initState`, via `getIt<AnalyticsService>()` — pattern intention d'écran, cf. `become_traveler_started`). Propriété `count` (nombre de demandes à traiter, sans PII).
- Table des events de `CLAUDE.md` mise à jour.

## Hors scope

- **Refresh côté expéditeur** (« ça ne passe pas de l'autre côté ») : l'app de l'expéditeur ne voit pas l'acceptation en temps réel — propagation cross-device (FCM/pull), distincte de cette refonte UI voyageur. Noté comme suite éventuelle.

## Tests

- Maj `bid_list_screen_test.dart` : suppression des assertions sur les 2 onglets ; vérifier liste « Acceptées » + présence/masquage du pill « À traiter » + badge compteur.
- Nouveau `pending_bids_screen_test.dart` : liste pending, Refuser/Accepter dispatch (cash→`BidAcceptanceBloc`, carte→`BidBloc`), titre « À traiter (N) », empty state.
- Nouveau `bid_card_test.dart` : bandeau cash (PENDING) vs escrow (PAYMENT_ESCROWED) vs badge statut (ACCEPTED…).
- `flutter analyze` clean, couverture ≥ 90 % du nouveau code.

## Critères d'acceptation

- [ ] Écran principal sans onglets, liste « Acceptées » conservée (recherche + chips).
- [ ] Pill « À traiter » + badge compteur à gauche de Scanner, masqué si 0.
- [ ] Tap → `PendingBidsScreen` avec back + titre « À traiter (N) » + Refuser/Accepter fonctionnels.
- [ ] Bandeau cash sur les bids PENDING, bandeau escrow inchangé.
- [ ] Retour depuis À traiter rafraîchit badge + liste.
- [ ] Event `pending_requests_opened` + table CLAUDE.md à jour.
- [ ] Tous les tests verts, ≥ 90 %.
