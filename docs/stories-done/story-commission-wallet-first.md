# Story — Commission Dony : wallet prioritaire + UI (Flutter)

**Date:** 2026-06-02
**Status:** ✅ Complète

## Résumé
Côté app, la feature « commission wallet prioritaire / carte en fallback » se traduit par : (1) gérer la réponse **409 INSUFFICIENT_WALLET** à l'acceptation d'un bid cash (proposer recharge ou paiement carte), (2) **ne plus exiger** de carte commission pour activer le toggle « Espèces » à la publication d'un trajet, (3) afficher un **encart explicatif** quand le voyageur active « Espèces », et (4) proposer le paiement en espèces à l'expéditeur quand l'annonce l'accepte.

## Fichiers créés
- `features/matching/presentation/widgets/cash_commission_notice.dart` — encart `CashCommissionNotice` (RichText) rappelant la règle wallet-first / recharge-ou-carte. Réutilisé dans les deux UI de publication.

## Fichiers modifiés
- `features/matching/data/models/acceptance_response.dart` — enum `insufficientWallet` + champs `availableBalance, requiredCommission, hasCard` ; parsing `INSUFFICIENT_WALLET`.
- `features/matching/data/datasources/bid_remote_datasource.dart` — `acceptBidWithCommission(bidId, {commissionSource='WALLET_FIRST'})` (query param) ; reparse des 409/422 ; `confirmCommissionAcceptance` reparse 422.
- `features/matching/data/repositories/bid_repository.dart` — passe `commissionSource`.
- `features/matching/bloc/bid_acceptance_*.dart` — état `BidWalletInsufficient(...)`, event `BidAcceptWithCardRequested`, `_handleResponse` gère les 4 statuts.
- `features/matching/presentation/screens/bid_detail_screen.dart` + `bid_list_screen.dart` — `_showWalletInsufficientSheet` (boutons dans `stickyBottom`), navigation top-up `/payments/wallet/topup/method`.
- `features/matching/presentation/screens/create_announcement_screen.dart` — toggle « Espèces » toujours actif + `CashCommissionNotice` révélé (AnimatedSize) quand activé ; suppression du gate carte commission.
- `features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart` — idem pour la variante bottom-sheet.

## Comment ça fonctionne

### Flux utilisateur — acceptation bid cash (voyageur)
1. Le voyageur accepte un bid cash → `BidAcceptRequested` → `acceptBidWithCommission(bidId, commissionSource: 'WALLET_FIRST')`.
2. **200** → `BidAccepted`. **202** → 3DS (`BidRequires3ds`). **409** → `BidWalletInsufficient(available, required, hasCard)`. **422** → `BidAcceptFailed`.
3. Sur `BidWalletInsufficient`, `_showWalletInsufficientSheet` propose : **« Recharger mon wallet »** (`context.push('/payments/wallet/topup/method')` puis re-`BidAcceptRequested`), et si `hasCard` **« Payer par carte »** (`BidAcceptWithCardRequested` → `commissionSource: CARD`), sinon **« Ajouter une carte »**.

### Flux utilisateur — publication trajet (voyageur)
- Le toggle « Espèces » est **toujours activable** (la capacité de prélèvement est vérifiée à l'acceptation, pas ici).
- Quand activé, `CashCommissionNotice` apparaît : « Vous ne pourrez accepter un colis en espèces que si la commission Dony peut être prélevée **sur votre wallet en priorité**. À défaut, il faudra le recharger ou enregistrer une carte valide au moment d'accepter. »
- À la soumission : `acceptedPaymentMethods = ['STRIPE', if cashEnabled 'CASH']`.

### Flux utilisateur — demande d'envoi (expéditeur)
- `CreateBidBottomSheet` lit `announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash)`. Si vrai, le sélecteur de paiement propose la tuile **« En espèces »** à l'expéditeur (à côté de Stripe / Wave / Orange Money). Le choix CASH déclenche `BidCreateRequested(paymentMethod: cash)`.

### BLoC — states/events
- `BidWalletInsufficient(availableBalance, requiredCommission, hasCard, bidId)` ; event `BidAcceptWithCardRequested(bidId)`.
- Retry wallet après recharge = ré-émission de `BidAcceptRequested` (idempotent côté back).

### Pièges et points d'attention
- **DonyButton dans bottom sheets** : tous les boutons du `_showWalletInsufficientSheet` sont dans `stickyBottom` (règle projet).
- **Encart animé** : `CashCommissionNotice` est enveloppé d'un `.animate().fadeIn(200ms)` dans un `AnimatedSize`. En test widget, après avoir tapé le toggle il faut `pump(Duration(milliseconds: 300))` pour vider le timer du fadeIn (sinon « A Timer is still pending »).
- **Imports morts** : la suppression du gate carte a rendu inutilisés `commission_method_*` dans les écrans de publication — nettoyés.

## Critères d'acceptation couverts
- [x] 409 INSUFFICIENT_WALLET géré : recharge ou carte proposées selon `hasCard`.
- [x] Toggle « Espèces » activable sans carte commission ; ancien lien « Ajouter une carte commission » supprimé.
- [x] Message explicatif affiché à l'activation du toggle « Espèces ».
- [x] Paiement espèces proposé à l'expéditeur quand l'annonce l'accepte.

## Tests
- Tests ciblés (suite complète non relancée — politique projet) :
  - `create_announcement_cash_toggle_test.dart` — 5 tests (toggle toujours actif, encart révélé/masqué, submit inclut CASH, edit-mode ON).
  - `prix_conditions_step_test.dart` + `prix_conditions_step_interactions_test.dart` + `create_announcement_bottom_sheet_test.dart` + `create_announcement_capacity_submit_test.dart` — tous verts (48 tests).
- `flutter analyze` → 0 erreur sur les fichiers modifiés (lints info pré-existants uniquement).
- Tests réécrits pour refléter la nouvelle règle (toggle toujours actif) : les assertions « switch désactivé sans carte » ont été remplacées par « switch activable » + `add-commission-card-link` absent.

## Décisions techniques
- **Encart partagé `CashCommissionNotice`** (DRY) : un seul widget pour les deux UI de publication (écran plein + bottom-sheet).
- **Part « expéditeur » déjà en place** : le sélecteur de paiement de `CreateBidBottomSheet` proposait déjà la tuile cash conditionnée à `acceptedPaymentMethods` — aucune modification nécessaire, l'aller-retour `CASH` (publication → annonce → demande) est validé par `create_announcement_cash_toggle_test`.
