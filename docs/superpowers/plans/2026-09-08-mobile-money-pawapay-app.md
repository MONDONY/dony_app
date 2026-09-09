# Rail mobile money pawaPay dans l'app : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** permettre un envoi payé en mobile money de bout en bout depuis l'app contre le backend pawaPay (compte de versement du voyageur, offre mobile money de l'expéditeur, acceptation dédiée, paiement avec sondage, Wave, deep link), testable sur le Redmi contre le sandbox staging.

**Architecture:** l'app garde sa structure feature-first (`bloc/`, `data/`, `presentation/`). Le compte de versement vit dans `features/payments`, le parcours de paiement d'un bid dans `features/matching` (fichiers mobile money existants réécrits sur le nouveau contrat). Aucun nouveau package, aucune l10n (français en dur, comme le reste). Deep link et notifications alignés sur la route d'attente existante.

**Tech Stack:** Flutter, flutter_bloc, GoRouter, Dio via `ApiClient`, json_serializable (build_runner) pour les enums existants, `fromJson` manuel pour les nouveaux modèles, bloc_test + mocktail.

**Spec:** `docs/superpowers/specs/2026-09-08-mobile-money-pawapay-app-design.md` (même dépôt). Cartographie du code : `/Users/aboubakardiakite/.claude/jobs/faaf28b7/tmp/flutter-map.md`.

## Global Constraints

- Répondre et commenter en français ; textes visibles en français, jamais de tiret cadratin « — » dans un texte affiché ; marque « Yadony » dans tout texte visible.
- Jamais `setState` (BLoC seul), jamais `Navigator.push` (GoRouter, sauf le cas déjà existant de `_showOfflinePaymentSuccess`), Dio uniquement via `ApiClient`.
- `DonyButton` d'un bottom sheet toujours dans `stickyBottom`, jamais dans le `child`.
- Events suffixés `Requested` (ou verbe au passé pour un fait : `Polled`, `Opened`), states `Initial/Loading/…/Error`, blocs en `registerFactory`, datasources et repositories en `registerLazySingleton`.
- Tout nouveau bloc reçoit `AnalyticsService` ; tout nouveau nom d'event déclaré dans `AnalyticsEvents` et ajouté à la table de `CLAUDE.md`.
- Erreurs métier affichées via `ErrorPresenter.show(context, error)` ; jamais `error.message` brut.
- Aucun numéro de téléphone en clair dans les logs, les analytics ou les textes : seulement les formes masquées rendues par le backend.
- Tests dans le même commit que le code ; `flutter analyze` propre sur tout le projet ; couverture globale visée ≥ 90 %, jamais sous le cliquet CI (78 %).
- Ne jamais committer `android/app/src/debug/AndroidManifest.xml` (modification locale Impeller) ni `android/app/google-services.json` ; `git add` avec des chemins explicites.
- Commits sans signature Claude, au nom du développeur.
- Une seule commande `flutter` à la fois sur la machine.

---

### Task 1: Enum `mobileMoney` et parsing robuste

**Files:**
- Modify: `lib/features/matching/data/models/bid_model.dart:7-27`
- Modify: `lib/features/matching/data/models/announcement_model.dart:177,271`
- Regenerate: `lib/features/matching/data/models/bid_model.g.dart`, `announcement_model.g.dart` (build_runner)
- Test: `test/features/matching/data/models/bid_payment_method_test.dart` (nouveau)

**Interfaces:**
- Produces: `BidPaymentMethod.mobileMoney` (`'MOBILE_MONEY'`) ; `BidPaymentMethodApi.fromApi(String?)` → `BidPaymentMethod?` (null si inconnu) ; `acceptedPaymentMethodsFromJson(Object?)` → `Set<BidPaymentMethod>` ignorant les valeurs inconnues.

- [ ] **Step 1: Écrire les tests**

```dart
// test/features/matching/data/models/bid_payment_method_test.dart
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MOBILE_MONEY est une valeur de BidPaymentMethod', () {
    expect(BidPaymentMethod.mobileMoney.apiValue, 'MOBILE_MONEY');
    expect(BidPaymentMethodApi.fromApi('MOBILE_MONEY'), BidPaymentMethod.mobileMoney);
  });

  test('fromApi rend null pour une valeur inconnue ou nulle', () {
    expect(BidPaymentMethodApi.fromApi('BITCOIN'), isNull);
    expect(BidPaymentMethodApi.fromApi(null), isNull);
  });

  test('acceptedPaymentMethodsFromJson ignore les valeurs inconnues', () {
    expect(
      acceptedPaymentMethodsFromJson(['CASH', 'BITCOIN', 'MOBILE_MONEY']),
      {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
    );
    expect(acceptedPaymentMethodsFromJson(null), {BidPaymentMethod.stripe});
  });

  test('BidModel.fromJson replie une méthode inconnue sur stripe', () {
    // Construire un JSON minimal valide en copiant la fixture d'un test existant
    // de bid_model (voir test/features/matching/data/models/bid_model_test.dart)
    // et remplacer paymentMethod par 'BITCOIN'.
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec de compilation** (`flutter test test/features/matching/data/models/bid_payment_method_test.dart`)

- [ ] **Step 3: Implémenter**

Dans `bid_model.dart`, après `orangeMoney`, ajouter :

```dart
  @JsonValue('MOBILE_MONEY')
  mobileMoney,
```

Compléter l'extension :

```dart
extension BidPaymentMethodApi on BidPaymentMethod {
  String get apiValue => _$BidPaymentMethodEnumMap[this]!;

