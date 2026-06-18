# Spec — Apple Pay, Google Pay & PayPal via Stripe

**Date:** 2026-06-18 | **Status:** 🟡 Validée (design) — implémentation à planifier
**Repos concernés:** `dony-back` (Spring Boot), `dony_app` (Flutter)
**Phase 1 de 2** — cette spec couvre l'activation Stripe. La phase 2 (design du bottom sheet de choix de paiement) sera un cycle séparé avec mockups.

---

## 1. Objectif

Permettre à l'expéditeur de payer son colis par **Apple Pay**, **Google Pay** et **PayPal**, en plus de la carte, le tout **via Stripe**. Aucun nouvel agrégateur : on s'appuie sur la PaymentSheet native Stripe déjà en place.

## 2. Décision d'architecture — Approche A (Stripe-native)

Le bottom sheet dony conserve ses **rails de haut niveau** : `Carte & wallets` · `Cash` · `Wave` · `Orange Money`. Quand l'expéditeur choisit **« Carte & wallets »** (= rail `STRIPE` existant), la **PaymentSheet Stripe** s'ouvre et affiche nativement Carte + Apple Pay + Google Pay + PayPal (selon dispo appareil/dashboard).

**Rejeté — Approche B (tuiles séparées par wallet) :** réimplémente ce que la PaymentSheet donne gratuitement, config native plus lourde (PlatformPay + 3 flux), risque de refus store sur les guidelines wallet. Aucun gain fonctionnel.

### Conséquence : aucun nouvel enum
Apple Pay / Google Pay / PayPal vivent **dans** la PaymentSheet → tous sous le rail `STRIPE`. `BidPaymentMethod` (Flutter), `PaymentMethod` (Flutter + backend) **ne changent pas**. Le `payment_method` backend reste `STRIPE`. L'instrument réel (carte/paypal/applepay/googlepay) est interne à Stripe ; il n'est exposé que via `payment_method.type` sur le PI/charge (utile pour analytics — optionnel).

## 3. Contrainte centrale — PayPal & `on_behalf_of`

