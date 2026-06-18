# Apple Pay / Google Pay / PayPal via Stripe — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'expéditeur de payer par Apple Pay, Google Pay et PayPal via la PaymentSheet Stripe native, en plus de la carte.

**Architecture:** Approche A (Stripe-native). Les wallets/PayPal vivent dans la PaymentSheet sous le rail `STRIPE` existant — aucun nouvel enum. Backend : on retire `on_behalf_of` du PI escrow (incompatible PayPal) et on ajoute `payment_method_types=[card,paypal]`. Front : init wallets + helper params factorisé + config native.

**Tech Stack:** Spring Boot / stripe-java (PaymentIntentCreateParams), Flutter / flutter_stripe ^12 (PaymentSheet).

---

## Repos & Branches

- **Backend** `dony-back` : créer branche `feature/stripe-wallets-paypal` (depuis `main`). Tâches B*.
- **Frontend** `dony_app` : branche `feature/stripe-wallets-paypal` **déjà créée** (contient la spec). Tâches F*.

Les commits backend vont sur le repo dony-back ; les commits frontend sur dony_app. Ne jamais mélanger.

## File Structure

**Backend (dony-back)**
- Modify `src/main/java/com/dony/api/payments/PaymentService.java` — 2 builders PI (≈:435 createEscrow, ≈:1237 négociation).
- Modify `src/test/java/com/dony/api/payments/PaymentServiceOnBehalfOfTest.java` — assertions du builder createEscrow.
- Modify `src/test/java/com/dony/api/payments/PaymentServiceTest.java:756` — assertions du builder négociation.

**Frontend (dony_app)**
- Create `lib/features/payments/data/stripe_payment_sheet_params.dart` — helper unique des params PaymentSheet (wallets).
- Create `test/features/payments/data/stripe_payment_sheet_params_test.dart` — test du helper.
- Modify `lib/features/payments/presentation/screens/payment_screen.dart:67-73` — utiliser le helper.
- Modify `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart:105-111` — utiliser le helper.
- Modify `lib/main.dart:82-83` — merchantIdentifier + urlScheme.
- Modify `android/app/src/main/AndroidManifest.xml` — meta-data Google Pay.
- Create `ios/Runner/Runner.entitlements` — capability Apple Pay (+ liaison Xcode manuelle).

**Hors scope (ne PAS faire) :** nouveaux enums PaymentMethod, design du bottom sheet (phase 2), analytics instrument, retrait de `ensureCardPaymentsCapability` (idempotent, sujet Connect séparé).

---

## Task B0: Créer la branche backend

