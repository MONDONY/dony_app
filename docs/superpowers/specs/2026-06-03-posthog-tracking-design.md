# PostHog Tracking — Design Spec
**Date:** 2026-06-03  
**Branch:** feature/analytics-posthog  
**Scope:** Tiers 1 + 2 + 3 (38 events)

---

## Contexte

Le SDK PostHog est déjà intégré (`posthog_flutter: ^5.25.2`) avec :
- Init manuel (`AUTO_INIT=false`) dans `main.dart`
- `AnalyticsService` avec abstraction `AnalyticsBackend` (mockable)
- Consentement RGPD opt-in strict via Hive (`kAnalyticsConsent`)
- `PosthogObserver` sur GoRouter pour le screen tracking automatique
- `AnalyticsConsentGate` pour identify/reset sur les changements d'auth

Ce spec couvre l'instrumentation des events métier dans les BLoCs et écrans.

---

## Architecture

### Principe directeur

Les events avec propriétés métier riches (amount, corridor, bid_id) vivent dans les **BLoC handlers**, pas dans un BlocObserver. Le BlocObserver ne gère que les erreurs globales.

```
AnalyticsEvents          → noms de constantes (zéro logique)
AnalyticsBlocObserver    → erreurs globales uniquement
BLoC handlers            → events métier avec propriétés
Écrans                   → events déclenchés par geste utilisateur sans BLoC
AnalyticsService         → gate isEnabled, no-op si refus/non configuré
PosthogObserver          → screen tracking automatique (GoRouter)
AnalyticsConsentGate     → identify/reset sur authStateChanges
```

### Injection

`AnalyticsService` est un singleton GetIt déjà enregistré. Il est passé comme paramètre constructeur aux 16 BLoCs concernés. Les écrans l'accèdent via `getIt<AnalyticsService>()`.

---

## Nouveaux fichiers

### `lib/core/services/analytics_events.dart`

Classe avec uniquement des `static const String`. Groupés par feature. Aucun import, aucune logique.

```dart
abstract final class AnalyticsEvents {
  // Auth
  static const signupStarted            = 'signup_started';
  static const otpSubmitted             = 'otp_submitted';
  static const signupCompleted          = 'signup_completed';
  static const analyticsConsentAnswered = 'analytics_consent_answered';
  static const loginSuccess             = 'login_success';
  static const loginFailed              = 'login_failed';

  // KYC
  static const kycStarted   = 'kyc_started';
  static const kycCompleted = 'kyc_completed';
  static const kycFailed    = 'kyc_failed';

  // Announcements
  static const announcementCreated = 'announcement_created';
  static const announcementViewed  = 'announcement_viewed';

  // Bids
  static const bidSubmitted = 'bid_submitted';
  static const bidAccepted  = 'bid_accepted';
  static const bidRejected  = 'bid_rejected';

  // Payments
  static const paymentInitiated    = 'payment_initiated';
  static const paymentSucceeded    = 'payment_succeeded';
  static const paymentFailed       = 'payment_failed';
  static const mobileMoneyAwaiting = 'mobile_money_awaiting';

  // Tracking / QR
  static const qrScanSuccess    = 'qr_scan_success';
  static const deliveryConfirmed = 'delivery_confirmed';

  // Package Request
  static const packageRequestCreated    = 'package_request_created';
  static const packageRequestSearched   = 'package_request_searched';
  static const negotiationOfferMade     = 'negotiation_offer_made';
  static const negotiationOfferAccepted = 'negotiation_offer_accepted';

  // Messaging
  static const conversationOpened = 'conversation_opened';
  static const messageSent        = 'message_sent';

  // Wallet
  static const walletTopupStarted   = 'wallet_topup_started';
  static const walletTopupCompleted = 'wallet_topup_completed';

  // Ratings
  static const ratingSubmitted = 'rating_submitted';

  // Cancellations
  static const cancellationInitiated = 'cancellation_initiated';
  static const rematchAccepted       = 'rematch_accepted';

  // Profile
  static const becomeTravelerStarted = 'become_traveler_started';
  static const upgradeToProStarted   = 'upgrade_to_pro_started';

  // Referral
  static const referralShared = 'referral_shared';

  // Settings
  static const analyticsConsentChanged    = 'analytics_consent_changed';
  static const accountDeletionRequested   = 'account_deletion_requested';

  // Errors (BlocObserver)
  static const blocError = 'bloc_error';
}
```

### `lib/core/services/analytics_bloc_observer.dart`

Override de `onError` uniquement. Capture le nom du BLoC et le type d'erreur.

```dart
class AnalyticsBlocObserver extends BlocObserver {
  const AnalyticsBlocObserver(this._analytics);
  final AnalyticsService _analytics;

  @override
  void onError(BlocBase bloc, Object error, StackTrace stack) {
    super.onError(bloc, error, stack);
    unawaited(_analytics.logEvent(AnalyticsEvents.blocError, properties: {
      'bloc_name': bloc.runtimeType.toString(),
      'error_type': error.runtimeType.toString(),
    }));
  }
}
```

---

## Catalogue des events