**PayPal ne supporte PAS `on_behalf_of` sur les charges Connect** (doc Stripe). Or, en Approche A, **un seul PI** doit accepter carte ET PayPal dans la même PaymentSheet (l'instrument est choisi au runtime, après création du PI). Donc :

> **On retire `on_behalf_of` du PI escrow.**

**Impact = quasi nul.** Le modèle est déjà *separate charges & transfers* : les fonds atterrissent sur la plateforme, le payout voyageur se fait via `Transfer` à la livraison. `on_behalf_of` ne servait qu'à l'attribution descriptor / merchant-of-record — non requis (et même non recommandé) en separate-charges. Restent **inchangés** : capture manuelle, webhook `payment_intent.amount_capturable_updated → ESCROW`, capture à l'acceptation du bid, `Transfer` net à la livraison, `statement_descriptor_suffix = DONY`.

## 4. Changements backend (`dony-back`)

### 4.1 `PaymentService` — 2 builders de PaymentIntent
- `createEscrow(...)` (≈ `PaymentService.java:435`)
- escrow négociation (≈ `PaymentService.java:1237`)

```java
PaymentIntentCreateParams.builder()
    .setAmount(amountCents)
    .setCurrency("eur")
    .setCaptureMethod(CaptureMethod.MANUAL)   // inchangé (escrow)
    .addPaymentMethodType("card")             // NEW — carte + Apple Pay + Google Pay
    .addPaymentMethodType("paypal")           // NEW — PayPal
    // .setOnBehalfOf(...)  ← SUPPRIMÉ (incompatible PayPal)
    .setStatementDescriptorSuffix("DONY")     // conservé
    .putMetadata(...)                         // inchangé
    .build();
```

Note : `payment_method_types` explicite (plutôt que `automatic_payment_methods`) pour un contrôle déterministe des moyens affichés (pas de Klarna/Bancontact surprise). PayPal étant un moyen à redirection, le retour est géré côté client via `Stripe.urlScheme`.

### 4.2 Webhook — inchangé
PayPal en capture manuelle émet `payment_intent.amount_capturable_updated` comme la carte → même handler `handlePaymentEscrowActive` → bascule PENDING → ESCROW. Aucun nouveau handler.

### 4.3 Tests
- MAJ des tests `PaymentService` assertant `setOnBehalfOf` → le nuller, asserter `payment_method_types = [card, paypal]`.
- Couverture ≥ 90 % (règle CLAUDE.md).

## 5. Changements Flutter (`dony_app`)

### 5.1 Init global — `main.dart` (après `Stripe.publishableKey`, avant `applySettings()`)
```dart
Stripe.merchantIdentifier = 'merchant.app.dony';   // Apple Pay (= merchant ID Apple)
Stripe.urlScheme = 'dony';                          // retour redirect PayPal (deep link existant)
await Stripe.instance.applySettings();
```

### 5.2 Helper params PaymentSheet (anti-drift)
Aujourd'hui 2 sites dupliquent les params : `payment_screen.dart:67` et `payment_recap_bottom_sheet.dart:105`. On factorise :
```dart
// lib/features/payments/data/stripe_payment_sheet_params.dart
SetupPaymentSheetParameters donyPaymentSheetParams(String clientSecret) =>
  SetupPaymentSheetParameters(
    merchantDisplayName: 'dony',
    paymentIntentClientSecret: clientSecret,
    style: ThemeMode.light,
    applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
    googlePay: PaymentSheetGooglePay(
      merchantCountryCode: 'FR',
      testEnv: _stripePk.startsWith('pk_test'),  // dérivé de la clé — pas de nouvel env
    ),
  );
```
PayPal : pas de param dédié — le redirect revient via `Stripe.urlScheme` global. Les 2 sites appellent `donyPaymentSheetParams(clientSecret)`.

### 5.3 Config native
**iOS** (`ios/Runner/`)
- Créer `Runner.entitlements` (inexistant aujourd'hui) → capability **Apple Pay** : `com.apple.developer.in-app-payments = [merchant.app.dony]`.
- `Info.plist` : vérifier que le scheme `dony` est dans `CFBundleURLTypes` (probable — deep links GoRouter).

**Android** (`android/app/src/main/AndroidManifest.xml`)
- Ajouter dans `<application>` : `<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true"/>` (requis Google Pay).
- Vérifier l'intent-filter `dony://` (probable — deep links).

### 5.4 Packages
**Aucun nouveau.** `flutter_stripe ^12` + `stripe_android 12.1.0` couvrent applePay/googlePay PaymentSheet + PayPal. `pay`/`google_pay`/`apple_pay` inutiles en Approche A.

### 5.5 Tests
- Test du helper `donyPaymentSheetParams` : params `applePay`/`googlePay` présents, `testEnv` dérivé de la clé.
- Couverture ≥ 90 %.

## 6. Flux de données (séquence, rail STRIPE)

1. Expéditeur choisit « Carte & wallets » → app `POST /payments` (ou `initiatePayment` négociation) → backend crée le PI (`card`+`paypal`, manual capture, sans `on_behalf_of`) → renvoie `clientSecret`.
2. App `initPaymentSheet(donyPaymentSheetParams(clientSecret))` → `presentPaymentSheet()`.
3. PaymentSheet affiche Carte / Apple Pay / Google Pay / PayPal. L'expéditeur choisit l'instrument.
   - PayPal → redirect → retour app via `dony://` (`Stripe.urlScheme`).
4. Autorisation (manual capture) → Stripe émet `payment_intent.amount_capturable_updated` → webhook → PENDING → **ESCROW** → bid promu.
5. Acceptation du bid → `pi.capture()` (in-process). Livraison → `Transfer` du **net** au voyageur.

## 7. Comptes à créer (prérequis — utilisateur)

**Apple Developer → Apple Pay**
1. S'enrôler Apple Developer Program (99 $/an).
2. Identifiers → Merchant ID `merchant.app.dony`.
3. Dashboard Stripe → Apple Pay → ajouter le merchant ID → Stripe génère un CSR → créer le Apple Pay Payment Processing Certificate côté Apple → ré-uploader dans Stripe.
4. Xcode → target Runner → capability Apple Pay → cocher `merchant.app.dony`.

**PayPal Business → PayPal**
1. Créer compte PayPal Business (gratuit, EUR).
2. Dashboard Stripe → Payment methods → PayPal → Activate → lier en OAuth.

**Google Pay** → aucun compte tiers. Activer dans dashboard Stripe.

**Stripe dashboard** (déjà accessible) → activer les 3 moyens en **test ET live**.

## 8. Edge cases & risques

- **Retrait `on_behalf_of`** : vérifier qu'aucun comportement ne dépend de l'attribution descriptor voyageur. `statement_descriptor_suffix(DONY)` exige que le compte plateforme ait un statement descriptor défini (dashboard) — à vérifier sinon le suffixe ne s'applique pas.
- **Hold PayPal** : auth PayPal tenue 10 j, étendue auto à 20 j. dony capture à l'acceptation (court). Confirmer que `BidTimeoutScheduler` expire les bids < 20 j (sinon hold périmé avant capture).
- **Régression carte** : tester les 2 flux (bid classique + négociation) après retrait `on_behalf_of` : escrow + capture à l'acceptation + `Transfer` net + descriptor DONY.
- **PayPal EUR only** : OK (corridors dony = EUR).

## 9. Plan de test

| Moyen | Comment | Vérifier |
|-------|---------|----------|
| Google Pay | Émulateur + compte Google + carte test, `testEnv:true` | PI auth → webhook `amount_capturable_updated` → ESCROW |
| Apple Pay | Device iOS réel, carte sandbox Wallet | même chemin escrow |
| PayPal | Test mode → PaymentSheet PayPal → redirect → retour `dony://` | PI auth (capture manuelle) → ESCROW |
| Régression carte | 2 flux (bid + négociation) | escrow + capture + `Transfer` net + descriptor DONY |

## 10. Hors scope (phase 2)

- **Design du bottom sheet** de choix de paiement (relooking tuile « Carte & wallets », iconographie wallets). Cycle séparé avec mockups visuels.
- **Analytics instrument** : tracker `payment_method.type` (carte/paypal/applepay/googlepay) sur `payment_succeeded` via le webhook. Optionnel, à décider en phase 2.

## 11. Critères d'acceptation

- [ ] Un expéditeur peut payer par carte, Apple Pay, Google Pay et PayPal via la PaymentSheet (rail STRIPE).
- [ ] Le PI escrow ne contient plus `on_behalf_of` et liste `[card, paypal]`.
- [ ] Le paiement PayPal autorise puis bascule en ESCROW via le webhook existant.
- [ ] La carte reste pleinement fonctionnelle sur les 2 flux (régression).
- [ ] Capture à l'acceptation + `Transfer` net à la livraison inchangés pour tous les instruments.
- [ ] Tests back + front à jour, couverture ≥ 90 %.
- [ ] Aucun nouvel enum de PaymentMethod introduit.