  /// Valeur reçue de l'API, ou null si l'app ne la connaît pas encore :
  /// une nouvelle méthode côté backend ne doit jamais faire planter un parsing.
  static BidPaymentMethod? fromApi(String? raw) {
    if (raw == null) return null;
    for (final entry in _$BidPaymentMethodEnumMap.entries) {
      if (entry.value == raw) return entry.key;
    }
    return null;
  }
}

/// Parsing tolérant de `acceptedPaymentMethods` : valeurs inconnues ignorées,
/// liste absente = carte (comportement historique).
Set<BidPaymentMethod> acceptedPaymentMethodsFromJson(Object? raw) {
  if (raw is! List) return const {BidPaymentMethod.stripe};
  return {
    for (final v in raw)
      if (BidPaymentMethodApi.fromApi(v as String?) case final m?) m,
  };
}
```

Sur `BidModel.paymentMethod` (ligne 126) ajouter `@JsonKey(unknownEnumValue: BidPaymentMethod.stripe)`. Sur `AnnouncementModel.acceptedPaymentMethods` (ligne 177) ajouter `@JsonKey(fromJson: acceptedPaymentMethodsFromJson)` (garder le `toJson` généré). Regénérer : `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Tests verts** : `flutter test test/features/matching/data/models/` puis `flutter analyze`.
- [ ] **Step 5: Commit** : `feat(matching): BidPaymentMethod.mobileMoney et parsing tolérant des méthodes de paiement`

---

### Task 2: Modèles `MobileMoneyAccount` et `MobileMoneyPaymentStatus`

**Files:**
- Create: `lib/features/payments/data/models/mobile_money_account.dart`
- Create: `lib/features/matching/data/models/mobile_money_payment_status.dart`
- Delete: `lib/features/matching/data/models/mobile_money_payment_model.dart` et `test/features/matching/data/models/mobile_money_payment_model_test.dart`
- Test: `test/features/payments/data/models/mobile_money_account_test.dart`, `test/features/matching/data/models/mobile_money_payment_status_test.dart`

**Interfaces:**
- Produces:

```dart
enum MobileMoneyAccountStatus { notConfigured, active, disabled }
class MobileMoneyAccount extends Equatable {
  const MobileMoneyAccount({required this.status, this.msisdnMasked, this.providerLabel, this.country, this.currency});
  factory MobileMoneyAccount.fromJson(Map<String, dynamic> json);
  bool get isActive => status == MobileMoneyAccountStatus.active;
}

enum MobileMoneyDepositStatus { created, accepted, processing, completed, failed, submitRejected, unknown }
class MobileMoneyDeposit extends Equatable {
  const MobileMoneyDeposit({required this.id, required this.status, this.providerLabel, this.msisdnMasked, this.authorizationUrl, this.failureCode, this.failureMessage});
  bool get isLive => status ∈ {created, accepted, processing};
  bool get isFailed => status ∈ {failed, submitRejected};
}
class MobileMoneyPaymentStatus extends Equatable {
  const MobileMoneyPaymentStatus({required this.bidId, required this.bidStatus, this.paymentStatus, this.deadlineAt, this.amount, this.currency = 'XOF', this.deposit});
  factory MobileMoneyPaymentStatus.fromJson(Map<String, dynamic> json);
  bool get isEscrowed => paymentStatus == 'ESCROW' || paymentStatus == 'RELEASED';
  bool get isDepositLive => deposit?.isLive ?? false;
  bool get isDepositFailed => deposit?.isFailed ?? false;
  bool isExpired(DateTime now) => bidStatus == 'CANCELLED' || (!isEscrowed && deadlineAt != null && now.isAfter(deadlineAt!));
  bool get isWaveRedirect => deposit?.authorizationUrl != null;
}
```

- [ ] **Step 1: Tests** : parsing complet (`deposit` nul et non nul, `deadlineAt` ISO 8601 UTC, `amount` entier ou décimal, statut de dépôt inconnu → `unknown`, statut de compte inconnu → `notConfigured`), getters (`isEscrowed` pour ESCROW et RELEASED, `isExpired` avant et après la deadline, jamais expiré si séquestré même deadline passée, `isWaveRedirect`).
- [ ] **Step 2: Échec** : `flutter test test/features/payments/data/models test/features/matching/data/models/mobile_money_payment_status_test.dart`
- [ ] **Step 3: Implémenter** (parsing manuel, `DateTime.parse(...).toLocal()` pour `deadlineAt`, `(json['amount'] as num?)?.toDouble()`, statuts via `switch` sur la chaîne avec repli `unknown`/`notConfigured`). Supprimer l'ancien modèle et son test (aucun autre appelant après la tâche 5 : vérifier par `grep -rn MobileMoneyPaymentModel lib test` à la fin de la tâche 5, l'ancien datasource l'utilise encore jusque-là : dans cette tâche, garder l'ancien fichier si la compilation l'exige et le supprimer en tâche 5).
- [ ] **Step 4: Verts + analyze.**
- [ ] **Step 5: Commit** : `feat(payments): modèles MobileMoneyAccount et MobileMoneyPaymentStatus (contrat pawaPay)`

---

### Task 3: Couche data (compte, statut, initiation, acceptation)

