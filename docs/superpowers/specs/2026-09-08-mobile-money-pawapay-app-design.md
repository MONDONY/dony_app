# Rail mobile money pawaPay dans l'app (design)

**Date :** 2026-09-08
**Branche :** `feature/pawapay-mobile-money` (dony_app), base `origin/main`
**Backend :** fusionné dans `main` de `yadony-back` le 2026-09-08 (PR #270), déployé sur staging, rail fermé en production. Contrat figé, documenté dans `yadony-back/docs/stories-done/story-mobile-money-pawapay.md` et `docs/runbooks/pawapay.md`.
**Cartographie du code existant :** rapport de lecture `flutter-map.md` (annexe de la session), résumé dans la section 3.

## 1. Objectif

Permettre un envoi payé en mobile money de bout en bout depuis l'app, contre le backend pawaPay : le voyageur active son compte de versement et accepte une offre mobile money ; l'expéditeur choisit le mobile money à la création de l'offre, puis paie après acceptation dans une fenêtre de 30 minutes (validation du code PIN sur son téléphone, ou redirection Wave) ; l'app suit l'état jusqu'au séquestre, à l'échec ou à l'expiration. Test de recette sur le Redmi (Android) contre le sandbox pawaPay via staging.

## 2. Contrat backend (figé)

| Endpoint | Rôle | Réponse |
|---|---|---|
| `GET /payments/mobile-money/account` | voyageur ou expéditeur | `MobileMoneyAccountResponse` |
| `POST /payments/mobile-money/account` | activation, sans corps (numéro lu chez Firebase) | idem |
| `DELETE /payments/mobile-money/account` | désactivation | idem |
| `POST /announcements/{id}/bids` avec `paymentMethod: "MOBILE_MONEY"`, `phoneNumber` facultatif (E.164) | offre de l'expéditeur | `BidModel` |
| `POST /bids/{bidId}/mobile-money/accept` | voyageur, endpoint dédié | `MobileMoneyPaymentStatusResponse` |
| `POST /bids/{bidId}/mobile-money/initiate` corps facultatif `{"phoneNumber": "..."}` | expéditeur, 201 | idem |
| `GET /bids/{bidId}/mobile-money/status` | expéditeur ou voyageur | idem |

`MobileMoneyAccountResponse` : `status` (`NOT_CONFIGURED`, `ACTIVE`, `DISABLED`), `msisdnMasked`, `provider`, `providerLabel`, `country`, `currency`, `verifiedAt`.

`MobileMoneyPaymentStatusResponse` : `bidId`, `bidStatus`, `paymentStatus` (`PENDING`, `ESCROW`, `RELEASED`, `REFUNDED`, `CANCELLED`, ou null), `deadlineAt`, `amount`, `currency`, `deposit` (null tant qu'aucun dépôt) avec `id`, `status` (`CREATED`, `ACCEPTED`, `PROCESSING`, `COMPLETED`, `FAILED`, `SUBMIT_REJECTED`), `provider`, `providerLabel`, `msisdnMasked`, `authorizationUrl` (Wave seulement), `failureCode`, `failureMessage`.

Annonce : `acceptedPaymentMethods` (liste de chaînes) peut désormais contenir `MOBILE_MONEY` ; le backend ne l'exige pas pour accepter une offre mobile money (seuls `CASH` et `STRIPE` sont contrôlés contre cette liste), mais c'est ce que l'app envoie quand le voyageur coche la bascule.

Codes d'erreur RFC 7807 à afficher (422 sauf mention) : `mobile-money-disabled`, `mobile-money-phone-required`, `mobile-money-account-unsupported`, `mobile-money-account-required`, `mobile-money-currency-mismatch`, `mobile-money-not-available`, `payment-method-unavailable-for-currency`, `mobile-money-payer-unsupported`, `mobile-money-deposit-rejected`, `mobile-money-payment-expired`, `mobile-money-payment-not-pending` (409), `mobile-money-operation-in-progress` (409), `mobile-money-provider-unavailable` (502), `invalid-payment-method`.

Deep link de retour après Wave : le backend redirige la page de rebond vers `yadony://bids/{bidId}/mobile-money/awaiting`. Pushs existants côté backend : `MM_PAYMENT_PENDING` (expéditeur, « Payez votre envoi »), `MOBILE_MONEY_PAYMENT_CONFIRMED`, expiration, échec de dépôt, versement.

## 3. État de l'app (ce que le design change)

- `BidPaymentMethod` (`features/matching/data/models/bid_model.dart`) : `stripe`, `cash`, `wave`, `orangeMoney` ; parsing `json_serializable` sans `unknownEnumValue` : toute valeur inconnue fait planter `AnnouncementModel.fromJson` et `BidModel.fromJson`.
- Le code mobile money (datasource, repository, modèle `paymentLink`, bloc, écran `MobileMoneyAwaitingScreen`, route `/bids/:bidId/mobile-money/awaiting`) date de l'ancien socle Wave/Orange et n'a plus d'appelant.
- `_PaymentMethodSelector` de `create_bid_bottom_sheet.dart` ne propose que carte et espèces ; `createBid` sait déjà envoyer `phoneNumber`.
- `TravelerPendingBar` : « Accepter » va vers `BidAcceptanceBloc` pour les espèces, sinon `BidBloc.acceptBid` (accept classique, refusé par le backend pour un bid mobile money).
- `SenderStickyBar.hasAction` ne prévoit un bouton en `AWAITING_PAYMENT` que pour la carte. `PaiementCard` et `_CashBadge` traitent tout non-carte comme des espèces.
- `ProfileMoneySection` (« Moi ») : entrées « Recevoir mes paiements » (Stripe) et « Carte commission espèces », rien pour le mobile money.
- `create_trip_screen.dart` : `acceptedPaymentMethods` = `STRIPE` si compte Stripe complet, `CASH` selon une bascule.
- `app.dart` : liste blanche stricte des deep links (`/stripe/onboarding/complete`, `/stripe/onboarding/refresh`, `/payment/confirm`, `/tracking/scan`), pas de chemin mobile money.
- `ErrorCatalog` : aucun code `mobile-money-*`.
- `notification_route_resolver.dart` : `MM_PAYMENT_PENDING` et `MOBILE_MONEY_PAYMENT_CONFIRMED` vont au détail du bid.

## 4. Design

### 4.1 Modèles et contrat
- `BidPaymentMethod.mobileMoney` (`MOBILE_MONEY`). `wave` et `orangeMoney` restent pour lire les anciens bids, jamais proposés. Tous les parsings de cet enum passent en `unknownEnumValue` (`BidModel.paymentMethod` → `stripe`, `AnnouncementModel.acceptedPaymentMethods` : valeur inconnue ignorée via un convertisseur dédié) : une valeur future ne doit plus faire planter l'app.
- `MobileMoneyAccount` (`features/payments/data/models/mobile_money_account.dart`) : `status` (enum `MobileMoneyAccountStatus {notConfigured, active, disabled}` avec repli `notConfigured`), `msisdnMasked`, `providerLabel`, `country`, `currency`.
- `MobileMoneyPaymentStatus` (`features/matching/data/models/mobile_money_payment_status.dart`) remplace `MobileMoneyPaymentModel` : `bidId`, `bidStatus`, `paymentStatus?`, `deadlineAt?`, `amount`, `currency`, `deposit?` (`MobileMoneyDeposit` : `id`, `status`, `providerLabel`, `msisdnMasked`, `authorizationUrl?`, `failureCode?`, `failureMessage?`). Getters : `isEscrowed` (`paymentStatus == ESCROW`), `isDepositFailed` (`deposit.status ∈ {FAILED, SUBMIT_REJECTED}`), `isDepositLive` (`deposit.status ∈ {CREATED, ACCEPTED, PROCESSING}`), `isExpired` (`bidStatus == CANCELLED` ou `deadlineAt` passé sans séquestre), `isWaveRedirect` (`authorizationUrl != null`).

### 4.2 Voyageur : compte de versement
- `features/payments/data/datasources/mobile_money_account_remote_datasource.dart` (`get`, `activate`, `disable`), repository, `MobileMoneyAccountBloc` (`registerFactory`, reçoit `AnalyticsService`) : events `MobileMoneyAccountRequested`, `MobileMoneyAccountActivateRequested`, `MobileMoneyAccountDisableRequested` ; states `Initial`, `Loading`, `Loaded(account)`, `Updating(account)`, `Error(message, account?)`.
- Écran `MobileMoneyAccountScreen` (`features/payments/presentation/screens/`), route `/payments/mobile-money/account`. Trois vues : non configuré (explication « votre numéro de téléphone Yadony servira de compte de versement », bouton « Activer le versement mobile money ») ; actif (opérateur, numéro masqué, devise, bouton secondaire « Désactiver ») ; désactivé (bouton « Réactiver »). Erreurs 422 affichées par `ErrorPresenter` avec les libellés du catalogue.
- Entrée dans `ProfileMoneySection` : `DonyListTile(label: 'Versement mobile money', subtitle: 'Zone CFA, Orange Money, Wave, MTN')`, toujours visible (le backend tranche l'éligibilité). Retour : `await context.push` puis rechargement.
- Création ou édition de trajet : bascule « Mobile money » à côté de « Espèces », visible seulement si la devise du trajet est `XOF` ou `XAF` ; désactivée avec sous-titre « Activez d'abord votre versement mobile money » et lien vers l'écran de compte si le compte n'est pas actif (lu par `MobileMoneyAccountBloc` au montage). Cochée, elle ajoute `MOBILE_MONEY` à `acceptedPaymentMethods`. Préremplie à l'édition depuis l'annonce.

### 4.3 Expéditeur : création de l'offre
- `_PaymentMethodSelector` : tuile « Mobile money » (`key: 'payment-method-mobile-money'`, libellé « Orange Money, Wave, MTN… ») si `announcement.acceptedPaymentMethods.contains(mobileMoney)`. Sélection par défaut inchangée (carte si disponible, sinon espèces, sinon mobile money).
- Champ facultatif « Numéro qui paiera » sous la tuile, prérempli avec le numéro du compte Yadony si connu, validation E.164 souple (chiffres, `+` accepté) ; envoyé dans `phoneNumber` de `BidCreateRequested` (chemin `BidCreateRequested`, pas `BidCheckoutRequested`).
- Succès : `DonySuccessScreen` avec sous-titre « Le voyageur doit accepter votre offre. Vous aurez ensuite 30 minutes pour payer par mobile money. »

### 4.4 Voyageur : acceptation
- `TravelerPendingBar` : si `bid.paymentMethod == mobileMoney` → `BidBloc.add(BidAcceptMobileMoneyRequested(bid.id))`. `BidBloc` appelle `BidRepository.acceptMobileMoneyBid(bidId)` (`POST /bids/{id}/mobile-money/accept`), relit le bid (`getBid`) et émet `BidAccepted(bid)` comme l'accept classique. Analytics `bidAccepted` avec `payment_method: mobile_money`.
- Détail voyageur en `AWAITING_PAYMENT` mobile money : bandeau « En attente du paiement mobile money de l'expéditeur, 30 min » (statut lu par `GET status` via `MobileMoneyPaymentBloc`, sondage 10 s comme aujourd'hui pour le détail).
- Badges : `_CashBadge` et `PaiementCard` distinguent le mobile money (« Paiement mobile money », icône smartphone, séquestre après paiement) des espèces.

### 4.5 Expéditeur : paiement
- `SenderStickyBar.hasAction` : `AWAITING_PAYMENT` et `mobileMoney` → bouton « Payer par mobile money » → `await context.push('/bids/${bid.id}/mobile-money/awaiting')`, rechargement du détail au retour.
- `MobileMoneyPaymentBloc` réécrit (reçoit `AnalyticsService`) : events `MobileMoneyPaymentOpened(bidId)` (lit le statut ; si aucun dépôt vivant ni séquestre, lance `initiate` sans numéro), `MobileMoneyPaymentInitiateRequested(bidId, phoneNumber?)` (nouvel essai, numéro de remplacement possible), `MobileMoneyStatusPolled(bidId)`. States : `Initial`, `Loading`, `AwaitingConfirmation(status)` (dépôt vivant : consigne PIN ou bouton Wave), `Escrowed(status)`, `DepositFailed(status)`, `Expired(status)`, `Error(message)`. Le sondage toutes les 5 s vit dans l'écran (Timer) comme aujourd'hui, arrêté sur état final.
- `MobileMoneyAwaitingScreen` réécrit sur `MobileMoneyPaymentStatus` : en-tête montant et devise, opérateur et numéro masqué, compte à rebours jusqu'à `deadlineAt` (mm:ss), zone d'état : « Validez le paiement sur votre téléphone (code PIN) » ou bouton « Ouvrir Wave » (`ExternalUrlLauncher.open(authorizationUrl)`), séquestre confirmé → `DonySuccessScreen` court puis `context.pop(true)` vers le détail ; dépôt refusé → message (`failureMessage` ou libellé du code) + bouton « Réessayer » + champ « Payer avec un autre numéro » ; expiré → message et retour. Analytics : `mobileMoneyAwaiting` (ouverture), `mobileMoneyInitiated`, `mobileMoneyConfirmed`, `mobileMoneyFailed`.
- Deep link : `app.dart` accepte `yadony://bids/{uuid}/mobile-money/awaiting` (validation UUID comme `announcement_deep_link.dart`) et navigue vers la route. `notification_route_resolver.dart` : `MM_PAYMENT_PENDING` → écran d'attente ; `MOBILE_MONEY_PAYMENT_CONFIRMED` → détail du bid (inchangé).

### 4.6 Erreurs
`ErrorCatalog._byCode` reçoit les codes de la section 2 avec des libellés courts en français (titre + explication + action), par exemple `mobile-money-payer-unsupported` → « Numéro non pris en charge. Vérifiez le numéro ou essayez-en un autre. », `mobile-money-payment-expired` → « Délai dépassé. Refaites une offre au voyageur. », `mobile-money-provider-unavailable` → « Service mobile money indisponible. Réessayez dans quelques minutes. ».

## 5. Hors périmètre
- Remboursements et versements côté app : uniquement les pushs et libellés existants.
- Négociation de prix en mobile money (le backend la refuse).
- Package requests (demandes de colis) : enum parallèle laissée telle quelle, sauf robustesse au parsing si trivial.
- Suppression des valeurs `wave`/`orangeMoney` de l'enum.

## 6. Tests
- Modèles : parsing complet, valeurs inconnues, getters d'état.
- Blocs : `bloc_test` sur chaque transition, erreurs `AppException` avec code.
- Widgets : écran compte (trois vues et actions), écran d'attente (états, compte à rebours figé par `Clock` injectable ou date fixe, boutons), sélecteur avec tuile mobile money et champ numéro, `TravelerPendingBar` (dispatch vers le bon bloc), `SenderStickyBar` (bouton et navigation).
- `flutter analyze` sur tout le projet ; couverture globale ≥ 90 % visée, jamais en dessous du cliquet CI (78 %).

## 7. Décisions
- Bascule explicite « Mobile money » côté voyageur plutôt qu'une déduction automatique : `acceptedPaymentMethods` reste la seule source de ce que l'expéditeur voit, comme pour les espèces.
- Écran d'attente réutilisé (route existante, deep link backend aligné) plutôt qu'un nouvel écran : évite le code mort et l'écart avec la page de rebond.
- Sondage de 5 s pendant l'attente : le callback pawaPay arrive en secondes, le poller backend rattrape en 2 minutes ; 5 s garde l'écran réactif sans charge notable.
- Aucune saisie du numéro de versement côté voyageur, conformément au backend (numéro Firebase, jamais saisi).
