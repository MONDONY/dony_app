# Centre d’aide Yadony Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire un Centre d’aide recherchable, accessible depuis le Profil, et fiabiliser le formulaire de contact par email.

**Architecture:** Un `FaqBloc` injecté par GetIt porte la recherche et les événements analytics. Le `SupportContactBloc` existant reçoit `AnalyticsService` et expose les transitions terminales du composeur mail, tandis que les écrans utilisent uniquement GoRouter et le design system Yadony.

**Tech Stack:** Flutter, Dart, flutter_bloc, GoRouter, GetIt, url_launcher, flutter_animate, PostHog via `AnalyticsService`.

## Global Constraints

- Toute copie publique utilise exactement « Yadony ».
- Aucun `setState` dans les features ; tout état fonctionnel passe par BLoC.
- Toute navigation passe par GoRouter.
- Tout nouveau BLoC reçoit `AnalyticsService`.
- Tous les appels analytics sont `unawaited()` et ne contiennent aucune PII.
- Les modifications locales hors périmètre sont préservées.

---

### Task 1: Recherche et analytics FAQ

**Files:**
- Create: `lib/features/profile/bloc/faq_bloc.dart`
- Create: `lib/features/profile/bloc/faq_event.dart`
- Create: `lib/features/profile/bloc/faq_state.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/features/profile/bloc/faq_bloc_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService.logEvent(String, properties:)`
- Produces: `FaqBloc`, `FaqState.query`, `FaqSearchChanged`,
  `FaqQuestionOpened`, `FaqContactRequested`

- [ ] **Step 1: Écrire les tests en échec**

Tester que `FaqSearchChanged('remboursement')` émet une requête normalisée et
que `FaqQuestionOpened('payments', 'refund')` appelle
`faq_question_opened` avec uniquement `category` et `question_id`.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/bloc/faq_bloc_test.dart`
Expected: FAIL car `FaqBloc` n’existe pas.

- [ ] **Step 3: Implémenter le BLoC minimal**

Créer les trois événements, l’état Equatable et les handlers. Déclarer
`faqQuestionOpened` et `faqContactRequested` dans `AnalyticsEvents`, puis
enregistrer `FaqBloc(getIt<AnalyticsService>())` dans GetIt.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/profile/bloc/faq_bloc_test.dart`
Expected: PASS.

### Task 2: Centre d’aide recherchable

**Files:**
- Modify: `lib/features/profile/presentation/screens/faq_screen.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/profile/presentation/screens/faq_screen_test.dart`

**Interfaces:**
- Consumes: `FaqBloc`, `FaqState.query`, route `/profile/help/contact`
- Produces: recherche visible, sections filtrées, état vide, CTA support

- [ ] **Step 1: Écrire les tests en échec**

Ajouter des tests qui saisissent « remboursement », vérifient la disparition
des questions non correspondantes, saisissent une requête inconnue pour voir
« Aucun résultat », puis touchent « Contacter le support » et observent la
route de test.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/presentation/screens/faq_screen_test.dart`
Expected: FAIL car le champ de recherche et le CTA n’existent pas.

- [ ] **Step 3: Implémenter l’interface minimale**

Fournir `FaqBloc` dans la route, ajouter `DonyTextField`, filtrer questions et
réponses avec une normalisation des accents, afficher l’état vide et la carte
support. Corriger les textes métier listés dans la spécification.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/profile/presentation/screens/faq_screen_test.dart`
Expected: PASS.

### Task 3: Entrée Profil

**Files:**
- Modify: `lib/features/profile/presentation/widgets/profile_sections.dart`
- Modify: `test/features/profile/presentation/profile_screen_test.dart`

**Interfaces:**
- Consumes: route `/profile/help/faq`
- Produces: ligne « FAQ & aide » dans « AIDE & RÉGLAGES »

- [ ] **Step 1: Écrire le test en échec**

