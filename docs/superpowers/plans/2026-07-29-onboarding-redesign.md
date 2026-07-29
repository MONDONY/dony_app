# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer l’onboarding scrollable en parcours horizontal de trois pages conforme au spec validé, sans changer la destination finale `/auth/method`.

**Architecture:** `OnboardingScreen` devient un `StatefulWidget` qui possède un `PageController` et l’index courant. Un `PageView` standard contient trois pages privées, tandis qu’un footer piloté par l’index réutilise `DonyStepIndicator` et `DonyButton`. `_FeatureCard` reste locale et inchangée dans son contenu.

**Tech Stack:** Flutter, Material 3, GoRouter, design system dony, flutter_test.

## Global Constraints

- Aucun `setState` dans la feature : l’index de page est exposé par un `ValueNotifier<int>`.
- Navigation finale strictement inchangée : `context.go('/auth/method')`.
- Swipe horizontal libre dans les deux sens.
- Aucun nouvel asset ni statistique chiffrée.
- `DonyStepIndicator`, `DonyButton`, `DonyLayout`, `DonySpacing`, `DonyRadius`, `DonyShadow` et les presets de mascotte existants doivent être réutilisés.
- Les trois cartes avantages gardent exactement leur contenu actuel.
- Ne pas modifier ni inclure les changements locaux sans rapport.

---

### Task 1: Contrats widget du parcours trois pages

**Files:**
- Modify: `test/features/auth/presentation/screens/onboarding_screen_test.dart`
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`

**Interfaces:**
- Consumes: `DonyStepIndicator(total: 3, current: index)`, `PageController.nextPage`, `GoRouter`.
- Produces: un onboarding dont les pages affichent successivement l’accroche, les avantages et la confiance.

- [ ] **Step 1: Écrire les tests en échec**

Ajouter des tests widget qui vérifient :

```dart
expect(find.text('Suivant'), findsOneWidget);
expect(find.text('Passer'), findsOneWidget);
expect(tester.widget<DonyStepIndicator>(find.byType(DonyStepIndicator)).current, 0);
```

Puis faire progresser le `PageView` par tap et swipe pour contrôler les types de mascotte `bienvenue`, `securise`, `confiant`, la présence groupée de `Vérifié` / `Tracé` / `Garanti`, l’index `0 → 1 → 2`, le retour swipe `2 → 1`, et l’absence de `Passer` en page 3.

- [ ] **Step 2: Vérifier l’échec**

Run: `flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart`

Expected: FAIL parce que l’écran actuel n’a ni `PageView`, ni `DonyStepIndicator`, ni CTA `Suivant`/`Passer`.

- [ ] **Step 3: Implémenter le minimum**

Convertir `OnboardingScreen` en `StatefulWidget`, créer et disposer :

```dart
final PageController _pageController = PageController();
final ValueNotifier<int> _currentPage = ValueNotifier(0);
```

Construire un `PageView` à trois enfants, mettre `_currentPage.value` à jour dans `onPageChanged`, et centraliser la navigation finale dans :

```dart
void _proceed() => context.go('/auth/method');
```

Le bouton `Passer` appelle `_proceed`; les deux premiers CTA appellent `nextPage`; le dernier appelle `_proceed`.

- [ ] **Step 4: Vérifier le vert**

Run: `flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart`

Expected: PASS.

### Task 2: Mise en page responsive et régression finale

**Files:**
- Modify: `test/features/auth/presentation/screens/onboarding_screen_test.dart`
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`

**Interfaces:**
- Consumes: les tokens et widgets du design system dony.
- Produces: trois pages sans scroll interne, mascottes centrées et dimensionnées selon l’espace, footer CGU uniquement sur la dernière page.

- [ ] **Step 1: Ajouter les tests de destination et petit écran**

Vérifier que `Passer` en P1 et P2 et `Commencer` en P3 affichent tous `Auth Method`, sans dispatcher `OnboardingCompleted`. Pomper aussi l’écran avec une taille mobile compacte et vérifier l’absence d’exception de layout.

- [ ] **Step 2: Vérifier l’échec pertinent**

Run: `flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart`

Expected: FAIL tant que les chemins finaux et la mise en page compacte ne sont pas tous couverts.

- [ ] **Step 3: Finaliser le layout**

Utiliser `LayoutBuilder` pour borner les mascottes (~35 % de hauteur sur P1, tailles réduites sur P2/P3), garder P2 sans `SingleChildScrollView`, conserver le footer CGU à l’identique sur P3 et appliquer les animations d’entrée existantes sans dépasser 500 ms.

- [ ] **Step 4: Vérifier et formater**

Run: `dart format lib/features/auth/presentation/screens/onboarding_screen.dart test/features/auth/presentation/screens/onboarding_screen_test.dart`

Run: `flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Vérification complète**

Run: `flutter analyze && flutter test --coverage`

Expected: analyse sans erreur, suite complète verte et couverture globale ≥ 90 %.
