# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project: Yadony Mobile App (Flutter)

P2P marketplace mobile pour la diaspora africaine (transport de colis vers l'Afrique).

**Stack:** Flutter/Dart · flutter_bloc · GoRouter · Dio · Hive · Firebase Auth (Phone) · Stripe · FCM · Sentry  
Min SDK: iOS 15+ / Android 7.0+ (API 24)

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
# Avec le pont flutter_skill (contrôle par agent IA) — développement uniquement
flutter run -t test_driver/main_dev.dart --dart-define-from-file=env.dev.json
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

- Lancer la recherche GPS **dès l'ouverture** de l'écran photo, avant `ImagePicker.pickImage()`, mais ne **jamais** bloquer l'ouverture de l'appareil photo sur elle (FLUTTER-D1) : relevé frais borné (`ScanLocator.fixTimeout`, repli sur la dernière position connue), puis attente d'au plus 5 s après la photo ; sans position, l'étape part sans coordonnées. Le lieu lisible (géocodage, réseau) se calcule en parallèle, borné par `ScanLocator.labelTimeout`
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

### 11. Langues — Français / English

- L'app est disponible en français et en anglais (`lib/l10n/`, ARB `app_fr.arb`/`app_en.arb`). Par défaut, la langue est celle du téléphone : anglais si le téléphone est en anglais, français sinon (`AppL10n.resolve`).
- L'utilisateur peut forcer un choix dans Réglages › Langue (« Langue du téléphone », « Français », « English ») ; le choix est stocké dans Hive (`UserPreferencesModel.languageCode`, `'system' | 'fr' | 'en'`) et synchronisé avec `preferredLanguage` côté backend.
- `context.l10n` (jamais `AppLocalizations.of(context)!`) est obligatoire pour tout texte affiché. `AppL10n.current` uniquement pour du code sans `BuildContext`. Jamais de texte traduit en dur, jamais gardé dans un `State`/`initState`.
- Garde-fou (`tool/check_hardcoded_strings.dart`) à 0 (seuil 0) — tout nouveau texte affiché doit passer par une clé ARB avant de committer.

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

**Route imbriquée (path relatif, enfant d'une `GoRoute`) → `name:` obligatoire, égal au chemin complet** (ex. `path: 'preferences'` sous `/settings` → `name: '/settings/preferences'`). go_router nomme la page `state.name ?? state.path`, et `state.path` d'un enfant n'est que son segment : sans `name`, PostHog reçoit `preferences`, `new` ou `:id`, sans parent. Le test `test/app/router_screen_names_test.dart` fait échouer toute route imbriquée non nommée.

### Scarabée de signalement — sur chaque écran

`DonyFeedbackButton` (🐞, `lib/core/design/widgets/dony_feedback_button.dart`) envoie à Sentry un message + la capture automatique de l'écran + jusqu'à 4 captures choisies par le testeur (galerie ou appareil photo, via `DonyMediaService`). La capture automatique passe par le `RepaintBoundary` global posé dans `app.dart` (`DonyFeedbackButton.appBoundaryKey`) : **aucun écran n'a besoin de son propre `RepaintBoundary`**.

- `DonyAppBar` et `DonySliverAppBar` l'ajoutent **par défaut** en fin d'`actions` (`showFeedback: false` pour l'exclure : verrouillage, splash…). Un écran qui le place lui-même dans `actions` n'est pas doublé.
- Un `AppBar` brut ou un header maison (onglets Recherche, Activités, Messages, Moi) doit le poser explicitement : `actions: const [DonyFeedbackButton()]`, en dernière position.
- Tests : `test/core/design/widgets/dony_app_bar_feedback_test.dart` (présence par défaut) et `dony_feedback_button_test.dart` (pièces jointes via `pickImageOverride`, envoi via `onSubmitOverride(FeedbackReport)`).
- **Type de retour** : la feuille propose trois puces, `Bug` (défaut), `Avis`, `Suggestion` (`FeedbackKind`). Le type part en tag Sentry `feedback_kind`, en propriété PostHog `kind`, et en préfixe `[BUG]` / `[AVIS]` / `[SUGGESTION]` de la description du signalement backend (motif `SCREEN_BUG` inchangé, contrat figé) : l'admin › Signalements filtre sur ce préfixe.
- **Deux destinations** : Sentry (message `screen_feedback: <route>` + User Feedback + pièces jointes) ET le backend, par `ScreenFeedbackSender` (`lib/core/services/screen_feedback_sender.dart`) : `POST /reports/photos` pour la capture automatique (PNG temporaire) et les captures du testeur, puis `POST /reports` cible `APP`, motif `SCREEN_BUG`, `screenRoute` (yadony-back #317). Le rapport apparaît dans l'admin › Signalements. L'envoi backend n'est **jamais bloquant** : hors ligne ou backend ancien, Sentry a déjà reçu le rapport et le testeur voit le succès.
- **La route ET la capture automatique se prennent au tap** sur le scarabée (`resolveRoute(outerContext)`, `_captureScreen()` avant `DonyBottomSheet.show`) : prise à l'envoi, la capture montrait la feuille de signalement au lieu de l'écran. La route, elle, ne se lit jamais depuis la feuille : elle vit sur le navigateur racine, hors de tout écran GoRouter, et rendait `unknown`.

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
| `onboarding_step_skipped` | PersonalInfoCubit.skip() (`step: 'personal_info'`) · CountryOnboardingCubit.skip()/continueAsSenderOnly() (`step: 'country'`) — étape du parcours d'onboarding progressif passée |
| `onboarding_step_viewed` | `resolvePostSignupRoute` — étape retenue à l'entrée du parcours d'onboarding progressif (propriétés `step` énumération fermée, `index`, `total`) |
| `onboarding_step_completed` | CountryOnboardingCubit.select() (`step: 'country'`) · PersonalInfoCubit.submit() (`step: 'personal_info'`) · AnalyticsConsentScreen._respond() (`step: 'consent'`) — étape du parcours d'onboarding progressif complétée |
| `onboarding_completed` | `resolvePostSignupRoute` — `nextStep` rend `null`, le compte est complet (propriété `steps_total`) |
| `first_steps_choice` | FirstStepsScreen._track — écran `/first-steps`, émis depuis l'écran (choix de navigation sans état métier). Propriété `choice` : `trip`/`parcel`/`later` (écran historique) ou `see_trips`/`open_trip`/`publish_parcel`/`create_alert`/`publish_trip`/`open_package`/`later` (écran personnalisé) ; `variant` (écran personnalisé seulement) : `sender_full`/`sender_empty`/`traveler_full`/`traveler_empty`/`both_full`/`both_empty` |
| `intent_declared` | IntentCubit.submit — intention enregistrée (`/auth/intent`, feuille d'intention, Réglages). Propriétés : `intent` (`SENDER`/`TRAVELER`/`BOTH`), `destination_country` (code pays ou `OTHER`), `source` (`SIGNUP`/`PROMPT`/`SETTINGS`) |
| `intent_prompt_shown` | _MapSenderViewState._maybeAskIntent — feuille d'intention affichée à un compte existant sans intention (2 fois max, 7 jours d'écart) |
| `first_action_card_tapped` | FirstActionCard — carte épinglée de l'accueil (KYC vérifié, aucune première action). Propriété `variant` (mêmes valeurs que `first_steps_choice.variant`, plus `unknown`) |
| `success_screen_tertiary_tapped` | DonySuccessScreen — action tertiaire (ex. « Configurer mes paiements » après la publication d'un trajet). Propriété `context` |
| `login_success` | AuthBloc (check / phone / social / email) |
| `login_failed` | AuthBloc._onCheckRequested() |
| `guest_session_started` | AuthBloc._onGuestSessionRequested() — session Firebase anonyme ouverte avec succès depuis « Parcourir sans compte » |
| `guest_session_failed` | AuthBloc._onGuestSessionRequested() — échec de l'ouverture (hors ligne, Firebase indisponible), propriété `reason` (code Firebase ou `unknown`) |
| `guest_data_claimed` | AuthBloc._claimGuestData() — favoris posés en session visiteur rattachés au compte (`POST /auth/guest/claim` accepté), aussi bien à l'inscription qu'à la connexion à un compte existant (téléphone, e-mail, Google, Apple). Sortie de l'entonnoir invité |
| `guest_data_claim_failed` | AuthBloc._claimGuestData() — rattachement refusé ou impossible, propriété `reason` (code métier backend `guest-claim-*` / `user-not-found`, ou `unknown`). L'inscription ou la connexion aboutit malgré tout : le visiteur perd ses favoris, jamais son compte. Doublé d'un `AppLog.warn` car l'analytics se tait si le consentement est refusé |
| `kyc_started` | KycBloc._onSessionRequested() |
| `kyc_completed` | KycBloc._onStatusRefreshed() — une fois par instance, et une fois par compte et par appareil (`KycCompletionTracker`, clé Hive par UID) : rouvrir l'écran de statut d'un compte déjà vérifié ne le réémet plus |
| `kyc_failed` | KycBloc._onSessionRequested() |
| `announcement_created` | AnnouncementBloc._onCreateRequested() |
| `announcement_viewed` | `recordTripView` (`trip_view_recording.dart`), appelé à l'ouverture de la feuille trajet expéditeur (`showTravelerAnnouncementSheet`) par toute personne autre que le voyageur, invités compris (propriétés `announcement_id`, `corridor`). Le même appel signale la vue au back (`POST /announcements/{id}/views`) pour un compte connecté uniquement |
| `trip_owner_detail_opened` | TripOwnerDetailScreen._evaluateViewer — émis quand le viewer est confirmé propriétaire (annonce chargée + auth résolue), une fois par écran (propriété `status`). Un visiteur non propriétaire (deep link d'affiche partagée) est basculé vers la sheet expéditeur sans émettre l'événement |
| `trip_audience_loaded` | TripAudienceCubit.load — audience du trajet chargée sur l'écran propriétaire (`GET /announcements/{id}/insights`), propriétés `unique_viewers` (personnes distinctes dans l'app) et `share_views` (vues de la page web de l'affiche). Non émis en cas d'échec ou sur un back sans la route |
| `trip_parcels_viewed` | TripParcelsSection — chargement de la liste des colis embarqués (propriété `count`) |
| `trip_parcels_filtered` | TripParcelsSection — chip de filtre statut tapée dans « Colis dans le trajet » (propriété `status`, `all` si « Tous ») |
| `surplus_opened` | AnnouncementBloc._onSurplusOpenRequested() |
| `bid_submitted` | BidBloc._onCreateRequested() |
| `bid_accepted` | BidAcceptanceBloc._handleResponse() |
| `bid_rejected` | BidBloc._onRejectRequested() — refus confirmé par le serveur, depuis la feuille du motif (`RejectReasonSheet`, FLUTTER-AF). Propriétés `bid_id`, `reason` : code de la liste fermée (`NO_CAPACITY`/`CONTENT_NOT_ACCEPTED`/`HANDOVER_NOT_POSSIBLE`/`TRIP_CHANGED`/`OTHER`), jamais un texte saisi |
| `payment_initiated` | PaymentScreen._pay() |
| `payment_succeeded` | PaymentBloc._onPaymentSheetCompleted() (`/payments/pay`) · `confirmBidPaymentSafely` (paiement carte d'une offre, `context: bid`) · NegotiationBloc._onCheckout() (paiement carte d'une demande négociée, `context: negotiation`, seulement pour un PaymentIntent `pi_…`, jamais pour un accord en espèces) |
| `connect_onboarding_link_opened` | ConnectOnboardingBloc._onLinkRequested — lien du formulaire Stripe Connect obtenu |
| `connect_onboarding_completed` | ConnectOnboardingBloc._onPollingRequested — compte de versement actif au retour de Stripe (pas au chargement d'un statut déjà actif) |
| `connect_onboarding_still_pending` | ConnectOnboardingBloc._onPollingRequested — retour de Stripe sans formulaire terminé |
| `connect_onboarding_failed` | ConnectOnboardingBloc — échec (propriétés `stage` : `link`/`status`/`rejected`/`disabled`/`launch`, `reason`) |
| `payment_failed` | PaymentBloc._onPaymentFailed() |
| `mobile_money_awaiting` | MobileMoneyAwaitingScreen.initState |
| `mobile_money_account_activated` | MobileMoneyAccountBloc._onActivateRequested — compte de versement mobile money du voyageur (Wave/Orange Money) activé avec succès, réseaux cochés compris (propriétés `provider`, `providers_count`, `currency`). Même event réémis par _onProvidersUpdateRequested quand les réseaux acceptés d'un compte déjà actif sont modifiés sans ressaisir le numéro (propriété additionnelle `update: true`) |
| `mobile_money_account_disabled` | MobileMoneyAccountBloc._onDisableRequested — compte de versement mobile money désactivé (propriétés `provider`, `currency`) |
| `mobile_money_initiated` | MobileMoneyPaymentBloc._initiateAndEmit — dépôt mobile money initié pour le paiement d'un bid ou d'un fil de négociation, avant confirmation (propriétés `provider`, `wave` : redirection Wave ou non, `chosen` : opérateur explicitement choisi par l'expéditeur à l'étape « Avec quel opérateur ? », sinon celui prédit par le back, `scope` : `bid`/`negotiation`) |
| `mobile_money_confirmed` | MobileMoneyPaymentBloc._emitKnown — dépôt mobile money séquestré, une seule fois par transition (propriété `scope` : `bid`/`negotiation`) |
| `mobile_money_failed` | MobileMoneyPaymentBloc._emitKnown — dépôt mobile money refusé par l'opérateur, une seule fois par transition (propriété `failure_code`) |
| `qr_scan_success` | TrackingBloc._onScanSubmit() |
| `suivi_mode_changed` | SuiviCubit.selectMode()/followParcel() — onglet Suivi : l'utilisateur choisit « Valider une étape » ou « Suivre un colis », ou passe en Suivre depuis la feuille d'un colis inconnu (propriété `mode` : `valider`/`suivre`). Non émis pour le mode par défaut ni pour un mode imposé par l'URL (`/tracking?mode=…`) |
| `suivi_trip_changed` | ScanHubCubit.selectTrip() — trajet affiché changé dans l'onglet Suivi (propriété `source` : `picker` pour la feuille « Choisir un trajet », `other_trip` pour « Passer sur ce trajet » après le QR d'un colis d'un autre trajet) |
| `suivi_qr_scanned` | SuiviCubit.onQrScanned() — QR Yadony lu depuis la caméra de l'onglet Suivi ou le lecteur plein écran de l'expéditeur (propriétés `mode` : `valider`/`suivre`, `outcome` : `own_trip` colis du trajet affiché, `other_trip` colis d'un autre trajet du voyageur, `unknown` colis hors de ses trajets). Jamais l'identifiant du colis |
| `suivi_track_submitted` | SuiviCubit — parcours d'un colis demandé en lecture seule (propriété `source` : `number` numéro saisi, `qr` QR lu en mode Suivre ou « Suivre ce colis », `my_shipments` ligne de « Mes envois »). Jamais le numéro saisi |
| `suivi_step_validated` | SuiviValidationCubit._send() — étape DEPART/TRANSIT validée depuis l'onglet Suivi, envoyée (ou mise dans la file hors ligne) une fois passé le délai d'annulation de 5 s, ou aussitôt si l'onglet ou l'app est quitté (propriétés `step` : `DEPART`/`TRANSIT`, `method` : `qr` QR lu, `manual` numéro saisi dans la feuille ou bouton « Valider le départ » d'une ligne colis). Jamais l'identifiant ni le numéro du colis |
| `suivi_step_undone` | SuiviValidationCubit.undo() — « Annuler » touché sur le bandeau d'une validation rapide pendant le délai : rien n'est envoyé (propriété `step`) |
| `delivery_confirmed` | ReceptionConfirmScreen._confirm() |
| `package_request_created` | PackageRequestFormBloc |
| `package_request_updated` | PackageRequestFormBloc._onStep3() (mode édition) |
| `package_request_published` | PackageRequestDetailCubit.publish() — bouton « Publier » de la barre fixe de « Ma demande » (écran ou sheet), brouillon → OPEN |
| `package_request_unpublished` | PackageRequestDetailCubit.unpublish() — entrée « Dépublier » du menu « … » de « Ma demande » (OPEN → brouillon) |
| `package_request_cancelled` | PackageRequestDetailCubit.cancel() — annulation confirmée par le serveur depuis le menu « … » ; l'écran reste ouvert sur l'état « Annulée » |
| `package_request_shared` | PackageRequestDetailCubit.trackShared() — bouton « Partager » de « Ma demande » (partage texte système) |
| `package_request_traveler_invited` | PackageRequestDetailCubit.invite() — invitation d'un voyageur sur l'axe acceptée par le serveur (propriété `outcome` : `sent` / `already_sent`) |
| `package_request_menu_opened` | PackageRequestDetailCubit.trackMenuOpened() — ouverture du menu « … » de « Ma demande » |
| `package_request_duplicate_started` | PackageRequestDetailCubit.trackDuplicateStarted() — formulaire de création pré-rempli ouvert depuis une demande (propriété `source` : `duplicate` / `similar` / `republish`) |
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
| `commission_funding_currency_chosen` | BidAcceptanceBloc._accept (`context: bid`) · NegotiationBloc._onSettleCommission (`context: negotiation`) — commission d'un accord en espèces : le voyageur choisit, sur la feuille « Solde insuffisant », de payer le complément depuis un autre portefeuille converti au taux du jour (`fundingCurrency`, FLUTTER-CG). Propriété `currency` : code ISO du portefeuille choisi. Jamais de montant ni de solde |
| `messages_negotiations_shortcut_opened` | NegotiationsShortcutSection — ligne « Discussions de prix » épinglée sous « Support Yadony » en tête de Messages, visible dès qu'une négociation (demande d'envoi ou prix d'un trajet) est ouverte, raccourci vers `/negotiations` (FLUTTER-44). Propriétés `open_count`, `awaiting_me_count` (c'est à l'utilisateur de répondre ou de payer) |
| `conversation_opened` | ChatScreen.initState |
| `message_sent` | ChatBloc._onSendText() |
| `conversation_notifications_muted` / `conversation_notifications_unmuted` | ConversationNotificationsCubit.toggle() (menu ⋯ du chat, `source: chat`) · ConversationListBloc._onMuteToggled() (volet glissant de la liste, `source: list`) — sourdine d'une conversation confirmée par le serveur (`POST /conversations/{id}/mute`/`unmute`, FLUTTER-CM). Non émis en cas d'échec (bascule annulée) |
| `conversation_call_initiated` | ChatScreen._call() — tap 📞 dans le header chat (numéro révélé) |
| `call_mode_chosen` | ChatScreen — choix dans la feuille d'appel quand les deux modes existent (propriété `mode` : `yadony`/`phone`). Non émis quand un seul mode est possible (un tap direct) |
| `call_started` | CallBloc._onStart — appel Yadony créé par le back (`POST /conversations/{id}/calls` accepté), avant la sonnerie |
| `call_connected` | CallBloc._onSnapshot — l'autre partie a décroché, une fois par appel |
| `call_ended` | CallBloc._onSnapshot — fin d'appel signalée par Stream (propriété `reason` : `hangup`/`rejected`/`missed`/`failed`) |
| `call_failed` | CallBloc._onStart — lancement refusé ou impossible (propriété `code` : code d'erreur du back, ex. `call-out-of-window`, ou `unknown`) |
| `call_incoming_accepted` | CallBloc._onIncomingAccept — appel entrant décroché (propriété `native` : vrai si décroché depuis CallKit ou la notification Android) |
| `call_lock_screen_prompt_shown` | CallLockScreenCubit.markPromptShown — feuille « Ne manquez aucun appel » montrée une seule fois par installation, à l'ouverture d'une conversation avec appel Yadony, quand un réglage Android masquerait un appel entrant écran verrouillé (FLUTTER-92). Propriété `kind` : `full_screen_intent` (Android 14+, plein écran refusé) / `manufacturer` (Xiaomi, Redmi, POCO : « Afficher sur l'écran de verrouillage » illisible, simple rappel) |
| `call_lock_screen_settings_opened` | CallLockScreenCubit.openSettings — réglage système ouvert depuis la feuille ou la ligne « Appels sur l'écran verrouillé » de Réglages › Notifications (Android seulement). Propriétés `kind`, `source` : `prompt` / `settings` |
| `message_blocked` | ChatScreen._sendText() — message refusé par ChatMessageValidator (propriété `reason`) |
| `wallet_topup_started` | WalletTopupAmountScreen.initState |
| `wallet_topup_completed` | WalletBloc (après topup réussi) |
| `wallet_topup_mobile_money_initiated` | WalletTopupMobileMoneyCubit.initiate() — dépôt pawaPay lancé pour une recharge du portefeuille, avant confirmation (propriétés `provider`, `currency`, `custom` : montant saisi via « Autre montant » plutôt que choisi parmi les montants proposés, FLUTTER-CF). Jamais le montant ni le numéro de téléphone, même masqué |
| `wallet_topup_mobile_money_confirmed` | WalletTopupMobileMoneyCubit._poll() — recharge confirmée par pawaPay, portefeuille crédité, une seule fois par recharge (mêmes propriétés `provider`, `currency`) |
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
| `upgrade_to_pro_started` | UpgradeToProScreen.initState — ouverture de l'écran PRO, dans ses deux vues (vente pour un non-abonné, gestion pour un abonné) : la même intention est mesurée dans les deux cas |
| `pro_subscription_viewed` | SubscriptionBloc._onRequested — après un `GET /billing/subscription` réussi, y compris quand `status` vaut `none` (propriété `status`) |
| `pro_portal_opened` | SubscriptionBloc._onPortalOpenRequested — ouverture réussie du portail web externe (vente ou gestion), en navigateur externe jamais en webview (propriété `target` : `upgrade`/`manage`) |
| `pro_portal_open_failed` | SubscriptionBloc._onPortalOpenRequested — l'ouverture échoue (URL invalide ou lanceur en échec), l'écran restaure l'état précédent (propriété `target`) |
| `pro_downgrade_blocked` | UpgradeToProBloc._onDowngrade — `DELETE /auth/me/upgrade-to-pro` refusé en `409` `active-stripe-subscription` : l'abonnement Stripe est encore actif, la résiliation passe par le portail web. Aucune propriété (ni identifiant, ni message serveur) |
| `help_center_opened` | HelpCenterBloc._onOpenRequested — ouverture réelle du hub, distincte du préchargement global |
| `help_tutorial_opened` | HelpCenterBloc._onTutorialOpenRequested (propriétés contrôlées `tutorial_id`, `source`). Émis aussi par le bouton « ? » de l'en-tête de l'onglet Suivi en mode Valider (`SuiviHelpButton`, `source: 'qr_handover'`), qui ouvre le tutoriel de la remise par QR |
| `help_tutorial_play_started` | HelpCenterBloc._onPlaybackRequested — lecture démarrée (propriété `tutorial_id`) |
| `help_tutorial_completed` | HelpCenterBloc._onPlaybackRequested — lecture terminée (propriété `tutorial_id`) |
| `help_tutorial_external_opened` | HelpCenterBloc._onExternalOpenRequested — ouverture YouTube externe réussie (propriété `tutorial_id`) |
| `help_social_link_opened` | HelpCenterBloc._onExternalOpenRequested — réseau social ouvert (propriété enum `network`) |
| `help_youtube_subscribe_tapped` | HelpCenterBloc._onExternalOpenRequested — chaîne YouTube ouverte (propriété contrôlée `source`) |
| `help_config_load_failed` | HelpCenterBloc._emitFailure — échec non bloquant (propriété fermée `reason`: `fetch`/`parse`/`launch`) |
| `referral_shared` | ReferralBloc._onShared() |
| `analytics_consent_changed` | PrivacySettingsScreen.onChanged |
| `phone_visibility_toggled` | PrivacySettingsBloc._onToggleHidePhone — bascule « Masquer mon numéro » confirmée par le serveur (propriété `hidden`) |
| `user_blocked` | BlockedUsersBloc._onBlock — blocage confirmé par le serveur, depuis une fiche profil, un profil public ou une conversation. Aucune propriété : l'identité de la personne bloquée est sensible |
| `user_unblocked` | BlockedUsersBloc._onUnblock — déblocage confirmé depuis Confidentialité › Utilisateurs bloqués |
| `account_deletion_requested` | AccountDeletionBloc._onRequestDeletion() |
| `wallet_refund_requested` | Deux émetteurs, tracés après succès serveur : DeletionEligibilityCubit.requestWalletRefund() depuis la sheet « Supprimer mon compte » (`source: 'account_deletion'`) et WalletRefundRequestCubit.submit() depuis l'écran wallet (`source: 'wallet'`). Demande de remboursement du montant remboursable du portefeuille (partiel : le bonus non remboursable reste sur le solde), automatique par Stripe quand la recharge d'origine le permet, manuelle sinon. Seule propriété `source` : ni montant ni devise, PII financière |
| `shipment_filter_applied` | ShipmentFilterCubit (statut/période/preset, sans PII) |
| `shipment_new_request_opened` | ShipmentListScreen et MesColisScreen — pill « Envoyer » du header ouvre le wizard de demande d'envoi |
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
| `recipient_notified` | PrevenirDestinataireCard._notify — l'expéditeur prévient son destinataire depuis l'encart « Prévenir … » du détail d'envoi : WhatsApp pré-rempli (`wa.me`), repli sur la feuille de partage si le numéro n'est pas international ou si WhatsApp ne s'ouvre pas (propriétés `with_code` : le code de retrait est dans le message, `channel` : `whatsapp`/`share`, `status`). Jamais le numéro ni le nom du destinataire |
| `bid_recipient_changed` | RecipientChangeCubit.submit — l'expéditeur change de destinataire depuis la carte « Colis & destinataire » ou le menu d'options du détail d'envoi, changement accepté par le serveur (`PUT /bids/{bidId}/recipient`) jusqu'à la remise (propriétés `phone_changed` : nouveau numéro, donc lien de suivi et code renouvelés, `status` : statut du colis avant le changement). Non émis sur un 409 (colis déjà remis). Jamais le nom ni le numéro |
| `recipient_replacement_requested` | RecipientReplacementCubit.request — le voyageur demande à l'expéditeur un autre destinataire après un refus (`POST /bids/{bidId}/recipient/replacement-request`, FLUTTER-E8), confirmé dans une feuille depuis la carte « Colis & destinataire » ou la feuille « Prévenir les destinataires ». Propriétés `status` (statut du colis) et `outcome` : `sent` (demande acceptée) ou `too_soon` (429, moins de 12 h après la précédente). Non émis sur un 409 ni une erreur réseau. Jamais le nom ni le numéro |
| `recipients_notify_opened` | NotifyRecipientsSheet.show — le voyageur ouvre la feuille « Prévenir les destinataires » de l'écran trajet (propriétés `count` : colis remis, en transit ou arrivés, `source` : `after_arrival` ouverture automatique après « Marquer arrivé », `manual` bouton de l'écran) |
| `recipient_contacted` | contactRecipient — le voyageur contacte un destinataire depuis la feuille « Prévenir les destinataires » ou la vue voyageur d'un envoi (propriétés `channel` : `whatsapp`/`sms`/`call`, `status` du colis, `in_app` : le destinataire suit le colis dans Yadony). Jamais le numéro ni le nom |
| `recipient_conversation_opened` | ConversationOpenBloc._onRecipientOpen — conversation séparée voyageur ↔ destinataire ouverte ou créée (`GET /conversations/bid/{bidId}/recipient`), depuis le bouton « Message » du voyageur (feuille « Prévenir les destinataires », carte « Contacter le destinataire ») ou « Écrire au voyageur » de l'écran `/receptions/{bidId}` (propriété `role` : `traveler`/`recipient`). Non émis sur un refus (403/404). Jamais le nom ni le numéro |
| `tool_configured` | ToolsCompletionCubit._trackProgress — un des cinq outils (Hub Activités › Outils) passe de 0 à au moins un élément entre deux chargements successifs (propriétés `tool` : clé API, `ready`, `total`). Non émis au premier chargement d'une session : un outil déjà prêt n'émet rien |
| `tools_setup_completed` | ToolsCompletionCubit._trackProgress — le dernier outil est rempli, `ready == total` (propriété `total`). Une fois par transition, jamais pour un compte déjà complet à l'ouverture |
| `payment_card_saved` | CommissionMethodBloc._saveAndReload — carte enregistrée après le SetupIntent Stripe (propriété `context` : `commission`, la carte du voyageur pour la commission d'un paiement en espèces). Jamais le numéro ni la marque |
| `price_grid_item_added` | PriceGridBloc._onAdd — article ajouté à la grille de prix, confirmé par le serveur. Aucune propriété : ni libellé ni prix |
| `price_grid_created` | PriceGridBloc._onAdd — premier article d'une grille vide : l'outil « grille de prix » devient prêt |
| `bid_cancelled` | BidBloc._onCancelRequested — offre annulée avant la remise, confirmée par le serveur (propriétés `actor` : `sender`/`traveler`, `status` : statut de l'offre rendu). L'annulation après remise reste `cancel_after_handover_initiated` |
| `recipient_message_tapped` | ConversationOpenBloc._onRecipientOpen — appui sur « Message » vers le destinataire (voyageur) ou « Écrire au voyageur » (destinataire), avant la réponse du serveur ; émis aussi quand l'ouverture est refusée (propriété `role` : `traveler`/`recipient`). `recipient_conversation_opened` ne part qu'au succès |
| `receptions_section_viewed` | ReceptionsCubit.load — section « Colis à recevoir » de l'onglet Suivi affichée (liste non vide), une fois par ouverture de l'onglet (propriétés `count`, `pending` : colis encore à confirmer). Jamais émis sur un back antérieur au lot 2 (404, section masquée) |
| `reception_opened` | ReceptionDetailCubit.load — écran `/receptions/{bidId}` chargé (section Suivi ou notification `RECIPIENT_PARCEL_*`), une fois par écran même après « Réessayer » (propriétés `link_status` : `PENDING`/`CONFIRMED`, `bid_status`). Jamais le nom, le numéro ni le code |
| `reception_confirmed` | ReceptionDetailCubit.confirm — « Oui, c'est pour moi » accepté par le serveur (`POST /receptions/{bidId}/confirm`), propriété `bid_status` |
| `reception_declined` | ReceptionDetailCubit.decline — « Ce n'est pas pour moi » confirmé dans la feuille de confirmation (FLUTTER-E8) puis accepté par le serveur (204), propriété `bid_status`. Non émis sur un 409 (colis déjà confirmé ailleurs) |
| `reception_withdrawn` | ReceptionDetailCubit.decline — « Me retirer de ce colis » confirmé dans la feuille de confirmation (FLUTTER-E8) puis accepté par le serveur (`POST /receptions/{bidId}/decline` sur un lien `CONFIRMED`, 204), tant que le colis est en cours (FLUTTER-9F). L'expéditeur et le voyageur reçoivent `RECIPIENT_WITHDRAWN`. Propriété `bid_status`. Non émis sur un 409 (`reception-not-withdrawable`, colis déjà livré) |
| `reception_traveler_rated` | ReceptionDetailCubit.rateTraveler — le destinataire confirmé note le voyageur depuis `/receptions/{bidId}` une fois le colis livré, note acceptée par le serveur (`POST /receptions/{bidId}/rating`, 201, FLUTTER-CA). Propriété `stars` (1 à 5). Non émis sur un 409 (`reception-already-rated`, `reception-rating-not-allowed`). Jamais le commentaire ni un identifiant |
| `screen_feedback_submitted` | Envoi du rapport 🐞 DonyFeedbackButton (propriétés `route`, `kind` : `bug`/`feedback`/`suggestion`, type choisi par le testeur sur les puces « Bug / Avis / Suggestion », `attachment_count` : captures jointes par le testeur, jamais leur contenu) |
| `profile_photo_updated` | AuthBloc._onAvatarUploadRequested() — upload photo de profil réussi |
| `profile_about_updated` | AuthBloc._onUpdateProfileRequested() — bio « À propos » renseignée |
| `public_reviews_opened` | UserReviewsCubit — ouverture de la bottom sheet « tous les avis » (propriété `rating_count`) |
| `reviews_filtered` | MyReviewsBloc._onStarFilterToggled — tap sur une ligne de distribution dans « Mes avis reçus » (propriété `stars`: note 1–5 ou `all` si filtre retiré) |
| `faq_question_opened` | FaqBloc — ouverture d’une réponse du Centre d’aide (propriétés `category`, `question_id`, identifiants non sensibles) |
| `faq_contact_requested` | FaqBloc — tap sur « Contacter le support » depuis le Centre d’aide |
| `support_ticket_created` | SupportBloc._onCreateRequested — ticket support créé avec succès (propriété `category`, énumération fermée backend ; jamais le sujet ni le message) |
| `support_ticket_message_sent` | SupportBloc._onMessageSendRequested — message utilisateur envoyé dans un ticket existant, avant rechargement du fil. Aucune propriété : le contenu ne part jamais dans l'analytics |
| `support_ticket_hidden` | SupportBloc._onHideRequested — ticket résolu retiré de « Mes tickets » (bouton corbeille puis confirmation), confirmé par le serveur (`DELETE /support/tickets/{id}`, FLUTTER-9W). Le ticket reste visible du back-office. Aucune propriété |
| `support_attachment_added` | SupportBloc — image jointe uploadée avec succès dans un fil support. Aucune propriété : ni chemin, ni taille, ni contenu ne partent dans l'analytics |
| `trip_matching_viewed` | PackageRequestSearchBloc._onFiltersChanged — chargement d'une recherche colis filtrée « Pour mes trajets » (propriété `count`) |
| `package_match_alert_toggled` | NotificationPrefsBloc._onPackageMatchAlertToggled — ligne « Nouveaux colis compatibles » des réglages de notifications (propriété `enabled`) |
| `announcements_inbox_opened` | AnnouncementsInboxBloc._onLoad — boîte « Annonces Yadony » chargée depuis la carte du sheet de notifications (propriétés `count`, `unread`), jamais le texte d'une annonce |
| `notification_detail_opened` | NotificationDetailCubit.load — écran de détail générique d'une notification chargé, réservé aux lignes sans deeplink (propriétés `type`, `category`), jamais le texte |
| `notification_pref_toggled` | NotificationPrefsBloc._onToggled — bascule d'une catégorie de push confirmée par le serveur (propriétés `pref`, `enabled`) ; non émis si l'écriture échoue |
| `subscription_push_toggled` | SubscriptionsBloc._onTogglePush — cloche d'un voyageur suivi, tracée avec l'état rendu par le serveur (propriété `enabled`). Ne mesure que le push : la notification reste inscrite au centre de notifications dans les deux cas |
| `subscription_removed` | SubscriptionsBloc._onUnsubscribe — désabonnement confirmé, après acquittement du serveur |
| `subscriptions_marked_all_seen` | SubscriptionsBloc._onMarkAllSeen — « Tout marquer comme vu » de l'en-tête (propriété `count` : pastilles réellement retirées). Non émis si l'appel échoue et que les pastilles reviennent |
| `subscription_last_trip_opened` | MesAbonnementsScreen — tap sur la ligne du dernier trajet d'une carte, raccourci vers l'annonce, distinct du tap sur la carte qui mène au profil du voyageur |
| `corridor_alert_toggled` | CorridorAlertListBloc._onToggle — actif/pause d'une alerte corridor (propriété `active`) |
| `corridor_alert_deleted` | CorridorAlertListBloc._onDelete — suppression d'une alerte corridor |
| `corridor_alert_created` | CorridorAlertFormCubit.submit() — création d'une alerte corridor |
| `corridor_alert_updated` | CorridorAlertFormCubit.submit() — édition d'une alerte corridor |
| `favorites_opened` | FavoritesScreen.initState — ouverture du hub favoris |
| `recipient_picker_opened` | RecipientPickerSheet.initState — ouverture de la sheet de sélection destinataire |
| `recipient_selected` | RecipientBloc._onPicked — destinataire confirmé dans la sheet (propriété `source`: saved/phone_contact/new) |
| `recipient_created` | RecipientBloc._onCreated — destinataire ajouté au carnet |
| `recipient_default_set` | RecipientBloc._onDefaultSet — destinataire marqué par défaut |
| `recipient_invitation_sent` | InviteRecipientCubit.submit — invitation « destinataire Yadony » partie depuis la feuille « Ajouter un destinataire Yadony » du carnet (`POST /recipient-invitations`, 202 identique que le compte existe ou non), propriété `channel` : `phone`/`email`. Non émis sur un 429 (quota) ni un 422. Jamais le numéro ni l'e-mail |
| `recipient_invitation_answered` | IncomingInvitationsCubit.accept()/decline() — l'invité répond à une demande depuis `/recipient-invitations`, réponse acceptée par le serveur (propriété `answer` : `accepted`/`declined`). Non émis sur le 409 `recipient-invitation-phone-required`. Jamais le prénom de l'expéditeur |
| `recipient_invitation_revoked` | SentInvitationsCubit.revoke() (`side: inviter`, « Annuler » d'une invitation envoyée du carnet) · IncomingInvitationsCubit.revoke() (`side: invitee`, « Retirer » un expéditeur autorisé), après le 204 du `DELETE /recipient-invitations/{id}` |
| `recipient_invitation_app_link_shared` | SentInvitationsCubit.trackAppLinkShared() — « Partager le lien de l'app » touché sur une invitation envoyée du carnet, à l'ouverture de la feuille de partage système (lien d'installation https://yadony.com). Aucune propriété : ni la cible, ni le canal choisi dans la feuille système |
| `activites_hub_trips_opened` / `activites_hub_envois_opened` / `activites_hub_demandes_opened` / `activites_hub_negotiations_opened` | ActivitesHubScreen — tap sur une tuile d'activité du hub. `activites_hub_envois_opened` porte la tuile « Mes colis », qui ouvre `/envois` (MesColisScreen : envois en route + demandes publiées) |
| `activites_hub_trip_create_opened` / `activites_hub_request_create_opened` | ActivitesHubScreen — CTA « Publier un trajet » / « Publier un colis » |
| `activites_hub_stats_period_changed` | ActivitesHubScreen — changement de période des statistiques |
| `activites_hub_stats_revenues_opened` / `activites_hub_stats_kg_sold_opened` / `activites_hub_stats_trips_opened` / `activites_hub_stats_parcels_opened` | ActivitesHubScreen._StatsRow — tap sur une tuile de statistiques (feuille Revenus, feuille Kg vendus, Mes trajets filtré Terminés, Mes colis filtré Livrés) |
| `activites_hub_menu_opened` | ActivitesHubScreen._openMenu — bouton burger du header, à l'ouverture de la feuille de menu (`ActivitesMenuSheet`). Émis même si la feuille est refermée sans choisir : c'est l'entrée de l'entonnoir |
| `activites_hub_search_opened` | ActivitesHubScreen._openMenu — entrée « Suivre un colis » de la feuille de menu (l'ancien bouton du header a été remplacé par le burger), qui ouvre l'onglet Suivi en mode Suivre (`/tracking?mode=suivre`) |
| `activites_hub_scan_opened` | ActivitesHubScreen._openMenu — entrée « Scanner un colis » de la feuille de menu, qui ouvre l'onglet Suivi en mode Valider (`/tracking?mode=valider`) |
| `activites_hub_settings_opened` | ActivitesHubScreen._openMenu — entrée « Paramètres » de la feuille de menu |
| `activites_hub_wallet_opened` | ActivitesHubScreen._openMenu — entrée « Portefeuille » de la feuille de menu |
| `activites_hub_history_opened` / `activites_hub_help_opened` / `activites_hub_alerts_opened` / `activites_hub_templates_opened` / `activites_hub_addresses_opened` / `activites_hub_recipients_opened` | ActivitesHubScreen — tuiles de la section Outils, et entrées correspondantes de la feuille de menu du burger (même événement des deux côtés : c'est la destination qui est mesurée, pas le chemin) |
| `activites_hub_tools_completion_loaded` | ToolsCompletionCubit.load — `GET /users/me/tools-completion` réussi (propriétés `ready`, `total`), non émis en cas d'échec |
| `activites_hub_tools_cta_tapped` | ActivitesHubScreen._onToolCta — tap sur le CTA de la carte « Publiez en 3 taps » (propriété `tool` : clé API de l'outil ouvert) |
| `activites_hub_intro_dismissed` | ActivitesHubScreen — fermeture (X) de la carte d'introduction |
| `profile_menu_opened` | ProfileScreen._openMenu — bouton burger de l'en-tête de l'onglet Moi, à l'ouverture de la feuille de menu (`ProfileMenuSheet`). Émis même si la feuille est refermée sans choisir : c'est l'entrée de l'entonnoir |
| `profile_menu_edit_opened` / `profile_menu_settings_opened` / `profile_menu_export_opened` | ProfileScreen._openMenu — entrées « Modifier le profil » (`/profile/edit`), « Paramètres » (`/settings`) et « Télécharger mes données » (`/settings/data`) de la feuille de menu. Ces trois destinations n'ont plus d'autre chemin depuis l'onglet Moi : le crayon du header et la tuile Paramètres ont été retirés |
| `profile_header_tapped` | ProfileScreen — tap sur l'avatar ou le nom de l'en-tête de l'onglet Moi, ouvre « Modifier le profil » (`/profile/edit`), raccourci vers la même destination que l'entrée du menu (FLUTTER-9X) |
| `profile_photo_viewed` | ProfilePhotoViewer.show — photo de profil ouverte en grand depuis « Modifier le profil » (tap sur l'avatar quand une photo existe, FLUTTER-9Y). Aucune propriété |
| `profile_languages_picked` | SpokenLanguagesSheet — liste déroulante des langues parlées validée depuis « Modifier le profil » (FLUTTER-9Z), avant l'enregistrement du profil (propriétés `count` : langues retenues, `custom_count` : langues saisies par « Autre langue »). Jamais le nom des langues saisies |
| `profile_menu_logout_tapped` | ProfileScreen._openMenu — entrée « Se déconnecter » de la feuille de menu, avant le dialogue de confirmation (la déconnexion effective reste `AuthLogoutRequested`) |
| `profile_menu_delete_opened` | ProfileScreen._openMenu — entrée « Supprimer mon compte » de la feuille de menu, à l'ouverture de `DeleteAccountBottomSheet` (la demande effective reste `account_deletion_requested`). L'entrée est masquée quand une suppression est déjà en cours |
| `traveler_bids_filter_applied` | TravelerBidsBloc._onFilterChanged — chips « À traiter / Acceptées / Terminées » de l'écran Demandes (propriété `filter`) |
| `home_search_mode_changed` | HomeScreen._onModeChanged — bascule du sélecteur de mode Trajets/Colis (propriété `mode`) |
| `home_cross_discovery_tapped` | HomeScreen._onCrossDiscoveryTap — bascule proposée depuis l'état vide (propriétés `from_mode`, `count`) |
| `home_matching_trips_filter_toggled` | HomeScreen._showFilterSheet — pastille « Pour mes trajets » de la feuille de filtres colis (propriétés `active`, `active_trips`) |
| `settings_guidance_cards_reset` | SettingsScreen._resetGuidanceCards — tuile « Réafficher les suggestions », efface les flags de fermeture des `ContextualTutorialCard` fermées dans l'app |
| `accessibility_setting_changed` | AccessibilityBloc — un réglage d'accessibilité est modifié (propriétés `setting`, `value`) ou réinitialisation complète (`setting: reset`) |
| `trip_marked_arrived` | AnnouncementBloc._onTripMarkArrivedRequested() — voyageur marque son trajet arrivé à destination |
| `arrival_instructions_updated` | AnnouncementBloc._onArrivalInstructionsUpdateRequested() — édition des instructions de retrait après le marquage initial |
| `trip_negotiable_toggled` | AnnouncementFormBloc._onNegotiableChanged — bascule « J'accepte les propositions de prix » de l'étape Prix & Conditions du wizard de publication d'un trajet (propriété `enabled`), émis aussi depuis l'étape Prix & conditions de l'écran modèle de trajet (même bloc `AnnouncementFormBloc`) |
| `trip_negotiation_opened` | BidNegotiationBloc._onOpen — l'expéditeur ouvre le mode négociation depuis le second CTA « Proposer un prix » du détail du trajet (propriété `announcement_id`). Aucun appel réseau : c'est l'entrée de l'entonnoir, mesurée même si aucune proposition n'est envoyée |
| `trip_negotiation_proposed` | BidNegotiationBloc._onPropose — première proposition de prix envoyée avec succès (propriétés `announcement_id`, `has_custom_items`, `custom_item_count`, `payment_method` : mode choisi à l'étape « Comment veux-tu payer ? », `STRIPE`/`CASH`/`MOBILE_MONEY`). Ni description, ni destinataire, ni montant : seul le motif de négociation est mesuré |
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
| `search_submitted` | HomeScreen._openComposer() — retour de l'écran de composition de recherche (bouton « Rechercher »), seul point d'émission : les chips et feuilles de filtres ne l'émettent pas, ils passent par `search_filter_applied` / `search_filter_cleared` (propriétés `mode`, `filter_count`, `came_from_phrase` — cette dernière mesure la part des recherches qui passent par la phrase plutôt que par les filtres au doigt, elle décidera du sort du bloc « En une phrase ») |
| `search_filter_applied` | HomeScreen._trackFilterDiff — un filtre passe d'inactif à actif, quel que soit le chemin (chip, feuille de filtres, composeur, bascule « Pour mes trajets »). Propriétés `filter` (énumération fermée de `HomeSearchFilters.activeKeys` : `departure`, `arrival`, `date`, `urgent`, `near_me`, `kilo_pro`, `rating`, `weight`, `price`, `weekend`, `transport_mode`, `kyc_verified`, `content_type`, `urgency`, `max_weight`, `parcel_size`, `matching_my_trips`) et `mode`. Jamais la valeur choisie (ville, poids, prix). Sert à classer les filtres les plus et les moins utilisés |
| `search_filter_cleared` | HomeScreen._trackFilterDiff — un filtre passe d'actif à inactif (mêmes propriétés `filter`, `mode`) |
| `preferred_language_synced` | LanguageSyncCubit.sync() — langue effective de l'app (`fr`/`en` résolue, jamais `system`) écrite avec succès dans `preferredLanguage` du compte serveur, au démarrage, à la connexion ou à un changement de langue (propriété `language`). Non émis quand la langue était déjà à jour côté serveur, sur un backend ancien (404) ou en cas d'échec réseau |
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
| _(polices embarquées)_ | **Plus Jakarta Sans**, Hanken Grotesk, Caveat — fichiers dans `assets/fonts/`, déclarés en `fonts:` dans le pubspec. `google_fonts` a été retiré : il les téléchargeait au premier lancement et l'échec remontait en erreur fatale (Sentry FLUTTER-2) |
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

**Typographie :** `Theme.of(context).textTheme.X` partout, jamais de `fontFamily` en dur. `fontSize < 12` interdit. Contraste ≥ 4.5:1.
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
