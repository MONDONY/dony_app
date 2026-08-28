# Story Lot 6 — Abonnement PRO payant, côté mobile (Flutter)

**Date :** 2026-08-28
**Status :** ✅ Complète
**Branche :** `feature/pro-abonnement`

## Résumé

Le compte PRO de Yadony passe de gratuit à un abonnement payant vendu sur un portail
web externe (`pro.yadony.com`). Ce lot est le dernier d'une série de cinq (back PR
#234, portail PR #24) et porte la partie mobile : lecture de l'état réel de
l'abonnement, ouverture du portail en navigateur externe pour vendre ou gérer, et
refonte complète de l'écran « Compte PRO » qui affichait jusqu'ici une promesse que le
backend ne tenait plus.

**Le défaut corrigé par ce lot :** `POST /auth/me/upgrade-to-pro` n'accorde plus le
statut PRO côté serveur depuis un lot backend antérieur (il ne met à jour que
`proCompanyName`/`proSiret`, jamais le statut lui-même). L'écran mobile, lui, recevait
un `200`, affichait « vous êtes maintenant PRO », rafraîchissait le profil — qui
revenait non-PRO. L'utilisateur voyait un mensonge d'interface confirmé puis
immédiatement démenti. Ce lot retire l'appel, retire la promesse, et fait dépendre
l'écran de la seule source de vérité : `GET /billing/subscription`.

## Fichiers créés

- `lib/features/billing/data/models/pro_subscription_model.dart` — `ProSubscriptionModel`, `ProSubscriptionStatus`, `ProSubscriptionSource`
- `lib/features/billing/data/billing_repository.dart` — lecture de l'abonnement + ouverture du portail en navigateur externe
- `lib/features/billing/bloc/subscription_bloc.dart` + `subscription_event.dart` + `subscription_state.dart`
- `lib/features/billing/presentation/widgets/subscription_status_banner.dart` — `SubscriptionStatusBanner`, `daysUntil()`, `subscriptionHasVisibleAlert()`
- `lib/features/billing/presentation/widgets/subscription_status_card.dart` — `SubscriptionStatusCard`
- `lib/features/billing/presentation/widgets/subscription_date_format.dart` — `formatSubscriptionDate()`, partagé par les deux widgets ci-dessus
- `lib/features/billing/presentation/widgets/subscription_banner_host.dart` — `SubscriptionBannerHost`, monté sur l'écran Profil
- Tests dédiés sous `test/core/config/`, `test/features/billing/**` (modèle, repository, BLoC, 3 widgets)

## Fichiers modifiés

