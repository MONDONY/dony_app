# Couverture de tests Flutter — Montée à 90%

**Date:** 2026-04-28
**Status:** ✅ Complète
**Résultat:** 90.0% (2260/2511 lignes) — 500 tests, tous verts

---

## Objectif

La règle absolue du projet (`CLAUDE.md`) exige une couverture minimale de **90%** sur les deux projets (back + front). La couverture Flutter était à **83%** en début de session. L'objectif était d'atteindre 90% sans modifier le code source.

---

## Fichiers de tests créés

### `test/features/auth/data/auth_remote_datasource_test.dart`
Tests du datasource auth :
- `register` — retourne `UserModel` en succès
- `getProfile` — retourne `UserModel`
- `deleteAccount` — complète sans erreur
- `updateProfile` — avec tous les champs, puis avec champs null

### `test/features/cancellation/data/cancellation_datasource_test.dart`
Tests du datasource annulation :
- `cancelTrip` — retourne `CancellationModel`
- `getRematchSuggestions` — liste avec un item, liste vide

### `test/features/auth/data/auth_repository_test.dart`
Tests de délégation du repository auth (MockAuthRemoteDatasource) :
- `register`, `getProfile`, `deleteAccount`, `updateProfile`

### `test/features/cancellation/data/cancellation_repository_test.dart`
Tests de délégation :
- `cancelTrip`, `getRematchSuggestions`

### `test/features/matching/data/repositories/announcement_repository_test.dart`
Tests de délégation (6 tests) :
- `createAnnouncement`, `getMyAnnouncements`, `getAnnouncementDetail`, `searchAnnouncements`, `deleteAnnouncement`, `updateAnnouncement`

### `test/features/kyc/data/kyc_repository_test.dart`
Tests avec MockApiClient + MockDio typé `Response<Map<String, dynamic>>` :
- `createSession` — succès, null → throws
- `getStatus` — succès, null → throws

### `test/features/payments/data/payment_datasource_test.dart`
Tests modèles + datasource :
- `ConnectAccountModel.fromJson` (2 tests, dont `stripeOnboarded` absent → false)
- `PaymentModel.fromJson`/`toJson` (5 tests)
- `createConnectAccount`, `createOnboardingLink`, `createPayment`
- `getPaymentForBid` — succès, 404 → null, 500 → rethrow

### `test/core/misc_coverage_test.dart`
Tests de constructeurs simples non couverts :
- `QrScanSuccess(event)` — constructeur non-const
- `QrScanError(message)` — constructeur non-const
- `QrScanSubmitRequested({bidId, eventType})` — constructeur named
- `LocalAuthError(message)` — constructeur non-const
- `EnvoisRefreshNotifier.requestRefresh()` — notifie les listeners

---

## Fichiers de tests modifiés

### `test/features/auth/bloc/auth_event_test.dart`
**Problème :** constructeurs `const` → lignes jamais exécutées au runtime (lcov count=0).
**Fix :** `// ignore_for_file: prefer_const_constructors` + tous les `const` remplacés par `final` (non-const).
Couvre : `AuthSendOtpRequested`, `AuthPhoneVerified`, `AuthRegisterRequested`, `AuthCheckRequested`, `AuthLogoutRequested`, `AuthDeleteAccountRequested`, `AuthUpdateProfileRequested`, `OnboardingCompleted`.

### `test/features/payments/bloc/payment_event_test.dart`
Même fix const→non-const.
Couvre : `PaymentConnectAccountRequested`, `PaymentOnboardingStatusChecked`, `PaymentInitiated`, `PaymentSheetCompleted`, `PaymentFailed`.

### `test/core/error/app_exception_test.dart`
Même fix — `const e = XException()` → `final e = XException()` avec `// ignore: prefer_const_constructors`.
Couvre les constructeurs de : `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ValidationException`, `ServerException`, `StorageException`.

### `test/features/auth/bloc/auth_bloc_test.dart`
Ajout du groupe `'AuthPhoneVerified — erreurs supplémentaires'` (6 tests) :
- `getProfile` throws generic Exception → `AuthOtpVerified` (ligne 141)
- `signInWithCredential` throws generic Exception → `AuthError` (ligne 146)
- `FirebaseAuthException` codes : `code-expired`, `too-many-requests`, `session-expired`, code inconnu (lignes 238-241)

Ajout du groupe `'AuthLocked'` (non-const) → couvre `auth_state.dart` ligne 63.

### `test/features/matching/bloc/bid_bloc_test.dart`
Ajout de tests d'erreurs systématiques pour chaque handler manquant (erreur générique + DioException) :
- `BidListRequested`, `BidMyListRequested`, `BidAcceptRequested`, `BidRejectRequested`, `BidCancelRequested`, `BidHideRequested`, `BidTravelerDismissRequested`, `BidHandoverRequested`, `BidDeleteRequested`, `BidMyListAutoRefreshRequested`
Total : 46 tests dans ce fichier.

### `test/core/design/widgets/dony_form_widgets_test.dart`
Ajout pour `DonyBadge` : types `success`, `warning`, `error` en non-const (couvre les branches du switch).
Ajout pour `DonyAvatar` : test `imageUrl` non-const (couvre les lignes 69-71).
Ajout test `SnackBarAction` présent quand `actionLabel` fourni (couvre `dony_snackbar.dart` lignes 30, 33).

### `test/features/matching/data/datasources/announcement_remote_datasource_test.dart`
Ajout d'un test `updateAnnouncement` avec champs optionnels (`departureTime`, `arrivalTime`, `departureLocation`, `arrivalLocation`) → couvre `announcement_remote_datasource.dart` lignes 112-117.

### `test/features/payments/bloc/payment_bloc_test.dart`
Ajout : erreur générique dans `PaymentOnboardingStatusChecked` → couvre `payment_bloc.dart` ligne 52.

### `test/features/matching/bloc/announcement_bloc_test.dart`
Ajout : erreur générique dans `AnnouncementUpdateRequested` → couvre `announcement_bloc.dart` ligne 133.

### `test/features/cancellation/bloc/cancellation_bloc_test.dart`
Ajout : erreur générique dans `RematchSuggestionsRequested` → couvre `cancellation_bloc.dart` ligne 46.

---

## Leçon technique clé — Constructeurs `const` et couverture lcov

Les constructeurs `const` en Dart sont évalués à la compilation. Au runtime, le constructeur n'est **jamais appelé**, donc lcov enregistre `DA:N,0` (non couvert) même si la ligne est syntaxiquement présente.

**Règle :** pour couvrir une ligne de constructeur `const`, instancier avec `final` (non-const) :
```dart
// ❌ Ne couvre pas la ligne du constructeur
const e = MyException('msg');

// ✅ Couvre la ligne
// ignore: prefer_const_constructors
final e = MyException('msg');
```

---

## Lignes volontairement non couvertes

| Fichier | Raison |
|---|---|
| `auth_bloc.dart` lignes 67–103 | Callbacks Firebase `verifyPhoneNumber` — impossibles à mocker en unit test |
| `local_auth_service.dart` (17 lignes) | Dépend de `FlutterSecureStorage` + `LocalAuthentication` (platform native) |

---

## Commandes pour vérifier

```bash
cd dony_app/
flutter test --coverage
awk '/^DA:/{split($0,a,":"); split(a[2],b,","); total++; if(b[2]>0) hit++} END{printf "Coverage: %d/%d = %.1f%%\n", hit, total, hit/total*100}' coverage/lcov.info
```
