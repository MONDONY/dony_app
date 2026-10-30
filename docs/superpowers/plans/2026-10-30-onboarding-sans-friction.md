# Onboarding sans friction : plan d'implémentation

> **Pour les agents :** SOUS-COMPÉTENCE REQUISE : utiliser superpowers:subagent-driven-development (recommandé) ou superpowers:executing-plans pour exécuter ce plan tâche par tâche. Les étapes utilisent des cases à cocher (`- [ ]`).

**Objectif :** réduire l'inscription à code reçu → « Faisons connaissance » (facultatif) → « Par quoi voulez-vous commencer ? », reporter pays, nom, mesure d'usage, parrainage et identité au moment du besoin, et ouvrir l'accueil sur le mode choisi.

**Architecture :** les étapes obligatoires de l'ancien parcours (jauge `OnboardingStep`, écrans consentement, pays, « Votre projet », nom, parrainage) sont supprimées. Un seul écran facultatif les remplace pour le nom et le pays. Le choix de « Par quoi voulez-vous commencer ? » enregistre l'intention côté serveur (`PUT /users/me/intent`), et l'accueil en déduit son mode par défaut (`SearchMode`). Aucun stockage local ni migration backend nouveaux.

**Stack :** Flutter, flutter_bloc, GoRouter, GetIt, Hive. Fiches de l'assistant dans `dony-back` (Markdown).

**Spec :** [docs/superpowers/specs/2026-10-30-onboarding-zero-friction-design.md](../specs/2026-10-30-onboarding-zero-friction-design.md) (la section « Mise à jour du 30/10 » prime sur son tableau). Maquettes : https://claude.ai/artifact/W8DDaysZuvXQu3zX2bbJag (structure et textes ; les couleurs et polices viennent du design system, voir ci-dessous).

## Global Constraints

- **Design system Yadony obligatoire** (`import 'package:dony/core/design/design_system.dart'`, règles dans `lib/core/design/CLAUDE.md`). Aucun widget maison quand un composant existe :
  - boutons : `DonyButton` (52 px, pleine largeur, variantes `primary`/`secondary`/`ghost`), jamais un `ElevatedButton` ou un `InkWell` stylé ;
  - en-têtes : `DonyAppBar` pour un écran de réglages, `AuthFlowHeader` / `AuthFlowBackground` / `AuthIntroCard` / `AuthFlowActions` (`lib/features/auth/presentation/widgets/auth_flow_chrome.dart`) pour un écran du parcours d'inscription, plus `DonyFeedbackButton` en dernière position de tout en-tête maison ;
  - feuilles : `DonyBottomSheet.show` avec le bouton dans `stickyBottom`, jamais dans `child`, et `analyticsName:` pour une feuille qui porte une étape de parcours ;
  - champs : `DonyTextField`, sélecteur : `DonySelectBar` ; retours : `DonySnackbar`, `DonyDialog` ; mascotte : `DonyMascotteAnimated` selon la table de `lib/core/design/CLAUDE.md` ; icônes : `DonyIcon('nom')`.
  - tokens : `DonySpacing`, `DonyRadius` (cartes 16, boutons 14, champs 12, feuilles 24), couleurs via `Theme.of(context).colorScheme` (jamais `DonyColors.surface`, `textPrimary` ou `bgApp` en dur : thème sombre), textes via `Theme.of(context).textTheme`. Primaire = bleu `#0B5FFF`, accent = terracotta, polices Hanken Grotesk (titres) et Plus Jakarta Sans (corps). **La toile de maquettes** a pu être dessinée avec l'ancienne palette verte : ne jamais en copier une couleur.
