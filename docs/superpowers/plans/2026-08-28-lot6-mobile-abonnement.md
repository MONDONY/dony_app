# Lot 6 — Abonnement PRO côté mobile — Plan d'implémentation

> **Pour les agents :** SOUS-COMPÉTENCE REQUISE — utiliser `superpowers:subagent-driven-development`. Les étapes utilisent la syntaxe case à cocher (`- [ ]`).

**Objectif :** l'application cesse de prétendre accorder le statut PRO. Elle explique l'abonnement payant, renvoie vers le portail web dans le navigateur externe, affiche l'état réel de l'abonnement et alerte sur l'impayé et la fin de grâce.

**Architecture :** nouvelle feature `lib/features/billing/` (`bloc/` + `data/` + `presentation/`), consommée par l'écran PRO existant et par un bandeau monté sur l'écran Profil. Aucun appel au Checkout ni au Customer Portal depuis l'app : le mobile ouvre des URL web.

**Tech :** Flutter, flutter_bloc, GetIt, Dio, GoRouter, `url_launcher` (déjà présent), `bloc_test` + `mocktail` (déjà présents). Aucune dépendance à ajouter.

**Dépôt :** `dony_app`, branche `feature/pro-abonnement` (déjà créée depuis `main` à jour, commit `7f276373`).

---

## Global Constraints

Ces contraintes lient **toutes** les tâches. Elles s'ajoutent aux exigences propres à chaque tâche.

- **Nom public : « Yadony »**, avec cette casse exacte, dans toute copie visible. Jamais « Dony » dans un texte affiché. Les identifiants techniques (`dony_app`, widgets `Dony*`, package `dony`) ne changent pas.
- **Jamais de tiret cadratin (« — ») dans un texte affiché à l'utilisateur.** Utiliser une virgule, un point ou deux phrases.
- **Jamais `setState`** : flutter_bloc pour tout état de feature. Un `TextEditingController` ou un `ScrollController` en `State` reste permis, ce n'est pas de l'état de feature.
- **Jamais `Navigator.push`** : GoRouter uniquement (`context.push` / `context.go` / `context.pop`).
- **Jamais le package `http`** : Dio via `ApiClient` unique.
- **Jamais instancier un service dans un widget ou un BLoC** : GetIt (`getIt<T>()`). `registerFactory` pour les BLoC, `registerLazySingleton` pour les repositories.
- **Jamais d'URL en dur** : `String.fromEnvironment` avec valeur par défaut, dans `lib/core/config/api_config.dart`.
- **Design system :** importer `package:dony/core/design/design_system.dart` et utiliser les rôles sémantiques (`DonyColors`, `DonySpacing`, `DonyRadius`) ou `Theme.of(context).colorScheme`. **Ne jamais utiliser les constantes `kGreenPrimary`, `kGreenDark`, `kBackground` etc. citées dans le `CLAUDE.md` racine : cette palette est périmée**, le design system est passé au bleu. Lire `lib/core/design/CLAUDE.md` avant d'écrire du widget.
- **Cibles tactiles ≥ 44×44 pt.** `Semantics` sur toute icône porteuse de sens. Aucune information transmise par la seule couleur.
- **Analytics :** tout nom d'event est d'abord déclaré dans `lib/core/services/analytics_events.dart`. Les events métier partent **du BLoC**, jamais du widget (exception admise : event de vue à l'ouverture d'écran via `addPostFrameCallback` dans `initState`). Toujours `unawaited(...)`. Tout BLoC reçoit `AnalyticsService` en paramètre de constructeur. **Aucune PII** dans les propriétés : jamais de téléphone, e-mail, nom, raison sociale, SIRET, montant exact.
- **Tests :** `mocktail` uniquement, jamais `mockito`. `blocTest` pour les BLoC. Couverture globale du dépôt ≥ 90 %.
- **Jamais deux commandes Flutter en parallèle**, même dans des dossiers différents : le cache FVM est partagé et produit de faux échecs. Une seule commande `flutter` à la fois, toujours.
- **Aucun code mort :** un widget, un écran ou une méthode sans appelant doit être supprimé, ainsi que ses tests dédiés. Vérifier par `grep` avant de conserver quoi que ce soit.
- **Périmètre strict : ce dépôt uniquement.** Aucune modification de `dony-back` ni de `dony-pro`. Un défaut constaté ailleurs se signale, il ne se corrige pas ici.

---

## Ce que le backend expose réellement

