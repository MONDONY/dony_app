# Stripe Data Foundations + Account Disabled Guards — Design

**Date:** 2026-05-18
**Sub-projets:** A (fondations data) + B (guards compte désactivé)
**Worktree:** `stripe-flutter-features`

---

## Objectif

Compléter les fondations data Stripe manquantes dans `dony_app` et implémenter les guards UI qui bloquent la création d'annonces/offres quand le compte Stripe Connect de l'utilisateur est désactivé ou rejeté.

## Architecture

### Nouveau package `features/stripe_account/`

```
lib/features/stripe_account/
├── bloc/
│   ├── stripe_account_bloc.dart
│   ├── stripe_account_event.dart
│   └── stripe_account_state.dart
├── data/
│   ├── stripe_account_repository.dart
│   └── stripe_account_api.dart
└── presentation/
    └── widgets/
        ├── account_disabled_banner.dart
        └── account_rejected_banner.dart
```

### Fichiers modifiés

- `lib/core/models/connect_account_status.dart` — ajout de `disabled` et `rejected`
- `lib/core/models/payment_status.dart` — conversion String → enum
- `lib/core/models/payment_model.dart` — ajout du champ `disputed`
- `lib/app/router.dart` — redirects GoRouter sur les routes de création
- `lib/app/shell_scaffold.dart` (ou équivalent) — banner persistant via `BlocBuilder`

### Injection globale

`StripeAccountBloc` fourni au niveau du `ShellRoute` via `BlocProvider`. Toutes les features sous le shell y accèdent via `context.read<StripeAccountBloc>()`.

---

## Modèles de données (Sub-projet A)

### `ConnectAccountStatus` — enum étendu

```dart
enum ConnectAccountStatus {
  notCreated,
  pendingOnboarding,
  onboardingComplete,
  disabled,   // compte temporairement désactivé par Stripe
  rejected,   // compte définitivement rejeté — nécessite re-onboarding
}
```

Mapping depuis l'API backend :
```dart
static ConnectAccountStatus fromString(String raw) =>
    ConnectAccountStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == raw.toUpperCase(),
      orElse: () => ConnectAccountStatus.notCreated,
    );
```

### `PaymentStatus` — String → enum

```dart
enum PaymentStatus {
  pending,
  authorized,
  captured,
  refunded,
  failed,
  disputed,   // nouveau : PaymentIntent sous chargeback actif
  canceled,
}

static PaymentStatus fromString(String raw) =>
    PaymentStatus.values.firstWhere(
      (e) => e.name == raw.toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
```

### `PaymentModel` — champ ajouté

```dart
final bool disputed;  // true = paiement sous chargeback, actions bloquées
```

---

## BLoC `StripeAccountBloc` (Sub-projet B)

### Events

```dart
abstract class StripeAccountEvent {}
class LoadAccountStatus extends StripeAccountEvent {}
class RefreshAccountStatus extends StripeAccountEvent {}  // déclenché au foreground
```

### States

```dart
class StripeAccountState {
  final ConnectAccountStatus status;
  final String? reason;       // raison du rejet (REJECTED uniquement)
  final bool isLoading;
  final String? error;
}
```

### Comportement

- `LoadAccountStatus` → `GET /api/v1/payments/account/status` → émet `loaded`
- Erreur réseau → émet `error` avec `status: unknown` — **ne bloque pas l'app**
- `RefreshAccountStatus` déclenché sur `AppLifecycleState.resumed` — couvre la réactivation automatique en session

---

## Data Flow

### Chargement initial

```
ShellRoute init
  └── StripeAccountBloc.add(LoadAccountStatus)
        └── StripeAccountRepository.fetchStatus()
              └── GET /api/v1/payments/account/status
                    → { status: "DISABLED", reason: "..." }
                          ├── GoRouter redirect actif
                          └── Banner visible dans ShellScaffold
```

### Guard GoRouter

```dart
redirect: (context, state) {
  final accountStatus = context.read<StripeAccountBloc>().state.status;
  final blocked = ['/announcements/create', '/bids/create'];
  if (!blocked.contains(state.matchedLocation)) return null;
  if (accountStatus == ConnectAccountStatus.disabled) return '/account/disabled';
  if (accountStatus == ConnectAccountStatus.rejected) return '/account/rejected';
  return null;
}
```

