# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project: Yadony Mobile App (Flutter)

P2P marketplace mobile pour la diaspora africaine (transport de colis vers l'Afrique).

**Stack:** Flutter/Dart · flutter_bloc · GoRouter · Dio · Hive · Firebase Auth (Phone) · Stripe · FCM · Sentry  
Min SDK: iOS 14+ / Android 8.0+ (API 26)

---

## Branding — RÈGLE ABSOLUE

- Le nom public de l'application et de la marque est **Yadony**.
- Toute copie visible par l'utilisateur doit écrire **Yadony**, avec cette casse exacte. Ne jamais afficher « Dony » pour désigner l'application ou la marque.
- `dony_app`, les classes/widgets `Dony*`, les packages, chemins, clés et le schème historique `dony://` sont des identifiants techniques internes. Ils ne définissent pas le nom public et ne doivent pas être renommés sans une migration dédiée.
- Lors de toute création ou modification d'écran, vérifier les titres, descriptions, messages, semantics et textes d'accessibilité afin qu'aucun nom public « Dony » ne soit introduit.

---

## Démarrage rapide — Émulateur Android (WSL2)

> L'IP WSL2 change à chaque redémarrage — toujours refaire l'étape 2.  
> `android/app/src/debug/AndroidManifest.xml` autorise déjà le HTTP cleartext en debug.

**1. Démarrer Spring Boot** (garder le terminal ouvert) :
```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony-back
./mvnw spring-boot:run -Dspring.profiles.active=dev
```

**2. Mettre à jour `env.dev.json`** :
```bash
WSL_IP=$(hostname -I | awk '{print $1}') && \
sed -i "s|\"API_BASE_URL\": \"http://[^\"]*\"|\"API_BASE_URL\": \"http://$WSL_IP:8080/api/v1\"|" env.dev.json
```

**3. Lancer Flutter** :
```bash
adb devices  # vérifier l'émulateur
flutter run --dart-define-from-file=env.dev.json -d emulator-5554
```

| Problème | Solution |
|----------|----------|
| `Connection refused` | Refaire étape 2 (IP périmée) ou démarrer Spring Boot (étape 1) |
| `emulator offline` | `adb kill-server && adb start-server` |
| Back ne reçoit rien | Vérifier `server.address=0.0.0.0` dans `application-dev.yml` |
| HTTP bloqué | Vérifier `android/app/src/debug/AndroidManifest.xml` |

---

## Commands

```bash
# Dev
flutter run --dart-define-from-file=env.dev.json [-d <device-id>]
flutter clean && flutter pub get && flutter run --dart-define-from-file=env.dev.json

# Qualité
flutter analyze && dart fix --apply && dart format lib/ test/

# Tests
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Build
flutter build apk --dart-define-from-file=env.prod.json --release
flutter build appbundle --dart-define-from-file=env.prod.json --release

# Code gen
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Architecture (Feature-First)

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart          # GoRouter — TOUTES les routes ici
│   └── theme.dart
├── core/
│   ├── di/injection.dart    # GetIt DI setup
│   ├── network/
│   │   ├── api_client.dart  # Instance Dio unique
│   │   └── auth_interceptor.dart
│   ├── storage/hive_service.dart
│   ├── error/
│   └── constants/
└── features/
    ├── auth/
    ├── kyc/
    ├── matching/
    ├── cancellation/        # DÉDIÉ — jamais dans matching/
    ├── tracking/            # offline_queue.dart (Hive)
    ├── payments/
    ├── notifications/
    ├── disputes/
    └── admin/
```

**Règle absolue :** chaque feature = exactement `bloc/` + `data/` + `presentation/`.  
`data/` contient : `models/`, `repositories/`, `datasources/`.

---

## Core Principles

### 1. State Management — flutter_bloc (JAMAIS setState)

- Events : suffixe `Requested` (`BidCreateRequested`, `TrackingQrScannedRequested`)
- States : sealed class → `Initial`, `Loading`, `Success`/`Authenticated`, `Error`
- Dans les widgets : `BlocConsumer` — `listener` pour navigation/snackbar, `builder` pour l'UI
- DI : `BlocProvider(create: (_) => getIt<XxxBloc>())` groupés dans `MultiBlocProvider`

### 2. Navigation — GoRouter (JAMAIS Navigator.push)

- Toutes les routes dans `lib/app/router.dart`
- Auth guard via `redirect` callback
- `context.go('/home')` · `context.push('/path', extra: data)` · `context.pop()`
- Deep links : `dony://payment/confirm?payment_intent=pi_xxx` · `dony://tracking/scan?bid_id=xxx` · `https://dony.app/tracking/{token}`

### 3. HTTP — Dio + AuthInterceptor (JAMAIS package http)

- Instance unique dans `ApiClient(baseUrl: ...)`
- `AuthInterceptor` injecte automatiquement le Firebase ID token sur chaque requête
- Timeouts : 10 s connect, 30 s receive. Retry avec exponential backoff sur erreurs réseau.

### 4. Environnement

```json
{ "API_BASE_URL": "http://<IP-WSL>:8080/api/v1", "FIREBASE_PROJECT_ID": "dony-dev",
  "STRIPE_PUBLISHABLE_KEY": "pk_test_xxx", "SENTRY_DSN": "..." }
```
Accès : `const x = String.fromEnvironment('API_BASE_URL');`  
Ne jamais hardcoder — toujours `--dart-define-from-file`.

### 5. Dependency Injection — GetIt (JAMAIS instancier directement)

- `registerLazySingleton` : Core, Repositories, Datasources
- `registerFactory` : BLoCs (nouvelle instance à chaque fois)
- Enregistrement dans `lib/core/di/injection.dart`

### 6. Hive — Stockage local

**Uniquement pour :** PIN (chiffré via `flutter_secure_storage`), queue QR offline (`OfflineScanEntry`).  
**Jamais :** tokens Firebase (`FirebaseAuth.instance.currentUser`), données KYC, données sensibles en clair.

`OfflineScanEntry` : `bidId`, `qrCode`, `gpsLat?`, `gpsLon?`, `photoPath?`, `timestamp`, `synced`.

### 7. Offline QR Scanning (CRITIQUE métier)

Les scans QR fonctionnent sans connexion :
- En ligne → `TrackingRepository.submitQrScan()` immédiatement
- Hors ligne → sauvegarde dans `OfflineQueue` (Hive), afficher "En attente de synchronisation…"
- `connectivity_plus` → dès reconnexion, `TrackingSyncRequested` déclenche la synchro (< 30 s, NFR1)
- Le backend valide que `offlineTimestamp` n'est pas dans le futur (anti-fraude)

### 8. QR Photo + GPS

- Capturer `Geolocator.getCurrentPosition()` **avant** `ImagePicker.pickImage()`
- Écrire lat/lon dans les métadonnées EXIF (package `exif`)
- Photo : qualité 85 %, max 1920×1080, taille max 10 MB (valider avant upload)

### 9. Biométrie et code PIN — Paiements (NFR14)

**Les protections locales sont facultatives et désactivées par défaut.** Elles ne sont plus imposées à l'inscription : l'utilisateur les active lui-même dans Réglages › Sécurité.

Avant tout paiement, passer par `requirePaymentAuth` (`features/payments/presentation/payment_auth.dart`), qui applique dans l'ordre :
1. biométrie si `kBiometricEnabled` est activé et le capteur disponible ;
2. sinon code PIN, **uniquement si l'utilisateur en a créé un** (`LocalAuthService.isPinSet`) ;
3. ni l'un ni l'autre → le paiement suit son cours. Réclamer un code inexistant rendrait tout paiement impossible.

Le verrouillage à l'ouverture suit la même règle : actif **si et seulement si** un PIN existe. Ne pas introduire de drapeau « PIN activé » séparé, le secure storage est la source de vérité.

### 10. FCM — Notifications

- Au démarrage : `PUT /users/me/fcm-token`. Réémettre sur `onTokenRefresh`.
- `POST /notifications/{id}/ack` pour toutes les notifications critiques (paiement, livraison, litige).
- Handler background = fonction top-level annotée `@pragma('vm:entry-point')`.

---

## Git Workflow — OBLIGATOIRE

- Ne jamais commit directement sur `main` — toujours créer une branche dédiée
- Nommage : `feature/<nom>`, `fix/<nom>`, `chore/<nom>`
- Ne jamais inclure `Co-Authored-By: Claude` dans les messages de commit — les commits sont au nom du développeur uniquement

---

## Analytics — PostHog (OBLIGATOIRE)

> **Règle absolue :** tout nouvel écran et toute nouvelle action métier doivent être trackés. Toute modification d'un écran existant doit vérifier et mettre à jour le tracking associé.

### Architecture

```
PostHog SDK (posthog_flutter)
    └── AnalyticsService          lib/core/services/analytics_service.dart
            ├── isEnabled gate    (configuré ET consentement = true)
            ├── AnalyticsBackend  abstraction mockable en test
            └── logEvent / logScreen / identify / reset

AnalyticsEvents                   lib/core/services/analytics_events.dart
    └── static const String       tous les noms d'events, snake_case

AnalyticsBlocObserver             lib/core/services/analytics_bloc_observer.dart
    └── onError → bloc_error      capture globale des erreurs BLoC
```

### Screen tracking — automatique

Le `PosthogObserver` est attaché au GoRouter dans `lib/app/router.dart`. Chaque navigation vers une route envoie automatiquement un `$screen`. **Pas besoin d'appeler `logScreen()` manuellement** pour le suivi de navigation de base.

Exception : si un écran a plusieurs états visuels distincts qui valent la peine d'être distingués (ex: step 1 / step 2 d'un wizard), utiliser `logScreen()` manuellement au changement d'état.