Relevé le 2026-08-28 sur la branche `feature/pro-saas-abonnement` de `dony-back` (lots 1 à 4, PR #234). Préfixe global `/api/v1`, déjà porté par `API_BASE_URL`, donc les chemins ci-dessous s'écrivent sans préfixe dans le code Dart.

### `GET /billing/subscription` — authentifié

**Répond toujours 200.** Jamais 404, jamais 204, jamais de corps vide.

```json
{
  "active": false,
  "status": "NONE",
  "source": null,
  "billingCycle": null,
  "currentPeriodEnd": null,
  "cancelAtPeriodEnd": false,
  "graceExpiresAt": null
}
```

| Champ | Type JSON | Nullable | Valeurs |
|---|---|---|---|
| `active` | booléen | non | vrai si le statut donne accès PRO |
| `status` | chaîne | non | `ACTIVE`, `PAST_DUE`, `LEGACY_GRACE`, `CANCELED`, `EXPIRED`, `NONE` |
| `source` | chaîne | **oui** | `STRIPE`, `ADMIN_GRANT`, `LEGACY_FREE` ; nul quand `status = NONE` |
| `billingCycle` | chaîne | **oui** | `MONTHLY`, `YEARLY` ; nul pour `ADMIN_GRANT` et `LEGACY_FREE` |
| `currentPeriodEnd` | chaîne ISO-8601 UTC | **oui** | fin de la période payée |
| `cancelAtPeriodEnd` | booléen | non | résiliation programmée |
| `graceExpiresAt` | chaîne ISO-8601 UTC | **oui** | échéance de la grâce historique ou d'impayé |

`"NONE"` est une chaîne littérale produite par le contrôleur, **absente de l'énumération Java**. Le modèle Dart doit donc la traiter comme une valeur légitime, pas comme une valeur inconnue.

`active` est calculé côté serveur : vrai pour `ACTIVE`, `PAST_DUE` et `LEGACY_GRACE`. Ne pas le recalculer côté Dart, ne pas le déduire de `status` : le lire.

Aucun identifiant Stripe n'est exposé, délibérément. Le mobile ne peut donc pas savoir si un client Stripe existe : `source` est le seul indice disponible.

### `POST /billing/checkout-session` et `POST /billing/portal-session`

Ils existent et renvoient `{ "url": "..." }`, **mais le mobile ne les appelle pas**. Deux raisons cumulées :

1. Stripe interdit ses parcours de paiement en webview, contrainte déjà rencontrée sur ce projet (KYC Stripe Identity, onboarding Connect).
2. Un paiement d'abonnement déclenché depuis l'app iOS relève des règles d'achat intégré. La décision produit est de vendre **uniquement sur le web**.

Le mobile ouvre donc des URL web fixes dans le navigateur externe. Aucune tâche de ce plan n'appelle ces deux endpoints.

### `POST /auth/me/upgrade-to-pro`

**N'accorde plus le statut PRO depuis le lot 2.** Le service ne met plus à jour que `proCompanyName` et `proSiret`, avec un `422 invalid-siret` si le SIRET n'a pas 14 chiffres. Il renvoie un `UserResponse` dont `isProAccount` est resté à sa valeur d'avant.

C'est le défaut central que ce lot corrige : l'écran actuel appelle cet endpoint, reçoit 200, affiche « Vous êtes maintenant PRO » et rafraîchit le profil, lequel revient non-PRO.

### `DELETE /auth/me/upgrade-to-pro`

- `409` code `not-pro-account` si le compte n'est pas PRO.
- `409` code `active-stripe-subscription` si `source = STRIPE` et statut donnant accès. Message serveur : résiliation via le portail Stripe uniquement.
- Sinon le downgrade s'applique (`LEGACY_FREE`, `ADMIN_GRANT`, ou abonnement Stripe déjà fermé).

### `GET /auth/me`

Renvoie `UserResponse`, qui contient `isProAccount` mais **aucune donnée d'abonnement**. Statut, cycle, date de fin et source viennent exclusivement de `GET /billing/subscription`.

### Format d'erreur

RFC 7807 `ProblemDetail`, `Content-Type: application/problem+json`. Chaque erreur porte une propriété **`code`** en plus de `type` (`https://yadony.app/errors/<code>`). C'est `code` qu'il faut tester, pas `title` ni `detail`.

Codes atteignables depuis le mobile sur ce périmètre : `unknown-user` (401), `billing-not-configured` (503), `subscription-already-active` (409), `no-stripe-customer` (404), `not-pro-account` (409), `active-stripe-subscription` (409), `invalid-siret` (422).

---

## Deux constats vérifiés qui déterminent le périmètre

### 1. Le formulaire d'entreprise écrit dans le vide

`UserModel` (`lib/features/auth/data/models/user_model.dart:82-83`) lit `json['companyName']` et `json['siret']`. Or `UserResponse` côté backend **ne contient ni l'un ni l'autre** : vérifié, zéro occurrence de `companyName`, `siret`, `proCompanyName` ou `proSiret` dans `UserResponse.java` et `AuthService.java`.

Les deux champs Dart sont donc **toujours nuls**. L'écran actuel affiche un bloc « informations entreprise » qui ne peut structurellement rien afficher.

Côté backend, `proSiret` est écrit par `UserService.upgradeToPro` et **lu par personne** : la seule occurrence de `getProSiret()` dans tout `src/main/java` est sa propre déclaration dans `UserEntity`.

**Décision : le formulaire raison sociale + SIRET est retiré du mobile.** Il collecte une donnée que l'application ne peut pas relire et que le serveur n'exploite pas. Le conserver reviendrait à afficher indéfiniment des champs vides à un abonné. C'est aussi ce qui vide `POST /auth/me/upgrade-to-pro` de son dernier usage mobile.

**À signaler, pas à corriger ici :** si la collecte du SIRET est un besoin réel (facturation, obligations déclaratives), sa place est le portail web, où vit déjà la facturation, ou bien il faut exposer les deux champs dans `UserResponse`. Les deux sortent du périmètre de ce dépôt.

### 2. `isProAccount` ne dit pas si l'accès est payé

Un compte en `LEGACY_GRACE` (PRO gratuit historique, 60 jours de sursis) et un compte en `PAST_DUE` (paiement échoué) ont tous deux `isProAccount = true`. Le booléen ne suffit donc pas : sans `GET /billing/subscription`, l'application ne peut pas distinguer un abonné en règle d'un utilisateur sur le point de tout perdre.

C'est la raison d'être du bandeau de la tâche 5.

---

## Décisions de conception

**L'ouverture d'URL doit être injectable.** Le dépôt appelle `launchUrl` directement dans neuf widgets, ce qui n'est pas testable. Un seul endroit fait mieux : `HelpCenterRepository.openExternal` (`lib/features/profile/data/repositories/help_center_repository.dart:87-100`) reçoit `UrlLauncherPlatform` en constructeur, valide le schéma, et attrape toute exception. **Ce plan suit ce précédent**, sans quoi le comportement central du lot resterait non testé.

**Les URL du portail sont configurables.** Le portail Nuxt sert ses routes sous `app.baseURL = "/pro/"` alors que le backend redirige vers `https://pro.yadony.com/...` sans ce préfixe. L'incohérence n'est pas tranchée. Une variable d'environnement `PRO_PORTAL_URL` absorbe les deux cas sans nouveau build de code : si le proxy inverse ne réécrit pas, la valeur devient `https://pro.yadony.com/pro`.

**Le bandeau ne se monte que si l'utilisateur est PRO.** `GET /billing/subscription` répond 200 même sans abonnement ; monter le bandeau pour tout le monde ajouterait un appel réseau à chaque ouverture du Profil pour la quasi-totalité des utilisateurs, qui ne sont pas PRO. Les seuls statuts porteurs d'une alerte (`PAST_DUE`, `LEGACY_GRACE`, résiliation programmée) impliquent tous `isProAccount = true`.

**Tarifs affichés :** 4,99 € par mois, ou 47,90 € par an. L'économie annuelle est de 11,98 €. Ne jamais l'exprimer en mois offerts : 11,98 € représente 2,4 mois, et toute formulation en mois entiers serait fausse.

---

## Risque produit à signaler, hors périmètre technique

Un lien sortant vers un achat d'abonnement depuis une application iOS touche aux règles de l'App Store sur les achats intégrés et l'orientation hors application. La décision produit de vendre uniquement sur le web est prise et ce plan l'applique. **Le point doit être vérifié avant soumission**, il ne se tranche pas dans le code. Aucune tâche ne doit tenter d'y répondre par une adaptation par plateforme : ce serait de la spéculation.

---

## Structure de fichiers

**Créés :**

```
lib/features/billing/data/models/pro_subscription_model.dart
lib/features/billing/data/billing_repository.dart
lib/features/billing/bloc/subscription_bloc.dart
lib/features/billing/bloc/subscription_event.dart      (part of)
lib/features/billing/bloc/subscription_state.dart      (part of)
lib/features/billing/presentation/widgets/subscription_status_banner.dart
lib/features/billing/presentation/widgets/subscription_status_card.dart

test/features/billing/data/pro_subscription_model_test.dart
test/features/billing/data/billing_repository_test.dart
test/features/billing/bloc/subscription_bloc_test.dart
test/features/billing/presentation/subscription_status_banner_test.dart
test/features/billing/presentation/subscription_status_card_test.dart
```

**Modifiés :**

```
lib/core/config/api_config.dart                        (URL du portail)
lib/core/di/injection.dart                             (repository + bloc)
lib/core/services/analytics_events.dart                (4 events)
lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart   (refonte)
lib/features/profile/presentation/profile_screen.dart  (montage du bandeau)
lib/features/profile/bloc/upgrade_to_pro_bloc.dart     (réduction au downgrade)
lib/features/profile/bloc/upgrade_to_pro_event.dart
lib/features/profile/bloc/upgrade_to_pro_state.dart
lib/features/profile/data/profile_repository.dart      (retrait de upgradeToPro)
env.dev.json, env.staging.json, env.prod.json, env.android.json,
env.dev.json.example, env.prod.json.example
CLAUDE.md                                              (table des events)
```

**Supprimés :** aucun fichier entier. Les tests de `upgradeToPro` disparaissent avec la méthode.

---

## Task 1 : Modèle d'abonnement et URL du portail

**Files :**
- Create: `lib/features/billing/data/models/pro_subscription_model.dart`
- Create: `test/features/billing/data/pro_subscription_model_test.dart`
- Modify: `lib/core/config/api_config.dart`
- Modify: `env.dev.json`, `env.staging.json`, `env.prod.json`, `env.android.json`, `env.dev.json.example`, `env.prod.json.example`

**Interfaces :**
- Consomme : rien
- Produit :
  - `enum ProSubscriptionStatus { active, pastDue, legacyGrace, canceled, expired, none, unknown }`
  - `enum ProSubscriptionSource { stripe, adminGrant, legacyFree, unknown }`
  - `class ProSubscriptionModel extends Equatable` avec `bool active`, `ProSubscriptionStatus status`, `ProSubscriptionSource? source`, `String? billingCycle`, `DateTime? currentPeriodEnd`, `bool cancelAtPeriodEnd`, `DateTime? graceExpiresAt`, plus `factory ProSubscriptionModel.fromJson(Map<String, dynamic> json)`
  - `const String kProPortalBaseUrl`
  - `String proPortalUpgradeUrl()`, `String proPortalSubscriptionUrl()`

- [ ] **Étape 1 : Écrire les tests du modèle**

Créer `test/features/billing/data/pro_subscription_model_test.dart`. Les cas à couvrir, chacun avec une charge utile JSON écrite à la main **exactement dans la forme du tableau backend ci-dessus** :

1. Abonnement mensuel actif complet : `active` vrai, statut `active`, source `stripe`, cycle `MONTHLY`, `currentPeriodEnd` parsée en `DateTime` **UTC** (asserter `isUtc` vrai), `cancelAtPeriodEnd` faux, `graceExpiresAt` nulle.
2. Absence d'abonnement : la charge utile littérale `{"active": false, "status": "NONE", "source": null, "billingCycle": null, "currentPeriodEnd": null, "cancelAtPeriodEnd": false, "graceExpiresAt": null}` donne le statut `none` et une source **nulle**, sans lever d'exception.
3. Grâce historique : statut `legacyGrace`, source `legacyFree`, `billingCycle` nul, `graceExpiresAt` parsée.
4. Impayé : statut `pastDue`, `active` vrai. Ce cas doit prouver que `active` est **lu du JSON et non déduit** du statut : mettre `"active": true` avec `"status": "PAST_DUE"` et asserter que le modèle rend `true`.
5. Octroi administrateur : source `adminGrant`, cycle nul.
6. Statut inconnu : `"status": "SOMETHING_NEW"` donne `unknown` sans exception. Idem pour une source inconnue.
7. Champs absents plutôt que nuls : une charge utile réduite à `{"active": false, "status": "NONE"}` ne doit pas lever. Les clés manquantes valent nul, `cancelAtPeriodEnd` retombe sur `false`.

Ajouter un test d'égalité `Equatable` : deux modèles construits des mêmes valeurs sont égaux.

- [ ] **Étape 2 : Lancer les tests, vérifier qu'ils échouent**

```bash
flutter test test/features/billing/data/pro_subscription_model_test.dart
```
Attendu : ÉCHEC à la compilation, le fichier de modèle n'existe pas.

- [ ] **Étape 3 : Écrire le modèle**

Créer `lib/features/billing/data/models/pro_subscription_model.dart`.

Les deux énumérations portent une valeur `unknown` de repli. Le décodage se fait par une fonction privée qui compare la chaîne brute du serveur, en majuscules, et retombe sur `unknown` pour toute valeur non reconnue. `none` est une valeur légitime du statut, pas un repli : la distinguer de `unknown` importe, la première signifie « le serveur affirme qu'il n'y a pas d'abonnement », la seconde « le serveur parle une langue que cette version ne connaît pas ».

`source` est nullable dans le modèle parce qu'il l'est dans la réponse. Ne pas le remplacer par une valeur sentinelle.

Les dates se parsent avec `DateTime.parse(...)`, qui rend un `DateTime` UTC pour une chaîne ISO-8601 terminée par `Z`. Ne pas appeler `.toLocal()` au décodage : la conversion en heure locale est une affaire d'affichage, elle appartient aux widgets.

- [ ] **Étape 4 : Lancer les tests, vérifier qu'ils passent**

```bash
flutter test test/features/billing/data/pro_subscription_model_test.dart
```
Attendu : SUCCÈS.

- [ ] **Étape 5 : Ajouter la configuration d'URL du portail**

Dans `lib/core/config/api_config.dart`, à la suite des constantes existantes, en calquant le style de `kApiBaseUrl` et de `posterShareBaseUrl` :

```dart
/// Base du portail web Yadony PRO, où se souscrit et se gère l'abonnement.
///
/// Le portail sert ses routes sous un préfixe (`app.baseURL`) qui peut ou non
/// être réécrit par le proxy inverse. Cette variable absorbe les deux cas :
/// sans réécriture, la valeur devient `https://pro.yadony.com/pro`.
const String kProPortalBaseUrl = String.fromEnvironment(
  'PRO_PORTAL_URL',
  defaultValue: 'https://pro.yadony.com',
);

/// Page de vente de l'abonnement PRO.
String proPortalUpgradeUrl() => '$kProPortalBaseUrl/upgrade';

/// Page de gestion de l'abonnement PRO.
String proPortalSubscriptionUrl() => '$kProPortalBaseUrl/parametres/abonnement';
```

Ajouter la clé `"PRO_PORTAL_URL": "https://pro.yadony.com"` dans les six fichiers d'environnement listés en tête de tâche. **Ne modifier aucune autre clé, ne jamais afficher ni recopier ailleurs les valeurs de secret** que ces fichiers contiennent.

Écrire deux tests dans un nouveau fichier `test/core/config/pro_portal_url_test.dart` : `proPortalUpgradeUrl()` se termine par `/upgrade`, `proPortalSubscriptionUrl()` se termine par `/parametres/abonnement`, et les deux commencent par `kProPortalBaseUrl` sans double barre oblique.

- [ ] **Étape 6 : Analyse et commit**

```bash
flutter analyze
```
Attendu : aucune erreur ni avertissement nouveau. **Lancer `flutter analyze` sur tout le projet, sans cibler de fichier** : une analyse ciblée laisse passer des lints que la CI voit.

```bash
git add lib/features/billing lib/core/config/api_config.dart test/features/billing test/core/config env.*.json env.*.json.example
git commit -m "feat(billing): modèle d'abonnement PRO et URL du portail web"
```

---

## Task 2 : Repository de facturation et ouverture externe testable

**Files :**
- Create: `lib/features/billing/data/billing_repository.dart`
- Create: `test/features/billing/data/billing_repository_test.dart`
- Modify: `lib/core/di/injection.dart`

**Interfaces :**
- Consomme : `ProSubscriptionModel` (tâche 1), `ApiClient` (`lib/core/network/api_client.dart`), `unwrapDioError` (`lib/core/error/`)
- Produit :
  - `class BillingRepository` avec le constructeur `BillingRepository(this._client, {UrlLauncherPlatform? launcher})`
  - `Future<ProSubscriptionModel> getSubscription()`
  - `Future<bool> openExternal(Uri uri)`

- [ ] **Étape 1 : Lire le précédent**

Ouvrir `lib/features/profile/data/repositories/help_center_repository.dart:87-100` et `lib/features/profile/data/profile_repository.dart`. Le premier montre l'ouverture d'URL injectable, le second le style d'appel Dio du dépôt. Calquer les deux.

Regarder aussi comment un test existant simule Dio (chercher un test de repository sous `test/features/` qui mocke `ApiClient` ou `Dio`) et suivre exactement le même montage plutôt que d'en inventer un.

- [ ] **Étape 2 : Écrire les tests**

Créer `test/features/billing/data/billing_repository_test.dart`.

Pour `getSubscription()` :
1. Une réponse 200 portant une charge utile d'abonnement actif rend un `ProSubscriptionModel` correspondant, et l'appel part bien sur le chemin `/billing/subscription` en `GET` (le vérifier).
2. Une réponse 200 portant la charge utile « aucun abonnement » rend un modèle de statut `none`, **sans lever**. C'est le cas nominal pour la majorité des utilisateurs, il ne doit jamais être traité comme une erreur.
3. Une `DioException` réseau est convertie en `AppException` par `unwrapDioError` et relancée. Asserter le type de l'exception, pas seulement qu'elle est levée.

Pour `openExternal(Uri)` :
4. Une URI `https` valide déclenche l'ouverture et rend `true`. Vérifier que le lanceur est appelé **en mode navigateur externe**, pas en vue intégrée : c'est la contrainte centrale du lot, une ouverture en webview ferait échouer le paiement Stripe. Asserter sur le paramètre transmis à `UrlLauncherPlatform`.
5. Un lanceur qui rend `false` fait rendre `false` au repository, sans lever.
6. Un lanceur qui lève une `PlatformException` fait rendre `false`, sans propager.
7. Une URI de schéma non `https` rend `false` **sans appeler le lanceur du tout**. Vérifier l'absence d'appel avec `verifyNever`. Un lien d'abonnement ne doit jamais partir en clair ni ouvrir un schéma arbitraire.
8. Une URI sans hôte rend `false` sans appeler le lanceur.

- [ ] **Étape 3 : Lancer les tests, vérifier qu'ils échouent**

```bash
flutter test test/features/billing/data/billing_repository_test.dart
```
Attendu : ÉCHEC à la compilation.

- [ ] **Étape 4 : Écrire le repository**

Créer `lib/features/billing/data/billing_repository.dart`.

`getSubscription()` fait `GET /billing/subscription` via `_client.dio`, passe `response.data` à `ProSubscriptionModel.fromJson` et laisse remonter `unwrapDioError(e)` sur `DioException`, comme `ProfileRepository`.

`openExternal(Uri uri)` reprend la logique de `HelpCenterRepository.openExternal` : le lanceur par défaut est `UrlLauncherPlatform.instance`, injectable par le constructeur pour les tests ; refuser toute URI dont le schéma n'est pas `https` ou dont l'hôte est vide, **avant** tout appel au lanceur ; envelopper l'appel dans un `try`/`catch` large rendant `false`.

L'ouverture doit se faire en navigateur externe. Vérifier dans `help_center_repository.dart` le nom exact du paramètre de `UrlLauncherPlatform` qui l'exige dans la version du package présente, et employer le même. Ne pas deviner.

- [ ] **Étape 5 : Lancer les tests, vérifier qu'ils passent**

```bash
flutter test test/features/billing/data/billing_repository_test.dart
```
Attendu : SUCCÈS.

- [ ] **Étape 6 : Enregistrer dans GetIt**

Dans `lib/core/di/injection.dart`, ajouter `getIt.registerLazySingleton<BillingRepository>(() => BillingRepository(getIt<ApiClient>()));` au même endroit et dans le même style que les autres repositories. Ne pas passer de lanceur : la valeur par défaut est la bonne en production.

- [ ] **Étape 7 : Analyse et commit**

```bash
flutter analyze
git add lib/features/billing lib/core/di/injection.dart test/features/billing
git commit -m "feat(billing): repository d'abonnement et ouverture du portail en navigateur externe"
```

---

## Task 3 : SubscriptionBloc et events analytics

**Files :**
- Create: `lib/features/billing/bloc/subscription_bloc.dart`, `subscription_event.dart`, `subscription_state.dart`
- Create: `test/features/billing/bloc/subscription_bloc_test.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `lib/core/di/injection.dart`

**Interfaces :**
- Consomme : `BillingRepository` (tâche 2), `ProSubscriptionModel` (tâche 1), `AnalyticsService` (`lib/core/services/analytics_service.dart`)
- Produit :
  - `enum ProPortalTarget { upgrade, manage }`
  - Events : `SubscriptionRequested()`, `ProPortalOpenRequested(ProPortalTarget target)`
  - States : `SubscriptionInitial`, `SubscriptionLoading`, `SubscriptionLoaded(ProSubscriptionModel subscription)`, `SubscriptionError(AppException error)`, `SubscriptionPortalLaunchFailed(ProSubscriptionModel? subscription)`
  - `class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState>`, constructeur `SubscriptionBloc(this._repository, this._analytics)`

- [ ] **Étape 1 : Déclarer les events analytics**

Dans `lib/core/services/analytics_events.dart`, ajouter quatre constantes, en respectant le style et l'ordre du fichier :

```dart
static const proSubscriptionViewed = 'pro_subscription_viewed';
static const proPortalOpened = 'pro_portal_opened';
static const proPortalOpenFailed = 'pro_portal_open_failed';
static const proDowngradeBlocked = 'pro_downgrade_blocked';
```

Le quatrième sert à la tâche 6 ; le déclarer ici évite un second passage sur ce fichier.

- [ ] **Étape 2 : Écrire les tests du BLoC**

Créer `test/features/billing/bloc/subscription_bloc_test.dart`, en calquant le montage sur `test/features/profile/bloc/upgrade_to_pro_bloc_test.dart` (mock du repository avec `mocktail`, `blocTest`, `registerFallbackValue` si nécessaire). Mocker aussi `AnalyticsService`.

Cas à couvrir :

1. L'état initial est `SubscriptionInitial`.
2. `SubscriptionRequested` avec un repository qui rend un abonnement actif émet `[SubscriptionLoading, SubscriptionLoaded]`, et l'état chargé porte le modèle rendu.
3. `SubscriptionRequested` émet l'event analytics `proSubscriptionViewed` avec la propriété `status` valant la chaîne du statut, **et rien d'autre**. Vérifier par `verify` que les propriétés ne contiennent ni date, ni source de paiement, ni identifiant.
4. `SubscriptionRequested` avec un repository qui lève émet `[SubscriptionLoading, SubscriptionError]`, et l'erreur portée est celle levée.
5. `ProPortalOpenRequested(ProPortalTarget.upgrade)` appelle `openExternal` avec l'URI de `proPortalUpgradeUrl()`. Asserter l'URI **exacte** transmise, pas seulement le fait qu'un appel a eu lieu.
6. `ProPortalOpenRequested(ProPortalTarget.manage)` appelle `openExternal` avec l'URI de `proPortalSubscriptionUrl()`. Ces deux tests sont ce qui empêche une inversion des deux cibles, laquelle enverrait un prospect sur une page de gestion vide et un abonné sur une page de vente.
7. Une ouverture réussie émet l'event `proPortalOpened` avec la propriété `target` valant `upgrade` ou `manage`.
8. Une ouverture qui rend `false` émet l'état `SubscriptionPortalLaunchFailed` **puis** restaure l'état chargé précédent, de sorte que l'écran reste affiché. Asserter la séquence complète des deux états.
9. Une ouverture qui rend `false` émet l'event `proPortalOpenFailed`.
10. `ProPortalOpenRequested` reçu alors qu'aucun abonnement n'a encore été chargé n'entraîne pas de plantage : l'échec émet `SubscriptionPortalLaunchFailed(null)` et l'état restauré est celui d'avant. Ce cas existe parce que la vue non abonnée ouvre le portail sans avoir besoin d'un abonnement chargé.

- [ ] **Étape 3 : Lancer les tests, vérifier qu'ils échouent**

```bash
flutter test test/features/billing/bloc/subscription_bloc_test.dart
```
Attendu : ÉCHEC à la compilation.

- [ ] **Étape 4 : Écrire le BLoC**

Créer les trois fichiers, `subscription_event.dart` et `subscription_state.dart` étant déclarés `part of` du bloc, comme `upgrade_to_pro_bloc.dart` le fait déjà. Classes scellées, `Equatable`.

`SubscriptionPortalLaunchFailed` est un état **transitoire de signalement** : le widget l'écoute dans un `BlocListener` pour afficher un message, et le `builder` continue de rendre l'état chargé qui suit immédiatement. Ne pas le transformer en drapeau porté par `SubscriptionLoaded` : `Equatable` empêcherait alors une seconde notification identique de repartir.

Tous les appels analytics sont `unawaited(...)`. Aucune propriété ne doit contenir de date, de montant, de raison sociale ni d'identifiant Stripe.

- [ ] **Étape 5 : Lancer les tests, vérifier qu'ils passent**

```bash
flutter test test/features/billing/bloc/subscription_bloc_test.dart
```
Attendu : SUCCÈS.

- [ ] **Étape 6 : Enregistrer dans GetIt**

`getIt.registerFactory(() => SubscriptionBloc(getIt<BillingRepository>(), getIt<AnalyticsService>()));` — `registerFactory`, jamais `registerLazySingleton` : un BLoC par route.

- [ ] **Étape 7 : Analyse et commit**

```bash
flutter analyze
git add lib/features/billing lib/core/services/analytics_events.dart lib/core/di/injection.dart test/features/billing
git commit -m "feat(billing): BLoC d'abonnement et ouverture du portail"
```

---

## Task 4 : Widgets de présentation, carte de statut et bandeau

**Files :**
- Create: `lib/features/billing/presentation/widgets/subscription_status_card.dart`
- Create: `lib/features/billing/presentation/widgets/subscription_status_banner.dart`
- Create: `test/features/billing/presentation/subscription_status_card_test.dart`
- Create: `test/features/billing/presentation/subscription_status_banner_test.dart`

**Interfaces :**
- Consomme : `ProSubscriptionModel` (tâche 1), `DonyStatusBanner` (`lib/core/design/widgets/dony_status_banner.dart`), le design system
- Produit :
  - `class SubscriptionStatusCard extends StatelessWidget` — `const SubscriptionStatusCard({required this.subscription, this.onManage, super.key})`
  - `class SubscriptionStatusBanner extends StatelessWidget` — `const SubscriptionStatusBanner({required this.subscription, this.onAction, super.key})`
  - `int? daysUntil(DateTime? instant, {DateTime? now})` exposée depuis le fichier du bandeau, pour être testable seule

Les deux widgets sont **purement présentationnels** : aucun accès à un BLoC, aucun `getIt`, aucune navigation. Ils reçoivent un modèle et des rappels.

- [ ] **Étape 1 : Écrire les tests de `daysUntil` et du bandeau**

Créer `test/features/billing/presentation/subscription_status_banner_test.dart`.

`daysUntil` d'abord, en tests purs sans `pumpWidget`, avec un `now` injecté :
1. Une échéance dans 7 jours pleins rend 7.
2. Une échéance dans 6 jours et 12 heures rend **7**, pas 6. L'arrondi se fait vers le haut : annoncer « 6 jours » quand il en reste presque 7 sous-estime le délai, et annoncer « 0 jour » quand il reste quelques heures serait faux.
3. Une échéance dans 2 heures rend 1.
4. Une échéance **déjà passée** rend 0, jamais un nombre négatif.
5. Une échéance nulle rend `null`.
6. Une échéance exprimée en UTC est comparée correctement à un `now` local : construire le cas de sorte qu'une comparaison naïve entre un `DateTime` UTC et un `DateTime` local produirait un résultat faux, et asserter le bon. C'est le piège réel, les dates du serveur arrivent toutes en UTC.

Puis le bandeau, en `pumpWidget` avec `MaterialApp` :
7. Statut `pastDue` : le bandeau s'affiche, de ton avertissement ou erreur, et son texte parle d'un paiement qui n'a pas abouti. Un bouton d'action est présent et appelle `onAction` au tap.
8. Statut `legacyGrace` avec `graceExpiresAt` dans 12 jours : le bandeau s'affiche et le texte contient « 12 ».
9. Statut `legacyGrace` sans `graceExpiresAt` : le bandeau s'affiche quand même, avec un texte qui ne mentionne aucun nombre de jours. Un serveur muet sur la date ne doit pas produire « dans null jours » ni faire disparaître l'alerte.
10. Statut `active` avec `cancelAtPeriodEnd` vrai et `currentPeriodEnd` renseignée : un bandeau d'information annonce la fin de l'accès, avec la date en heure **locale**.
11. Statut `active` avec `cancelAtPeriodEnd` faux : **rien ne s'affiche**. Asserter l'absence de `DonyStatusBanner`, pas seulement l'absence d'un texte.
12. Statuts `none`, `canceled`, `expired` : rien ne s'affiche.
13. Statut `unknown` : rien ne s'affiche. Une version du serveur plus récente ne doit pas provoquer d'alerte inventée.
14. Le bandeau ne comporte **aucun tiret cadratin** dans ses textes. Écrire l'assertion explicitement sur les chaînes rendues.

- [ ] **Étape 2 : Lancer les tests, vérifier qu'ils échouent**

```bash
flutter test test/features/billing/presentation/subscription_status_banner_test.dart
```
Attendu : ÉCHEC à la compilation.

- [ ] **Étape 3 : Écrire `daysUntil` et le bandeau**

Créer `lib/features/billing/presentation/widgets/subscription_status_banner.dart`.

`daysUntil` normalise les deux instants avant de les soustraire, calcule la différence en minutes puis divise par 1440 en arrondissant **vers le haut**, et borne le résultat à zéro. Rendre `null` si l'échéance est nulle.

Le bandeau s'appuie sur `DonyStatusBanner` et n'en réimplémente pas la mise en forme. Choisir le ton par le statut. Quand rien n'est à signaler, rendre `const SizedBox.shrink()`.

Les dates affichées passent par `.toLocal()`.

> **Correction du 2026-08-28 :** ce plan affirmait initialement que `intl` n'était pas une dépendance du projet et demandait de composer les dates à la main. C'est **faux** : `intl: ^0.20.2` est déclaré dans `pubspec.yaml`, `flutter_localizations` aussi, et `DateFormat(..., 'fr')` est employé dans une douzaine d'écrans. Réutiliser `intl`, ne pas écrire une n-ième liste de mois en dur.

Textes indicatifs, à ajuster au ton du dépôt, sans tiret cadratin et avec « Yadony » si la marque est nommée :
- Impayé : « Votre dernier paiement n'a pas abouti. Sans régularisation, votre accès PRO sera suspendu. » Action : « Régler ».
- Grâce historique avec date : « Votre accès PRO gratuit prend fin dans N jours. » Action : « S'abonner ».
- Grâce historique sans date : « Votre accès PRO gratuit prendra bientôt fin. » Action : « S'abonner ».
- Résiliation programmée : « Votre abonnement PRO prend fin le <date>. » Pas d'action, ou « Gérer ».

- [ ] **Étape 4 : Lancer les tests, vérifier qu'ils passent**

```bash
flutter test test/features/billing/presentation/subscription_status_banner_test.dart
```
Attendu : SUCCÈS.

- [ ] **Étape 5 : Écrire les tests de la carte de statut**

Créer `test/features/billing/presentation/subscription_status_card_test.dart`.

1. Abonnement mensuel actif : la carte affiche un libellé d'état lisible en français, la mention du rythme mensuel, et la date de prochain renouvellement en heure locale.
2. Abonnement annuel actif : la carte affiche le rythme annuel. Ce test et le précédent, ensemble, empêchent un libellé figé sur un seul cycle.
3. Octroi administrateur : `billingCycle` étant nul, la carte n'affiche **aucune mention de rythme de facturation**, et ne montre aucun prix. Un accès offert n'est pas facturé, afficher « 4,99 € par mois » y serait un mensonge.
4. Grâce historique : la carte indique que l'accès est gratuit et temporaire.
5. Résiliation programmée : la carte le dit explicitement, en plus de la date.
6. `onManage` nul : aucun bouton de gestion n'est rendu. `onManage` fourni : le bouton est rendu et le rappel part au tap.
7. Aucun tiret cadratin dans les textes rendus.

- [ ] **Étape 6 : Lancer, vérifier l'échec, écrire la carte, vérifier le succès**

```bash
flutter test test/features/billing/presentation/subscription_status_card_test.dart
```

Créer `lib/features/billing/presentation/widgets/subscription_status_card.dart`. Carte du design system, `elevation: 0` et bordure, rayon et espacements pris dans les tokens. Le bouton de gestion n'est rendu que si `onManage` n'est pas nul.

- [ ] **Étape 7 : Analyse et commit**

```bash
flutter analyze
git add lib/features/billing/presentation test/features/billing/presentation
git commit -m "feat(billing): carte de statut et bandeau d'alerte d'abonnement"
```

---

## Task 5 : Bandeau d'abonnement sur l'écran Profil

**Files :**
- Modify: `lib/features/profile/presentation/profile_screen.dart`
- Create: `lib/features/billing/presentation/widgets/subscription_banner_host.dart`
- Create: `test/features/billing/presentation/subscription_banner_host_test.dart`

**Interfaces :**
- Consomme : `SubscriptionBloc` (tâche 3), `SubscriptionStatusBanner` (tâche 4)
- Produit : `class SubscriptionBannerHost extends StatelessWidget` — `const SubscriptionBannerHost({required this.isProAccount, super.key})`

- [ ] **Étape 1 : Lire l'écran hôte**

Ouvrir `lib/features/profile/presentation/profile_screen.dart`. Le corps est un `CustomScrollView` dont le second sliver est un `SliverList.list(children: _sections(...))`, alimenté par une méthode `_sections` qui reçoit déjà `isProAccount`. Le bandeau se pose **en tête de cette liste**.

L'écran fait 392 lignes et n'a pas de `BlocProvider` pour la facturation. Le composant à créer se fournit donc lui-même son BLoC, pour que la modification de l'écran se réduise à une seule ligne dans `_sections`.

- [ ] **Étape 2 : Écrire les tests**

Créer `test/features/billing/presentation/subscription_banner_host_test.dart`, en calquant le montage GetIt sur `test/features/profile/presentation/upgrade_to_pro_screen_test.dart` (enregistrement dans `setUp`, désenregistrement dans `tearDown`).

1. `isProAccount` faux : **aucun appel réseau n'est déclenché**. Vérifier par `verifyNever` sur `getSubscription` du repository mocké. C'est la garantie qui évite d'ajouter une requête à chaque ouverture du Profil pour la majorité des utilisateurs, qui ne sont pas PRO. Le widget rend un `SizedBox.shrink()`.
2. `isProAccount` vrai : `getSubscription` est appelé exactement une fois.
3. État chargé sur un statut `pastDue` : le bandeau est rendu.
4. État chargé sur un statut `active` sans résiliation : rien n'est rendu, et surtout **aucun espace vide résiduel** n'est introduit dans la liste.
5. État d'erreur : rien n'est rendu, et **aucun message d'erreur n'apparaît**. Un profil ne doit pas se couvrir d'une erreur technique parce qu'un appel secondaire a échoué.
6. État de chargement : rien n'est rendu. Pas d'indicateur de progression, qui ferait sauter la mise en page à chaque ouverture du Profil.
7. Le tap sur l'action du bandeau déclenche `ProPortalOpenRequested`. Vérifier la cible transmise : `upgrade` pour une grâce historique, `manage` pour un impayé. Un abonné en impayé doit atteindre son moyen de paiement, pas une page de vente.

- [ ] **Étape 3 : Lancer les tests, vérifier qu'ils échouent**

- [ ] **Étape 4 : Écrire le composant**

Créer `lib/features/billing/presentation/widgets/subscription_banner_host.dart`.

Si `isProAccount` est faux, rendre `const SizedBox.shrink()` **avant toute création de BLoC**, et non pas créer le BLoC puis s'abstenir de lui envoyer l'event : le premier évite l'instanciation, le second la retarde seulement.

Sinon, `BlocProvider(create: (_) => getIt<SubscriptionBloc>()..add(const SubscriptionRequested()))` autour d'un `BlocConsumer`. Le `listener` traite `SubscriptionPortalLaunchFailed` en affichant un message par le mécanisme de snackbar du dépôt (`DonySnackbar`, employé par l'écran PRO actuel). Le `builder` rend `SubscriptionStatusBanner` sur l'état chargé et `SizedBox.shrink()` partout ailleurs.