- Libellé de bouton sur une ligne, 2 à 4 mots ; deux boutons côte à côte seulement s'ils font ≈ 12 caractères, sinon empilés avec le principal en haut. Vérifier en FR et EN à 360 dp (`tester.takeException()` nul, hauteur du bouton inchangée).
- Textes via ARB (`lib/l10n/app_fr.arb`, `app_en.arb`, même clé), `context.l10n`, jamais de texte en dur ; `dart run tool/check_hardcoded_strings.dart` reste à 0. Nom public **Yadony**. Pas de tiret cadratin dans l'UI, pas d'emoji, aucun dégradé.
- GoRouter uniquement, BLoC/Cubit sans `setState`, `getIt` pour l'injection, tout nouveau Cubit reçoit `AnalyticsService` ; événements déclarés dans `AnalyticsEvents`, émis dans le Cubit avec `unawaited`, sans PII. Tout code devenu sans appelant est supprimé avec ses tests.
- Branche `feature/onboarding-sans-friction` dans un worktree `dony_app-worktrees/onboarding-sans-friction`, jamais sur `main`, aucune ligne `Co-Authored-By`. Aucun build ni envoi store sans accord explicite (la fusion de l'app sur `main` déclenche TestFlight et Play interne).
- Tests : `flutter test` entier au vert avant chaque commit, couverture globale ≥ 90 %.
- PR jumelles : la PR `dony-back` (fiches de l'assistant, Task 9) est fusionnée avant la PR app, CI verte et tous les checks « pass ».

## Review Focus

- Un utilisateur qui passe tout puis publie un trajet sans pays arrive sur la sélection du pays et n'y reboucle pas (Task 7).
- Un code de parrainage refusé par le serveur (404, 409 `already-referred`, auto-parrainage) ne fait ni erreur brute ni boucle, et le code est oublié (Task 5).
- La feuille de mesure d'usage fermée par un geste ne déclenche aucun suivi, revient à l'ouverture suivante et n'apparaît jamais en session invitée (Task 6).
- `declareIntent` lent ou en échec n'empêche jamais d'atteindre l'accueil, qui s'ouvre alors sur « J'envoie un colis » (Task 3).
- Une route retirée ouverte par un lien ou une pile restaurée mène à l'accueil sans boucle (Task 8).
- Un prénom ou un nom fait d'espaces n'est jamais envoyé (Task 4).

---

### Task 0: Worktree et branche

- [ ] Depuis le dépôt principal : `git worktree add dony_app-worktrees/onboarding-sans-friction -b feature/onboarding-sans-friction origin/main`, puis copier les fichiers de secrets absents d'un worktree neuf (`env.*.json`, fichiers natifs ignorés) et lancer `flutter pub get`.
- [ ] Vérifier la base : `flutter test` doit passer avant toute modification.

---

### Task 1: L'intention n'exige plus le pays visé

**Files:**
- Modify: `lib/features/activation/bloc/intent_cubit.dart` (`IntentFormState.isValid`)
- Modify: `lib/features/activation/presentation/widgets/intent_form.dart` (section destination marquée facultative)
- Modify: `lib/l10n/app_fr.arb`, `app_en.arb` (`settingsIntentSubtitle`, libellé facultatif de la destination)
- Test: `test/features/activation/bloc/intent_cubit_test.dart`

**Interfaces:**
- Produces: `IntentFormState.isValid` vrai dès que `intent != null`. `destinationForApi` inchangé (`OTHER` ou absent donne `null`).

- [ ] **Step 1: tests qui échouent** dans `intent_cubit_test.dart` : `isValid est vrai avec une intention et sans destination` ; `submit envoie destinationCountry null quand aucune destination n'est choisie` (mock `ActivationRepository.declareIntent` appelé avec `destinationCountry: null`, `source: IntentSource.signup`) ; `submit reste inactif sans intention`.
- [ ] **Step 2:** `flutter test test/features/activation/bloc/intent_cubit_test.dart` doit échouer.
- [ ] **Step 3:** modifier `isValid` en `intent != null`. Dans `IntentForm`, la destination reste proposée mais son titre précise qu'elle est facultative (clé ARB). Sous-titre de Réglages › « Ce que je fais sur Yadony » : FR « Choisit aussi l'écran d'accueil. », EN équivalent.
- [ ] **Step 4:** relancer ce fichier et `test/features/settings` : tout au vert.
- [ ] **Step 5:** commit `feat(activation): le pays visé devient facultatif dans l'intention`.

---

### Task 2: L'accueil s'ouvre sur le mode de l'intention

**Files:**
- Modify: `lib/features/home/domain/search_mode.dart`
- Modify: `lib/features/home/presentation/home_screen.dart` (`initState`, ligne ~428 `_mode = SearchMode.trips`)
- Test: `test/features/home/domain/search_mode_test.dart` (créer), widget test dans `test/features/home/presentation/` (le fichier existant le plus proche de `HomeScreen`)

**Interfaces:**
- Produces: `SearchMode searchModeForIntent(UserIntent? intent)` : `UserIntent.traveler` donne `SearchMode.parcels` ; `sender`, `both` et `null` donnent `SearchMode.trips`.
- Consumes: `ActivationCubit` / `ActivationLoaded.status.intent` (`lib/features/activation/bloc/activation_cubit.dart`), fourni à l'échelle de l'app (`app.dart:387`).

- [ ] **Step 1: tests qui échouent** : `searchModeForIntent` pour les quatre entrées (`traveler`, `sender`, `both`, `null`) ; widget test `HomeScreen` : avec `ActivationLoaded(intent: traveler)` le segment « Je voyage » est actif, avec `ActivationLoaded(intent: both)`, `ActivationUnavailable` ou `ActivationError` c'est « J'envoie un colis » ; `un rechargement d'activation avec la même intention ne réinitialise pas un mode choisi à la main` ; `un changement d'intention applique le nouveau mode`.
- [ ] **Step 2:** lancer les deux fichiers, échec attendu.
- [ ] **Step 3:** ajouter `searchModeForIntent`. Dans `HomeScreen`, lire l'état courant de `ActivationCubit` à `initState` pour fixer `_mode`, et ajouter un `BlocListener<ActivationCubit, ActivationState>` qui, seulement quand l'intention chargée **diffère** de la précédente, appelle `_onModeChanged(searchModeForIntent(intent))`. Ne pas toucher à `ActiveRoleCubit`.
- [ ] **Step 4:** relancer, plus `test/features/home`, au vert.
- [ ] **Step 5:** commit `feat(home): mode d'accueil par défaut selon l'intention`.

---

### Task 3: « Par quoi voulez-vous commencer ? » enregistre l'intention

**Files:**
- Modify: `lib/features/auth/presentation/screens/first_steps_screen.dart`
- Modify: `lib/app/router.dart` (route `firstStepsRoute`, ajouter `BlocProvider<IntentCubit>` comme le faisait la route `intentStepRoute`)
- Modify: `lib/l10n/app_fr.arb`, `app_en.arb` (`firstStepsSend*`, `firstStepsTravel*`, `firstStepsBrowse*`)
- Test: `test/features/auth/presentation/screens/first_steps_screen_test.dart`

**Interfaces:**
- Consumes: `IntentCubit.selectIntent(UserIntent)`, `IntentCubit.submit(IntentSource.signup)` (Task 1), `AuthRepository.markOnboardingSeen()`.
- Produces: trois choix. « Envoyer un colis » : intention `sender`. « Voyager avec des colis » : intention `traveler`. « Je regarde d'abord » et « Plus tard » : aucune intention. Tous vont vers `/home`. Propriété `choice` de `first_steps_choice` : `send`, `travel`, `browse`, `later`.

- [ ] **Step 1: tests qui échouent** : `toucher Envoyer un colis déclare SENDER puis va sur /home` ; `toucher Voyager avec des colis déclare TRAVELER puis va sur /home` ; `Je regarde d'abord et Plus tard ne déclarent rien et vont sur /home` ; `une erreur de declareIntent mène quand même à /home` ; `markOnboardingSeen est appelé une fois à l'affichage` ; `le libellé le plus long tient sur une ligne à 360 dp en FR et EN`.
- [ ] **Step 2:** lancer le fichier, échec attendu.
- [ ] **Step 3:** réécrire la variante sans intention de `FirstStepsScreen` : deux `_ChoiceCard` existantes (envoyer, voyager), une ligne « Je regarde d'abord » et `DonyButton` ghost « Plus tard » en pied. Les routes `/trips/publish-intro` et `/parcels/send-intro` ne sont plus la destination. Garder la variante `FirstStepsPersonalized` (retour de vérification d'identité depuis le profil) intacte. L'appel serveur ne bloque jamais la navigation (`unawaited`, navigation sur `saved` **ou** `error`).
- [ ] **Step 4:** relancer, plus `test/features/activation`, au vert.
- [ ] **Step 5:** commit `feat(auth): premiers pas déclare l'intention et ouvre l'accueil`.

---

### Task 4: Écran facultatif « Faisons connaissance »

**Files:**
- Create: `lib/features/auth/bloc/profile_basics_cubit.dart`
- Create: `lib/features/auth/presentation/screens/profile_basics_screen.dart`
- Create: `lib/features/auth/domain/country_from_phone.dart`
- Modify: `lib/app/router.dart` (route `profileBasicsRoute = '/auth/profile-basics'`, `BlocProvider<ProfileBasicsCubit>` via `getIt`)
- Modify: `lib/core/di/injection.dart`, `lib/core/services/analytics_events.dart`, ARB FR/EN (`profileBasics*`)
- Test: `test/features/auth/bloc/profile_basics_cubit_test.dart`, `test/features/auth/domain/country_from_phone_test.dart`, `test/features/auth/presentation/screens/profile_basics_screen_test.dart`

**Interfaces:**
- Produces:
  - `String? countryFromPhone(String? e164)` : code ISO du pays d'après l'indicatif, `null` si inconnu ou vide (utiliser la table d'indicatifs de `dial_code_picker.dart` / `DialCodeCubit`).
  - `sealed class ProfileBasicsState` : `Initial`, `Saving`, `Success`, `Error`.
  - `ProfileBasicsCubit(AuthRepository, BusinessPrefsRepository, Box<dynamic> prefs, AnalyticsService)` avec `Future<void> submit({String firstName = '', String lastName = '', String? countryCode})` et `Future<void> skip()`.
  - Événements : `profileBasicsViewed`, `profileBasicsCompleted` (propriétés `has_name`, `has_country`), `profileBasicsSkipped`.
- Consumes: `AuthRepository.updateProfile(firstName:, lastName:)`, séquence pays de l'ancien `CountryOnboardingCubit.select` (`fetchPrefs`, `updatePrefs`, `HiveService.kCountryCode`, `kCurrencyCode`, `kTravelerCountryUnsupported = false`).

- [ ] **Step 1: tests qui échouent** : `countryFromPhone` (`+33…` donne `FR`, `+221…` donne `SN`, chaîne vide et inconnu donnent `null`) ; cubit : `submit avec un prénom seul écrit le nom et pas le pays` ; `des espaces seuls ne déclenchent aucun appel` ; `submit avec un pays écrit le pays dans l'ordre serveur puis Hive` ; `skip n'appelle aucun repository et ne rend jamais Error` ; `un échec réseau du nom rend Error sans toucher au pays` ; événements `completed` (`has_name`, `has_country`) et `skipped` sans PII ; écran : prénom, nom et pays visibles, pays prérempli d'après le téléphone du profil, « Continuer » toujours actif, « Passer pour l'instant » navigue vers `/first-steps` sans appel.
- [ ] **Step 2:** lancer les trois fichiers, échec attendu.
- [ ] **Step 3:** implémenter. L'écran suit le patron de `personal_info_screen.dart` (`AuthFlowBackground`, en-tête sans jauge avec `DonyBrandMark` + `DonyFeedbackButton`, `AuthIntroCard.compact`, `DonyTextField` pour prénom et nom, `DonySelectBar` pour le pays qui ouvre la liste déjà utilisée par `country_selection_screen.dart`, à extraire en widget partagé si elle est en ligne, `AuthFlowActions` avec `onSkip`). Succès et passage vont tous deux sur `firstStepsRoute` et déclenchent `AuthProfileRefreshRequested`. `profileBasicsViewed` part à l'ouverture (`addPostFrameCallback`).
- [ ] **Step 4:** relancer, plus `test/app/router_screen_names_test.dart`, au vert.
- [ ] **Step 5:** commit `feat(auth): écran facultatif Faisons connaissance (nom et pays)`.

---

### Task 5: Le code de parrainage du lien s'applique tout seul

**Files:**
- Create: `lib/features/referral/data/pending_referral_redeemer.dart`
- Modify: `lib/core/di/injection.dart`, `lib/features/auth/presentation/screens/profile_basics_screen.dart`, `lib/core/services/analytics_events.dart`, ARB FR/EN (`referralAutoApplied*`)
- Test: `test/features/referral/data/pending_referral_redeemer_test.dart`, `profile_basics_screen_test.dart`

**Interfaces:**
- Produces: `enum PendingReferralOutcome { none, applied, rejected }` et `PendingReferralRedeemer(PendingReferralCodeStore, ReferralRepository)` avec `Future<PendingReferralOutcome> apply()`. Lit `store.current`, appelle `ReferralRepository.redeemCode(code)`, **efface toujours le code** quel que soit le résultat, ne lève jamais.
- Consumes: Task 4 (appelé depuis `ProfileBasicsScreen`, qui n'apparaît qu'après une nouvelle inscription).

- [ ] **Step 1: tests qui échouent** : `aucun code donne none et n'appelle pas le serveur` ; `succès donne applied et efface le code` ; `404, 409 et erreur réseau donnent rejected, effacent le code, ne lèvent pas` ; écran : `snackbar de succès pour applied`, `aucun message pour none et rejected`, événement `referral_auto_applied` avec `outcome`.
- [ ] **Step 2:** échec attendu.
- [ ] **Step 3:** implémenter ; `ProfileBasicsScreen` appelle `apply()` une fois (`addPostFrameCallback`) et affiche un `DonySnackbar` de type `success` seulement pour `applied`. La saisie manuelle reste dans Profil › Parrainage (inchangée).
- [ ] **Step 4:** tests au vert.
- [ ] **Step 5:** commit `feat(referral): application automatique du code venu d'un lien`.

---

### Task 6: Mesure d'usage en feuille sur l'accueil

**Files:**
- Create: `lib/core/services/consent_prompt.dart`, `lib/features/auth/presentation/widgets/analytics_consent_sheet.dart`
- Modify: `lib/core/widgets/analytics_consent_gate.dart` (`_onLogin`, cas `askConsent`), `lib/app/main_shell.dart` (écoute et ouverture), `lib/core/di/injection.dart`, ARB FR/EN (`consentSheet*`)
- Test: `test/core/widgets/analytics_consent_gate_test.dart` (existant, à adapter), `test/features/auth/presentation/widgets/analytics_consent_sheet_test.dart`

**Interfaces:**
- Produces: `ConsentPrompt` (`ValueNotifier<bool>` enveloppé, singleton GetIt) avec `request()` et `clear()` ; `AnalyticsConsentSheet.show(BuildContext)` (`DonyBottomSheet.show`, `analyticsName: 'consent/analytics'`, `stickyBottom` = `DonyButton` « Accepter » au-dessus de `DonyButton` « Refuser », donc empilés). Accepter appelle `setConsent(granted: true, source: 'manual')`, refuser `granted: false`, puis `ConsentPrompt.clear()`. Fermer par geste ne répond pas.
- Consumes: `GdprHelper.resolveConsentAction` (inchangé : hors RGPD reste `autoGrantNonGdpr`).

- [ ] **Step 1: tests qui échouent** : gate : `askConsent appelle ConsentPrompt.request et ne navigue plus` ; `session anonyme ne déclenche rien` ; `hors RGPD accorde automatiquement sans feuille` ; feuille : `Accepter enregistre granted true avec source manual`, `Refuser enregistre granted false`, `fermer par geste n'enregistre rien et laisse la demande active` ; `les deux libellés tiennent sur une ligne à 360 dp en FR et EN`.
- [ ] **Step 2:** échec attendu.
- [ ] **Step 3:** implémenter ; `MainShell` ouvre la feuille une seule fois par ouverture d'app quand `ConsentPrompt` est actif et que le shell est affiché. Ne plus naviguer vers `/auth/analytics-consent`.
- [ ] **Step 4:** tests au vert.
- [ ] **Step 5:** commit `feat(analytics): consentement en feuille sur l'accueil`.

---

### Task 7: Le pays est demandé à la publication d'un trajet s'il manque

**Files:**
- Modify: `lib/app/router.dart` (garde `guardedRoutes`, ligne ~382), `lib/features/auth/presentation/screens/country_selection_screen.dart`
- Test: `test/app/router_auth_redirect_test.dart` ou le test de garde de routes le plus proche, `test/features/auth/presentation/screens/country_selection_screen_test.dart`

**Interfaces:**
- Produces: `/auth/country-selection?next=<chemin interne>`. Après choix du pays : `context.go(next ?? '/home')`. « Passer » : toujours `context.go('/home')` (jamais `next`, pour ne pas reboucler sur la garde). `next` n'est accepté que s'il commence par `/` et pas par `//` ; sinon `/home`. La garde de `/trips/create` redirige aussi quand `HiveService.kCountryCode` est vide, vers `/auth/country-selection?next=/trips/create`.

- [ ] **Step 1: tests qui échouent** : garde : `pays vide redirige vers la sélection avec next`, `pays renseigné laisse passer`, `kTravelerCountryUnsupported garde son comportement` ; écran : `choisir un pays va vers next`, `next externe ou en // retombe sur /home`, `Passer va sur /home et ne rebondit pas`, plus aucune navigation vers `intentStepRoute`.
- [ ] **Step 2:** échec attendu.
- [ ] **Step 3:** implémenter. Retirer le paramètre `progress` de `CountrySelectionScreen` et la jauge (le reste du chrome, `AuthFlowHeader`, est conservé en version sans jauge).
- [ ] **Step 4:** tests au vert.
- [ ] **Step 5:** commit `feat(auth): pays demandé à la publication d'un trajet s'il manque`.

---

### Task 8: Résolution post-inscription, retrait de l'ancien parcours

**Files:**
- Modify: `lib/features/auth/presentation/post_signup_route.dart`, `lib/features/auth/presentation/screens/otp_verification_screen.dart` (`_continueAfterSignup`), `lib/app/router.dart` (routes et `_publicRoutes`), `lib/features/kyc/presentation/kyc_return_route.dart`, `kyc_status_screen.dart`, `kyc_webview_screen.dart`, `lib/features/payments/presentation/screens/payout_onboarding_screen.dart`, `lib/features/stripe_account/presentation/widgets/identity_required_view.dart`, `lib/features/profile/presentation/widgets/profile_sections.dart`
- Delete (après vérification par `grep` qu'aucun appelant ne reste) : `onboarding_step.dart` (garder `effectiveStripeStatus`, à déplacer dans `lib/features/stripe_account/presentation/effective_stripe_status.dart`), `personal_info_screen.dart`, `personal_info_cubit.dart`, `referral_code_screen.dart`, `analytics_consent_screen.dart`, `intent_step_screen.dart`, la section GP Pro d'inscription (`gp_pro_signup_section.dart`, `GpProSignupCubit`) si plus utilisée, `DonyOnboardingGauge` si plus utilisé, et leurs tests (`onboarding_step_test.dart`, `read_onboarding_progress_test.dart`, `personal_info_*_test.dart`, `referral_code_screen_test.dart`, `analytics_consent_screen_test.dart`, `intent_step_screen_test.dart`)
- Test: `test/features/auth/presentation/post_signup_route_test.dart` (réécrire), `test/app/router_auth_redirect_test.dart`, `test/a11y/large_text_smoke_test.dart` (retirer les références supprimées), tests KYC et paiements existants adaptés

**Interfaces:**
- Produces: `String resolvePostSignupRoute(UserModel? user)` : `user?.onboardingSeenAt != null` donne `'/home'`, sinon `profileBasicsRoute`. Fonction pure, synchrone. `const kKycVerifyRoute = '/kyc/verify'` remplace `OnboardingStep.identity.route`. Les routes retirées `/auth/personal-info`, `/auth/referral-code`, `/auth/analytics-consent`, `/auth/intent` redirigent vers `/home`.
- Consumes: Task 4 (`profileBasicsRoute`).

- [ ] **Step 1: tests qui échouent** : `resolvePostSignupRoute` pour `onboardingSeenAt` nul, posé et `user` nul ; redirect : chacune des quatre routes retirées mène à `/home` sans boucle ; KYC : fermer l'écran d'identité hors parcours revient en arrière (ou `/home`), aucun écran KYC ne reçoit plus de `progress` ; paiements idem ; `OtpVerificationScreen` : après `AuthNewAccountAuthenticated`, navigation vers `profileBasicsRoute`.
- [ ] **Step 2:** échec attendu.
- [ ] **Step 3:** réécrire le résolveur, retirer jauge et branchements `routeAfter` des écrans KYC et paiements (les entrées par le profil gardent leur comportement), supprimer les fichiers listés, ajouter les redirections de routes retirées, retirer les routes de `_publicRoutes`. `flutter analyze` ne doit signaler aucun import orphelin.
- [ ] **Step 4:** `flutter analyze && flutter test` au vert.
- [ ] **Step 5:** commit `refactor(auth): inscription réduite au code, suppression de l'ancien parcours`.

---

### Task 9: Fiches de l'assistant (dépôt `dony-back`, PR jumelle, à fusionner avant l'app)

**Files:**
- Modify: `dony-back/src/main/resources/assistant/kb/{fr,en}/ecran-premiers-pas.md`, `ecran-parrainage.md`, `parrainage.md`, `ecran-profil.md` (même `id` en FR et EN)
- Vérifier : `grep -rE "analytics-consent|personal-info|referral-code|country-selection|auth/intent|first-steps" dony-back/src/main/resources/assistant/kb` et retirer toute route supprimée des en-têtes `routes`.
- Test: tests existants de la base de connaissances de l'assistant (`grep -rl KnowledgeBase dony-back/src/test`)

- [ ] **Step 1:** écrire la modification dans un worktree du back créé depuis `origin/main` (le checkout courant peut être en retard sur `main`), branche `feature/fiches-onboarding-sans-friction`.
- [ ] **Step 2:** contenu à refléter : l'inscription s'arrête au code ; nom et pays sont facultatifs et se complètent plus tard ; le code de parrainage d'un lien s'applique tout seul, sinon saisie dans Profil › Parrainage ; l'accueil s'ouvre sur « Je voyage » seulement après le choix « Voyager avec des colis », modifiable dans Réglages › « Ce que je fais sur Yadony » ; l'identité est demandée avant d'envoyer un colis ou de publier un trajet.
- [ ] **Step 3:** `./mvnw test -Dtest='*KnowledgeBase*'` au vert (un seul Maven à la fois), puis la suite complète.
- [ ] **Step 4:** commit `docs(assistant): fiches de l'inscription sans friction`, ouvrir la PR, fusionner dès la CI verte. Un déploiement du back est nécessaire pour que les fiches servent (propriétaire).

---

### Task 10: Documentation, analytics et vérification finale

**Files:**
- Modify: `CLAUDE.md` du dépôt app (table « Events actuellement implémentés »)
- Test: toute la suite

- [ ] **Step 1:** dans la table des événements : retirer `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_step_skipped`, `onboarding_completed` ; corriger `signup_completed` (émis par `OtpVerificationScreen._continueAfterSignup`, pas `PinSetupScreen`) ; ajouter `profile_basics_viewed`, `profile_basics_completed`, `profile_basics_skipped`, `referral_auto_applied` ; mettre à jour `first_steps_choice` (valeurs `send`, `travel`, `browse`, `later`) et retirer `gp_pro_application_submitted` avec `source: signup` si la section a été supprimée.
- [ ] **Step 2:** `flutter analyze` sans erreur ni avertissement, `dart run tool/check_hardcoded_strings.dart` à 0, `flutter test test/app/router_screen_names_test.dart` au vert. Vérifier deux comportements que le design suppose déjà acquis, et ajouter un test s'il n'existe pas : (a) un compte sans prénom s'affiche avec son nom d'utilisateur, jamais son téléphone ni son e-mail (`UserModel.displayName` côté app, `UserEntity.publicDisplayName` côté back) ; (b) le refus 403 `contact-kyc-required` d'une offre ouvre `KycRequiredBottomSheet` et non une erreur brute.
- [ ] **Step 3:** `flutter test --coverage` entier au vert, couverture globale ≥ 90 % (`genhtml coverage/lcov.info -o coverage/html`).
- [ ] **Step 4:** recette sur simulateur iOS (le propriétaire valide avant tout build de recette) : inscription par téléphone → code → « Faisons connaissance » passé → « Voyager avec des colis » → l'accueil s'ouvre sur « Je voyage » ; relancer l'app : toujours « Je voyage » ; Réglages › « Ce que je fais sur Yadony » → « Envoyer des colis » : l'accueil repasse sur « J'envoie un colis » ; thème sombre et 360 dp sur chacun des écrans touchés.
- [ ] **Step 5:** commit `docs(app): table des événements de l'inscription sans friction`, ouvrir la PR app citant la PR back, fusion après la PR back et une CI verte.
