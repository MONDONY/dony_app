# Edit Profile Bottom Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir l'écran `EditProfileScreen` (accessible via `/profile/edit`) en un `EditProfileBottomSheet` déclenché directement depuis la bannière de complétion dans `ProfileScreen`, en supprimant la route GoRouter correspondante.

**Architecture:** On crée `lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart` contenant toute la logique du formulaire (controllers, date picker, save). La bannière `_ProfileCompletionBanner` dans `profile_screen.dart` appelle `EditProfileBottomSheet.show(context)` au lieu de `context.push('/profile/edit')`. La route `/profile/edit` et le fichier `edit_profile_screen.dart` sont supprimés. Le BLoC `AuthBloc` reste inchangé.

**Tech Stack:** Flutter BLoC (`AuthBloc`/`AuthUpdateProfileRequested`), `DonyBottomSheet.show()`, `DonyTextField`, `DonyButton`, `DonySnackbar`, `flutter_animate`, `mocktail`, `bloc_test`

---

## Fichiers concernés

| Action | Fichier |
|--------|---------|
| **Créer** | `lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart` |
| **Créer** | `test/features/profile/presentation/widgets/edit_profile_bottom_sheet_test.dart` |
| **Modifier** | `lib/features/profile/presentation/profile_screen.dart` |
| **Modifier** | `lib/app/router.dart` |
| **Supprimer** | `lib/features/profile/presentation/edit_profile_screen.dart` |

---

## Contexte codebase

### `DonyBottomSheet.show()` (pattern existant)
```dart
// lib/core/design/widgets/dony_bottom_sheet.dart
abstract final class DonyBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    bool isDismissible = true,
    bool showHandle = true,
    bool isScrollControlled = true,
    bool isDanger = false,
  })
}
```

### `AuthBloc` events/states pertinents
```dart
// lib/features/auth/bloc/auth_event.dart
class AuthUpdateProfileRequested extends AuthEvent {
  final String? firstName;
  final String? lastName;
  final String? email;
  final DateTime? birthDate;
  final String? city;
  const AuthUpdateProfileRequested({this.firstName, this.lastName, this.email, this.birthDate, this.city});
}

// lib/features/auth/bloc/auth_state.dart
class AuthLoading extends AuthState {}
class AuthProfileUpdated extends AuthState { final UserModel user; }
class AuthError extends AuthState { final String message; }
class AuthAuthenticated extends AuthState { final UserModel user; }
```

### `_ProfileCompletionBanner` dans `profile_screen.dart` (ligne 210-212)
```dart
_ProfileCompletionBanner(
  user: user,
  onTap: () => context.push('/profile/edit'),  // ← À remplacer
  ...
)
```

### Route à supprimer dans `router.dart` (ligne ~147)
```dart
GoRoute(
  path: '/profile/edit',
  builder: (context, state) => const EditProfileScreen(),
),
```

---

## Task 1 — Créer `EditProfileBottomSheet`

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart`

- [ ] **Step 1: Créer le fichier**

```dart
// lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

abstract final class EditProfileBottomSheet {
  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      title: 'Compléter mon profil',
    child: BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: const _EditProfileContent(),
      ),
    );
  }
}

class _EditProfileContent extends StatefulWidget {
  const _EditProfileContent();