- [ ] **Étape 5 : Lancer les tests, vérifier qu'ils passent**

- [ ] **Étape 6 : Monter le composant dans le Profil**

Dans `_sections`, insérer `SubscriptionBannerHost(isProAccount: isProAccount)` en première position, suivi de l'espacement de section employé par les éléments voisins. Ne rien changer d'autre à cet écran.

- [ ] **Étape 7 : Lancer les tests de l'écran Profil**

```bash
flutter test test/features/profile
```
Attendu : SUCCÈS. Si un test de l'écran Profil casse, c'est que le montage introduit une dépendance GetIt non satisfaite dans son montage de test : l'ajouter au `setUp` du test concerné plutôt que de retirer le composant.

- [ ] **Étape 8 : Analyse et commit**

```bash
flutter analyze
git add lib/features/billing lib/features/profile/presentation/profile_screen.dart test/features/billing
git commit -m "feat(billing): bandeau d'état d'abonnement sur l'écran Profil"
```

---

## Task 6 : Refonte de l'écran PRO

C'est la tâche centrale du lot. Elle retire le mensonge d'interface et le remplace par un parcours honnête.

**Files :**
- Modify: `lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart` (562 lignes, refonte)
- Modify: `lib/features/profile/bloc/upgrade_to_pro_bloc.dart`, `upgrade_to_pro_event.dart`, `upgrade_to_pro_state.dart`
- Modify: `lib/features/profile/data/profile_repository.dart`
- Modify: `lib/core/di/injection.dart`
- Modify: `test/features/profile/bloc/upgrade_to_pro_bloc_test.dart`
- Modify: `test/features/profile/presentation/upgrade_to_pro_screen_test.dart`

