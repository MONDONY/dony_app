# Story 6.3 — Paiement expéditeur avec création d'escrow (Flutter)

**Date:** 2026-04-25
**Status:** ✅ Complète

---

## Résumé

Un expéditeur ayant un bid accepté peut accéder à l'écran de paiement, consulter le récapitulatif (poids, prix/kg, commission, total) et payer via la feuille de paiement native Stripe (`flutter_stripe`). Le `clientSecret` retourné par le backend alimente directement la feuille Stripe.

---

## Fichiers créés

- `features/payments/data/models/payment_model.dart` — `{ id, bidId, clientSecret, amount, commissionAmount, status }`
- `features/payments/data/models/payment_model.g.dart` — code généré (json_serializable)
- `features/payments/presentation/screens/payment_screen.dart` — écran récapitulatif + intégration Stripe

## Fichiers modifiés

- `features/payments/bloc/payment_event.dart` — ajout `PaymentInitiated(bidId)`, `PaymentSheetCompleted`, `PaymentFailed(message)`
- `features/payments/bloc/payment_state.dart` — ajout `PaymentSheetReady(clientSecret, amount, commissionAmount, paymentId)`, `PaymentEscrowPending(amount)`
- `features/payments/bloc/payment_bloc.dart` — ajout `_onPaymentInitiated`, `_onPaymentSheetCompleted`, `_onPaymentFailed`
- `features/payments/data/datasources/payment_remote_datasource.dart` — ajout `createPayment(bidId)`
- `features/payments/data/repositories/payment_repository.dart` — ajout `createPayment(bidId)`
- `app/router.dart` — route `/payments/pay` avec `BidModel` en `extra`

---

## Comment ça fonctionne

### Flux utilisateur

```
1. Expéditeur navigue vers /payments/pay (BidModel passé en extra)
        ↓
2. Écran affiche récapitulatif: poids, prix/kg, montant, commission
        ↓
3. Tap "Payer X.XX €"
   → dispatch PaymentInitiated(bid.id)
   → BLoC appelle POST /payments → PaymentModel { clientSecret }
   → emit PaymentSheetReady(clientSecret, amount, commission)
        ↓
4. BlocConsumer listener détecte PaymentSheetReady
   → initPaymentSheet(paymentSheetParameters: ...)
   → presentPaymentSheet() → feuille native Stripe
        ↓
5a. Succès : dispatch PaymentSheetCompleted
    → BLoC emit PaymentEscrowPending(amount)
    → Écran affiche vue "Paiement sécurisé ✓"
        ↓
5b. Annulation (FailureCode.Canceled) : aucune action, revient à l'écran récap
5c. Erreur Stripe : dispatch PaymentFailed(message) → PaymentError → bannière rouge
```

### BLoC — transitions d'état

| Event | → État |
|-------|--------|
| `PaymentInitiated` | `PaymentLoading` → `PaymentSheetReady` ou `PaymentError` |
| `PaymentSheetCompleted` | `PaymentEscrowPending` |
| `PaymentFailed` | `PaymentError` |

### Calculs côté Flutter (affichage uniquement)

Les calculs dans `_PaymentSummaryView` servent uniquement à l'affichage. La source de vérité est le backend :
- `amount = bid.weightKg × bid.pricePerKg`
- `commission = amount × 0.12`

### Appels API

- `POST /api/v1/payments` — body `{ bidId }` — retourne `{ clientSecret, amount, commissionAmount, ... }`

### Navigation

- Route : `/payments/pay` — `BidModel` passé via `context.push('/payments/pay', extra: bid)`
- Pas de route de retour explicite — le bouton `<` de l'AppBar fait pop naturellement

### Pièges et points d'attention

- `FailureCode.Canceled` (utilisateur ferme la feuille) est géré silencieusement (pas d'erreur affichée). Seules les vraies erreurs Stripe montrent une bannière.
- `presentPaymentSheet()` est appelé depuis le `listener` du `BlocConsumer`, pas du `builder`. Le `listener` est appelé une seule fois par changement d'état, ce qui évite les doubles présentations.
- Si `bid.pricePerKg == null` (cas théorique pour des bids anciens), l'affichage montre `0.00 €`. Le backend valide et retourne l'erreur appropriée.

---

## Critères d'acceptation couverts

- [x] **Given** un expéditeur avec un bid accepté **When** il ouvre l'écran paiement **Then** il voit le récapitulatif poids / prix/kg / commission / total → `_SummaryCard` + `_EscrowInfoBanner`
- [x] **When** il tape "Payer" **Then** la feuille de paiement native Stripe s'ouvre → `initPaymentSheet` + `presentPaymentSheet`
- [x] **When** le paiement réussit **Then** l'écran "Paiement sécurisé ✓" est affiché → état `PaymentEscrowPending`
- [x] **Given** un paiement échoué (carte refusée) **Then** l'erreur est affichée → `PaymentError` → `_ErrorBanner`

## Décisions techniques

**Stripe SDK dans le listener, pas dans le BLoC** : `presentPaymentSheet()` est une opération UI (modal native). La déléguer au `listener` du `BlocConsumer` garde le BLoC pur et testable. Le BLoC se charge uniquement de l'appel API et de la gestion d'état.

**`PaymentFailed` comme event séparé** : permet au screen de signaler au BLoC que la feuille Stripe a échoué (ex: carte déclinée), sans que le BLoC ne connaisse l'API Stripe.