**Files:**
- Create: `lib/features/payments/data/datasources/mobile_money_account_remote_datasource.dart`, `lib/features/payments/data/repositories/mobile_money_account_repository.dart`
- Modify: `lib/features/matching/data/datasources/mobile_money_remote_datasource.dart`, `lib/features/matching/data/repositories/mobile_money_repository.dart`
- Modify: `lib/features/matching/data/datasources/bid_remote_datasource.dart` (après `acceptBid`, ligne 169), `lib/features/matching/data/repositories/bid_repository.dart`
- Modify: `lib/core/di/injection.dart:441-450` (+ enregistrement du datasource et du repository compte, à côté du bloc de la tâche 4)
- Test: `test/features/payments/data/datasources/mobile_money_account_remote_datasource_test.dart`, `test/features/payments/data/repositories/mobile_money_account_repository_test.dart`, mise à jour de `test/features/matching/data/datasources/mobile_money_remote_datasource_test.dart` et `.../repositories/mobile_money_repository_test.dart`, ajout dans `bid_remote_datasource_test.dart` et `bid_repository_test.dart`

**Interfaces:**
- Produces:

```dart
class MobileMoneyAccountRemoteDatasource {
  const MobileMoneyAccountRemoteDatasource(this._client);
  Future<MobileMoneyAccount> get();        // GET  /payments/mobile-money/account
  Future<MobileMoneyAccount> activate();   // POST /payments/mobile-money/account (sans corps)
  Future<MobileMoneyAccount> disable();    // DELETE /payments/mobile-money/account
}
class MobileMoneyAccountRepository { get(); activate(); disable(); }   // façade 1:1

class MobileMoneyRemoteDatasource {
  Future<MobileMoneyPaymentStatus> getStatus(String bidId);                       // GET  /bids/$bidId/mobile-money/status
  Future<MobileMoneyPaymentStatus> initiate(String bidId, {String? phoneNumber}); // POST /bids/$bidId/mobile-money/initiate, corps {"phoneNumber": ...} seulement si non vide
  Future<MobileMoneyPaymentStatus> accept(String bidId);                          // POST /bids/$bidId/mobile-money/accept
}
class MobileMoneyRepository { getStatus(); initiate(); accept(); }

// BidRemoteDatasource / BidRepository
Future<BidModel> acceptMobileMoneyBid(String bidId);  // POST /bids/$bidId/mobile-money/accept puis relecture du bid (même appel que BidDetailRequested)
```