**Interfaces :**
- Consomme : `SubscriptionBloc`, `SubscriptionStatusCard`, `SubscriptionStatusBanner`, `AuthBloc` (`AuthStateUser.currentUser`)
- Produit : rien de nouveau vers l'extérieur. La route `/profile/upgrade-to-pro` et le nom `UpgradeToProScreen` **ne changent pas** : cinq appelants en dépendent (`profile_sections.dart:257`, `trip_owner_detail_screen.dart:356`, `create_trip_screen.dart:1675` et `:1689`, `package_request_create_screen.dart:289`).

### Ce que l'écran doit devenir

**Vue non abonné** (`isProAccount` faux). Purement informative :
- Ce qu'apporte le compte PRO, repris des avantages déjà listés dans l'écran actuel.
- Les tarifs : 4,99 € par mois, ou 47,90 € par an, soit 11,98 € d'économie sur l'année. **Ne jamais traduire cette économie en mois offerts.**
- Une phrase qui dit clairement où se souscrit l'abonnement, par exemple « L'abonnement se souscrit sur le site Yadony PRO, dans votre navigateur. »
- Un bouton unique qui envoie `ProPortalOpenRequested(ProPortalTarget.upgrade)`.
- **Aucun formulaire, aucun champ de saisie, aucune promesse d'activation immédiate.**