### Custom events — règles

**1. Tout nom d'event doit d'abord être déclaré dans `AnalyticsEvents` :**
```dart
// lib/core/services/analytics_events.dart
abstract final class AnalyticsEvents {
  static const myNewEvent = 'my_new_event';  // ajouter ici
}
```

**2. Les events métier se tirent dans le BLoC, jamais dans le widget :**
```dart
// ✅ CORRECT — dans le handler BLoC
unawaited(_analytics.logEvent(
  AnalyticsEvents.bidSubmitted,
  properties: {'corridor': '${e.from}→${e.to}', 'weight_kg': e.weightKg},
));

// ❌ INTERDIT — dans un widget
getIt<AnalyticsService>().logEvent('bid_submitted');
```

Exception acceptée : events de vue/intention déclenchés à l'ouverture d'un écran (`wallet_topup_started`) — via `addPostFrameCallback` dans `initState`.

**3. Tout nouveau BLoC doit recevoir `AnalyticsService` en paramètre :**
```dart
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc(this._repository, this._analytics) : super(MyInitial()) { ... }
  final MyRepository _repository;
  final AnalyticsService _analytics;
}
```
Et enregistré dans `lib/core/di/injection.dart` :
```dart
getIt.registerFactory(() => MyBloc(getIt(), getIt<AnalyticsService>()));
```

**4. Toujours `unawaited()` — le tracking ne doit jamais bloquer le flux :**
```dart
unawaited(_analytics.logEvent(AnalyticsEvents.paymentSucceeded));
```

### PII — interdit dans les properties

| ❌ Jamais | ✅ À la place |
|-----------|--------------|
| Numéro de téléphone | UID backend (UUID) |
| Email | — |
| Nom / prénom | — |
| Adresse exacte | Ville seulement |
| Valeur déclarée exacte | Tranche (ex: `'<100€'`) |
| Token / clé | — |

### Consentement RGPD — persistance backend (source de vérité)

