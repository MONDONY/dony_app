# Story — Rail mobile money pawaPay côté app (Flutter)
**Date:** 2026-09-08 | **Status:** ✅ Complète | **Branche:** `feature/pawapay-mobile-money`

## Résumé

Le backend a remplacé les anciens stubs Wave/Orange Money par un rail mobile
money unique via l'agrégateur pawaPay (annonces en XOF/XAF, dépôt de
l'expéditeur séquestré par Yadony, versement au voyageur à la livraison). L'app
parlait encore l'ancien contrat (`paymentLink`, `regenerateLink`, méthodes
`WAVE`/`ORANGE_MONEY`). Cette story aligne l'app sur le nouveau contrat :

1. **Voyageur** : un écran « Versement mobile money » dans « Moi » active le
   compte de versement (numéro Firebase du voyageur, jamais saisi) ; une
   bascule « Mobile money » sur les trajets en zone CFA déclare le mode accepté.
2. **Expéditeur** : dans l'offre, une tuile « Mobile money » et un champ
   « Numéro qui paiera (facultatif) » pré-rempli avec son numéro ; après
   acceptation par le voyageur, un bouton « Payer par mobile money » dans le
   détail de l'envoi ouvre l'écran d'attente qui déclenche le dépôt (code PIN
   chez l'opérateur, ou redirection Wave), sonde le statut et se referme au
   séquestre.
3. **Transverse** : `MOBILE_MONEY` dans `BidPaymentMethod`, badges et carte
   paiement, 14 messages d'erreur catalogués au tutoiement, 5 events
   analytics, lien profond `yadony://bids/{uuid}/mobile-money/awaiting`, push
   `MM_PAYMENT_PENDING` routé vers l'écran d'attente.

Spécification : `docs/superpowers/specs/2026-09-08-mobile-money-pawapay-app-design.md`.
Plan (13 tâches) : `docs/superpowers/plans/2026-09-08-mobile-money-pawapay-app.md`.

## Fichiers créés / modifiés

**Modèles et données**
- `lib/features/matching/data/models/bid_model.dart` — `BidPaymentMethod.mobileMoney` (`MOBILE_MONEY`), `unknownEnumValue` vers `stripe`, `acceptedPaymentMethodsFromJson` tolérant aux valeurs inconnues (`announcement_model.dart`).
- `lib/features/matching/data/models/mobile_money_payment_status.dart` — `MobileMoneyPaymentStatus` (statut du bid, `deadlineAt` UTC, montant, dernier `MobileMoneyDeposit`) avec `isEscrowed`, `isDepositLive`, `isDepositFailed`, `isExpired(now)`, `isWaveRedirect`. Remplace `mobile_money_payment_model.dart` (supprimé).
- `lib/features/payments/data/models/mobile_money_account.dart` — compte de versement (`notConfigured`/`active`/`disabled`, numéro masqué, opérateur, pays, devise).
- `lib/features/payments/data/datasources/mobile_money_account_remote_datasource.dart`, `.../repositories/mobile_money_account_repository.dart` — `GET`/`POST`/`DELETE /payments/mobile-money/account`.
- `lib/features/matching/data/datasources/mobile_money_remote_datasource.dart`, `.../repositories/mobile_money_repository.dart` — `getStatus`, `initiate(bidId, phoneNumber?)` (`/bids/{id}/mobile-money/status|initiate`).
- `lib/features/matching/data/datasources/bid_remote_datasource.dart`, `bid_repository.dart` — `acceptMobileMoneyBid` (`POST /bids/{id}/mobile-money/accept` puis relecture du bid).
- `lib/core/di/injection.dart` — enregistrements des datasources, repositories et blocs.