**Vue abonné** (`isProAccount` vrai) :
- `SubscriptionStatusBanner` en tête, s'il a quelque chose à dire.
- `SubscriptionStatusCard` avec l'état réel.
- Le bouton de gestion (`onManage`) envoie `ProPortalOpenRequested(ProPortalTarget.manage)`, et n'est rendu **que si `source` vaut `stripe`**. C'est le seul indice disponible : le serveur n'expose délibérément aucun identifiant Stripe, l'application ne peut donc pas savoir autrement si un espace de gestion existe. Un accès offert par un administrateur ou une grâce historique n'a rien à gérer.
- Le bouton « Revenir en compte standard » est rendu **uniquement si `source` ne vaut pas `stripe`**. Pour un abonné payant, ce bouton ne pourrait qu'échouer en `409`, et lui proposer un geste voué au refus est pire que de ne pas le proposer. La résiliation d'un abonnement payant se fait sur le portail.
- L'état de l'abonnement n'étant connu qu'après chargement, la vue abonné rend d'abord un état de chargement discret, et masque les deux boutons tant que `source` est inconnue. Ne jamais afficher un bouton dont la légitimité n'est pas encore établie.

**Filet de sécurité sur la résiliation.** Même masqué, le chemin de downgrade peut renvoyer `409 active-stripe-subscription` (course entre un abonnement souscrit sur le web et un écran mobile ouvert avant). Le `BlocListener` doit reconnaître ce code et afficher un message qui renvoie vers la gestion sur le web, plutôt que l'erreur brute du serveur. Émettre alors l'event `proDowngradeBlocked`.