### Tier 1 — Funnel de conversion (20 events)

#### Auth

| Event | Propriétés | Déclencheur |
|---|---|---|
| `signup_started` | `method: phone\|email` | `phone_auth_screen` — onSubmit |
| `otp_submitted` | `attempt_count: int` | `otp_verification_screen` — on code complet |
| `signup_completed` | — | `pin_setup_screen` — après `savePin()` |
| `analytics_consent_answered` | `granted: bool` | `analytics_consent_screen` — bouton Accepter/Non merci |
| `login_success` | `method: phone\|email` | `AuthBloc` — état `Authenticated` |
| `login_failed` | `error_type: String` | `AuthBloc` — état `AuthError` |

#### KYC

| Event | Propriétés | Déclencheur |
|---|---|---|
| `kyc_started` | `user_role: sender\|traveler` | `KycBloc` — handler KycStarted |
| `kyc_completed` | — | `KycBloc` — état KycSuccess |
| `kyc_failed` | `reason: String` | `KycBloc` — état KycError |

#### Announcements

| Event | Propriétés | Déclencheur |
|---|---|---|
| `announcement_created` | `corridor: String`, `weight_kg: double`, `price: int` | `AnnouncementBloc` — success |
| `announcement_viewed` | `announcement_id: String`, `corridor: String` | `announcement_detail_screen` — initState |

#### Bids

| Event | Propriétés | Déclencheur |
|---|---|---|
| `bid_submitted` | `announcement_id: String`, `amount: int`, `weight_kg: double` | `BidBloc` — success |
| `bid_accepted` | `bid_id: String`, `amount: int` | `BidAcceptanceBloc` — accepted |
| `bid_rejected` | `bid_id: String` | `BidAcceptanceBloc` — rejected |

#### Payments

| Event | Propriétés | Déclencheur |
|---|---|---|
| `payment_initiated` | `method: card\|mobile_money\|wallet`, `amount: int` | `payment_screen` — bouton payer |
| `payment_succeeded` | `method: String`, `amount: int`, `bid_id: String` | `PaymentBloc` — success |
| `payment_failed` | `method: String`, `error_code: String` | `PaymentBloc` — error |
| `mobile_money_awaiting` | `provider: String` | `mobile_money_awaiting_screen` — initState |

#### Tracking / QR

| Event | Propriétés | Déclencheur |
|---|---|---|
| `qr_scan_success` | `scan_type: pickup\|handover\|delivery` | `TrackingBloc` — success |
| `delivery_confirmed` | `bid_id: String` | `reception_confirm_screen` — confirm |

---

### Tier 2 — Adoption features (10 events)

#### Package Request

| Event | Propriétés | Déclencheur |
|---|---|---|
| `package_request_created` | `corridor: String` | `PackageRequestBloc` — success |
| `package_request_searched` | `corridor: String` | `PackageRequestSearchBloc` — search |
| `negotiation_offer_made` | `amount: int`, `context: sender\|traveler` | `NegotiationBloc` — offer sent |
| `negotiation_offer_accepted` | `amount: int` | `NegotiationBloc` — accepted |

#### Messaging

| Event | Propriétés | Déclencheur |
|---|---|---|
| `conversation_opened` | `context: bid\|package_request` | `chat_screen` — initState |
| `message_sent` | — | `ChatBloc` — message sent |

#### Wallet

| Event | Propriétés | Déclencheur |
|---|---|---|
| `wallet_topup_started` | — | `wallet_topup_amount_screen` — initState |
| `wallet_topup_completed` | `amount: int` | `WalletBloc` — success |

#### Ratings

| Event | Propriétés | Déclencheur |
|---|---|---|
| `rating_submitted` | `score: int`, `role_rated: sender\|traveler` | `RatingBloc` — success |

---

### Tier 3 — UX & rétention (8 events)

#### Cancellations

| Event | Propriétés | Déclencheur |
|---|---|---|
| `cancellation_initiated` | `reason: String`, `initiator_role: sender\|traveler` | `CancellationBloc` — initiated |
| `rematch_accepted` | — | `CancellationBloc` — rematch success |

#### Profile

| Event | Propriétés | Déclencheur |
|---|---|---|
| `become_traveler_started` | — | `become_traveler_screen` — initState |
| `upgrade_to_pro_started` | — | `upgrade_to_pro_screen` — initState |

#### Referral

| Event | Propriétés | Déclencheur |
|---|---|---|
| `referral_shared` | `channel: String` | `ReferralBloc` — share action |

#### Settings

| Event | Propriétés | Déclencheur |
|---|---|---|
| `analytics_consent_changed` | `granted: bool` | `privacy_settings_screen` — toggle |
| `account_deletion_requested` | — | `AccountDeletionBloc` — initiated |

#### Erreurs globales (BlocObserver)

| Event | Propriétés | Déclencheur |
|---|---|---|
| `bloc_error` | `bloc_name: String`, `error_type: String` | `AnalyticsBlocObserver.onError` |

---

## Règles PII