Ajouter la route FAQ au routeur de test et vérifier qu’un tap sur « FAQ &
aide » affiche le stub `FAQ`.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/presentation/profile_screen_test.dart`
Expected: FAIL car la ligne n’existe pas.

- [ ] **Step 3: Ajouter la ligne**

Insérer un `DonyListTile` avec `circle-help`, le libellé « FAQ & aide » et
`context.push('/profile/help/faq')`.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/profile/presentation/profile_screen_test.dart`
Expected: PASS.

### Task 4: Workflow du composeur mail

**Files:**
- Modify: `lib/features/profile/bloc/support_contact_bloc.dart`
- Modify: `lib/features/profile/bloc/support_contact_event.dart`
- Modify: `lib/features/profile/bloc/support_contact_state.dart`
- Modify: `lib/core/di/injection.dart`
- Modify: `lib/core/services/analytics_events.dart`
- Test: `test/features/profile/bloc/support_contact_bloc_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService`
- Produces: `SupportEmailComposerOpened`, `SupportEmailComposerFailed`,
  états `success` et `error`

- [ ] **Step 1: Écrire les tests en échec**

Tester les transitions `submitting → success` et `submitting → error`, ainsi
que les événements `support_email_composer_opened` et
`support_contact_failed` sans texte libre.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/bloc/support_contact_bloc_test.dart`
Expected: FAIL car les événements terminaux n’existent pas.

- [ ] **Step 3: Implémenter les transitions**

Injecter `AnalyticsService`, ajouter les handlers terminaux et mettre à jour
l’enregistrement GetIt.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/profile/bloc/support_contact_bloc_test.dart`
Expected: PASS.

### Task 5: Formulaire support fiable

**Files:**
- Modify: `lib/features/profile/presentation/screens/support_contact_screen.dart`
- Modify: `test/features/profile/presentation/screens/support_contact_screen_test.dart`

**Interfaces:**
- Consumes: événements terminaux du `SupportContactBloc`
- Produces: libellé Mail explicite, adresse copiable, écran conservé

- [ ] **Step 1: Écrire les tests en échec**

Vérifier « Continuer dans l’app Mail », la présence sélectionnable de
`support@dony.app` et le maintien de l’écran lors d’un état success.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/profile/presentation/screens/support_contact_screen_test.dart`
Expected: FAIL sur les nouveaux libellés et le comportement de succès.

- [ ] **Step 3: Implémenter l’interface**

Émettre `SupportSubmitRequested` avant `launchUrl`, signaler réussite ou
échec au BLoC, ne plus appeler `context.pop()`, utiliser les champs Yadony et
ajouter une action de copie de l’adresse.

- [ ] **Step 4: Vérifier le passage**

Run: `flutter test test/features/profile/presentation/screens/support_contact_screen_test.dart`
Expected: PASS.

### Task 6: Documentation et vérification

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: nouveaux événements analytics
- Produces: table analytics synchronisée

- [ ] **Step 1: Documenter les événements**

Ajouter `faq_question_opened`, `faq_contact_requested`,
`support_email_composer_opened` et `support_contact_failed`, avec leurs
propriétés non sensibles.

- [ ] **Step 2: Formater**

Run: `dart format lib/features/profile lib/core/services/analytics_events.dart lib/core/di/injection.dart lib/app/router.dart test/features/profile`
Expected: exit 0.

- [ ] **Step 3: Exécuter les tests ciblés**

Run: `flutter test test/features/profile/bloc/faq_bloc_test.dart test/features/profile/bloc/support_contact_bloc_test.dart test/features/profile/presentation/screens/faq_screen_test.dart test/features/profile/presentation/screens/support_contact_screen_test.dart test/features/profile/presentation/profile_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Analyser**

Run: `flutter analyze lib/features/profile lib/app/router.dart lib/core/di/injection.dart lib/core/services/analytics_events.dart`
Expected: aucune erreur.