- [ ] **Étape 1 : Écrire les tests du BLoC réduit**

Modifier `test/features/profile/bloc/upgrade_to_pro_bloc_test.dart`.

Retirer les cas de `UpgradeToProSubmitted` : l'event disparaît. **Ne pas affaiblir les cas de downgrade conservés**, les garder tels quels avec toutes leurs assertions.

Ajouter :
1. `DowngradeRequested` sur un `409` de code `active-stripe-subscription` émet un état d'erreur portant ce code. Asserter le code, pas le message.
2. Ce même cas émet l'event analytics `proDowngradeBlocked`, sans propriété portant de PII.

Le BLoC reçoit désormais `AnalyticsService` : adapter tous les montages du fichier.

- [ ] **Étape 2 : Lancer, vérifier l'échec**

```bash
flutter test test/features/profile/bloc/upgrade_to_pro_bloc_test.dart
```

- [ ] **Étape 3 : Réduire le BLoC et le repository**

Dans `upgrade_to_pro_event.dart`, supprimer `UpgradeToProSubmitted`. Dans `upgrade_to_pro_state.dart`, supprimer `UpgradeToProSuccess` et `UpgradeToProError` s'ils n'ont plus d'émetteur, après vérification par `grep` qu'aucun autre fichier ne les référence. Dans le BLoC, supprimer `_onSubmitted` et ajouter `AnalyticsService` au constructeur.