Aucune propriété ne doit contenir :
- Numéro de téléphone
- Email
- Nom ou prénom
- Adresse postale exacte
- Montant exact de colis déclaré
- Tout identifiant lié à la carte bancaire

Les identifiants sont toujours des UUIDs backend opaques.

---

## Fichiers à créer / modifier

### Nouveaux (2)
```
lib/core/services/analytics_events.dart
lib/core/services/analytics_bloc_observer.dart
```

### Modifiés — infrastructure (2)
```
lib/main.dart                   ← Bloc.observer = AnalyticsBlocObserver(...)
lib/core/di/injection.dart      ← passer AnalyticsService aux 16 BLoCs
```

### Modifiés — BLoCs (16 — `mobile_money_awaiting` déclenché depuis l'écran, pas le BLoC)
```
features/auth/bloc/auth_bloc.dart
features/kyc/bloc/kyc_bloc.dart
features/matching/bloc/announcement_bloc.dart
features/matching/bloc/bid_bloc.dart
features/matching/bloc/bid_acceptance_bloc.dart
features/payments/bloc/payment_bloc.dart
features/tracking/bloc/tracking_bloc.dart
features/package_request/bloc/package_request_bloc.dart
features/package_request/bloc/package_request_search_bloc.dart
features/package_request/bloc/negotiation_bloc.dart
features/messaging/bloc/chat/chat_bloc.dart
features/payments/bloc/wallet/wallet_bloc.dart
features/ratings/bloc/rating_bloc.dart
features/cancellation/bloc/cancellation_bloc.dart
features/settings/bloc/account_deletion_bloc.dart
features/referral/bloc/referral_bloc.dart
```

### Modifiés — écrans (13)
```
features/auth/presentation/screens/phone_auth_screen.dart
features/auth/presentation/screens/otp_verification_screen.dart
features/auth/presentation/screens/pin_setup_screen.dart
features/auth/presentation/screens/analytics_consent_screen.dart
features/matching/presentation/screens/announcement_detail_screen.dart
features/payments/presentation/screens/payment_screen.dart
features/matching/presentation/screens/mobile_money_awaiting_screen.dart
features/tracking/presentation/screens/reception_confirm_screen.dart
features/messaging/presentation/screens/chat_screen.dart
features/payments/presentation/screens/wallet/wallet_topup_amount_screen.dart
features/profile/presentation/screens/become_traveler_screen.dart
features/profile/presentation/screens/upgrade_to_pro_screen.dart
features/settings/presentation/screens/privacy_settings_screen.dart
```

### Nouveaux — tests (18 : 1 helper partagé + 17 fichiers de test)
```
test/helpers/mock_analytics_backend.dart   ← déplacé de analytics_service_test.dart
test/core/services/analytics_events_test.dart
test/core/services/analytics_bloc_observer_test.dart
test/features/auth/bloc/auth_bloc_analytics_test.dart
test/features/kyc/bloc/kyc_bloc_analytics_test.dart
test/features/matching/bloc/announcement_bloc_analytics_test.dart
test/features/matching/bloc/bid_bloc_analytics_test.dart
test/features/matching/bloc/bid_acceptance_bloc_analytics_test.dart
test/features/payments/bloc/payment_bloc_analytics_test.dart
test/features/tracking/bloc/tracking_bloc_analytics_test.dart
test/features/package_request/bloc/package_request_bloc_analytics_test.dart
test/features/package_request/bloc/negotiation_bloc_analytics_test.dart
test/features/messaging/bloc/chat_bloc_analytics_test.dart
test/features/payments/bloc/wallet_bloc_analytics_test.dart
test/features/ratings/bloc/rating_bloc_analytics_test.dart
test/features/cancellation/bloc/cancellation_bloc_analytics_test.dart
test/features/settings/bloc/account_deletion_bloc_analytics_test.dart
test/features/referral/bloc/referral_bloc_analytics_test.dart
```

---

## Stratégie de test

**Pattern par BLoC :** 2 tests minimum par BLoC modifié.

1. **Happy path** : event envoyé avec les bonnes propriétés quand `isEnabled = true`
2. **Consent off** : aucun event envoyé quand `isEnabled = false`

**Mock partagé** : `MockAnalyticsBackend` déplacé dans `test/helpers/` pour être réutilisé dans tous les tests sans duplication.

**Pas de widget tests** pour les events analytics (ils sont dans la couche BLoC).

**Couverture cible** : ≥ 90% maintenue après ajout des 17 fichiers de test.

---

## Funnels PostHog recommandés

Une fois les events en place, créer ces funnels dans le dashboard PostHog :

1. **Inscription** : `signup_started` → `otp_submitted` → `signup_completed` → `analytics_consent_answered`
2. **KYC** : `kyc_started` → `kyc_completed`
3. **Premier envoi (expéditeur)** : `package_request_created` → `negotiation_offer_accepted` → `payment_succeeded`
4. **Premier trajet (voyageur)** : `announcement_created` → `bid_accepted` → `qr_scan_success` → `delivery_confirmed`
5. **Conversion bid** : `announcement_viewed` → `bid_submitted` → `bid_accepted`
