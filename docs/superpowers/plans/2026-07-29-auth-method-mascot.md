# Auth Method Mascot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le papillon générique de l’écran de connexion par la mascotte Yadony accueillante.

**Architecture:** Le changement reste limité à la couche présentation de l’authentification. Un test widget dédié verrouille le type et la taille de la mascotte ainsi que l’absence de l’ancien avatar, puis `AuthMethodScreen` réutilise directement le composant du design system déjà exporté.

**Tech Stack:** Flutter, Dart, flutter_bloc, flutter_test, bloc_test, mocktail, design system Yadony.

## Global Constraints

- Le nom public de l’application est **Yadony**.
- Ne créer aucun asset et réutiliser `DonyMascotteAnimated`.
- Utiliser `DonyMascotteType.joyeux` et `DonyMascotteSize.md`.
- Ne modifier aucun texte, BLoC, route, tracking ou comportement d’authentification.
- Ne jamais utiliser `setState` ou `Navigator.push`.
- Ne jamais inclure `Co-Authored-By: Claude` dans un commit.

---

### Task 1: Remplacer le papillon par la mascotte Yadony

**Files:**
- Create: `test/features/auth/presentation/screens/auth_method_screen_test.dart`
- Modify: `lib/features/auth/presentation/screens/auth_method_screen.dart:56`

**Interfaces:**
- Consumes: `DonyMascotteAnimated({required DonyMascotteType type, DonyMascotteSize size})` exporté par `design_system.dart`.
- Produces: `AuthMethodScreen` affiche une mascotte `joyeux` en taille `md` sans `DonyHeroAvatar`.

- [ ] **Step 1: Écrire le test widget en échec**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _app(AuthBloc bloc) => MaterialApp.router(
  theme: AppTheme.light(),
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const AuthMethodScreen(),
        ),
      ),
    ],
  ),
);

void main() {
  testWidgets('affiche la mascotte Yadony joyeuse à la place du papillon',
      (tester) async {
    final bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_app(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final animated = tester.widget<DonyMascotteAnimated>(
      find.byType(DonyMascotteAnimated),
    );
    expect(animated.type, DonyMascotteType.joyeux);
    expect(animated.size, DonyMascotteSize.md);
    expect(find.byType(DonyHeroAvatar), findsNothing);
    expect(find.text('🦋'), findsNothing);

    await bloc.close();
  });
}
```

- [ ] **Step 2: Exécuter le test et vérifier l’échec attendu**

Run:

```bash
flutter test test/features/auth/presentation/screens/auth_method_screen_test.dart
```

Expected: FAIL parce qu’aucun `DonyMascotteAnimated` n’est encore rendu et que `DonyHeroAvatar` est toujours présent.

- [ ] **Step 3: Écrire l’implémentation minimale**

Dans `AuthMethodScreen`, remplacer :

```dart
Center(child: const DonyHeroAvatar(emoji: '🦋'))
    .animate()
    .fadeIn(duration: 300.ms)
    .scaleXY(begin: 0.85, curve: Curves.easeOutBack),
```

par :

```dart
const Center(
  child: DonyMascotteAnimated(
    type: DonyMascotteType.joyeux,
  ),
),
```

`DonyMascotteSize.md` est la valeur par défaut du composant ; le test vérifie
explicitement cette taille sans ajouter un argument redondant dans l’écran.

- [ ] **Step 4: Formater et vérifier le test ciblé**

Run:

```bash
dart format lib/features/auth/presentation/screens/auth_method_screen.dart test/features/auth/presentation/screens/auth_method_screen_test.dart
flutter test test/features/auth/presentation/screens/auth_method_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Vérifier l’analyse statique et les tests d’authentification concernés**

Run:

```bash
flutter analyze lib/features/auth/presentation/screens/auth_method_screen.dart test/features/auth/presentation/screens/auth_method_screen_test.dart
flutter test test/features/auth/presentation/screens/auth_method_screen_test.dart test/features/auth/presentation/screens/onboarding_screen_test.dart
git diff --check
```

Expected: analyse sans erreur, tests verts et diff sans erreur d’espacement.

- [ ] **Step 6: Committer l’implémentation**

```bash
git add lib/features/auth/presentation/screens/auth_method_screen.dart test/features/auth/presentation/screens/auth_method_screen_test.dart docs/superpowers/plans/2026-07-29-auth-method-mascot.md
git commit -m "fix(auth): use Yadony login mascot"
```