Dans `lib/features/profile/data/profile_repository.dart`, supprimer `upgradeToPro`. Vérifier par `grep` qu'aucun autre appelant n'existe avant de supprimer, et supprimer aussi les tests dédiés à cette méthode.

Mettre à jour l'enregistrement GetIt de `UpgradeToProBloc` avec le nouveau paramètre.

- [ ] **Étape 4 : Lancer, vérifier le succès**

- [ ] **Étape 5 : Écrire les tests de l'écran**

Modifier `test/features/profile/presentation/upgrade_to_pro_screen_test.dart`. Le montage existant (GetIt, `MockAuthBloc` avec `whenListen`, `MaterialApp.router`, constante `_kSettle` pour laisser les animations se terminer) est le bon, le réutiliser. Ajouter un `MockSubscriptionBloc`.

Cas à couvrir :

1. Utilisateur non PRO : les tarifs 4,99 € et 47,90 € sont affichés, le bouton d'accès au portail est présent, et **aucun champ de saisie n'existe**. Asserter `find.byType(TextField)` et `find.byType(TextFormField)` vides. C'est ce test qui garantit que le formulaire trompeur ne revient pas.
2. Utilisateur non PRO : le tap sur le bouton envoie `ProPortalOpenRequested(ProPortalTarget.upgrade)`. Asserter la cible.
3. Utilisateur non PRO : aucun texte ne promet une activation depuis l'application. Asserter l'absence de la formulation retenue à l'étape 6 si elle existait avant.
4. Utilisateur PRO, abonnement Stripe actif : la carte de statut est rendue, le bouton de gestion est présent, et **le bouton « Revenir en compte standard » est absent**.
5. Utilisateur PRO, source `adminGrant` : le bouton de gestion est **absent**, le bouton de retour au compte standard est **présent**.
6. Utilisateur PRO, source `legacyFree` : même attendu que le cas 5, et le bandeau de grâce est rendu.
7. Utilisateur PRO, état de chargement de l'abonnement : **ni l'un ni l'autre des deux boutons** n'est rendu.
8. Utilisateur PRO, statut `pastDue` : le bandeau d'impayé est rendu.
9. Un état d'erreur de la souscription sur un utilisateur PRO n'efface pas l'écran : la page reste lisible et propose un moyen de réessayer.
10. Le downgrade refusé en `409 active-stripe-subscription` affiche un message qui mentionne la gestion sur le web, et **pas** le message brut du serveur.
11. Aucun tiret cadratin dans les textes rendus par l'écran, dans les deux vues.
12. « Yadony » est écrit avec cette casse partout où la marque est nommée, et « Dony » n'apparaît dans aucun texte affiché.