**BLoC**
- `lib/features/payments/bloc/mobile_money_account_{bloc,event,state}.dart` — chargement, activation, désactivation du compte ; analytics `mobile_money_account_activated|disabled`.
- `lib/features/matching/bloc/mobile_money_payment_{bloc,event,state}.dart` — `Opened` (lit le statut, initie le dépôt si rien n'est en cours), `InitiateRequested(bidId, phoneNumber?)`, `StatusPolled` ; états `AwaitingConfirmation`, `Escrowed`, `DepositFailed`, `Expired`, `Error` ; analytics `mobile_money_initiated|confirmed|failed` une fois par transition.
- `lib/features/matching/bloc/bid_{bloc,event}.dart` — `BidAcceptMobileMoneyRequested` (analytics `bid_accepted` avec `payment_method: mobile_money`).
- `lib/features/matching/bloc/announcement_form_{bloc,event,state}.dart` — `MobileMoneyAcceptedChanged`, champ `mobileMoneyAccepted`.
- `lib/core/currency/supported_currency.dart` — `isMobileMoneyEligible` (XOF, XAF).

**Écrans et widgets**
- `lib/features/payments/presentation/screens/mobile_money_account_screen.dart` (route `/payments/mobile-money/account`, tuile dans `profile_sections.dart`).
- `lib/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart`, `.../screens/create_trip_screen.dart` — bascule « Mobile money » (visible, désactivée hors CFA ou sans compte actif, remise à zéro si la devise quitte la zone CFA), `MOBILE_MONEY` dans `paymentMethods`.
- `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart`, `.../create_bid/payer_phone.dart` — tuile, champ numéro payeur, `normalizePayerPhone`, sous-titre de succès ; jamais en mode négociation.
- `lib/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart` — pas de négociation sur un trajet qui n'accepte que le mobile money.
- `lib/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart`, `paiement_card.dart`, `.../action_bars/bid_detail_action_bars.dart`, `.../screens/bid_detail_screen.dart` — bouton « Payer par mobile money » (`AWAITING_PAYMENT`), rechargement du détail au retour, badge et carte « Paiement mobile money ».
- `lib/features/matching/presentation/widgets/bid_accept_dispatch.dart` — `dispatchBidAccept` : espèces vers `BidAcceptanceBloc`, mobile money vers `BidAcceptMobileMoneyRequested`, sinon `BidAcceptRequested` (trois sites : barre d'action, Demandes, Offres en attente).
- `lib/features/matching/presentation/screens/mobile_money_awaiting_screen.dart` — réécrit (voir plus bas).
- `lib/app/mobile_money_deep_link.dart`, `lib/app/app.dart` — résolveur de lien profond et liste ordonnée `_parameterizedResolvers` parcourue avant la liste blanche.
- `lib/features/notifications/notification_route_resolver.dart` — `MM_PAYMENT_PENDING` vers `/bids/{id}/mobile-money/awaiting`.
- `lib/core/error/error_catalog.dart` — 13 codes `mobile-money-*` et `invalid-payment-method`, `payment-method-unavailable-for-currency` mis à jour ; `lib/core/services/analytics_events.dart` et `CLAUDE.md` (table analytics).

## Comment ça fonctionne

### Flux utilisateur (étape par étape)

1. Le voyageur ouvre « Moi » puis « Versement mobile money » et active son compte : le backend prédit l'opérateur à partir de son numéro Firebase (`POST /payments/mobile-money/account`) et renvoie `active` avec le numéro masqué.
2. Sur un trajet en XOF ou XAF, l'étape « Prix et conditions » montre la bascule « Mobile money » : active seulement si le compte est actif (sinon un bouton « Activer le versement » mène à l'écran du compte). La liste envoyée porte `MOBILE_MONEY`.
3. L'expéditeur, dans la sheet d'offre, choisit « Mobile money » et laisse ou modifie le numéro payeur (normalisé : chiffres et `+` initial seulement, vide = `null`). `BidCreateRequested(paymentMethod: mobileMoney, phoneNumber: …)`.
4. Le voyageur accepte depuis la barre d'action, Demandes ou Offres en attente : `dispatchBidAccept` envoie `BidAcceptMobileMoneyRequested`, le bid passe en `AWAITING_PAYMENT` avec `deadlineAt` à +30 min ; l'expéditeur reçoit le push `MM_PAYMENT_PENDING`.
5. Depuis le détail de l'envoi (« Payer par mobile money »), le push ou le lien profond, l'écran d'attente s'ouvre : `MobileMoneyPaymentOpened` lit le statut et initie le dépôt s'il n'y en a pas de vivant. Un `Timer` sonde toutes les 5 s (`MobileMoneyStatusPolled`), un second anime le compte à rebours.
6. Code PIN : l'écran affiche « Valide le paiement sur ton téléphone… ». Wave : bouton « Ouvrir Wave » vers l'`authorizationUrl` reçue par callback backend.
7. Au séquestre (`Escrowed`), snackbar « Paiement confirmé, ton envoi est sécurisé » puis `context.pop(true)` : le détail se recharge (`onPaymentReturned`). Échec : message de l'opérateur, champ « Payer avec un autre numéro (facultatif) » et « Réessayer » (`InitiateRequested`). Expiration : « Retour » (`pop(false)`).

### BLoC : events, states, transitions

- `MobileMoneyPaymentBloc` : `Opened` → `Loading` → état dérivé du statut (`_stateFor` : `Escrowed` si séquestré, `Expired` si `deadlineAt` dépassée ou bid annulé, `DepositFailed`, `AwaitingConfirmation` si dépôt vivant) ou initiation puis état dérivé ; `StatusPolled` → réémet seulement à une transition ; `InitiateRequested` → `Loading` puis état dérivé. Les analytics ne partent qu'une fois par transition.
- `MobileMoneyAccountBloc` : `Requested` → `Loading` → `Loaded` ; `ActivateRequested`/`DisableRequested` → `Updating(account)` → `Loaded` ; `Error(error, account?)` conserve le dernier compte connu pour ne pas vider l'écran.
- `AnnouncementFormBloc` : `MobileMoneyAcceptedChanged(bool)` miroir de `CashAcceptedChanged`.

### Écrans et widgets clés

- `MobileMoneyAwaitingScreen` (`StatefulWidget` pour les deux `Timer`, aucun `setState` : `ValueNotifier<Duration>` + `ValueListenableBuilder`) : `_AwaitingBody` (montant via `formatPriceIn`, opérateur, numéro masqué, compte à rebours rouge sous 5 min, consigne PIN ou bouton Wave), `_FailedBody`, `_ExpiredBody`, `_EscrowedBody`. `listenWhen` sur changement de type d'état ; `Escrowed` et `Expired` annulent les deux timers, `DepositFailed` n'annule que le sondage, `dispose` annule tout.
- `PrixConditionsStep` : la bascule mobile money est rendue par une méthode partagée dans les deux dispositions (Stripe configuré ou non), une seule visible à la fois.
- `CreateBidBottomSheet` : `_PayerPhoneField` dans le `child` défilant (jamais dans `stickyBottom`), contrôleur disposé dans `dispose()`.

### Appels API

- `GET|POST|DELETE /payments/mobile-money/account`
- `POST /announcements/{id}/bids` avec `paymentMethod: MOBILE_MONEY`, `phoneNumber` facultatif
- `POST /bids/{id}/mobile-money/accept` (jamais l'accept classique pour un bid mobile money)
- `POST /bids/{id}/mobile-money/initiate` (`{ "phoneNumber": "…" }` facultatif), `GET /bids/{id}/mobile-money/status`

### Pièges et points d'attention

- `deadlineAt` arrive en `LocalDateTime` UTC sans suffixe de zone : `_parseUtc` force l'UTC, sinon le compte à rebours serait décalé de l'heure locale.
- Le backend refuse toute négociation en mobile money (422 `mobile-money-negotiation-unsupported`) : la sheet en mode négociation ne propose jamais la tuile, et un trajet qui n'accepte que le mobile money n'a pas d'action de négociation.
- Le numéro payeur est validé côté backend par un `@Pattern` E.164 (400) puis normalisé (422 `mobile-money-invalid-phone`) : `normalizePayerPhone` retire espaces, tirets et parenthèses avant l'envoi ; aucune autre validation côté app.
- L'ordre de repli du numéro à l'initiation est : numéro fourni sur l'écran d'attente, puis numéro de l'offre, puis téléphone Firebase de l'expéditeur.
- `CreateTripScreen` lit désormais `MobileMoneyAccountBloc` via `getIt` : tout harnais de test qui monte cet écran doit l'enregistrer (cf. `test/a11y/large_text_smoke_test.dart`).
- La bascule mobile money se remet à `false` quand la devise du trajet quitte XOF/XAF (le backend refuserait `MOBILE_MONEY` en 422).
- Le sondage continue sur l'état `Error` de l'écran d'attente (récupération automatique au retour du réseau), et `dispose` l'arrête.
- Les anciennes valeurs `WAVE`/`ORANGE_MONEY` sont tolérées en lecture (`unknownEnumValue`) mais ne sont plus proposées.

## Critères d'acceptation couverts

- [x] Le voyageur active et désactive son compte de versement depuis « Moi », avec l'état affiché (opérateur, numéro masqué, devise).
- [x] La bascule « Mobile money » n'est proposée qu'en XOF/XAF et n'est active qu'avec un compte de versement actif ; `MOBILE_MONEY` est envoyé dans `paymentMethods`.
- [x] L'expéditeur choisit le mobile money dans son offre et renseigne un numéro payeur facultatif, pré-rempli et modifiable.
- [x] Le voyageur accepte une offre mobile money depuis les trois écrans d'acceptation par l'endpoint dédié.
- [x] L'expéditeur paie depuis le détail de l'envoi, le push ou le lien profond ; l'écran gère PIN, Wave, échec avec relance, expiration et confirmation, et le détail se recharge au retour.
- [x] Badges, carte paiement, messages d'erreur (tutoiement, sans tiret cadratin) et analytics en place ; plus aucune trace de l'ancien contrat (`paymentLink`, `regenerateLink`, `MobileMoneyPaymentModel`).

## Tests

- `flutter analyze` → aucun avertissement.
- `flutter test --coverage --exclude-tags golden` → 7639 tests verts, 2 ignorés, 0 rouge (après correction du harnais d'accessibilité à 200 %).
- Couverture globale : 82,3 % de lignes (plancher CI 78 %, cible projet 90 %). Fichiers nouveaux du chantier : 100 % (modèles, datasources, repositories, blocs, écran du compte, résolveur de lien profond, `payer_phone`, `bid_accept_dispatch`, `paiement_card`) ; `mobile_money_awaiting_screen` 95 %, `sender_sticky_bar` 96 %, `create_bid_bottom_sheet` 93 %, `prix_conditions_step` 99,8 %. Les fichiers préexistants restés sous 90 % (`create_trip_screen` 83 %, `bid_detail_action_bars` 63 % dont `SenderActionBar` inutilisé, `bid_detail_screen` 35 %) le sont sur du code antérieur au chantier.
- Tests ajoutés ou réécrits : `bid_model_test`, `mobile_money_payment_status_test`, `mobile_money_account_test`, datasources et repositories mobile money, `mobile_money_account_bloc_test`, `mobile_money_payment_bloc_test`, `bid_bloc_test`, `announcement_form_bloc_test`, `error_catalog_test`, `mobile_money_account_screen_test`, `prix_conditions_step_mobile_money_test`, `create_trip_screen_test`, `create_bid_bottom_sheet_mobile_money_test`, `payer_phone_test`, `traveler_announcement_bottom_sheet_test`, `sender_sticky_bar_test` et `_mobile_money_test`, `paiement_card_test`, `bid_accept_dispatch_test`, `mobile_money_awaiting_screen_test`, `mobile_money_deep_link_test`, `notification_route_resolver_test`, `profile_screen_test`, `large_text_smoke_test`.

## Suite du 2026-09-09 : saisie du numéro quand le profil n'en a pas

Les comptes n'ont pas de numéro de téléphone tant que la vérification par SMS
(Twilio) n'est pas configurée. Règle produit : si le profil a un numéro, aucune
saisie (le backend utilise le numéro vérifié par OTP) ; sinon l'app demande le
numéro, que Twilio soit actif ou non. Côté backend, dony-back #274 accepte un
corps facultatif `{"phoneNumber"}` à l'activation, utilisé seulement sans
téléphone Firebase.

- `MobileMoneyAccountRemoteDatasource.activate({phoneNumber})`, event
  `MobileMoneyAccountActivateRequested({phoneNumber})`, état
  `MobileMoneyAccountPhoneRequired(account)` émis sur le 422
  `mobile-money-phone-required` (sans snackbar).
- `MobileMoneyAccountScreen` : `_PayoutNumberForm` (double saisie « Numéro de
  versement » / « Confirme le numéro », normalisation par `normalizePayerPhone`,
  bouton actif seulement quand les deux coïncident) affiché quand l'utilisateur
  connecté n'a pas de numéro ou sur `PhoneRequired` ; corps sous `SafeArea`.
- `MobileMoneyAwaitingScreen` : `_PhoneRequiredBody` (« Numéro qui paiera » +
  « Réessayer » → `InitiateRequested(bidId, phoneNumber)`) sur la même erreur ;
  corps sous `SafeArea`.
- Sheet d'offre : aide « Ton compte n'a pas de numéro : indique celui qui
  paiera. » ; catalogue `mobile-money-phone-required` → « Numéro manquant ».
- Piège : un numéro saisi n'est pas vérifié par OTP (risque documenté dans le
  service backend) ; le formulaire exige la double saisie pour limiter la faute
  de frappe.

## Décisions techniques

- **Le bloc initie le dépôt à l'ouverture de l'écran** plutôt qu'au tap d'un bouton : le paiement est déjà décidé par l'expéditeur au moment où il ouvre l'écran, et le bloc reste idempotent (un dépôt vivant n'est jamais doublé).
- **Compte à rebours et sondage par `Timer` + `ValueNotifier`**, sans `setState`, conformément à la règle du projet ; `listenWhen` sur le type d'état pour un `pop(true)` unique. Alternative écartée : un `Stream.periodic` dans le bloc, qui aurait lié la durée de vie du sondage à celle du bloc plutôt qu'à celle de l'écran.
- **Tutoiement** sur tous les textes (la spécification les avait au vouvoiement) : l'app tutoie partout ailleurs.
- **Bascule visible mais désactivée hors CFA** (avec la raison en sous-titre) plutôt qu'absente : l'utilisateur comprend pourquoi le mode n'est pas disponible.
- **Pas de mobile money en négociation** : reflet strict du backend, avec garde au point d'entrée pour ne jamais ouvrir un parcours voué au 422.
- **Helper `dispatchBidAccept`** plutôt que trois copies du branchement, et retrait de `MobileMoneyRepository.accept` (doublon de `BidRepository.acceptMobileMoneyBid`, sans appelant).
- **Le numéro de versement du voyageur n'est jamais saisi** : c'est son numéro Firebase, décision produit du rail backend.