- `lib/core/config/api_config.dart` — `kProPortalBaseUrl` (`PRO_PORTAL_URL`), `proPortalUpgradeUrl()`, `proPortalSubscriptionUrl()`
- `env.dev.json.example`, `env.prod.json.example` — clé `PRO_PORTAL_URL` (+ les 4 fichiers d'environnement réels gitignorés, mis à jour sur disque hors dépôt)
- `lib/core/di/injection.dart` — `BillingRepository` (lazy singleton), `SubscriptionBloc` (factory), `UpgradeToProBloc` (factory, n'était enregistré nulle part avant ce lot)
- `lib/core/services/analytics_events.dart` — 4 constantes (`proSubscriptionViewed`, `proPortalOpened`, `proPortalOpenFailed`, `proDowngradeBlocked`)
- `lib/features/profile/data/profile_repository.dart` — `upgradeToPro()` supprimée, `downgradePro()` conservée et documentée avec ses deux codes de refus RFC 7807
- `lib/features/profile/bloc/upgrade_to_pro_bloc.dart` (+ event + state) — réduit à un seul geste, le retour en compte standard
- `lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart` — refonte complète (voir plus bas), route et nom de classe conservés
- `lib/features/profile/presentation/profile_screen.dart` — montage de `SubscriptionBannerHost` en tête de `_sections`
- `CLAUDE.md` — table des events analytics complétée

## Comment ça fonctionne

### Flux utilisateur — non-abonné consultant l'écran PRO

1. Un des cinq appelants (`trip_owner_detail_screen.dart`, `create_trip_screen.dart` ×2,
   `package_request_create_screen.dart`, `profile_sections.dart`) fait
   `context.push('/profile/upgrade-to-pro')`.
2. `UpgradeToProScreen` monte `UpgradeToProBloc` et `SubscriptionBloc` (ce dernier en
   `lazy: false`, voir « Pièges »). Le `create` du `BlocProvider<SubscriptionBloc>`
   n'envoie `SubscriptionRequested` que si le compte est déjà PRO — un non-abonné ne
   génère aucun appel réseau, `GET /billing/subscription` n'aurait rien à lui montrer.
3. `_UpgradeToProView` lit `AuthBloc` et affiche `_ProPitchView` : mascotte, 4
   avantages, tarifs (`4,99 € par mois` / `47,90 € par an` / économie chiffrée en euros,
   jamais en mois offerts), un bandeau d'information, un unique bouton « S'abonner sur
   le site Yadony PRO ». **Aucun champ de saisie.**
4. Le bouton envoie `ProPortalOpenRequested(ProPortalTarget.upgrade)` au
   `SubscriptionBloc`, qui résout `proPortalUpgradeUrl()` et ouvre le navigateur
   externe de l'appareil (jamais une webview).
5. L'abonnement se souscrit entièrement hors de l'application, sur le portail web.
6. **Le retour du navigateur est ce qui referme le parcours**, sur cet écran comme sur
   le bandeau d'abonnement du Profil (`SubscriptionBannerHost`), qui ouvre lui aussi le
   portail et applique désormais la même mécanique. L'écran observe le
   cycle de vie de l'application (`WidgetsBindingObserver`). Au passage à
   `AppLifecycleState.resumed`, **et seulement si cet écran a lui-même lancé le
   navigateur** (drapeau `_hasLaunchedBrowser`), il envoie
   `AuthProfileRefreshRequested` à l'`AuthBloc` — jamais `AuthCheckRequested`, qui
   émettrait `AuthLoading` et ferait clignoter l'écran. Le profil rechargé rend
   `isProAccount` vrai, le `BlocListener<AuthBloc>` déclenche alors
   `SubscriptionRequested` et l'écran bascule sur la vue abonnée.

   **La reprise recharge aussi l'abonnement lui-même, systématiquement**, sans
   condition sur l'état du `SubscriptionBloc`. Une garde « ne recharger que si rien
   n'a jamais été chargé » ne laisserait passer que les non-abonnés : l'état initial
   n'existe que pour eux. Elle neutraliserait donc le rechargement pour les trois
   parcours qui en ont le plus besoin — l'impayé qui vient de régulariser, l'accès
   fermé qui vient de se réabonner, et la résiliation faite sur le portail — qui
   reviendraient tous sur un écran inchangé.

   Le `BlocListener<AuthBloc>` ne sert, lui, qu'à la PREMIÈRE connaissance du statut :
   il compare la PRO-ness à `_lastKnownIsPro`, mémoire de la dernière valeur réellement
   connue, et non à `previous`. Sans cette mémoire, un cycle
   PRO → `AuthLoading` → PRO se lirait comme une bascule « non PRO vers PRO » et
   redemanderait un abonnement déjà chargé.

   Rien d'autre dans l'application ne rafraîchit le profil à ce moment : les autres
   émetteurs sont le démarrage à froid, le parcours KYC, la réactivation de compte et
   la résiliation réussie, et l'observateur de cycle de vie global ne recharge que le
   compte Stripe Connect, sur un shell dont cette route ne fait pas partie. Sans ce
   rappel, l'abonné qui revient du portail retrouvait la page de vente et son unique
   bouton, qui le renvoyait au portail qu'il venait de quitter.

### Flux utilisateur — abonné consultant/gérant l'écran PRO

1. Même route, `_UpgradeToProView` affiche `_ProSubscriberView` :
   `SubscriptionStatusBanner` (si une alerte est à signaler) puis
   `SubscriptionStatusCard`, puis, selon `source`, un bouton « Gérer mon abonnement »
   ou « Revenir en compte standard », ou aucun des deux.
2. « Gérer mon abonnement » (visible seulement si `source == stripe`) envoie
   `ProPortalOpenRequested(ProPortalTarget.manage)` → ouverture de
   `proPortalSubscriptionUrl()` en navigateur externe.
3. « Revenir en compte standard » (visible seulement si `source ∈ {adminGrant,
   legacyFree}`) ouvre `DonyDialog` de confirmation puis envoie `DowngradeRequested` au
   `UpgradeToProBloc`, qui appelle `DELETE /auth/me/upgrade-to-pro`. En cas de succès :
   `AuthCheckRequested` (rafraîchit le profil), snackbar de confirmation, retour en
   arrière si possible.
4. Si le serveur refuse en `409` avec le code `active-stripe-subscription` (un
   abonnement Stripe a été souscrit sur le web pendant que l'écran était déjà ouvert —
   filet de sécurité, pas le cas nominal puisque le bouton est déjà masqué pour
   `source == stripe`), un message dédié renvoie vers le portail plutôt que le message
   générique du catalogue d'erreurs.

### Flux — bandeau sur l'écran Profil

`SubscriptionBannerHost(isProAccount: ...)` en tête de `ProfileScreen._sections`. Si le
compte n'est pas PRO : `SizedBox.shrink()` immédiat, aucun BLoC créé, aucun appel
réseau. Si PRO : crée son propre `SubscriptionBloc`, envoie `SubscriptionRequested`,
et affiche `SubscriptionStatusBanner` seulement si `subscriptionHasVisibleAlert()` est
vrai (impayé, fin de grâce, ou résiliation programmée sur un abonnement actif) — sinon
rien, espacement de section compris (porté par le composant lui-même, jamais par
l'écran hôte, pour éviter un doublon d'espacement).

### BLoC — `SubscriptionBloc`

| Event | Effet |
|---|---|
| `SubscriptionRequested` | `Loading` → `getSubscription()` → `Loaded(subscription)` ou `Error`. Émet `pro_subscription_viewed` (propriété `status`) sur succès |
| `ProPortalOpenRequested(target)` | Résout l'URL selon `target`, appelle `openExternal(uri)`. Succès → `pro_portal_opened` (`target`), aucun changement d'état. Échec → `pro_portal_open_failed` (`target`), émission transitoire de `SubscriptionPortalLaunchFailed(subscription?)` puis restauration immédiate de l'état précédent |

`ProPortalOpenRequested` utilise `exhaustMap` (rxdart) : droppable, un double appui ne
peut jamais ouvrir le navigateur deux fois ni mettre une seconde ouverture en file.

`SubscriptionPortalLaunchFailed` est un état **transitoire de signalement**, jamais un
drapeau porté par `SubscriptionLoaded` : un widget qui écoute son émission (pour un
snackbar) le voit une fois par échec, même si l'abonnement affiché n'a pas changé —
un drapeau bool sur `Loaded` aurait produit un état strictement égal (Equatable) au
précédent en cas d'échecs répétés, et rien n'aurait été notifié la seconde fois.

### BLoC — `UpgradeToProBloc`

Réduit à `DowngradeRequested` → `UpgradeToProLoading` → `DowngradeSuccess` |
`DowngradeError`. Les anciens `UpgradeToProSubmitted`/`Success`/`Error` (formulaire de
souscription) sont supprimés, avec le formulaire qu'ils pilotaient. `DowngradeError`
porte l'`AppException` telle quelle ; l'écran distingue le code
`active-stripe-subscription` (constante exportée `kActiveStripeSubscriptionCode`) pour
un message dédié, et laisse tout le reste (dont `not-pro-account`) au
`ErrorPresenter` générique.

### Écrans et widgets clés

- **`UpgradeToProScreen`** (`lib/features/profile/presentation/screens/upgrade_to_pro_screen.dart`) — `StatelessWidget` racine, monte les deux BLoCs. Route `/profile/upgrade-to-pro` et nom de classe conservés à dessein : cinq appels `context.push` en dépendent.
- **`_UpgradeToProView`** — `StatefulWidget` qui choisit entre trois vues selon l'état d'authentification :
  - `_ProAuthPendingView` : authentification pas encore résolue (démarrage à froid). N'affirme ni « abonné » ni « non-abonné ».
  - `_ProPitchView` : vue de vente, non-abonné.
  - `_ProSubscriberView` : vue d'état, abonné — elle-même à quatre branches selon l'état de `SubscriptionBloc` (`Loaded`, `Error`, `Loading`, `Initial`, ce dernier avec son propre bouton « Réessayer » pour ne jamais enfermer l'utilisateur sur un indicateur sans issue).
- **`SubscriptionStatusBanner`** — bandeau d'alerte purement présentationnel (aucun `getIt`, aucune navigation), `SizedBox.shrink()` si rien à signaler. `daysUntil(instant, {now})` calcule le nombre de jours pleins restants en normalisant les deux instants en UTC avant soustraction (jamais par champs calendaires, sensibles au fuseau).
- **`SubscriptionStatusCard`** — carte d'état : libellé de statut, rythme de facturation (absent pour un octroi admin, jamais de prix affiché — le modèle ne porte structurellement aucun champ de prix), date de renouvellement ou de fin, bouton « Gérer mon abonnement » optionnel.
- **`SubscriptionBannerHost`** — se fournit lui-même son `SubscriptionBloc`, s'auto-monte sur l'écran Profil.

### Appels API

| Appel | Usage | Notes |
|---|---|---|
| `GET /billing/subscription` | `BillingRepository.getSubscription()` | Répond **toujours 200**, `status: "NONE"` (chaîne littérale hors enum Java) quand il n'y a rien. Ne jamais traiter l'absence d'abonnement comme une erreur. `active` est calculé côté serveur et lu tel quel, jamais redérivé du `status` côté Dart |
| `DELETE /auth/me/upgrade-to-pro` | `ProfileRepository.downgradePro()` | Deux codes de refus RFC 7807 : `active-stripe-subscription` (409, traité avec un message dédié) et `not-pro-account` (409, message générique du catalogue) |
| `POST /auth/me/upgrade-to-pro` | **Supprimé de `lib/`** | N'accordait déjà plus le statut PRO côté serveur ; zéro appel restant, vérifié par recherche dans tout `lib/` |

Ouverture du portail : jamais un appel API, un `Uri.parse()` local suivi de
`UrlLauncherPlatform.instance.launchUrl(uri, LaunchOptions(mode:
PreferredLaunchMode.externalApplication))`.

## Pièges et points d'attention

1. **`POST /auth/me/upgrade-to-pro` ne faisait déjà plus rien.** Avant ce lot, l'écran
   appelait cet endpoint, recevait 200, affichait « vous êtes maintenant PRO »,
   rafraîchissait le profil — qui revenait non-PRO, puisque le backend ne mettait à
   jour que `proCompanyName`/`proSiret`, jamais le statut. C'est le défaut central que
   ce lot corrige en supprimant l'appel et en le remplaçant par un renvoi vers le
   portail web, seul endroit où l'abonnement se souscrit réellement.

2. **Le formulaire raison sociale et SIRET a été retiré, pas juste caché.**
   `UserResponse` (backend) ne renvoie ni `companyName` ni `siret` : les champs Dart
   correspondants (`UserModel.companyName`, `UserModel.siret`) sont donc **toujours
   nuls**, quoi que l'utilisateur ait saisi. Pire, `getProSiret()` côté backend n'a
   **aucun appelant** dans tout `src/main/java` — la donnée collectée n'était lue par
   personne. Le formulaire écrivait dans le vide des deux côtés : il ne pouvait ni
   relire ce qu'il avait envoyé, ni influencer quoi que ce soit côté serveur. Retiré
   plutôt que corrigé, parce que la correction (exposer les champs dans
   `UserResponse`) est un changement backend, hors périmètre de ce dépôt.

3. **La visibilité des deux boutons de la vue abonnée se décide sur `source`, pas sur
   un identifiant Stripe.** Le backend n'expose délibérément aucun identifiant Stripe
   au client. `source` (`stripe` / `adminGrant` / `legacyFree` / `unknown` / `null`)
   est donc le seul indice disponible pour savoir si un espace de gestion Stripe
   existe réellement. Règle : `stripe` → « Gérer » visible, « Revenir en compte
   standard » masqué (résilier un abonnement Stripe actif depuis l'app échouerait
   systématiquement en 409) ; `adminGrant`/`legacyFree` → l'inverse (rien à gérer sur
   un accès offert ou une grâce historique, mais le retour en compte standard est un
   geste légitime) ; `null`/`unknown` → **aucun des deux boutons**, jamais un geste
   dont la légitimité n'est pas établie.

4. **`PRO_PORTAL_URL` existe pour absorber une incohérence de préfixe non tranchée.**
   Le portail web sert ses routes sous un préfixe `/pro/` (`app.baseURL` côté PR #24),
   mais les URL de retour configurées côté backend (PR #234) n'en tiennent pas compte.
   Si le proxy inverse en production ne réécrit pas ce préfixe, `PRO_PORTAL_URL` doit
   valoir `https://pro.yadony.com/pro` et non `https://pro.yadony.com` (valeur par
   défaut Dart). La décision de déploiement reste entière ; cette variable ne fait que
   permettre de la corriger sans nouveau build.

5. **Le mode d'ouverture « navigateur externe » n'est pas cosmétique.** Pour une URL
   `https`, le mode par défaut d'`url_launcher_platform_interface` (`platformDefault`)
   **bascule en webview**. Stripe interdit explicitement ses parcours de paiement en
   webview. `BillingRepository.openExternal()` passe donc explicitement
   `PreferredLaunchMode.externalApplication` — retirer ce paramètre romprait
   silencieusement le paiement sans qu'aucune erreur ne remonte (l'URL s'ouvrirait
   quand même, juste dans le mauvais conteneur).

6. **Risque App Store à vérifier avant soumission, non tranché dans le code.** Un lien
   sortant vers un achat d'abonnement depuis une application iOS est un point de
   vigilance connu des règles App Store (contournement possible de la commission
   Apple). La décision produit de vendre uniquement sur le web est prise et assumée
   par ce lot, mais la conformité effective vis-à-vis d'Apple doit être vérifiée avant
   toute soumission — ce n'est pas un sujet que le code peut trancher seul.

7. **`unawaited()` seul n'attrape pas une Future de tracking rejetée.** Une rejection
   asynchrone échappe au `try/catch` du handler BLoC, qui a déjà rendu la main avant
   qu'elle ne s'exécute, et devient une erreur de zone non gérée. `SubscriptionBloc`
   et `UpgradeToProBloc` s'en protègent chacun avec un `_track()` privé (best-effort,
   `try/catch` local). Ce filet n'est pas généralisé à `AnalyticsService` : tous les
   autres BLoC du dépôt restent exposés au même risque si leur backend analytics
   rejette une Future.

8. **`SubscriptionBloc` est monté en `lazy: false` sur l'écran PRO, pour une raison
   précise et non testable.** Le `BlocListener<AuthBloc>` qui déclenche
   `SubscriptionRequested` à la bascule PRO lit `context.read<SubscriptionBloc>()` :
   si le BLoC n'existait pas encore à cet instant, cette lecture le construirait, son
   `create` relirait un état déjà PRO et enverrait une première demande, immédiatement
   suivie de celle du listener — deux appels réseau. `lazy: false` empêche ce cas.
   Aucun test ne peut le prouver directement (le scénario est aujourd'hui inatteignable
   tant qu'un autre mécanisme force la construction dès la première image) ; c'est un
   durcissement documenté en commentaire, pas une régression observée.

9. **Le filtre `buildWhen` de la vue distingue un état de passage d'une absence
   d'utilisateur — les deux ont été confondus une fois avant correction.** Un premier
   correctif (`current is! AuthLoading` remplacé temporairement par `_userOf(current)
   != null`) supprimait bien le clignotement de la page de vente pendant le
   rafraîchissement du profil (`AuthLoading`), mais figeait aussi l'écran sur la vue
   abonnée après une déconnexion, une suppression de compte ou un verrouillage — tous
   des états terminaux sans utilisateur qui doivent, eux, provoquer un nouveau rendu.
   La version finale filtre **deux** familles, via `_informsAboutSession` : `AuthLoading`,
   état de passage, et `AuthError`, état *surchargé* que six handlers d'`AuthBloc`
   émettent sur l'échec d'une action annexe (mise à jour de profil, envoi d'avatar,
   ajout de téléphone ou d'e-mail, suppression de compte, rafraîchissement de profil)
   alors que l'utilisateur reste pleinement authentifié. Le critère n'est donc pas
   « cet état porte-t-il un utilisateur » mais « cet état renseigne-t-il sur la
   session ». Le même critère gouverne l'écoute, pas seulement le rendu.

## Critères d'acceptation couverts

- [x] L'écran PRO n'affirme plus jamais un statut que le serveur ne peut pas garantir
- [x] Aucun formulaire de souscription dans le parcours (zéro `Form`/`TextField`/`TextFormField`)
- [x] L'abonnement se vend et se gère exclusivement sur le portail web, en navigateur externe
- [x] La vue abonnée reflète l'état réel (`GET /billing/subscription`), jamais une supposition dérivée du statut PRO local
- [x] Les boutons de gestion/résiliation n'apparaissent que quand leur issue est cohérente avec `source`
- [x] Le bandeau d'alerte d'abonnement est visible sur l'écran Profil pour tout compte PRO ayant quelque chose à signaler
- [x] `PRO_PORTAL_URL` configurable par environnement, avec repli fonctionnel par défaut
- [x] Tracking analytics complet (vue, ouverture réussie/échouée du portail, refus de résiliation), sans PII
- [x] Les cinq appelants existants de `/profile/upgrade-to-pro` continuent de fonctionner sans modification
- [x] Aucun code mort laissé (ancien formulaire, ancien BLoC de souscription, `ProfileRepository.upgradeToPro`)

## Décisions techniques

- **`active` n'est jamais redérivé côté Dart.** Le modèle le lit tel quel du JSON
  serveur : un abonnement `pastDue` peut rester `active` tant que la période de grâce
  n'est pas expirée, une règle métier qui appartient au backend.
- **`ProPortalTarget` et son mapping (`proPortalTargetFor`) vivent dans
  `subscription_event.dart`**, collés à l'énumération qu'ils produisent, plutôt que
  dupliqués dans chaque widget appelant — remonté après une revue qui avait trouvé
  deux copies privées.
- **`subscriptionHasVisibleAlert()` est une fonction de premier niveau partagée**, pas
  une méthode privée à chaque appelant : `UpgradeToProScreen` et
  `SubscriptionBannerHost` l'utilisent tous les deux pour savoir si l'espacement qui
  suit le bandeau doit exister.
- **Le montage de test de `BillingRepository.openExternal` utilise `mocktail` +
  `MockPlatformInterfaceMixin`**, plutôt que la Fake manuelle utilisée par
  `HelpCenterRepository` (seul précédent d'ouverture d'URL dans le dépôt) — nécessaire
  pour `verify`/`verifyNever`/`captureAny` sur le mode de lancement. Les deux montages
  coexistent désormais dans le dépôt, sans convention écrite pour un futur troisième.
- **Pas de bouton de fermeture sur `SubscriptionStatusBanner`.** Non demandé ;
  `DonyStatusBanner` le supporte déjà si un lot futur en a besoin.

## Dettes ouvertes (hors périmètre de ce lot, liste non exhaustive à date de rédaction)

- `UserModel.companyName` et `UserModel.siret` sont des champs morts, toujours nuls,
  jamais retirés de `UserModel` — à faire dans un lot dédié, en coordination avec le
  backend s'il décide un jour d'exposer réellement ces champs.
- **Le routeur ne redirige pas** sur une déconnexion volontaire survenant écran
  ouvert. `UpgradeToProScreen` s'assure de ne plus afficher d'actions périmées dans ce
  cas, mais ne renvoie l'utilisateur nulle part ; ce trou n'est pas spécifique à cet
  écran, il vaut pour toute l'application. La condition de reconstruction de l'écran
  (`buildWhen`) qui traite ce cas a fait l'objet de plusieurs vagues d'ajustement
  pendant ce lot (voir tâche 6) et reste un point sensible : vérifier son état réel
  dans le fichier plutôt que de se fier à ce document si un doute apparaît.
- Le message du refus `409 active-stripe-subscription` est un `DonySnackbar` direct,
  pas une entrée du catalogue d'erreurs (`ErrorCatalog`) — plus propre à long terme,
  mais toucherait un fichier partagé par toute l'application, hors périmètre.
- Le second code de refus (`not-pro-account`) retombe sur le message générique
  d'`ErrorPresenter` (« L'état actuel ne permet pas cette action. »), peu informatif ;
  acceptable car l'utilisateur ne peut atteindre ce cas que sur une désynchronisation.
- Aucune notification push à l'entrée en impayé ou à l'approche de fin de grâce —
  utile, mais c'est un lot backend de notifications, pas mobile.

## Tests

- Suite complète du dépôt (`flutter test --coverage`, tâche 7) : **7013 tests
  passés, 0 échec** (`All tests passed!`).
- Couverture mesurée depuis `coverage/lcov.info` (lignes, pas une estimation) :
  - `lib/features/billing/` : **98,11 %** (208/212 lignes) — au-dessus du seuil de
    90 % du dépôt, aucun test supplémentaire nécessaire. Les 4 lignes non couvertes
    sont un repli DI jamais exercé par les tests (`BillingRepository` :
    `launcher ?? UrlLauncherPlatform.instance`, le mock est toujours injecté) et des
    artefacts de canonicalisation de constructeurs `const` sur `subscription_event.dart`
    (surcharge abstraite `props => []` jamais atteinte car chaque sous-classe la
    redéfinit, et un constructeur `const` déjà canonicalisé) — pas des branches
    métier manquantes.
  - Global du dépôt : **81,60 %** (47432/58128 lignes), sous le seuil de 90 % —
    dette préexistante et hors périmètre de ce lot, qui ne porte que sur
    `lib/features/billing/`.
- `flutter analyze` sur tout le projet : `No issues found!` à la clôture du lot.