- [ ] **Step 1: Créer la branche depuis main**

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony-back
git checkout main && git pull
git checkout -b feature/stripe-wallets-paypal
```

---

## Task B1: PI `createEscrow` — retirer on_behalf_of, ajouter card+paypal

**Files:**
- Modify: `src/main/java/com/dony/api/payments/PaymentService.java:435-451`
- Test: `src/test/java/com/dony/api/payments/PaymentServiceOnBehalfOfTest.java:149-188`

- [ ] **Step 1: Adapter le test au nouveau comportement (le faire échouer)**

Dans `PaymentServiceOnBehalfOfTest.java`, renommer la méthode et remplacer le bloc d'assertions (lignes ~149-188). Remplacer :

```java
    @Test
    void success_paymentIntent_has_onBehalfOf_and_no_transferData_no_appFee() {
```
par :
```java
    @Test
    void success_paymentIntent_no_onBehalfOf_cardAndPaypal_no_transferData_no_appFee() {
```

Puis remplacer le commentaire + l'assertion on_behalf_of :
```java
            PaymentIntentCreateParams params = paramsCaptor.getValue();
            // on_behalf_of must be set to traveler's Stripe account
            assertThat(params.getOnBehalfOf()).isEqualTo("acct_traveler_123");
```
par :
```java
            PaymentIntentCreateParams params = paramsCaptor.getValue();
            // on_behalf_of retiré (incompatible PayPal) ; PI Stripe-native carte + PayPal
            assertThat(params.getOnBehalfOf()).isNull();
            assertThat(params.getPaymentMethodTypes()).containsExactly("card", "paypal");
```

- [ ] **Step 2: Lancer le test → doit échouer**

Run: `./mvnw test -Dtest=PaymentServiceOnBehalfOfTest#success_paymentIntent_no_onBehalfOf_cardAndPaypal_no_transferData_no_appFee`
Expected: FAIL — `getOnBehalfOf()` vaut encore "acct_traveler_123" et `getPaymentMethodTypes()` est null.

- [ ] **Step 3: Modifier le builder createEscrow**

Dans `PaymentService.java`, builder ≈:435. Remplacer :
```java
                    .setCaptureMethod(PaymentIntentCreateParams.CaptureMethod.MANUAL)
                    .setOnBehalfOf(traveler.getStripeAccountId())
                    .setStatementDescriptorSuffix("DONY")
```
par :
```java
                    .setCaptureMethod(PaymentIntentCreateParams.CaptureMethod.MANUAL)
                    // Approche A : carte + Apple Pay + Google Pay (= "card") + PayPal,
                    // tous dans la PaymentSheet. on_behalf_of retiré : PayPal ne le
                    // supporte pas, et il n'est pas requis en separate charges & transfers.
                    .addPaymentMethodType("card")
                    .addPaymentMethodType("paypal")
                    .setStatementDescriptorSuffix("DONY")
```

- [ ] **Step 4: Lancer le test → doit passer**

Run: `./mvnw test -Dtest=PaymentServiceOnBehalfOfTest`
Expected: PASS (toute la classe).

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/payments/PaymentService.java \
        src/test/java/com/dony/api/payments/PaymentServiceOnBehalfOfTest.java
git commit -m "feat(payments): escrow PI accepte card+paypal, retire on_behalf_of (createEscrow)"
```

---

## Task B2: PI escrow négociation — retirer on_behalf_of, ajouter card+paypal

**Files:**
- Modify: `src/main/java/com/dony/api/payments/PaymentService.java:1237-1254`
- Test: `src/test/java/com/dony/api/payments/PaymentServiceTest.java:751-756`

- [ ] **Step 1: Adapter le test (le faire échouer)**

Dans `PaymentServiceTest.java` ≈:751-756, remplacer :
```java
            PaymentIntentCreateParams params = capturedParams.get();
            assertThat(params).isNotNull();
            assertThat(params.getAmount()).isEqualTo(3920L);               // gross cents
            assertThat(params.getApplicationFeeAmount()).isNull();         // PAS de fee ici
            assertThat(params.getTransferData()).isNull();                 // pas de destination charge
            assertThat(params.getOnBehalfOf()).isEqualTo("acct_traveler"); // merchant of record
```
par :
```java
            PaymentIntentCreateParams params = capturedParams.get();
            assertThat(params).isNotNull();
            assertThat(params.getAmount()).isEqualTo(3920L);               // gross cents
            assertThat(params.getApplicationFeeAmount()).isNull();         // PAS de fee ici
            assertThat(params.getTransferData()).isNull();                 // pas de destination charge
            assertThat(params.getOnBehalfOf()).isNull();                   // retiré (incompatible PayPal)
            assertThat(params.getPaymentMethodTypes()).containsExactly("card", "paypal");
```

- [ ] **Step 2: Lancer le test → doit échouer**

Run: `./mvnw test -Dtest=PaymentServiceTest#createNegotiationEscrow_success_buildsManualCaptureIntent_andSavesGross`
(si le nom diffère, lancer la classe : `./mvnw test -Dtest=PaymentServiceTest`)
Expected: FAIL sur `getOnBehalfOf()` (vaut encore "acct_traveler").

- [ ] **Step 3: Modifier le builder négociation**

Dans `PaymentService.java`, builder ≈:1237. Remplacer :
```java
                    .setCaptureMethod(PaymentIntentCreateParams.CaptureMethod.MANUAL)
                    .setOnBehalfOf(traveler.getStripeAccountId())
```
par :
```java
                    .setCaptureMethod(PaymentIntentCreateParams.CaptureMethod.MANUAL)
                    // Approche A : carte + wallets + PayPal dans la PaymentSheet.
                    // on_behalf_of retiré (PayPal ne le supporte pas).
                    .addPaymentMethodType("card")
                    .addPaymentMethodType("paypal")
```

- [ ] **Step 4: Lancer le test → doit passer**

Run: `./mvnw test -Dtest=PaymentServiceTest`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/dony/api/payments/PaymentService.java \
        src/test/java/com/dony/api/payments/PaymentServiceTest.java
git commit -m "feat(payments): escrow négociation accepte card+paypal, retire on_behalf_of"
```

---

## Task B3: Suite backend complète + couverture

- [ ] **Step 1: Lancer toute la suite**

Run: `./mvnw test`
Expected: BUILD SUCCESS. Surveiller particulièrement `CucumberE2ETest` (paie un escrow) et tout test mockant `Account.retrieve`.

- [ ] **Step 2: Si un test casse, le corriger**

Chercher d'autres assertions résiduelles : `grep -rn "OnBehalfOf\|on_behalf_of" src/test`. Adapter (on_behalf_of est désormais null partout pour les PI escrow). Re-lancer.

- [ ] **Step 3: Couverture ≥ 90 %**

Run: `./mvnw test jacoco:report` puis vérifier `target/site/jacoco/index.html` (package payments).

- [ ] **Step 4: Commit (si fixups)**

```bash
git add -A && git commit -m "test(payments): aligne les assertions PI escrow sur le retrait on_behalf_of"
```

---

## Task F1: Helper params PaymentSheet (wallets) + test

**Files:**
- Create: `lib/features/payments/data/stripe_payment_sheet_params.dart`
- Test: `test/features/payments/data/stripe_payment_sheet_params_test.dart`

- [ ] **Step 1: Écrire le test (échoue car le fichier n'existe pas)**

Créer `test/features/payments/data/stripe_payment_sheet_params_test.dart` :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';

void main() {
  test('donyPaymentSheetParams configure wallets + clientSecret', () {
    final params = donyPaymentSheetParams('pi_secret_123');

    expect(params.paymentIntentClientSecret, 'pi_secret_123');
    expect(params.merchantDisplayName, 'dony');
    expect(params.applePay?.merchantCountryCode, 'FR');
    expect(params.googlePay?.merchantCountryCode, 'FR');
    // testEnv dérivé de la clé : en test (pas de dart-define) → false
    expect(params.googlePay?.testEnv, false);
  });
}
```

- [ ] **Step 2: Lancer le test → doit échouer**

Run: `flutter test test/features/payments/data/stripe_payment_sheet_params_test.dart`
Expected: FAIL — Target of URI doesn't exist (`stripe_payment_sheet_params.dart`).

- [ ] **Step 3: Créer le helper**

Créer `lib/features/payments/data/stripe_payment_sheet_params.dart` :
```dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

/// Params uniques de la PaymentSheet Stripe pour dony (Approche A).
///
/// Affiche Carte + Apple Pay + Google Pay + PayPal dans la feuille native :
/// - Apple Pay / Google Pay = wallets carte (config client ci-dessous).
/// - PayPal = activé côté PaymentIntent (`payment_method_types`) + dashboard ;
///   le retour de redirection passe par `Stripe.urlScheme` (réglé dans main.dart).
///
/// `testEnv` Google Pay est dérivé de la clé publiable (`pk_test` → sandbox),
/// pour ne pas introduire un nouvel env.
SetupPaymentSheetParameters donyPaymentSheetParams(String clientSecret) {
  return SetupPaymentSheetParameters(
    merchantDisplayName: 'dony',
    paymentIntentClientSecret: clientSecret,
    style: ThemeMode.light,
    applePay: const PaymentSheetApplePay(merchantCountryCode: 'FR'),
    googlePay: PaymentSheetGooglePay(
      merchantCountryCode: 'FR',
      testEnv: _stripePublishableKey.startsWith('pk_test'),
    ),
  );
}
```

- [ ] **Step 4: Lancer le test → doit passer**

Run: `flutter test test/features/payments/data/stripe_payment_sheet_params_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/payments/data/stripe_payment_sheet_params.dart \
        test/features/payments/data/stripe_payment_sheet_params_test.dart
git commit -m "feat(payments): helper PaymentSheet params avec Apple Pay + Google Pay"
```

---

## Task F2: Câbler le helper dans payment_screen.dart

**Files:**
- Modify: `lib/features/payments/presentation/screens/payment_screen.dart:67-73`

- [ ] **Step 1: Importer le helper + remplacer les params inline**

En haut du fichier, ajouter l'import :
```dart
import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';
```
Puis remplacer (≈:67-73) :
```dart
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'dony',
          paymentIntentClientSecret: state.clientSecret,
          style: ThemeMode.light,
        ),
      );
```
par :
```dart
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: donyPaymentSheetParams(state.clientSecret),
      );
```

- [ ] **Step 2: Analyse + tests de l'écran**

Run: `flutter analyze lib/features/payments/presentation/screens/payment_screen.dart`
Expected: No issues.
Run: `flutter test test/features/payments/`
Expected: PASS (les tests existants de l'écran restent verts ; la présentation Stripe n'est pas mockée mais la compilation/branchement est validée).

- [ ] **Step 3: Commit**

```bash
git add lib/features/payments/presentation/screens/payment_screen.dart
git commit -m "refactor(payments): payment_screen utilise donyPaymentSheetParams (wallets)"
```

---

## Task F3: Câbler le helper dans payment_recap_bottom_sheet.dart

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart:105-111`

- [ ] **Step 1: Importer le helper + remplacer les params inline**

Ajouter l'import en haut :
```dart
import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';
```
Puis remplacer (≈:105-111) :
```dart
                          await Stripe.instance.initPaymentSheet(
                            paymentSheetParameters:
                                SetupPaymentSheetParameters(
                              paymentIntentClientSecret: init.clientSecret,
                              merchantDisplayName: 'Dony',
                            ),
                          );
```
par :
```dart
                          await Stripe.instance.initPaymentSheet(
                            paymentSheetParameters:
                                donyPaymentSheetParams(init.clientSecret),
                          );
```

- [ ] **Step 2: Analyse + tests**

Run: `flutter analyze lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart`
Expected: No issues.
Run: `flutter test test/features/package_request/`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart
git commit -m "refactor(payments): recap négociation utilise donyPaymentSheetParams (wallets)"
```

---

## Task F4: Init global Stripe — merchantIdentifier + urlScheme

**Files:**
- Modify: `lib/main.dart:82-83`

- [ ] **Step 1: Ajouter merchantIdentifier + urlScheme**

Remplacer (≈:82-83) :
```dart
  Stripe.publishableKey = _stripePublishableKey;
  await Stripe.instance.applySettings();
```
par :
```dart
  Stripe.publishableKey = _stripePublishableKey;
  // Apple Pay : merchant ID Apple (effectif une fois le certificat Apple créé).
  Stripe.merchantIdentifier = 'merchant.app.dony';
  // Retour de redirection PayPal vers l'app (scheme déjà déclaré natif).
  Stripe.urlScheme = 'dony';
  await Stripe.instance.applySettings();
```

- [ ] **Step 2: Analyse**

Run: `flutter analyze lib/main.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(payments): init Stripe merchantIdentifier + urlScheme (wallets/PayPal)"
```

---

## Task F5: Config native Android (Google Pay)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Ajouter le meta-data Google Pay dans `<application>`**

Juste après le bloc `<meta-data ... com.posthog.posthog.AUTO_INIT .../>` (avant `<activity>`), ajouter :
```xml
        <meta-data
            android:name="com.google.android.gms.wallet.api.enabled"
            android:value="true" />
```

- [ ] **Step 2: Vérifier le build Android (manifest valide)**

Run: `flutter build apk --debug --dart-define-from-file=env.dev.json`
Expected: BUILD réussit (le manifest est valide ; pas d'erreur de merge).

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(payments): active Google Pay (wallet meta-data Android)"
```

---

## Task F6: Config native iOS (Apple Pay entitlement)

**Files:**
- Create: `ios/Runner/Runner.entitlements`

- [ ] **Step 1: Créer le fichier entitlements**

Créer `ios/Runner/Runner.entitlements` :
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.in-app-payments</key>
	<array>
		<string>merchant.app.dony</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Lier l'entitlement dans Xcode (manuel — gated sur compte Apple)**

Dans Xcode → target Runner → Signing & Capabilities → **+ Capability → Apple Pay** → ajouter `merchant.app.dony`. Cela renseigne `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` dans `project.pbxproj`. (Étape manuelle : nécessite le compte Apple Developer + le merchant ID créé. Sans ce compte, le fichier reste présent mais Apple Pay n'apparaît pas.)

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Runner.entitlements
git commit -m "feat(payments): entitlement Apple Pay iOS (merchant.app.dony)"
```

---

## Task F7: Suite front complète + couverture

- [ ] **Step 1: Analyse + tests**

Run: `flutter analyze`
Expected: No issues (0 erreur).
Run: `flutter test --coverage`
Expected: tous verts.

- [ ] **Step 2: Couverture ≥ 90 %**

Vérifier `coverage/lcov.info` (au besoin `genhtml coverage/lcov.info -o coverage/html`).

- [ ] **Step 3: Commit (si fixups)**

```bash
git add -A && git commit -m "test(payments): couverture wallets ≥ 90%"
```

---

## Self-Review (auteur)

- **Couverture spec :** §4 backend (B1,B2,B3) ; §5.1 init (F4) ; §5.2 helper (F1) + câblage (F2,F3) ; §5.3 natif (F5 Android, F6 iOS) ; §5.5 tests (F1,F7) ; §3 retrait on_behalf_of (B1,B2) ; §2 zéro enum (aucune tâche d'enum — voulu). ✓
- **Pas de placeholder :** tout le code des steps est concret. La seule étape manuelle (F6 step 2 Xcode) est intrinsèquement hors-CLI et clairement signalée. ✓
- **Cohérence des noms :** `donyPaymentSheetParams(String)` identique en F1/F2/F3 ; `payment_method_types=[card,paypal]` identique en B1/B2 (assertion `containsExactly("card","paypal")`). ✓
- **Hors scope confirmé :** bottom sheet (phase 2), analytics instrument, retrait `ensureCardPaymentsCapability`. ✓