---

## Écrans informatifs (hors shell)

### `/account/disabled`

- **Titre :** "Compte temporairement désactivé"
- **Message :** "Votre compte Stripe est temporairement désactivé. La création de nouvelles offres est bloquée jusqu'à la réactivation automatique par Stripe."
- **Bouton primaire :** "Voir mon compte Stripe" → WebView Stripe dashboard
- **Bouton secondaire :** affiché après 2 taps sur le bouton primaire → "Contacter le support Dony" (deeplink email)
- **Pas de bouton de re-onboarding** : la réactivation est automatique côté Stripe/webhook

### `/account/rejected`

- **Titre :** "Compte rejeté"
- **Message :** "Votre compte Stripe a été rejeté. Vous devez reconfigurer un nouveau compte pour continuer." + raison si disponible depuis l'API
- **Bouton primaire :** "Reconfigurer mon compte" → relance le flow Stripe Connect onboarding (crée un nouveau compte)
- **Bouton secondaire :** affiché après 2 taps sur le bouton primaire → "Contacter le support Dony"

---

## Banner persistant

Intégré dans le `ShellScaffold` via `BlocBuilder<StripeAccountBloc, StripeAccountState>` :

```dart
BlocBuilder<StripeAccountBloc, StripeAccountState>(
  buildWhen: (prev, curr) => prev.status != curr.status,
  builder: (context, state) {
    if (state.status == ConnectAccountStatus.disabled) {
      return const AccountDisabledBanner();
    }
    if (state.status == ConnectAccountStatus.rejected) {
      return const AccountRejectedBanner();
    }
    return const SizedBox.shrink();
  },
)
```

---

## Gestion d'erreurs

| Situation | Comportement |
|---|---|
| Erreur réseau au chargement | `status: unknown`, app non bloquée, retry au foreground |
| `PaymentStatus` inconnu reçu | fallback `PaymentStatus.pending` |
| `ConnectAccountStatus` inconnu | fallback `ConnectAccountStatus.notCreated` |
| Réactivation en session | `AppLifecycleState.resumed` → `RefreshAccountStatus` → banner disparaît, redirects levées |

---

## Tests

| Composant | Type | Cas couverts |
|---|---|---|
| `StripeAccountBloc` | Unit | `LoadAccountStatus` → loading/loaded/error ; chaque statut enum |
| GoRouter redirect | Unit | DISABLED → `/account/disabled` ; REJECTED → `/account/rejected` ; OK → null |
| `AccountDisabledBanner` | Widget | visible si DISABLED, absent sinon |
| `AccountRejectedBanner` | Widget | visible si REJECTED, bouton support au 2e tap |
| `PaymentStatus.fromString` | Unit | chaque valeur + fallback inconnu |
| `ConnectAccountStatus.fromString` | Unit | DISABLED, REJECTED, inconnu |
| Écran `/account/disabled` | Widget | bouton Stripe présent, bouton support conditionnel |
| Écran `/account/rejected` | Widget | raison affichée si présente, onboarding déclenché |

Couverture cible : **≥ 90 %** sur `features/stripe_account/`.

---

## Critères d'acceptation

- [ ] `ConnectAccountStatus.disabled` et `ConnectAccountStatus.rejected` existent et se désérialisent depuis l'API
- [ ] `PaymentStatus` est un enum (pas un String) ; tous les usages existants migrés
- [ ] `PaymentModel.disputed` existe et est désérialisé depuis l'API
- [ ] Créer une annonce avec compte DISABLED → redirect vers `/account/disabled`
- [ ] Créer une offre avec compte DISABLED → redirect vers `/account/disabled`
- [ ] Créer une annonce avec compte REJECTED → redirect vers `/account/rejected`
- [ ] Banner visible sur home et profil quand DISABLED ou REJECTED
- [ ] Banner disparaît automatiquement quand le statut repasse à ONBOARDING_COMPLETE (foreground refresh)
- [ ] Écran DISABLED : bouton support visible après 2 taps sur "Voir mon compte Stripe"
- [ ] Écran REJECTED : bouton support visible après 2 taps sur "Reconfigurer mon compte"
- [ ] `flutter test` → 0 rouge, couverture ≥ 90 % sur `stripe_account/`