  @override
  State<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<_EditProfileContent> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  DateTime? _birthDate;
  bool _initialized = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _initFromUser(UserModel user) {
    if (_initialized) return;
    _initialized = true;
    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _emailCtrl.text = user.email ?? '';
    _cityCtrl.text = user.city ?? '';
    _birthDate = user.birthDate;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _save() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    context.read<AuthBloc>().add(AuthUpdateProfileRequested(
          firstName: firstName.isNotEmpty ? firstName : null,
          lastName: lastName.isNotEmpty ? lastName : null,
          email: email.isNotEmpty ? email : null,
          birthDate: _birthDate,
          city: city.isNotEmpty ? city : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdated) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: 'Profil mis à jour avec succès',
            type: DonySnackbarType.success,
          );
        }
        if (state is AuthError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        UserModel? user;
        if (state is AuthAuthenticated) user = state.user;
        if (state is AuthProfileUpdated) user = state.user;
        if (user != null) _initFromUser(user);

        final isLoading = state is AuthLoading;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.md,
            DonySpacing.base,
            mq.padding.bottom + 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        'Ces informations inspirent confiance aux autres membres de la communauté.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── Section Identité ────────────────────────────────
              _SectionLabel(label: 'Identité', tt: tt, cs: cs),
              const SizedBox(height: DonySpacing.md),
              DonyTextField(
                controller: _firstNameCtrl,
                label: 'Prénom',
                prefixIcon: Icons.person_outline_rounded,
                enabled: !isLoading,
              ),
              const SizedBox(height: DonySpacing.md),
              DonyTextField(
                controller: _lastNameCtrl,
                label: 'Nom de famille',
                prefixIcon: Icons.person_outline_rounded,
                enabled: !isLoading,
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── Section Contact ─────────────────────────────────
              _SectionLabel(label: 'Contact', tt: tt, cs: cs),
              const SizedBox(height: DonySpacing.md),
              DonyTextField(
                controller: _emailCtrl,
                label: 'Email (optionnel)',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: DonySpacing.xxl),

              // ── Section Infos personnelles ──────────────────────
              _SectionLabel(label: 'Informations personnelles', tt: tt, cs: cs),
              const SizedBox(height: DonySpacing.md),
              GestureDetector(
                onTap: isLoading ? null : _pickBirthDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: cs.onSurfaceVariant, size: 20),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Text(
                          _birthDate != null
                              ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                              : 'Date de naissance',
                          style: tt.bodyLarge?.copyWith(
                            color: _birthDate != null ? cs.onSurface : cs.onSurfaceVariant,
                            fontWeight: _birthDate != null ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              DonyTextField(
                controller: _cityCtrl,
                label: "Ville / lieu d'habitation",
                prefixIcon: Icons.location_city_outlined,
                enabled: !isLoading,
              ),
              const SizedBox(height: DonySpacing.xl),

              // ── Bouton sauvegarder ──────────────────────────────
              DonyButton(
                label: 'Enregistrer',
                onPressed: isLoading ? null : _save,
                isLoading: isLoading,
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.tt, required this.cs});
  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}
```

- [ ] **Step 2: Vérifier que ça compile**
```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart
```
Attendu: 0 erreurs.

---

## Task 2 — Mettre à jour `profile_screen.dart` et `router.dart`

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart:210-212`
- Modify: `lib/app/router.dart:~144-149`

- [ ] **Step 1: Modifier le call site dans `profile_screen.dart`**

Remplacer (ligne ~212) :
```dart
onTap: () => context.push('/profile/edit'),
```
par :
```dart
onTap: () => EditProfileBottomSheet.show(context),
```

Ajouter l'import en haut du fichier si absent :
```dart
import 'package:dony/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart';
```

Supprimer l'import GoRouter s'il n'est plus utilisé ailleurs dans le fichier (vérifier avec `grep 'context\.push\|context\.go\|GoRouter' profile_screen.dart`).

- [ ] **Step 2: Supprimer la route `/profile/edit` dans `router.dart`**

Supprimer le bloc :
```dart
GoRoute(
  path: '/profile/edit',
  builder: (context, state) => const EditProfileScreen(),
),
```

Supprimer aussi l'import de `EditProfileScreen` s'il devient inutilisé :
```dart
import 'package:dony/features/profile/presentation/edit_profile_screen.dart';
```

- [ ] **Step 3: Supprimer `edit_profile_screen.dart`**
```bash
rm lib/features/profile/presentation/edit_profile_screen.dart
```

- [ ] **Step 4: Vérifier compilation globale**
```bash
flutter analyze
```
Attendu: 0 erreurs nouvelles (les `info` pré-existantes sont tolérées).

---

## Task 3 — Tests du bottom sheet

**Files:**
- Create: `test/features/profile/presentation/widgets/edit_profile_bottom_sheet_test.dart`

Le bottom sheet utilise `AuthBloc` via `BlocProvider.value()`. On mocke le BLoC avec `MockAuthBloc` (mocktail + bloc_test).

- [ ] **Step 1: Écrire le fichier de test**

```dart
// test/features/profile/presentation/widgets/edit_profile_bottom_sheet_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Construit le widget sous test enveloppé dans un GoRouter + BlocProvider.
Widget _wrap(MockAuthBloc authBloc, {UserModel? user}) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => EditProfileBottomSheet.show(ctx),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ouvre le bottom sheet en tapant sur le bouton déclencheur.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const AuthUpdateProfileRequested(),
    );
    registerFallbackValue(const AuthCheckRequested());
  });

  group('EditProfileBottomSheet', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    testWidgets('affiche le formulaire avec les 4 champs', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthInitial(),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc));
      await _openSheet(tester);

      expect(find.text('Prénom'), findsOneWidget);
      expect(find.text('Nom de famille'), findsOneWidget);
      expect(find.text('Email (optionnel)'), findsOneWidget);
      expect(find.text('Date de naissance'), findsOneWidget);
      expect(find.text("Ville / lieu d'habitation"), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('pré-remplit les champs depuis AuthAuthenticated', (tester) async {
      final user = UserModel(
        id: '1',
        phoneNumber: '+33600000000',
        firstName: 'Ibrahima',
        lastName: 'Diallo',
        email: 'ibra@test.com',
        city: 'Paris',
        birthDate: DateTime(1990, 6, 15),
        roles: const ['ROLE_SENDER'],
        kycStatus: 'NOT_STARTED',
        createdAt: DateTime(2024),
      );

      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(user),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc, user: user));
      await _openSheet(tester);

      expect(find.widgetWithText(TextField, 'Ibrahima'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Diallo'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ibra@test.com'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Paris'), findsOneWidget);
      expect(find.text('15/06/1990'), findsOneWidget);
    });

    testWidgets('dispatche AuthUpdateProfileRequested au tap sur Enregistrer',
        (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthInitial(),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc));
      await _openSheet(tester);

      await tester.enterText(find.widgetWithText(TextField, '').first, 'Fatou');
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pump();

      verify(() => mockAuthBloc.add(any(that: isA<AuthUpdateProfileRequested>()))).called(1);
    });

    testWidgets('désactive le bouton pendant AuthLoading', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.value(AuthLoading()),
        initialState: AuthLoading(),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc));
      await _openSheet(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('affiche un snackbar succès et ferme le sheet sur AuthProfileUpdated',
        (tester) async {
      final user = UserModel(
        id: '1',
        phoneNumber: '+33600000000',
        firstName: 'Fatou',
        roles: const ['ROLE_SENDER'],
        kycStatus: 'NOT_STARTED',
        createdAt: DateTime(2024),
      );

      whenListen<AuthState>(
        mockAuthBloc,
        Stream.fromIterable([AuthProfileUpdated(user)]),
        initialState: AuthInitial(),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      // Le sheet est fermé → on retrouve le bouton d'ouverture
      expect(find.text('Ouvrir'), findsOneWidget);
      expect(find.text('Profil mis à jour avec succès'), findsOneWidget);
    });

    testWidgets('affiche un snackbar erreur sur AuthError', (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.fromIterable([const AuthError('Connexion impossible')]),
        initialState: AuthInitial(),
      );

      await tester.pumpWidget(_wrap(mockAuthBloc));
      await _openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('Connexion impossible'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests (ils doivent passer)**
```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/profile/presentation/widgets/edit_profile_bottom_sheet_test.dart --reporter expanded
```
Attendu: 5/5 tests verts.

- [ ] **Step 3: Vérifier qu'aucun autre test n'est cassé**
```bash
flutter test
```
Attendu: même nombre d'échecs qu'avant (les 30 pré-existants liés à la contamination GetIt sont ignorés). Aucun nouveau test rouge.

- [ ] **Step 4: Commit**
```bash
git add \
  lib/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart \
  lib/features/profile/presentation/profile_screen.dart \
  lib/app/router.dart \
  test/features/profile/presentation/widgets/edit_profile_bottom_sheet_test.dart
git commit -m "feat(profile): convert EditProfileScreen to bottom sheet

Remove /profile/edit route and edit_profile_screen.dart.
Completion banner now calls EditProfileBottomSheet.show()."
```

---

## Self-review

| Exigence | Couverte par |
|----------|-------------|
| Formulaire avec 4 champs (prénom, nom, email, date, ville) | Task 1 — `_EditProfileContent` |
| Pré-remplissage depuis `AuthAuthenticated` | Task 1 — `_initFromUser()` |
| Dispatch `AuthUpdateProfileRequested` | Task 1 — `_save()` |
| Fermeture après succès + snackbar | Task 1 — listener `AuthProfileUpdated` |
| Snackbar erreur | Task 1 — listener `AuthError` |
| Bouton désactivé pendant loading | Task 1 — `isLoading` guard |
| `useRootNavigator: true` via `DonyBottomSheet.show()` | Task 1 (DonyBottomSheet l'applique déjà) |
| Suppression route `/profile/edit` | Task 2 |
| Suppression fichier `edit_profile_screen.dart` | Task 2 |
| Tests complets (5 scénarios) | Task 3 |
| Commit | Task 3 — Step 4 |