- [ ] **Step 1: Tests** avec `MockDio`/le harnais déjà utilisé dans `mobile_money_remote_datasource_test.dart` : chemins et verbes exacts, corps d'`initiate` absent quand `phoneNumber` est null ou vide, présent sinon, parsing des réponses, propagation des `DioException`.
- [ ] **Step 2: Échec.**
- [ ] **Step 3: Implémenter.** Retirer `regenerateLink` (plus d'appelant après la tâche 5). Enregistrer datasource et repository compte dans `injection.dart` sous un commentaire `// Payments — Mobile money (compte de versement)`.
- [ ] **Step 4: Verts + analyze.**
- [ ] **Step 5: Commit** : `feat(payments): couche data du compte de versement et du paiement mobile money`

---

### Task 4: `MobileMoneyAccountBloc`

**Files:**
- Create: `lib/features/payments/bloc/mobile_money_account_bloc.dart`, `mobile_money_account_event.dart`, `mobile_money_account_state.dart`
- Modify: `lib/core/di/injection.dart` (`registerFactory<MobileMoneyAccountBloc>`), `lib/core/services/analytics_events.dart:60` (ajouter `mobileMoneyAccountActivated = 'mobile_money_account_activated'`, `mobileMoneyAccountDisabled = 'mobile_money_account_disabled'`)
- Test: `test/features/payments/bloc/mobile_money_account_bloc_test.dart`

**Interfaces:**

```dart
sealed class MobileMoneyAccountEvent extends Equatable { const MobileMoneyAccountEvent(); }
class MobileMoneyAccountRequested extends MobileMoneyAccountEvent { const MobileMoneyAccountRequested(); }
class MobileMoneyAccountActivateRequested extends MobileMoneyAccountEvent { const MobileMoneyAccountActivateRequested(); }
class MobileMoneyAccountDisableRequested extends MobileMoneyAccountEvent { const MobileMoneyAccountDisableRequested(); }

sealed class MobileMoneyAccountState extends Equatable { const MobileMoneyAccountState(); }
class MobileMoneyAccountInitial extends MobileMoneyAccountState {}
class MobileMoneyAccountLoading extends MobileMoneyAccountState {}
class MobileMoneyAccountLoaded extends MobileMoneyAccountState { final MobileMoneyAccount account; }
class MobileMoneyAccountUpdating extends MobileMoneyAccountState { final MobileMoneyAccount account; }
class MobileMoneyAccountError extends MobileMoneyAccountState { final Object error; final MobileMoneyAccount? account; }

class MobileMoneyAccountBloc extends Bloc<MobileMoneyAccountEvent, MobileMoneyAccountState> {
  MobileMoneyAccountBloc(this._repository, this._analytics);
}
```

Comportement : `Requested` → `Loading` → `Loaded` ou `Error(error)` ; `ActivateRequested` → `Updating(accountCourant ou notConfigured)` → `Loaded(nouveau)` + `logEvent(mobileMoneyAccountActivated, properties: {'provider': account.providerLabel ?? 'inconnu', 'currency': account.currency ?? ''})` ou `Error(error, accountCourant)` ; `DisableRequested` symétrique avec `mobileMoneyAccountDisabled`. `error` est l'exception issue de `unwrapDioError(e)` (jamais une chaîne), pour que l'écran appelle `ErrorPresenter.show`.

- [ ] **Step 1: Tests** `blocTest` : chaque transition, erreur `ValidationException('...', code: 'mobile-money-disabled')` conservée telle quelle dans `Error.error`, analytics appelée avec le bon nom (mock `AnalyticsService`, `verify`).
- [ ] **Step 2: Échec.** - [ ] **Step 3: Implémenter.** - [ ] **Step 4: Verts + analyze.**
- [ ] **Step 5: Commit** : `feat(payments): MobileMoneyAccountBloc`

---

### Task 5: `MobileMoneyPaymentBloc` réécrit

**Files:**
- Rewrite: `lib/features/matching/bloc/mobile_money_payment_bloc.dart`, `mobile_money_payment_event.dart`, `mobile_money_payment_state.dart`
- Modify: `lib/core/di/injection.dart:448-450` (`MobileMoneyPaymentBloc(getIt<MobileMoneyRepository>(), getIt<AnalyticsService>())`), `analytics_events.dart` (ajouter `mobileMoneyInitiated = 'mobile_money_initiated'`, `mobileMoneyConfirmed = 'mobile_money_confirmed'`, `mobileMoneyFailed = 'mobile_money_failed'`)
- Delete: ancien modèle `mobile_money_payment_model.dart` et son test s'ils existent encore
- Test: `test/features/matching/bloc/mobile_money_payment_bloc_test.dart` (réécrit)

**Interfaces:**

```dart
sealed class MobileMoneyPaymentEvent extends Equatable { const MobileMoneyPaymentEvent(); }
/// Ouverture de l'écran : lit le statut ; sans dépôt vivant ni séquestre, lance l'initiation.
class MobileMoneyPaymentOpened extends MobileMoneyPaymentEvent { final String bidId; }
/// Nouvel essai, éventuellement avec un autre numéro payeur.
class MobileMoneyPaymentInitiateRequested extends MobileMoneyPaymentEvent { final String bidId; final String? phoneNumber; }
/// Sondage périodique (silencieux : ne passe jamais par Loading).
class MobileMoneyStatusPolled extends MobileMoneyPaymentEvent { final String bidId; }

sealed class MobileMoneyPaymentState extends Equatable { const MobileMoneyPaymentState(); }
class MobileMoneyPaymentInitial extends MobileMoneyPaymentState {}
class MobileMoneyPaymentLoading extends MobileMoneyPaymentState {}
class MobileMoneyPaymentAwaitingConfirmation extends MobileMoneyPaymentState { final MobileMoneyPaymentStatus status; }
class MobileMoneyPaymentEscrowed extends MobileMoneyPaymentState { final MobileMoneyPaymentStatus status; }
class MobileMoneyPaymentDepositFailed extends MobileMoneyPaymentState { final MobileMoneyPaymentStatus status; }
class MobileMoneyPaymentExpired extends MobileMoneyPaymentState { final MobileMoneyPaymentStatus status; }
class MobileMoneyPaymentError extends MobileMoneyPaymentState { final Object error; }

class MobileMoneyPaymentBloc extends Bloc<MobileMoneyPaymentEvent, MobileMoneyPaymentState> {
  MobileMoneyPaymentBloc(this._repository, this._analytics, {DateTime Function()? now});
}
```

Règles de transition (fonction privée `_stateFor(MobileMoneyPaymentStatus s)`) : `s.isEscrowed` → `Escrowed` ; sinon `s.isExpired(now())` → `Expired` ; sinon `s.isDepositFailed` → `DepositFailed` ; sinon `s.isDepositLive` → `AwaitingConfirmation` ; sinon `null` (aucun dépôt : il faut initier).

- `Opened` : `Loading` ; `getStatus` ; si `_stateFor` rend un état, l'émettre ; sinon `initiate(bidId)` puis émettre `_stateFor(résultat) ?? AwaitingConfirmation(résultat)`, `logEvent(mobileMoneyInitiated, {'provider': providerLabel, 'wave': isWaveRedirect})`.
- `InitiateRequested` : `Loading` ; `initiate(bidId, phoneNumber)` ; idem.
- `Polled` : pas de `Loading` ; `getStatus` ; état rendu par `_stateFor`, ou état courant inchangé si `null` ; une `Escrowed` atteinte pour la première fois déclenche `logEvent(mobileMoneyConfirmed)` ; une `DepositFailed` atteinte pour la première fois déclenche `logEvent(mobileMoneyFailed, {'failure_code': failureCode ?? ''})`. Une erreur réseau pendant un sondage ne change pas l'état (le prochain sondage réessaie) sauf si l'état courant est `Loading`/`Initial`.
- Toute exception hors sondage → `Error(unwrapDioError(e))` (jamais `e.toString()`).

- [ ] **Step 1: Tests** `blocTest` couvrant chaque règle ci-dessus, dont : ouverture avec dépôt vivant (pas d'`initiate`), ouverture sans dépôt (`initiate` appelé une fois), sondage silencieux, sondage en erreur réseau ignoré, `isExpired` avec `now` injecté, analytics une seule fois par transition.
- [ ] **Step 2: Échec.** - [ ] **Step 3: Implémenter.** - [ ] **Step 4: Verts + analyze** (l'écran de la tâche 12 ne compile plus : adapter `mobile_money_awaiting_screen.dart` a minima pour compiler, ou le réécrire déjà selon la tâche 12 si l'implémenteur enchaîne ; les tests d'écran existants peuvent être marqués à réécrire mais jamais supprimés sans remplacement dans la tâche 12).
- [ ] **Step 5: Commit** : `feat(matching): MobileMoneyPaymentBloc sur le contrat pawaPay (ouverture, initiation, sondage)`

---

### Task 6: Acceptation dédiée côté voyageur

**Files:**
- Modify: `lib/features/matching/bloc/bid_event.dart` (après `BidAcceptRequested`, ligne 117) : `class BidAcceptMobileMoneyRequested extends BidEvent { final String bidId; }`
- Modify: `lib/features/matching/bloc/bid_bloc.dart` (handler `_onAcceptMobileMoneyRequested` calqué sur `_onAcceptRequested` lignes 134-151 : `BidLoading`, `_repository.acceptMobileMoneyBid`, `BidAccepted(bid)`, `logEvent(AnalyticsEvents.bidAccepted, properties: {'payment_method': 'mobile_money'})` si l'accept classique logue un event, erreur → même état d'erreur que l'accept classique)
- Modify: `lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart:82-90`

```dart
                      if (bid.paymentMethod == BidPaymentMethod.cash) {
                        context.read<BidAcceptanceBloc>().add(ace.BidAcceptRequested(bid.id));
                      } else if (bid.paymentMethod == BidPaymentMethod.mobileMoney) {
                        context.read<BidBloc>().add(BidAcceptMobileMoneyRequested(bid.id));
                      } else {
                        context.read<BidBloc>().add(BidAcceptRequested(bid.id));
                      }
```

- Test: `test/features/matching/bloc/bid_bloc_test.dart` (cas accept mobile money succès et erreur), `test/features/matching/presentation/widgets/action_bars/bid_detail_action_bars_test.dart` (un bid `mobileMoney` envoie `BidAcceptMobileMoneyRequested` à `BidBloc`, jamais à `BidAcceptanceBloc`)

- [ ] Step 1 tests, Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(matching): acceptation dédiée d'un bid mobile money par le voyageur`

---

### Task 7: Catalogue d'erreurs et events analytics

**Files:**
- Modify: `lib/core/error/error_catalog.dart` (`_byCode`, ligne 38 : nouveau groupe `// ─── Mobile money (pawaPay) ───`), en copiant `severity` et `icon` de l'entrée 422 voisine la plus proche (`request/already-accepted`).
- Modify: `CLAUDE.md` (table des events analytics, lignes 304-487) : lignes pour `mobile_money_account_activated`, `mobile_money_account_disabled`, `mobile_money_initiated`, `mobile_money_confirmed`, `mobile_money_failed`, propriétés et écran déclencheur.
- Test: `test/core/error/error_catalog_test.dart` (existant ou nouveau) : chaque code rend un titre non générique.

Entrées (titre / message) :
- `mobile-money-disabled` : « Mobile money indisponible » / « Le paiement mobile money n'est pas ouvert pour le moment. Choisissez un autre moyen de paiement. »
- `mobile-money-phone-required` : « Numéro introuvable » / « Aucun numéro de téléphone n'est associé à votre compte Yadony. Ajoutez-le dans votre profil. »
- `mobile-money-account-unsupported` : « Numéro non pris en charge » / « Votre numéro n'est pas rattaché à un opérateur mobile money compatible, ou sa devise ne correspond pas à votre zone. »
- `mobile-money-account-required` : « Compte de versement requis » / « Activez votre versement mobile money avant d'accepter cette offre. »
- `mobile-money-currency-mismatch` : « Devise différente » / « Votre compte de versement mobile money n'est pas dans la devise de ce trajet. »
- `mobile-money-not-available` : « Mobile money non proposé » / « Ce voyageur n'accepte pas le paiement mobile money. »
- `payment-method-unavailable-for-currency` : « Moyen de paiement indisponible » / « Ce moyen de paiement n'est pas proposé dans la devise de ce trajet. »
- `mobile-money-payer-unsupported` : « Numéro non pris en charge » / « Vérifiez le numéro qui doit payer, ou essayez avec un autre numéro. »
- `mobile-money-deposit-rejected` : « Paiement refusé » / « L'opérateur a refusé la demande de paiement. Réessayez, éventuellement avec un autre numéro. »
- `mobile-money-payment-expired` : « Délai dépassé » / « Le délai de paiement de 30 minutes est passé. Refaites une offre au voyageur. »
- `mobile-money-payment-not-pending` : « Paiement déjà traité » / « Ce paiement n'est plus en attente. »
- `mobile-money-operation-in-progress` : « Opération en cours » / « Une opération mobile money est déjà en cours pour cet envoi. Patientez quelques instants. »
- `mobile-money-provider-unavailable` : « Service indisponible » / « Le service mobile money ne répond pas. Réessayez dans quelques minutes. »
- `invalid-payment-method` : « Moyen de paiement invalide » / « Ce moyen de paiement n'est pas reconnu. Mettez l'application à jour. »

- [ ] Step 1 tests, Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(core): libellés des erreurs mobile money et events analytics du rail`

---

### Task 8: Écran du compte de versement et entrée dans « Moi »

**Files:**
- Create: `lib/features/payments/presentation/screens/mobile_money_account_screen.dart`
- Modify: `lib/app/router.dart` (à côté de `/payments/onboarding`, ligne 778) : `GoRoute(path: '/payments/mobile-money/account', builder: (_, __) => BlocProvider(create: (_) => getIt<MobileMoneyAccountBloc>()..add(const MobileMoneyAccountRequested()), child: const MobileMoneyAccountScreen()))`
- Modify: `lib/features/profile/presentation/widgets/profile_sections.dart:162-169` : avant la tuile « Carte commission espèces », ajouter

```dart
                DonyListTile(
                  iconAsset: 'smartphone',
                  iconColor: cs.primary,
                  iconBgColor: cs.primaryContainer,
                  label: 'Versement mobile money',
                  subtitle: 'Zone CFA : Orange Money, Wave, MTN',
                  onTap: () => context.push('/payments/mobile-money/account'),
                ),
```

- Test: `test/features/payments/presentation/screens/mobile_money_account_screen_test.dart`, mise à jour du test de `profile_sections` s'il existe (la tuile est présente et navigue).

Écran (`StatelessWidget` + `BlocConsumer<MobileMoneyAccountBloc, MobileMoneyAccountState>`), AppBar `DonyAppBarBackButton()` + titre « Versement mobile money » :
- `Loading`/`Initial` : `CircularProgressIndicator`.
- `Loaded`/`Updating` selon `account.status` :
  - `notConfigured` : carte explicative (« Votre numéro de téléphone Yadony devient votre compte de versement. Le montant net de chaque envoi vous est versé dessus à la livraison. »), liste des opérateurs (« Orange Money, Wave, MTN, Free… »), `DonyButton(label: 'Activer le versement mobile money', isLoading: state is Updating, onPressed: () => bloc.add(const MobileMoneyAccountActivateRequested()))`.
  - `active` : carte avec `providerLabel`, `msisdnMasked`, `currency`, badge `DonyBadge(label: 'ACTIF', type: DonyBadgeType.success)`, `DonyButton(label: 'Désactiver', variant: DonyButtonVariant.ghost, ...DisableRequested)`.
  - `disabled` : texte « Versement désactivé. Vos informations sont conservées. », `DonyButton(label: 'Réactiver', ...ActivateRequested)`.
- `Error` : `listener` → `ErrorPresenter.show(context, state.error)` ; `builder` → si `state.account != null`, la vue correspondante, sinon `DonyEmptyState(title: 'Impossible de charger votre compte', actionLabel: 'Réessayer', onAction: ... Requested)`.
- Analytics : `screen` non tracé ici (les actions le sont dans le bloc).

- [ ] Step 1 tests widget (trois vues, boutons envoient les bons events via `MockBloc`, erreur affichée), Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(payments): écran du compte de versement mobile money et entrée dans le profil`

---

### Task 9: Bascule « Mobile money » à la création ou l'édition d'un trajet

**Files:**
- Modify: `lib/features/matching/bloc/announcement_form_event.dart:109-116` (ajouter `MobileMoneyAcceptedChanged(bool accepted)`), `announcement_form_state.dart:73,101,157,191,216` (champ `mobileMoneyAccepted`), `announcement_form_bloc.dart:35,164-169` (handler)
- Modify: `lib/features/matching/presentation/screens/create_trip_screen.dart` : `_mobileMoneyEnabledNotifier = ValueNotifier<bool>(false)` (à côté de `_cashEnabledNotifier`, ligne 586) ; préremplissage à l'édition (ligne 707) ; listener `_syncMobileMoneyAcceptedToFormBloc` (ligne 826 et 1121) ; ajout à la liste des notifiers de signature (ligne 904) ; passage au `PrixConditionsStep` (ligne 1937) des paramètres `mobileMoneyEnabledNotifier`, `currencyNotifier: _currencyNotifier`, `mobileMoneyAccountActive` (lu depuis un `BlocBuilder<MobileMoneyAccountBloc, ...>` fourni par l'écran : `BlocProvider(create: (_) => getIt<MobileMoneyAccountBloc>()..add(const MobileMoneyAccountRequested()))` ajouté au `MultiBlocProvider` de l'écran, ligne 206) ; liste envoyée (ligne 1359) : `if (_mobileMoneyEnabledNotifier.value) 'MOBILE_MONEY'`.
- Modify: `lib/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart:77,559-580` : nouveaux paramètres, et sous la `SwitchListTile` espèces une seconde `SwitchListTile(key: Key('payment-method-mobile-money'), value: mobileMoneyEnabled, onChanged: eligible && accountActive ? (v) => mobileMoneyEnabledNotifier.value = v : null, title: Row(DonyIcon('smartphone'), Text('Mobile money')), subtitle: Text(!eligible ? 'Disponible pour les trajets en XOF ou XAF' : !accountActive ? 'Activez d\'abord votre versement mobile money' : 'Orange Money, Wave, MTN'))`, précédée d'un `TextButton('Activer le versement')` → `context.push('/payments/mobile-money/account')` quand `eligible && !accountActive`. `eligible` = `currencyNotifier.value.code` ∈ {`XOF`, `XAF`} (via `ValueListenableBuilder`).
- Test: `test/features/matching/bloc/announcement_form_bloc_test.dart` (nouvel event), tests de `prix_conditions_step` (bascule absente hors CFA, désactivée sans compte, active avec compte), test de `create_trip_screen` sur la liste envoyée si un test couvre déjà `paymentMethods`.

- [ ] Step 1 tests, Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(matching): bascule mobile money sur les trajets en zone CFA`

---

### Task 10: Offre de l'expéditeur en mobile money

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_bid_bottom_sheet.dart` :
  - lignes 148-155 : `late final bool _isMobileMoneyAvailable;` (commentaire à réécrire : le mobile money direct est de retour via pawaPay, `MOBILE_MONEY`, les anciens `WAVE`/`ORANGE_MONEY` restent retirés) ;
  - ligne 255 : `bool get _hasAlternativePaymentMethods => _isCashAvailable || _isMobileMoneyAvailable;`
  - lignes 268-276 : `_isMobileMoneyAvailable = widget.announcement.acceptedPaymentMethods.contains(BidPaymentMethod.mobileMoney);` et défaut `_isStripeAvailable ? stripe : _isCashAvailable ? cash : mobileMoney` ;
  - nouveau contrôleur `_payerPhoneCtrl = TextEditingController(text: <numéro de l'utilisateur connecté si AuthBloc l'expose, sinon vide>)`, disposé ;
  - lignes 699-733 (`_confirmPayment`) : `if (method == cash || method == mobileMoney)` → `BidCreateRequested(... paymentMethod: method, phoneNumber: method == mobileMoney && _payerPhoneCtrl.text.trim().isNotEmpty ? _payerPhoneCtrl.text.trim() : null, ...)` ;
  - lignes 773-783 : `BidPaymentMethod.mobileMoney => 'Paiement mobile money : si le voyageur accepte, vous recevrez une notification et aurez 30 minutes pour valider le paiement sur votre téléphone. Le montant est gardé en sécurité par Yadony jusqu'à la livraison.'` ;
  - lignes 1420-1436 : passer `isMobileMoneyAvailable: _isMobileMoneyAvailable` et, `if (method == BidPaymentMethod.mobileMoney) ...[SizedBox, _PayerPhoneField(controller: _payerPhoneCtrl)]` ;
  - `_PaymentMethodSelector` (2141-2188) : paramètre `isMobileMoneyAvailable = false` et tuile `_MethodTile(key: Key('payment-method-mobile-money'), iconAsset: 'smartphone', label: 'Mobile money', sublabel: 'Orange Money, Wave, MTN', selected: selectedMethod == mobileMoney, onTap: () => onChanged(mobileMoney))` ;
  - nouveau widget `_PayerPhoneField` (contenu informatif + `TextField` `keyboardType: TextInputType.phone`, libellé « Numéro qui paiera (facultatif) », aide « Par défaut, votre numéro Yadony. Vous recevrez la demande de paiement sur ce numéro. ») dans le `child` scrollable, jamais dans le sticky bottom.
- Test: `test/features/matching/presentation/widgets/create_bid_bottom_sheet_success_test.dart` (sous-titre mobile money), tests du sélecteur (tuile présente si l'annonce accepte le mobile money, absente sinon ; sélection affiche le champ numéro ; `_confirmPayment` envoie `BidCreateRequested` avec `paymentMethod: mobileMoney` et le numéro saisi, ou null si vide).

- [ ] Step 1 tests, Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(matching): choix du mobile money et numéro payeur dans l'offre de l'expéditeur`

---

### Task 11: Barre expéditeur, badges et carte paiement

**Files:**
- Modify: `lib/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart:64-66` (`return bid.paymentMethod == BidPaymentMethod.stripe || bid.paymentMethod == BidPaymentMethod.mobileMoney;`) et `131-180` : nouveau bloc avant le bloc stripe

```dart
    if (status == 'AWAITING_PAYMENT' &&
        bid.paymentMethod == BidPaymentMethod.mobileMoney) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Payer par mobile money',
            iconAsset: 'smartphone',
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : () => context.push('/bids/${bid.id}/mobile-money/awaiting'),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Annuler la demande',
            variant: DonyButtonVariant.ghost,
            onPressed: isLoading ? null : () => _showDeleteDialog(context, title: 'Annuler la demande de transport ?', body: "Aucun paiement n'a été effectué. La demande sera retirée.", confirmLabel: 'Oui, annuler', dismissLabel: 'Retour'),
          ),
        ],
      );
    }
```

  Le retour de `context.push` doit déclencher le rechargement du détail : si `SenderStickyBar` ne peut pas le faire lui-même, exposer un callback `onPaymentReturned` appelé après `await context.push<bool>(...)` et branché dans `bid_detail_screen.dart` sur `BidDetailRequested` + `_loadPaymentStatus()`.
- Modify: `lib/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart:290-296,501-534` : `_MobileMoneyBadge` (icône `smartphone`, couleur `cs.primary`, texte « Paiement mobile money ») rendu quand `bid.paymentMethod == mobileMoney`, `_CashBadge` sinon pour les non-stripe.
- Modify: `lib/features/matching/presentation/widgets/bid_detail/paiement_card.dart:46-63` : branche `else if (bid.paymentMethod == BidPaymentMethod.mobileMoney)` → `Row(DonyIcon('smartphone', color: cs.primary), Text('Paiement mobile money, gardé en sécurité par Yadony jusqu'à la livraison : $senderLabel'), DonyBadge(label: 'MOBILE MONEY', type: DonyBadgeType.info))`.
- Test: `sender_sticky_bar_test.dart` (bouton présent en `AWAITING_PAYMENT` mobile money, navigation vers la route d'attente), `bid_detail_action_bars_test.dart` (badge mobile money), `paiement_card_test.dart`.

- [ ] Step 1 tests, Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(matching): paiement mobile money depuis le détail de l'envoi, badges et carte paiement`

---

### Task 12: Écran d'attente réécrit, deep link, notifications

**Files:**
- Rewrite: `lib/features/matching/presentation/screens/mobile_money_awaiting_screen.dart`
- Create: `lib/app/mobile_money_deep_link.dart` : `String? resolveMobileMoneyAwaitingDeepLink(Uri uri)` (`yadony://bids/{uuid}/mobile-money/awaiting` → `/bids/{uuid}/mobile-money/awaiting`, même `RegExp` UUID que `announcement_deep_link.dart`, null sinon)
- Modify: `lib/app/app.dart:147-189` : remplacer le bras unique par une liste ordonnée `static final _parameterizedResolvers = <String? Function(Uri)>[resolveAnnouncementDeepLink, resolveMobileMoneyAwaitingDeepLink];` parcourue avant la liste blanche (le commentaire l'exigeait au deuxième chemin paramétré).
- Modify: `lib/features/notifications/notification_route_resolver.dart:54` : `'MM_PAYMENT_PENDING' when _isUuid(bidId) => '/bids/$bidId/mobile-money/awaiting',`
- Test: `test/features/matching/presentation/screens/mobile_money_awaiting_screen_test.dart` (réécrit), `test/app/mobile_money_deep_link_test.dart`, mise à jour de `test/app/app_deep_link_test.dart` s'il existe, `notification_route_resolver_test.dart`.

Écran (`StatefulWidget` pour le `Timer` de sondage, 5 s, et le compte à rebours affiché via un `Timer` d'une seconde ; pas de `setState` : le compte à rebours passe par un `ValueNotifier<Duration>` + `ValueListenableBuilder`) :
- `initState` : analytics `mobileMoneyAwaiting` en `addPostFrameCallback` (comme aujourd'hui), `bloc.add(MobileMoneyPaymentOpened(bidId))`, `Timer.periodic(5 s)` → `MobileMoneyStatusPolled`.
- `listener` : `Escrowed` → annuler les timers, `DonySnackbar` succès « Paiement confirmé, votre envoi est sécurisé », `context.pop(true)` (retour au détail) ; `Expired` et `DepositFailed` → annuler le sondage ; `Error` → `ErrorPresenter.show`.
- `builder` :
  - `Loading`/`Initial` : spinner.
  - `AwaitingConfirmation(status)` : carte en-tête (montant + devise formatés avec l'utilitaire de devise existant, `providerLabel`, `msisdnMasked`), compte à rebours « Temps restant mm:ss » jusqu'à `deadlineAt` (rouge sous 5 min), puis : si `status.isWaveRedirect` → texte « Terminez le paiement dans l'application Wave » et `DonyButton(label: 'Ouvrir Wave', iconAsset: 'external-link', onPressed: () => getIt<ExternalUrlLauncher>().open(Uri.parse(authorizationUrl)))` (vérifier l'enregistrement DI d'`ExternalUrlLauncher`, sinon l'instancier comme le font ses appelants existants) ; sinon → texte « Validez le paiement sur votre téléphone : une demande de code PIN vient de vous être envoyée par $providerLabel. » ; en bas : « La confirmation est automatique, gardez cet écran ouvert. »
  - `DepositFailed(status)` : icône alerte, `failureMessage` si présent sinon « Le paiement a été refusé par l'opérateur », champ « Payer avec un autre numéro (facultatif) » + `DonyButton(label: 'Réessayer', onPressed: () => bloc.add(MobileMoneyPaymentInitiateRequested(bidId, phoneNumber: saisi ou null)))`.
  - `Expired` : « Délai dépassé. La demande a été annulée, refaites une offre au voyageur. » + `DonyButton(label: 'Retour', variant: ghost, onPressed: () => context.pop(false))`.
  - `Escrowed` : icône succès + « Paiement confirmé » (affiché le temps du pop).
  - `Error` : `DonyEmptyState` avec « Réessayer » → `MobileMoneyPaymentOpened`.
- Titre AppBar : « Paiement mobile money ».

- [ ] Step 1 tests (états, boutons, navigation, deep link, résolution de notification), Step 2 échec, Step 3 implémenter, Step 4 verts + analyze.
- [ ] **Step 5: Commit** : `feat(matching): écran de paiement mobile money (PIN, Wave, compte à rebours), deep link et push`

---

### Task 13: Vérification finale et recette sur le Redmi

**Files:** aucun nouveau ; `CLAUDE.md` (table analytics) si la tâche 7 ne l'a pas fait ; `docs/stories-done/` : `story-mobile-money-pawapay-app.md` à rédiger à la fin (fichiers, flux, pièges, tests, couverture).

- [ ] `flutter analyze` sur tout le projet, zéro avertissement nouveau.
- [ ] `flutter test --coverage --exclude-tags golden` : tout vert ; couverture globale lue dans `coverage/lcov.info` (`lcov --summary`), ≥ cliquet CI et en hausse ; ≥ 90 % sur les fichiers de ce plan.
- [ ] `grep -rn "regenerateLink\|MobileMoneyPaymentModel\|paymentLink" lib test` : aucun reste.
- [ ] Build et installation sur le Redmi (fait par le contrôleur, pas par un sous-agent) : `flutter build apk --debug --dart-define-from-file=/Users/aboubakardiakite/Desktop/dony/dony_app/env.staging.json` puis `adb install -r`, parcours de recette selon `yadony-back/docs/runbooks/pawapay.md`, section « Recette pas à pas ».
- [ ] Documentation `docs/stories-done/story-mobile-money-pawapay-app.md`, commit `docs: story rail mobile money côté app`.