- [ ] **Étape 6 : Lancer, vérifier l'échec, réécrire l'écran, vérifier le succès**

Réécrire `upgrade_to_pro_screen.dart`. `UpgradeToProScreen` monte désormais **deux** BLoC en `MultiBlocProvider` : `UpgradeToProBloc` et `SubscriptionBloc`, ce dernier recevant `SubscriptionRequested` à la création uniquement si l'utilisateur est PRO.

Conserver l'event de vue `upgradeToProStarted` en `addPostFrameCallback` dans `initState`, il mesure toujours la même intention.

Réutiliser `SubscriptionStatusCard` et `SubscriptionStatusBanner` de la tâche 4 sans les redéfinir. Réutiliser `DonyStatusBanner` pour les messages d'information de la vue non abonnée.

Supprimer tout widget privé devenu sans appelant après la refonte, ainsi que ses tests.

- [ ] **Étape 7 : Suite complète et analyse**

Une seule commande, jamais deux commandes Flutter en parallèle :

```bash
flutter analyze && flutter test
```
Attendu : SUCCÈS intégral. Rapporter le résultat réel, y compris en cas d'échec.

- [ ] **Étape 8 : Commit**

```bash
git add lib test
git commit -m "feat(billing): l'écran PRO devient informatif et renvoie vers le portail web"
```

---

## Task 7 : Documentation et couverture

**Files :**
- Modify: `CLAUDE.md` (table des events analytics)
- Create: `docs/stories-done/story-lot6-abonnement-mobile.md`

- [ ] **Étape 1 : Mettre à jour la table des events**

Dans le `CLAUDE.md` du dépôt, ajouter quatre lignes à la table « Events actuellement implémentés », dans le style des lignes voisines : `pro_subscription_viewed`, `pro_portal_opened`, `pro_portal_open_failed`, `pro_downgrade_blocked`, chacune avec son déclencheur et ses propriétés.

Vérifier au passage si une ligne existante décrit un event supprimé par ce lot, et la retirer le cas échéant.

- [ ] **Étape 2 : Mesurer la couverture**

```bash
flutter test --coverage
```

Relever la couverture globale et celle de `lib/features/billing/`. Le seuil du dépôt est de 90 %. Si `lib/features/billing/` est en dessous, ajouter les tests manquants **avant** de conclure, en visant les branches non prises plutôt qu'en gonflant le nombre de cas.

- [ ] **Étape 3 : Écrire la documentation de story**

Créer `docs/stories-done/story-lot6-abonnement-mobile.md` selon le gabarit du `CLAUDE.md` (Résumé, Fichiers créés/modifiés, Comment ça fonctionne avec flux utilisateur, BLoC, écrans, appels API, pièges, Critères d'acceptation, Décisions techniques).

Y consigner explicitement :
- que `POST /auth/me/upgrade-to-pro` n'accordait plus le statut PRO et que l'écran mobile affirmait le contraire, ce que ce lot corrige ;
- que le formulaire raison sociale et SIRET a été retiré parce que `UserResponse` ne renvoie ni `companyName` ni `siret`, et que `proSiret` n'est lu par aucun code du backend ;
- que la visibilité des deux boutons de la vue abonné se décide sur `source`, faute d'identifiant Stripe exposé ;
- que `PRO_PORTAL_URL` existe pour absorber l'incohérence de préfixe `/pro/` entre le portail et les URL de retour du backend ;
- le risque App Store lié au lien sortant vers un achat, à vérifier avant soumission.

- [ ] **Étape 4 : Commit**

```bash
git add CLAUDE.md docs/stories-done
git commit -m "docs(billing): documentation de clôture du lot 6, abonnement mobile"
```

---

## Vérification de fin de lot

- [ ] `flutter analyze` ne signale rien de nouveau, lancé sur tout le projet
- [ ] `flutter test` passe intégralement
- [ ] Couverture globale ≥ 90 %, `lib/features/billing/` ≥ 90 %
- [ ] Aucun champ de saisie ne subsiste dans le parcours de passage en PRO
- [ ] Aucun appel à `POST /auth/me/upgrade-to-pro` ne subsiste dans `lib/`
- [ ] Aucun tiret cadratin dans un texte affiché ajouté par ce lot
- [ ] « Yadony » écrit avec la bonne casse, « Dony » absent de tout texte affiché
- [ ] Les cinq appelants de `/profile/upgrade-to-pro` fonctionnent toujours
- [ ] Aucun widget ni méthode sans appelant laissé dans le dépôt
- [ ] Aucune modification hors du dépôt `dony_app`

## Hors périmètre

- Appeler `POST /billing/checkout-session` ou `POST /billing/portal-session` depuis l'application : écarté, Stripe interdit ses parcours en webview et la vente est web-only par décision produit
- Exposer `companyName` et `siret` dans `UserResponse` : correction backend, autre dépôt
- Adapter le parcours par plateforme pour les règles de l'App Store : décision produit, à trancher hors du code
- Trancher l'incohérence de préfixe `/pro/` : `PRO_PORTAL_URL` l'absorbe, la décision de déploiement reste entière
- Notification push à l'entrée en impayé ou à l'approche de fin de grâce : utile, mais c'est un lot backend de notifications