Le consentement n'est PAS qu'un flag Hive local. **Backend = source de vérité, Hive = cache, `audit_log` = preuve légale.**
- `AnalyticsService.setConsent({required granted, source})` → écrit Hive + pousse au backend (`PUT /auth/me/analytics-consent`, fire-and-forget tolérant aux pannes).
- `AnalyticsService.syncFromBackend()` → au login (via `AnalyticsConsentGate`) réconcilie : le backend prime, et un utilisateur réinstallé ayant déjà répondu n'est pas redemandé.
- **Toujours passer `source`** à `setConsent` : `manual` (écran), `auto_non_gdpr` (auto hors RGPD), `settings` (réglages). Jamais de PII dans le payload — uniquement `granted` / `policyVersion` / `source`.
- Toute nouvelle décision de consentement doit d'abord `syncFromBackend()` avant de tester `hasAnswered` (cf. `resolvePostPinSetupRoute`).

### Checklist tracking — nouvel écran

- [ ] La route est dans `router.dart` → screen tracking automatique ✅
- [ ] Si l'écran a un état d'intention (ouverture = début d'un funnel) → `addPostFrameCallback` + `logEvent` dans `initState`
- [ ] Si l'écran contient un formulaire de soumission → event dans le BLoC après succès
- [ ] Si l'écran contient des actions secondaires (filtres, tri, partage) → event dans le BLoC ou widget selon le cas
- [ ] Nom d'event ajouté dans `AnalyticsEvents`
- [ ] Aucune PII dans les properties

### Checklist tracking — modification d'écran existant

- [ ] Les actions modifiées/ajoutées ont leurs events mis à jour
- [ ] Les actions supprimées ont leurs events retirés du code (pas de `AnalyticsEvents`)
- [ ] Si le BLoC change de signature, vérifier `injection.dart`

### Events actuellement implémentés

| Event | Déclencheur |
|-------|-------------|
| `signup_started` | PhoneAuthScreen._submit() |
| `otp_submitted` | OtpVerificationScreen._verify() |
| `signup_completed` | PinSetupScreen._handleComplete() |
| `analytics_consent_answered` | AnalyticsConsentScreen._respond() |
| `login_success` | AuthBloc (check / phone / social / email) |
| `login_failed` | AuthBloc._onCheckRequested() |
| `guest_session_started` | AuthBloc._onGuestSessionRequested() — session Firebase anonyme ouverte avec succès depuis « Parcourir sans compte » |
| `guest_session_failed` | AuthBloc._onGuestSessionRequested() — échec de l'ouverture (hors ligne, Firebase indisponible), propriété `reason` (code Firebase ou `unknown`) |
| `guest_data_claimed` | AuthBloc._claimGuestData() — favoris posés en session visiteur rattachés au compte (`POST /auth/guest/claim` accepté), aussi bien à l'inscription qu'à la connexion à un compte existant (téléphone, e-mail, Google, Apple). Sortie de l'entonnoir invité |
| `guest_data_claim_failed` | AuthBloc._claimGuestData() — rattachement refusé ou impossible, propriété `reason` (code métier backend `guest-claim-*` / `user-not-found`, ou `unknown`). L'inscription ou la connexion aboutit malgré tout : le visiteur perd ses favoris, jamais son compte. Doublé d'un `AppLog.warn` car l'analytics se tait si le consentement est refusé |
| `kyc_started` | KycBloc._onSessionRequested() |
| `kyc_completed` | KycBloc._onStatusRefreshed() |
| `kyc_failed` | KycBloc._onSessionRequested() |
| `announcement_created` | AnnouncementBloc._onCreateRequested() |
| `announcement_viewed` | AnnouncementDetailScreen (BlocListener) |
| `trip_owner_detail_opened` | TripOwnerDetailScreen.initState — ouverture de l'écran détail trajet par le propriétaire (propriété `status`) |
| `trip_parcels_viewed` | TripParcelsSection — chargement de la liste des colis embarqués (propriété `count`) |
| `trip_parcels_filtered` | TripParcelsSection — chip de filtre statut tapée dans « Colis dans le trajet » (propriété `status`, `all` si « Tous ») |
| `surplus_opened` | AnnouncementBloc._onSurplusOpenRequested() |
| `bid_submitted` | BidBloc._onCreateRequested() |
| `bid_accepted` | BidAcceptanceBloc._handleResponse() |
| `bid_rejected` | BidBloc._onRejectRequested() |
| `payment_initiated` | PaymentScreen._pay() |
| `payment_succeeded` | PaymentBloc._onPaymentSheetCompleted() |
| `payment_failed` | PaymentBloc._onPaymentFailed() |
| `mobile_money_awaiting` | MobileMoneyAwaitingScreen.initState |
| `qr_scan_success` | TrackingBloc._onScanSubmit() |
| `delivery_confirmed` | ReceptionConfirmScreen._confirm() |
| `package_request_created` | PackageRequestFormBloc |
| `package_request_updated` | PackageRequestFormBloc._onStep3() (mode édition) |
| `package_request_published` | PackageRequestDetailScreen._publish() / PackageRequestDetailBottomSheet._publish() — tuile « Publier » de la grille propriétaire (brouillon → OPEN) |
| `package_request_unpublished` | PackageRequestDetailScreen._unpublish() / PackageRequestDetailBottomSheet._unpublish() — tuile « Dépublier » de la grille propriétaire (OPEN → brouillon) |
| `package_request_photo_added` | PackageRequestPhotosCubit.add() — photo colis uploadée au wizard |
| `package_request_photo_removed` | PackageRequestPhotosCubit.remove() — photo retirée avant publication |
| `package_request_detail_opened` | PackageRequestPublicDetailScreen.initState — ouverture du détail plein écran |
| `package_request_reported` | PackageRequestPublicDetailScreen._report() — signalement (propriété `reason`) |
| `package_request_searched` | PackageRequestSearchBloc |
| `negotiation_offer_made` | NegotiationBloc._onStart()/_onCounter() |
| `negotiation_offer_accepted` | NegotiationBloc._onAccept() |
| `negotiation_cancelled` | NegotiationBloc._onCancel() — l'une des parties met fin à la négociation |
| `negotiation_nudge_sent` | NegotiationBloc._onNudge() — relance envoyée |
| `negotiation_commission_settled` | NegotiationBloc._handleCommissionResponse() — voyageur a réglé la commission Yadony d'un accord cash (direct ou après 3DS), l'accord est scellé (propriété `thread_id`) |
| `negotiation_commission_declined` | NegotiationBloc._onDeclineCommission() — voyageur renonce explicitement au règlement, la demande est libérée immédiatement pour un autre voyageur |
| `conversation_opened` | ChatScreen.initState |
| `message_sent` | ChatBloc._onSendText() |
| `conversation_call_initiated` | ChatScreen._call() — tap 📞 dans le header chat (numéro révélé) |
| `message_blocked` | ChatScreen._sendText() — message refusé par ChatMessageValidator (propriété `reason`) |
| `wallet_topup_started` | WalletTopupAmountScreen.initState |
| `wallet_topup_completed` | WalletBloc (après topup réussi) |
| `disputes_opened` | DisputeListBloc._onLoad — premier chargement de « Mes litiges » (propriété `count`) |
| `dispute_detail_opened` | DisputeDetailScreen.initState — ouverture du détail d'un litige (propriété `status`) |
| `rating_submitted` | RatingBloc._onSubmit()/_onTravelerSubmit() |
| `cancellation_initiated` | CancellationBloc._onTripCancellationRequested() |
| `rematch_accepted` | RematchSearchScreen — tap « Envoyer une demande » sur une alternative (propriété `count`) |
| `rematch_alternatives_opened` | RematchSearchScreen.initState — ouverture de l'écran alternatives (propriété `source`: `in_app`/`deep_link`) |
| `no_show_reported_by_sender` | CancellationBloc._onTravelerNoShowReport() — expéditeur signale le voyageur absent |
| `no_show_reported_by_traveler` | CancellationBloc._onNoShowReport() — voyageur signale l'expéditeur absent |
| `delivery_no_show_reported_by_traveler` | CancellationBloc._onDeliveryNoShowReport — voyageur signale l'absence du destinataire à la livraison |
| `delivery_no_show_reported_by_sender` | CancellationBloc._onTravelerDeliveryNoShowReport — expéditeur signale que le voyageur ne livre pas |
| `delivery_no_show_contested` | CancellationBloc._onDeliveryNoShowContest — contestation d'un signalement d'absence à la livraison |
| `cancel_after_handover_initiated` | CancellationBloc._onCancelAfterHandover() — annulation après remise (propriété `actor`: sender/traveler, D5/D6) |
| `return_code_viewed` | CancellationBloc._onReturnCodeRequested() — expéditeur consulte son code de retour (D7) |
| `return_code_entry_opened` | ReturnEntrySheet.show() — voyageur ouvre la saisie du code de retour (propriété `status`) |
| `return_confirmed` | CancellationBloc._onReturnConfirm() — voyageur confirme la restitution du colis (D7) |
| `upgrade_to_pro_started` | UpgradeToProScreen.initState |
| `help_center_opened` | HelpCenterBloc._onOpenRequested — ouverture réelle du hub, distincte du préchargement global |
| `help_tutorial_opened` | HelpCenterBloc._onTutorialOpenRequested (propriétés contrôlées `tutorial_id`, `source`) |
| `help_tutorial_play_started` | HelpCenterBloc._onPlaybackRequested — lecture démarrée (propriété `tutorial_id`) |
| `help_tutorial_completed` | HelpCenterBloc._onPlaybackRequested — lecture terminée (propriété `tutorial_id`) |
| `help_tutorial_external_opened` | HelpCenterBloc._onExternalOpenRequested — ouverture YouTube externe réussie (propriété `tutorial_id`) |
| `help_social_link_opened` | HelpCenterBloc._onExternalOpenRequested — réseau social ouvert (propriété enum `network`) |
| `help_youtube_subscribe_tapped` | HelpCenterBloc._onExternalOpenRequested — chaîne YouTube ouverte (propriété contrôlée `source`) |
| `help_config_load_failed` | HelpCenterBloc._emitFailure — échec non bloquant (propriété fermée `reason`: `fetch`/`parse`/`launch`) |
| `referral_shared` | ReferralBloc._onShared() |
| `analytics_consent_changed` | PrivacySettingsScreen.onChanged |
| `phone_visibility_toggled` | PrivacySettingsBloc._onToggleHidePhone — bascule « Masquer mon numéro » confirmée par le serveur (propriété `hidden`) |
| `account_deletion_requested` | AccountDeletionBloc._onRequestDeletion() |
| `wallet_refund_requested` | DeletionEligibilityCubit.requestWalletRefund() — solde wallet bloquant la suppression, ticket de remboursement manuel ouvert (aucune propriété : ni montant ni devise, PII financière) |
| `shipment_filter_applied` | ShipmentFilterCubit (statut/période/preset, sans PII) |
| `shipment_new_request_opened` | ShipmentListScreen — pill « Envoyer » du header ouvre le wizard de demande d'envoi |
| `publish_intro_stripe_reminder_tapped` | PublishIntroScreen (trajet) — tap sur le rappel « Activez les paiements par carte » → onboarding Stripe Connect |
| `trip_filter_applied` | TripFilterCubit.setFilter() — chips statut « Mes trajets » (Activités), propriété `status` |
| `envoyer_envois` / `envoyer_demandes` | EnvoyerHubScreen `logScreen` au changement d'onglet (Envois / Demandes) |
| `urgent_filter_toggled` | HomeScreen._onUrgentToggle — chip 🔥 Urgent (propriété `active`) |
| `firm_price_taken` | NegotiationBloc._onStart() — voyageur prend un prix ferme |
| `payment_method_selected` | NegotiationBloc._onCheckout() — mode de paiement retenu par l'expéditeur au checkout final (le voyageur ne choisit plus au trip-linking : `paymentMethod` y est un placeholder, `acceptedPaymentMethods.first`) |
| `trip_link_payment_blocked` | NegotiationBloc._onSubmitTrip()/_onCreateDedicatedTrip() — 422 `payment-method/*` : le voyageur ne peut honorer aucun mode accepté par l'expéditeur (propriété `reason` : `no_card`/`no_cash_funds`/`none`) |
| `bid_qr_sheet_opened` | QrSheet ouverte depuis le détail d'envoi (propriété `status`) |
| `bid_qr_downloaded` | Tap « Enregistrer » ou « Partager » dans la QrSheet |
| `bid_retrait_code_opened` | RetraitCodeSheet ouverte depuis le talon (propriété `status`) |
| `bid_photo_added` | BidPhotosCubit.add() — photo de colis uploadée à la création de l'offre |
| `bid_photo_removed` | BidPhotosCubit.remove() — photo retirée avant soumission |
| `bid_photos_viewed` | BidPhotoViewerModal.initState — ouverture de la visionneuse (propriété `photo_count`) |
| `reimbursement_conditions_opened` | ReimbursementInfoBanner — tap « Voir conditions » vers la FAQ remboursement |
| `pending_requests_opened` | PendingBidsScreen — ouverture de l'écran « À traiter » depuis le bouton de la liste des demandes (propriété `count`) |
| `traveler_call_initiated` | Tap 📞 sur la carte voyageur (propriété `status`) |
| `tracking_link_shared` | Partage de l'URL de suivi (app bar ou carte) |
| `screen_feedback_submitted` | Envoi du rapport 🐞 DonyFeedbackButton (propriété `route`) |
| `profile_photo_updated` | AuthBloc._onAvatarUploadRequested() — upload photo de profil réussi |
| `profile_about_updated` | AuthBloc._onUpdateProfileRequested() — bio « À propos » renseignée |
| `public_reviews_opened` | UserReviewsCubit — ouverture de la bottom sheet « tous les avis » (propriété `rating_count`) |
| `reviews_filtered` | MyReviewsBloc._onStarFilterToggled — tap sur une ligne de distribution dans « Mes avis reçus » (propriété `stars`: note 1–5 ou `all` si filtre retiré) |
| `faq_question_opened` | FaqBloc — ouverture d’une réponse du Centre d’aide (propriétés `category`, `question_id`, identifiants non sensibles) |
| `faq_contact_requested` | FaqBloc — tap sur « Contacter le support » depuis le Centre d’aide |
| `support_email_composer_opened` | SupportContactBloc — brouillon support ouvert dans l’application Mail (propriété `category`, aucun texte libre) |
| `support_contact_failed` | SupportContactBloc — échec d’ouverture de l’application Mail (propriétés `category`, `reason`, aucun texte libre) |
| `trip_matching_viewed` | PackageRequestSearchBloc._onFiltersChanged — chargement d'une recherche colis filtrée « Pour mes trajets » (propriété `count`) |
| `package_match_alert_toggled` | NotificationPrefsBloc._onPackageMatchAlertToggled — ligne « Nouveaux colis compatibles » des réglages de notifications (propriété `enabled`) |
| `notification_pref_toggled` | NotificationPrefsBloc._onToggled — bascule d'une catégorie de push confirmée par le serveur (propriétés `pref`, `enabled`) ; non émis si l'écriture échoue |
| `corridor_alert_toggled` | CorridorAlertListBloc._onToggle — actif/pause d'une alerte corridor (propriété `active`) |
| `corridor_alert_deleted` | CorridorAlertListBloc._onDelete — suppression d'une alerte corridor |
| `corridor_alert_created` | CorridorAlertFormCubit.submit() — création d'une alerte corridor |
| `corridor_alert_updated` | CorridorAlertFormCubit.submit() — édition d'une alerte corridor |
| `favorites_opened` | FavoritesScreen.initState — ouverture du hub favoris |
| `recipient_picker_opened` | RecipientPickerSheet.initState — ouverture de la sheet de sélection destinataire |
| `recipient_selected` | RecipientBloc._onPicked — destinataire confirmé dans la sheet (propriété `source`: saved/phone_contact/new) |
| `recipient_created` | RecipientBloc._onCreated — destinataire ajouté au carnet |
| `recipient_default_set` | RecipientBloc._onDefaultSet — destinataire marqué par défaut |
| `activites_hub_trips_opened` / `activites_hub_envois_opened` / `activites_hub_demandes_opened` / `activites_hub_negotiations_opened` | ActivitesHubScreen — tap sur une tuile d'activité du hub |
| `activites_hub_trip_create_opened` / `activites_hub_request_create_opened` | ActivitesHubScreen — CTA « Publier un trajet » / « Publier un colis » |
| `activites_hub_stats_period_changed` | ActivitesHubScreen — changement de période des statistiques |
| `activites_hub_search_opened` | ActivitesHubScreen — bouton « Suivre un colis » du header |
| `activites_hub_history_opened` / `activites_hub_help_opened` / `activites_hub_alerts_opened` / `activites_hub_templates_opened` / `activites_hub_addresses_opened` / `activites_hub_recipients_opened` | ActivitesHubScreen — tuiles de la section Outils |
| `activites_hub_intro_dismissed` | ActivitesHubScreen — fermeture (X) de la carte d'introduction |
| `traveler_bids_filter_applied` | TravelerBidsBloc._onFilterChanged — chips « À traiter / Acceptées / Terminées » de l'écran Demandes (propriété `filter`) |
| `home_search_mode_changed` | HomeScreen._onModeChanged — bascule du sélecteur de mode Trajets/Colis (propriété `mode`) |
| `home_cross_discovery_tapped` | HomeScreen._onCrossDiscoveryTap — bascule proposée depuis l'état vide (propriétés `from_mode`, `count`) |
| `home_matching_trips_filter_toggled` | HomeScreen._showFilterSheet — pastille « Pour mes trajets » de la feuille de filtres colis (propriétés `active`, `active_trips`) |
| `home_guidance_carousel_cta_tapped` | EvergreenGuidanceCarousel — tap sur une carte du carousel de guidance evergreen (Recherche), toute la carte est cliquable (propriété `slide` : trip/parcel/alert/kyc/tutorial) |
| `home_guidance_carousel_slide_dismissed` | EvergreenGuidanceCarousel — croix (X) de fermeture manuelle d'une slide, masquage définitif (propriété `slide` : trip/parcel/alert/kyc/tutorial) |
| `settings_guidance_cards_reset` | SettingsScreen._resetGuidanceCards — tuile « Réafficher les suggestions », efface tous les flags de fermeture manuelle du carousel de guidance (Recherche) et des `ContextualTutorialCard` fermées ailleurs dans l'app |
| `accessibility_setting_changed` | AccessibilityBloc — un réglage d'accessibilité est modifié (propriétés `setting`, `value`) ou réinitialisation complète (`setting: reset`) |
| `trip_marked_arrived` | AnnouncementBloc._onTripMarkArrivedRequested() — voyageur marque son trajet arrivé à destination |
| `arrival_instructions_updated` | AnnouncementBloc._onArrivalInstructionsUpdateRequested() — édition des instructions de retrait après le marquage initial |
| `trip_negotiable_toggled` | AnnouncementFormBloc._onNegotiableChanged — bascule « J'accepte les propositions de prix » de l'étape Prix & Conditions du wizard de publication d'un trajet (propriété `enabled`) |
| `trip_negotiation_opened` | BidNegotiationBloc._onOpen — l'expéditeur ouvre le mode négociation depuis le second CTA « Proposer un prix » du détail du trajet (propriété `announcement_id`). Aucun appel réseau : c'est l'entrée de l'entonnoir, mesurée même si aucune proposition n'est envoyée |
| `trip_negotiation_proposed` | BidNegotiationBloc._onPropose — première proposition de prix envoyée avec succès (propriétés `announcement_id`, `has_custom_items`, `custom_item_count`). Ni description, ni destinataire, ni montant : seul le motif de négociation est mesuré |
| `trip_negotiation_countered` | BidNegotiationBloc._onCounter — contre-offre acceptée par le serveur (propriétés `bid_id`, `round`, `actor`: `sender`/`traveler`). `actor` est dérivé de `netEur`, que le backend ne renseigne que pour le voyageur |
| `trip_negotiation_accepted` | BidNegotiationBloc._onAccept — l'une des parties accepte le prix en discussion (propriétés `bid_id`, `round`, `actor`) |
| `trip_negotiation_rejected` | BidNegotiationBloc._onReject — l'une des parties refuse et clôt le fil (propriétés `bid_id`, `round`, `actor`) |
| `trip_negotiation_payment_started` | BidNegotiationBloc._onCheckout — l'expéditeur lance le paiement d'un accord scellé côté carte depuis le fil, `POST /bids/{bidId}/negotiation/checkout` accepté (propriété `bid_id`). Un accord en espèces (`PENDING`) ne l'émet jamais : c'est le voyageur qui règle la commission par le geste existant |
| `trip_poster_opened` | TripPosterScreen.initState — ouverture de l'affiche partageable d'un trajet |
| `trip_poster_shared` | TripPosterScreen — partage de l'image via la feuille système (`action: share`) ou enregistrement galerie (`action: save`) ; non émis si le partage est annulé |
| `trip_poster_link_copied` | TripPosterScreen — tap sur « Copier le lien » ou « Copier la légende ». Le canal réel est porté par le lien lui-même (`?c=lien` / `?c=post` / `?c=partage`), pas par une propriété : il doit survivre au partage hors de l'app |
| `search_composer_opened` | SearchComposerBloc._onStarted() — déclenché par `SearchComposerStarted`, émis depuis `SearchComposerScreen.initState` (`addPostFrameCallback`) à l'ouverture de l'écran de composition de recherche, avant le premier comptage sur les filtres hérités de l'onglet (propriété `mode`) |
| `search_phrase_parsed` | SearchComposerBloc._onPhraseSubmitted() — après un appel réussi au parseur serveur (`SearchParseRepository.parse`), que la phrase soit reconnue ou non (propriétés `recognized_count`, `unresolved_count`). La phrase elle-même n'est jamais envoyée |
| `search_parse_failed` | SearchComposerBloc._onPhraseSubmitted() — la phrase parsée par le serveur ne reconnaît aucun champ (`result.recognized` vide), sous-cas de `search_phrase_parsed` (propriété `unresolved_kinds`) |
| `search_submitted` | HomeScreen._onFiltersChanged() — à chaque application de filtres sur l'écran Rechercher (retour de l'écran de composition, mais aussi tout autre changement de filtre : chips, sheets de date/prix/poids/note, bascule « Pour mes trajets »), seul point de sortie de tout changement de filtre (propriétés `mode`, `filter_count`, `came_from_phrase` — cette dernière mesure la part des recherches qui passent par la phrase plutôt que par les filtres au doigt, elle décidera du sort du bloc « En une phrase ») |
| `bloc_error` | AnalyticsBlocObserver.onError() — global |

---

## Critical Rules

### NEVER
1. Commit directly on `main` — always use a feature branch
2. Add `Co-Authored-By: Claude` in commit messages
3. `setState` → BLoC
4. `Navigator.push()` → GoRouter
5. Package `http` → Dio
6. Instancier services dans widgets/BLoCs → GetIt
7. Données sensibles dans Hive en clair
8. Tokens Firebase dans Hive → `FirebaseAuth.instance.currentUser`
9. Photos > 10 MB
10. Contourner `requirePaymentAuth` avant un paiement (il décide seul si une vérification s'applique)
11. GPS oublié dans les métadonnées EXIF
12. URLs/clés hardcodées → `--dart-define-from-file`
13. PII dans les properties analytics (téléphone, email, nom, adresse exacte)
14. Appeler `Posthog()` directement → passer par `AnalyticsService`
15. Créer un BLoC sans injecter `AnalyticsService` en paramètre
16. Ajouter un nom d'event inline → toujours passer par `AnalyticsEvents.xxx`
17. **Icône camion (`Icons.local_shipping*`)** → JAMAIS l'utiliser dans le projet (mode de transport, envoi, livraison, ou autre). dony = transport par voyageur (bagage en avion), pas par camion. Préférer `Icons.inventory_2_rounded` (colis), `Icons.flight_rounded` (trajet/transport), `Icons.outbox_rounded` (envoi). Exception : uniquement si je le précise explicitement.
18. Laisser du code mort dans le repo — un widget/écran/service sans aucun appelant doit être supprimé, pas laissé "au cas où". Vérifier par `grep` avant de le garder ; supprimer aussi ses tests dédiés

### ALWAYS
1. BLoC pour tout état de feature
2. GoRouter avec auth guard
3. Dio + `AuthInterceptor`
4. Hive pour queue QR offline
5. Synchro automatique à la reconnexion
6. GPS capturé avant la photo
7. `requirePaymentAuth` avant paiement — biométrie et PIN restant facultatifs côté utilisateur
8. ACK FCM pour notifications critiques
9. FCM token mis à jour sur `onTokenRefresh`
10. Validation côté client (backend = source de vérité)
11. Tracking sur tout nouvel écran (screen auto + events métier si applicable)
12. Mettre à jour le tracking lors de toute modification d'écran existant
13. `unawaited()` sur tous les appels `_analytics.logEvent()`

---

## Règle — Rafraîchissement des données après navigation (OBLIGATOIRE)

> **Contexte :** Chaque route crée une nouvelle instance BLoC (`registerFactory`). L'écran parent et l'écran fils ont donc des BLoCs distincts. Sans signal explicite, le parent ne sait jamais qu'une donnée a changé.

### Pattern selon le type de navigation

**A — `context.push()` vers un écran d'édition/création :**

```dart
// ✅ CORRECT — écran liste
onTap: () async {
  final changed = await context.push<bool>('/profile/addresses/${address.id}');
  if ((changed ?? false) && context.mounted) {
    context.read<XxxBloc>().add(const XxxListRequested());
  }
},

// ✅ CORRECT — écran d'édition (dans le BlocListener après succès)
if (state.status == XxxStatus.success) {
  context.pop(true);  // true = signale un changement réel
}

// ❌ INTERDIT
onTap: () => context.push('/profile/addresses/${address.id}'),  // non awaité
context.pop();  // sans valeur après une sauvegarde
```

**B — BottomSheet de création/édition :**

```dart
// ✅ CORRECT — toujours awaiter les bottom sheets qui modifient des données
onPressed: () async {
  await CreateXxxBottomSheet.show(context);
  if (context.mounted) {
    context.read<XxxBloc>().add(const XxxListRequested());
  }
},

// ❌ INTERDIT
onPressed: () => CreateXxxBottomSheet.show(context),  // non awaité
```

**C — Exception : BLoC partagé (pas de refresh nécessaire)**

Si le bottom sheet utilise `context.read<XxxBloc>()` depuis le provider du parent (même instance), le parent se reconstruit automatiquement. Pas besoin du pattern await/refresh.

Cas typiques en shared BLoC : `HandoverBottomSheet` (BidBloc), bottom sheets de négociation (NegotiationBloc), `EditProfileBottomSheet` (AuthBloc).

### Règles de diagnostic

Avant de naviguer vers un écran fils, se poser ces questions :
1. **Est-ce que cet écran peut modifier des données ?** Si non → pas de refresh nécessaire.
2. **Le BLoC parent et le BLoC fils sont-ils la même instance ?** Si oui → pas de refresh (shared BLoC).
3. **C'est `context.push()` ?** → `await context.push<bool>()` + `if (result == true) reload`.
4. **C'est un bottom sheet qui modifie des données ?** → `await Sheet.show()` + reload.
5. **L'écran fils appelle `context.pop()` après save ?** → `context.pop(true)` si le caller conditionne le reload sur le résultat.

### Checklist à appliquer à chaque nouvel écran/bottom sheet

- [ ] Tout `context.push()` vers écran qui crée/modifie → `await context.push<bool>()` + reload conditionnel
- [ ] Tout `BottomSheet.show()` qui modifie des données → `await Sheet.show()` + reload
- [ ] Tout `context.pop()` dans un BlocListener après succès → `context.pop(true)`
- [ ] Pas de `unawaited(context.push(...))` vers un écran d'édition

---

## Feature Implementation Checklist

**Avant de commencer :**
- [ ] Lire la story dans `/docs-claude/docs/stories/epic-XX-*.md`
- [ ] BLoC (events + states + bloc)
- [ ] Data models (`fromJson`/`toJson`) + repository + datasource
- [ ] Routes dans `lib/app/router.dart`
- [ ] DI dans `lib/core/di/injection.dart`

**Avant de marquer complète :**
- [ ] Tous les critères Given/When/Then couverts
- [ ] BLoC (no `setState`), GoRouter (no `Navigator`)
- [ ] Loading + Error states gérés avec messages utilisateur
- [ ] Support offline si requis · Biométrie/PIN si paiement · ACK FCM si notifications
- [ ] Tests unitaires BLoC + widget tests écrans critiques
- [ ] Couverture ≥ 90 % (`flutter test --coverage`)
- [ ] **Analytics** : nouveaux events ajoutés dans `AnalyticsEvents`, tirés dans le BLoC, `AnalyticsService` injecté, aucune PII
- [ ] **Analytics** : table des events dans `CLAUDE.md` mise à jour

---

## Testing

- BLoC : `blocTest<XBloc, XState>` → `build` / `act` / `expect`
- Widgets : `tester.pumpWidget(BlocProvider(...))` + `find.byType()` / `find.text()`
- Couverture ≥ 90 % — tous les tests passent avant tout commit

---

## Design et UI — HIG + Material 3

> **RÈGLE ABSOLUE :** Tout écran doit être conforme aux Apple HIG et Material Design 3. Un refus App Store / Play Store pour non-conformité est inacceptable.

### Bibliothèques obligatoires

| Package | Usage |
|---------|-------|
| `flutter_animate` | Micro-animations et transitions |
| `google_fonts` | **Plus Jakarta Sans** — tous les textes |
| `pinput` | Champ PIN/OTP |
| `flutter_secure_storage` | Stockage PIN (Keystore/Keychain) |

### Palette (source de vérité : `lib/app/theme.dart`)

```dart
const kGreenPrimary  = Color(0xFF1A6B3C);  // CTA, actifs
const kGreenDark     = Color(0xFF134F2D);  // gradients, headers
const kGreenAccent   = Color(0xFF4CAF7D);  // accents secondaires
const kGreenLight    = Color(0xFFE8F5EE);  // bg chips actifs
const kBackground    = Color(0xFFF4F6F8);  // fond (jamais blanc pur)
const kSurface       = Color(0xFFFFFFFF);  // cards, inputs, appbar
const kTextPrimary   = Color(0xFF0D1B2A);
const kTextSecondary = Color(0xFF6B7A8D);
const kTextHint      = Color(0xFFADB5BD);
const kBorder        = Color(0xFFE9ECEF);
const kError         = Color(0xFFE53935);
const kWarning       = Color(0xFFF59E0B);
const kSuccess       = Color(0xFF16A34A);
```

### Règles HIG obligatoires

**Typographie :** `GoogleFonts.plusJakartaSans` partout. `fontSize < 12` interdit. Contraste ≥ 4.5:1.
- Grand titre : `28–32 / w800 / letterSpacing -0.5`
- Titre nav : `17–18 / w700` · Section : `15–16 / w600` · Corps : `14–15 / w400` · Caption : `12–13 / w500`

**Touch targets :** min 44×44 pt pour tout élément interactif. `InkWell`/`GestureDetector` avec padding suffisant.

**Navigation :**
- Back iOS → `Icons.arrow_back_ios_rounded` (taille 20, `kGreenPrimary`), Android → `Icons.arrow_back_rounded`
- `centerTitle: false`. Écrans principaux : `SliverAppBar(expandedHeight: 100–120)`.

**Bottom sheets :**
- Handle : `Container(width: 40, height: 4, color: kBorder)`
- `isScrollControlled: true` · `borderRadius: BorderRadius.vertical(top: Radius.circular(20))`
- Respecter `MediaQuery.of(context).viewInsets.bottom`
- Dialogs uniquement pour actions destructives irréversibles.

**Couleurs :** jamais `0xFFFFFFFF` en fond → `kBackground`. Gradients uniquement sur hero cards/headers.

**Espacement :** padding horizontal 20 pt. Entre sections 24–28 pt. Interne cards 16 pt.  
Border radius : cards 16 · boutons 14 · chips 20 · inputs 12 · badges 8.

**Animations (`flutter_animate`) :** entrée 250–300 ms `easeOutCubic`, sortie 150–200 ms `easeInCubic`. Stagger : 60 ms × index. Max 500 ms.

**États :**
- Loading → `CircularProgressIndicator(color: kGreenPrimary)` centré
- Erreur → icône + titre + description + "Réessayer"
- Vide → illustration + titre + CTA
- Désactivé → `opacity: 0.4`

**Formulaires :** labels flottants (`labelText`). Validation à la perte de focus. Submit désactivé (`onPressed: null`) pendant loading. `suffixText` pour les unités (€, kg).

**Accessibilité :** `Semantics` sur icônes sans label. `tooltip` sur `IconButton`. Info jamais transmise par couleur seule.

### Material 3

`useMaterial3: true`. `ElevatedButton` elevation 0. Cards elevation 0 + border `kBorder`. `SnackBarBehavior.floating` radius 12. `AppBar scrolledUnderElevation: 0`.

### PIN — standard dony

Utiliser `DonyKeypad` (`lib/core/widgets/dony_keypad.dart`) — ne jamais recréer le clavier.
```dart
PinTheme(width: 56, height: 64,
  decoration: BoxDecoration(color: kGreenLight,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: kGreenPrimary, width: 2)))
```

### Templates d'écrans

**Écran secondaire :**
```dart
Scaffold(
  backgroundColor: kBackground,
  appBar: AppBar(
    title: Text('Titre', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
    backgroundColor: kSurface, elevation: 0,
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    child: Column(children: [/* contenu */])
        .animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  ),
)
```

**Écran principal (Large Title) :**
```dart
Scaffold(
  backgroundColor: kBackground,
  body: CustomScrollView(slivers: [
    SliverAppBar(
      pinned: true, expandedHeight: 110,
      backgroundColor: kSurface, elevation: 0, surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text('Grand titre', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
        expandedTitleScale: 1.5,
      ),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kBorder, height: 1)),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      sliver: SliverList(delegate: SliverChildListDelegate([/* contenu */])),
    ),
  ]),
)
```

---

## Performance

- Images : max 10 MB, qualité 85 %, 1920×1080. `CachedNetworkImage` dans les listes.
- Listes longues : `ListView.builder` + pagination 20 items.
- `dispose()` : fermer BLoCs, désabonner streams, annuler timers.
- Réseau : retry exponential backoff. Cache si possible.

---

## Security Checklist

- [ ] Aucun secret dans le code → `--dart-define-from-file`
- [ ] Biométrie/PIN pour paiements
- [ ] Firebase token auto-refreshed (jamais stocké dans Hive)
- [ ] HTTPS uniquement + SSL pinning en production
- [ ] ProGuard/R8 + obfuscation activés (release)
- [ ] Aucune donnée sensible dans les logs en production
- [ ] Sentry configuré

---

## Documentation story complète

Créer `docs/stories-done/story-<epic>.<num>-<slug>.md` quand la story est **100% terminée**.

```markdown
# Story X.Y — Titre (Flutter)
**Date:** YYYY-MM-DD | **Status:** ✅ Complète

## Résumé
## Fichiers créés / modifiés
## Comment ça fonctionne
### Flux utilisateur (étape par étape)
### BLoC : events, states, transitions importantes
### Écrans et widgets clés (ce qu'ils affichent, quel BLoC, quelle navigation)
### Appels API (endpoint, body, gestion erreurs)
### Pièges et points d'attention
## Critères d'acceptation couverts
## Décisions techniques
```

**Règles :** ne pas créer avant 100% terminé · inclure les critères d'acceptation · "Comment ça fonctionne" doit permettre la maintenance sans relire tout le code.

---

## Documentation

- Architecture : `/docs-claude/docs/planning-artifacts/architecture.md`
- Stories : `/docs-claude/docs/stories/epic-*.md`
- PRD : `/docs-claude/docs/planning-artifacts/prd.md`
