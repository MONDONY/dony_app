# Auth Modes (Email OTP + OAuth Direct) — Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter le mode email OTP et corriger le flux OAuth (Google/Apple) pour les nouveaux utilisateurs dans l'app Flutter dony.

**Architecture:** Trois nouveaux events + states dans AuthBloc, un nouvel écran EmailAuthScreen, adaptation de OtpVerificationScreen (mode phone/email), adaptation de RoleSelectionScreen (pendingEmail post-auth), mise à jour du router GoRouter.

**Tech Stack:** Flutter/Dart · flutter_bloc · GoRouter · Dio · firebase_auth · google_sign_in · sign_in_with_apple · design system dony (DonyButton, DonyMascotteAnimated, DonyTextField)

**Spec de référence :** `docs/superpowers/specs/2026-05-19-auth-modes-email-oauth-design.md`

---

## File Map

| Fichier | Action | Rôle |
|---------|--------|------|
| `lib/features/auth/bloc/auth_event.dart` | Modify | +3 events |
| `lib/features/auth/bloc/auth_state.dart` | Modify | +3 states |
| `lib/features/auth/bloc/auth_bloc.dart` | Modify | +3 handlers, fix `_checkProfileAfterOAuth` |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | Modify | +sendEmailOtp, +verifyEmailOtp, +registerWithEmail |
| `lib/features/auth/data/repositories/auth_repository.dart` | Modify | +3 méthodes qui délèguent au datasource |
| `lib/features/auth/presentation/screens/email_auth_screen.dart` | Create | Saisie email, dispatche AuthEmailOtpSendRequested |
| `lib/features/auth/presentation/screens/otp_verification_screen.dart` | Modify | +OtpMode enum, +mode/contact params |
| `lib/features/auth/presentation/screens/role_selection_screen.dart` | Modify | +pendingEmail param, BlocListener post-auth |
| `lib/features/auth/presentation/screens/phone_auth_screen.dart` | Modify | +lien email, handle AuthOAuthNewUser |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | Modify | extra String → Map |
| `lib/app/router.dart` | Modify | +2 routes, extra Map, +public routes |
| `test/features/auth/bloc/auth_bloc_test.dart` | Modify | +tests nouveaux handlers + fix OAuth |
| `test/features/auth/presentation/screens/email_auth_screen_test.dart` | Create | widget tests |
| `test/features/auth/presentation/screens/otp_verification_screen_test.dart` | Create/Modify | +tests mode email |

---

## Task 1 — Events & States

**Files:**
- Modify: `lib/features/auth/bloc/auth_event.dart`
- Modify: `lib/features/auth/bloc/auth_state.dart`

- [ ] **Step 1 : Écrire le test vérifiant que les nouveaux types existent**

```dart
// test/features/auth/bloc/auth_events_states_test.dart
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthEmailOtpSendRequested', () {
    test('props contient email', () {
      const e = AuthEmailOtpSendRequested('a@b.com');
      expect(e.props, ['a@b.com']);
    });
  });

  group('AuthEmailOtpVerifyRequested', () {
    test('props contient email et code', () {
      const e = AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456');
      expect(e.props, ['a@b.com', '123456']);
    });
  });

  group('AuthRegisterWithEmailRequested', () {
    test('props contient email et roles', () {
      const e = AuthRegisterWithEmailRequested(email: 'a@b.com', roles: ['SENDER']);
      expect(e.props, ['a@b.com', ['SENDER']]);
    });
  });

  group('AuthEmailOtpSent', () {
    test('copyWith met à jour secondsLeft', () {
      const s = AuthEmailOtpSent('a@b.com', secondsLeft: 60);
      expect(s.copyWith(secondsLeft: 30).secondsLeft, 30);
      expect(s.copyWith(secondsLeft: 30).email, 'a@b.com');
    });
  });

  group('AuthEmailOtpVerified', () {
    test('props contient email', () {
      const s = AuthEmailOtpVerified('a@b.com');
      expect(s.props, ['a@b.com']);
    });
  });

  group('AuthOAuthNewUser', () {
    test('props contient email', () {
      const s = AuthOAuthNewUser('a@b.com');
      expect(s.props, ['a@b.com']);
    });
  });
}
```

- [ ] **Step 2 : Lancer le test — vérifier qu'il échoue**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/auth/bloc/auth_events_states_test.dart
```
Attendu : FAIL — types non définis.

- [ ] **Step 3 : Ajouter les 3 events dans `auth_event.dart`**

Ajouter à la fin du fichier (après `AuthAppleSignInRequested`, ligne 91) :

```dart
class AuthEmailOtpSendRequested extends AuthEvent {
  final String email;
  const AuthEmailOtpSendRequested(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthEmailOtpVerifyRequested extends AuthEvent {
  final String email;
  final String code;
  const AuthEmailOtpVerifyRequested({required this.email, required this.code});
  @override
  List<Object?> get props => [email, code];
}

class AuthRegisterWithEmailRequested extends AuthEvent {
  final String email;
  final List<String> roles;
  const AuthRegisterWithEmailRequested({required this.email, required this.roles});
  @override
  List<Object?> get props => [email, roles];
}
```

- [ ] **Step 4 : Ajouter les 3 states dans `auth_state.dart`**

Ajouter à la fin du fichier (après `AuthProfileUpdated`, ligne 91) :

```dart
class AuthEmailOtpSent extends AuthState {
  final String email;
  final int secondsLeft;
  const AuthEmailOtpSent(this.email, {this.secondsLeft = 60});
  AuthEmailOtpSent copyWith({int? secondsLeft}) =>
      AuthEmailOtpSent(email, secondsLeft: secondsLeft ?? this.secondsLeft);
  @override
  List<Object?> get props => [email, secondsLeft];
}

class AuthEmailOtpVerified extends AuthState {
  final String email;
  const AuthEmailOtpVerified(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthOAuthNewUser extends AuthState {
  final String email;
  const AuthOAuthNewUser(this.email);
  @override
  List<Object?> get props => [email];
}
```

- [ ] **Step 5 : Relancer le test — vérifier qu'il passe**

```bash
flutter test test/features/auth/bloc/auth_events_states_test.dart
```
Attendu : PASS (6/6).

- [ ] **Step 6 : Commit**

```bash
git add lib/features/auth/bloc/auth_event.dart \
        lib/features/auth/bloc/auth_state.dart \
        test/features/auth/bloc/auth_events_states_test.dart
git commit -m "feat(auth): add email OTP and OAuth new user events/states"
```

---

## Task 2 — AuthBloc : nouveaux handlers + fix OAuth

**Files:**
- Modify: `lib/features/auth/bloc/auth_bloc.dart`
- Modify: `test/features/auth/bloc/auth_bloc_test.dart`

- [ ] **Step 1 : Écrire les tests failing dans `auth_bloc_test.dart`**

Ouvrir `test/features/auth/bloc/auth_bloc_test.dart` et ajouter les groupes suivants (à la fin des groupes existants) :

```dart
// ─── AuthEmailOtpSendRequested ────────────────────────────────────────────────
group('AuthEmailOtpSendRequested', () {
  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthEmailOtpSent] en cas de succès',
    build: () {
      when(() => mockAuthRepository.sendEmailOtp('a@b.com'))
          .thenAnswer((_) async {});
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
    expect: () => [
      const AuthLoading(),
      isA<AuthEmailOtpSent>().having((s) => s.email, 'email', 'a@b.com'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthError] si le repository lance une exception',
    build: () {
      when(() => mockAuthRepository.sendEmailOtp(any()))
          .thenThrow(Exception('network error'));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthEmailOtpSendRequested('a@b.com')),
    expect: () => [const AuthLoading(), isA<AuthError>()],
  );
});

// ─── AuthEmailOtpVerifyRequested ─────────────────────────────────────────────
group('AuthEmailOtpVerifyRequested', () {
  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthEmailOtpVerified] en cas de succès',
    build: () {
      when(() => mockAuthRepository.verifyEmailOtp('a@b.com', '123456'))
          .thenAnswer((_) async {});
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '123456')),
    expect: () => [
      const AuthLoading(),
      isA<AuthEmailOtpVerified>().having((s) => s.email, 'email', 'a@b.com'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthError] si code invalide',
    build: () {
      when(() => mockAuthRepository.verifyEmailOtp(any(), any()))
          .thenThrow(Exception('invalid code'));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthEmailOtpVerifyRequested(email: 'a@b.com', code: '000000')),
    expect: () => [const AuthLoading(), isA<AuthError>()],
  );
});

// ─── AuthRegisterWithEmailRequested ──────────────────────────────────────────
group('AuthRegisterWithEmailRequested', () {
  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthAuthenticated] en cas de succès',
    build: () {
      when(() => mockAuthRepository.registerWithEmail(
              email: 'a@b.com', roles: ['SENDER']))
          .thenAnswer((_) async => fakeUser);
      when(() => mockLocalAuthService.clearPin()).thenAnswer((_) async {});
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const AuthRegisterWithEmailRequested(email: 'a@b.com', roles: ['SENDER']),
    ),
    expect: () => [
      const AuthLoading(),
      isA<AuthAuthenticated>(),
    ],
    verify: (_) {
      verify(() => mockLocalAuthService.clearPin()).called(1);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'émet [AuthLoading, AuthError] si register échoue',
    build: () {
      when(() => mockAuthRepository.registerWithEmail(
              email: any(named: 'email'), roles: any(named: 'roles')))
          .thenThrow(Exception('email already exists'));
      when(() => mockLocalAuthService.clearPin()).thenAnswer((_) async {});
      return buildBloc();
    },
    act: (bloc) => bloc.add(
      const AuthRegisterWithEmailRequested(email: 'a@b.com', roles: ['SENDER']),
    ),
    expect: () => [const AuthLoading(), isA<AuthError>()],
  );
});

// ─── Fix AuthGoogleSignInRequested → AuthOAuthNewUser (nouveau user) ──────────
group('AuthGoogleSignInRequested 404 → AuthOAuthNewUser', () {
  blocTest<AuthBloc, AuthState>(
    'émet AuthOAuthNewUser (pas AuthOtpVerified) quand GET /me retourne 404',
    build: () {
      final mockGoogleUser = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
      when(() => mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.accessToken).thenReturn('access');
      when(() => mockGoogleAuth.idToken).thenReturn('id');
      when(() => mockFirebaseAuth.signInWithCredential(any()))
          .thenAnswer((_) async => FakeUserCredential());
      when(() => mockFirebaseAuth.currentUser).thenReturn(MockFirebaseUser()..emailValue = 'test@gmail.com');
      when(() => mockAuthRepository.getProfile()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: 404,
          ),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
    expect: () => [
      const AuthLoading(),
      isA<AuthOAuthNewUser>().having((s) => s.email, 'email', 'test@gmail.com'),
    ],
  );
});
```

> **Note :** `MockFirebaseUser` doit avoir un champ `emailValue` pour simuler `currentUser.email`. Ajouter si nécessaire dans la section mocks du fichier de test :
> ```dart
> class MockFirebaseUser extends Mock implements User {
>   String emailValue = '';
>   @override
>   String? get email => emailValue;
> }
> ```

- [ ] **Step 2 : Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/auth/bloc/auth_bloc_test.dart
```
Attendu : erreurs de compilation (méthodes non définies dans le repository).

- [ ] **Step 3 : Ajouter les 3 handlers et corriger `_checkProfileAfterOAuth` dans `auth_bloc.dart`**

**3a — Enregistrer les handlers dans le constructeur** (après la ligne `on<AuthAppleSignInRequested>`, ligne 51) :

```dart
on<AuthEmailOtpSendRequested>(_onEmailOtpSendRequested);
on<AuthEmailOtpVerifyRequested>(_onEmailOtpVerifyRequested);
on<AuthRegisterWithEmailRequested>(_onRegisterWithEmailRequested);
```

**3b — Corriger `_checkProfileAfterOAuth`** (remplacer complètement le bloc catch DioException 404) :

```dart
Future<void> _checkProfileAfterOAuth(Emitter<AuthState> emit) async {
  try {
    final user = await _authRepository.getProfile();
    emit(AuthAuthenticated(user));
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) {
      final email = _firebaseAuth.currentUser?.email ?? '';
      emit(AuthOAuthNewUser(email));
    } else {
      emit(AuthError(unwrapDioError(e)));
    }
  } catch (e) {
    emit(AuthError(_friendlyError(e)));
  }
}
```

**3c — Ajouter les 3 nouveaux handlers** (après `_checkProfileAfterOAuth`, avant les helpers) :

```dart
// ─── Email OTP — envoi ────────────────────────────────────────────────────────

Future<void> _onEmailOtpSendRequested(
  AuthEmailOtpSendRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthLoading());
  try {
    await _authRepository.sendEmailOtp(event.email);
    emit(AuthEmailOtpSent(event.email, secondsLeft: 60));
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const AuthOtpTimerTicked());
    });
  } catch (e) {
    emit(AuthError(_friendlyError(e)));
  }
}

// ─── Email OTP — vérification ─────────────────────────────────────────────────

Future<void> _onEmailOtpVerifyRequested(
  AuthEmailOtpVerifyRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthLoading());
  try {
    await _authRepository.verifyEmailOtp(event.email, event.code);
    emit(AuthEmailOtpVerified(event.email));
  } catch (e) {
    emit(AuthError(_friendlyError(e)));
  }
}

// ─── Inscription par email (post-OAuth ou post-email OTP) ────────────────────

Future<void> _onRegisterWithEmailRequested(
  AuthRegisterWithEmailRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthLoading());
  try {
    final user = await _authRepository.registerWithEmail(
      email: event.email,
      roles: event.roles,
    );
    await _localAuthService.clearPin();
    emit(AuthAuthenticated(user));
  } catch (e) {
    emit(AuthError(_friendlyError(e)));
  }
}
```

**3d — Mettre à jour `_onOtpTimerTicked`** pour gérer `AuthEmailOtpSent` (remplacer le handler existant) :

```dart
void _onOtpTimerTicked(AuthOtpTimerTicked event, Emitter<AuthState> emit) {
  final current = state;
  if (current is AuthOtpSent && current.secondsLeft > 0) {
    emit(current.copyWith(secondsLeft: current.secondsLeft - 1));
  } else if (current is AuthEmailOtpSent && current.secondsLeft > 0) {
    emit(current.copyWith(secondsLeft: current.secondsLeft - 1));
  }
}
```

- [ ] **Step 4 : Relancer les tests**

```bash
flutter test test/features/auth/bloc/auth_bloc_test.dart
```
Attendu : erreurs de compilation sur `mockAuthRepository.sendEmailOtp` etc. (méthodes non définies). Normal — le repository sera mis à jour en Task 3. Vérifier que les tests de la Task 1 passent toujours :

```bash
flutter test test/features/auth/bloc/auth_events_states_test.dart
```
Attendu : PASS.

- [ ] **Step 5 : Commit (partiel — le BLoC compile mais les tests du BLoC échouent encore)**

```bash
git add lib/features/auth/bloc/auth_bloc.dart
git commit -m "feat(auth): add email OTP handlers and fix OAuth new user state"
```

---

## Task 3 — AuthRemoteDatasource + AuthRepository

**Files:**
- Modify: `lib/features/auth/data/datasources/auth_remote_datasource.dart`
- Modify: `lib/features/auth/data/repositories/auth_repository.dart`

- [ ] **Step 1 : Ajouter 3 méthodes dans `auth_remote_datasource.dart`**

Ajouter à la fin de la classe (après `updateProfile`, avant la `}` finale) :

```dart
Future<void> sendEmailOtp(String email) async {
  await _apiClient.dio.post<void>(
    '/auth/email-otp/send',
    data: {'email': email},
  );
}

Future<void> verifyEmailOtp(String email, String code) async {
  await _apiClient.dio.post<void>(
    '/auth/email-otp/verify',
    data: {'email': email, 'code': code},
  );
}

Future<UserModel> registerWithEmail({
  required String email,
  required List<String> roles,
}) async {
  final response = await _apiClient.dio.post<Map<String, dynamic>>(
    '/auth/register',
    data: {'email': email, 'roles': roles},
  );
  return UserModel.fromJson(response.data!);
}
```

- [ ] **Step 2 : Ajouter 3 méthodes dans `auth_repository.dart`**

Ajouter à la fin de la classe (après `updateProfile`, avant la `}` finale) :

```dart
Future<void> sendEmailOtp(String email) =>
    _datasource.sendEmailOtp(email);

Future<void> verifyEmailOtp(String email, String code) =>
    _datasource.verifyEmailOtp(email, code);

Future<UserModel> registerWithEmail({
  required String email,
  required List<String> roles,
}) =>
    _datasource.registerWithEmail(email: email, roles: roles);
```

- [ ] **Step 3 : Relancer les tests BLoC — doivent passer maintenant**

```bash
flutter test test/features/auth/bloc/auth_bloc_test.dart
```
Attendu : PASS (tous les tests, nouveaux inclus).

- [ ] **Step 4 : Commit**

```bash
git add lib/features/auth/data/datasources/auth_remote_datasource.dart \
        lib/features/auth/data/repositories/auth_repository.dart
git commit -m "feat(auth): add sendEmailOtp, verifyEmailOtp, registerWithEmail to datasource"
```

---

## Task 4 — EmailAuthScreen

**Files:**
- Create: `lib/features/auth/presentation/screens/email_auth_screen.dart`
- Create: `test/features/auth/presentation/screens/email_auth_screen_test.dart`

- [ ] **Step 1 : Écrire les tests widget failing**

```dart
// test/features/auth/presentation/screens/email_auth_screen_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/email_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _wrap(Widget child, {required AuthBloc bloc}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => BlocProvider<AuthBloc>.value(value: bloc, child: child)),
        GoRoute(path: '/auth/email-otp', builder: (_, __) => const Scaffold(body: Text('OTP Screen'))),
      ],
    ),
  );
}

void main() {
  late MockAuthBloc mockBloc;

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
  });

  testWidgets('affiche le champ email et le bouton désactivé à vide', (tester) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Envoyer le code'), findsOneWidget);
    // Bouton désactivé car champ vide
    final btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Envoyer le code'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('active le bouton quand un email valide est saisi', (tester) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Envoyer le code'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('dispatche AuthEmailOtpSendRequested sur submit', (tester) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.pump();
    await tester.tap(find.text('Envoyer le code'));

    verify(() => mockBloc.add(const AuthEmailOtpSendRequested('user@example.com'))).called(1);
  });

  testWidgets('navigue vers /auth/email-otp quand AuthEmailOtpSent émis', (tester) async {
    whenListen(
      mockBloc,
      Stream.fromIterable([const AuthLoading(), AuthEmailOtpSent('user@example.com')]),
      initialState: const AuthInitial(),
    );

    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.text('OTP Screen'), findsOneWidget);
  });

  testWidgets('affiche la mascotte confiant', (tester) async {
    await tester.pumpWidget(_wrap(const EmailAuthScreen(), bloc: mockBloc));
    await tester.pumpAndSettle();
    expect(find.byType(DonyMascotteAnimated), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/auth/presentation/screens/email_auth_screen_test.dart
```
Attendu : FAIL — `EmailAuthScreen` n'existe pas.

- [ ] **Step 3 : Créer `email_auth_screen.dart`**

```dart
// lib/features/auth/presentation/screens/email_auth_screen.dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validate);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validate() {
    final v = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    if (valid != _isValid) setState(() => _isValid = valid);
  }

  void _submit() {
    if (!_isValid) return;
    context.read<AuthBloc>().add(
          AuthEmailOtpSendRequested(_emailController.text.trim()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthEmailOtpSent) {
          context.push('/auth/email-otp', extra: {'email': state.email});
        } else if (state is AuthError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: false,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        DonySpacing.sm, DonySpacing.sm, DonySpacing.sm, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Retour',
                        onPressed: () => context.pop(),
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(DonyRadius.iconBtn),
                          ),
                          child: Icon(Icons.chevron_left_rounded,
                              size: 20, color: cs.primary),
                        ),
                      ),
                    ),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          h, DonySpacing.lg, h, DonySpacing.xl),
                      child: DonyLayout.constrained(
                        context,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: DonyMascotteAnimated(
                                type: DonyMascotteType.confiant,
                                size: DonyMascotteSize.md,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xl),
                            Text(
                              'Entre ton email',
                              style: tt.displayLarge?.copyWith(
                                color: cs.onSurface,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.sm),
                            Text(
                              'Tu recevras un code de vérification à 6 chiffres',
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xxl),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: 'Adresse email',
                                hintText: 'exemple@gmail.com',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pinned CTA
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(top: BorderSide(color: cs.outline)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        h, DonySpacing.base, h, DonySpacing.base + bottom),
                    child: DonyButton(
                      label: 'Envoyer le code',
                      onPressed: (_isValid && !isLoading) ? _submit : null,
                      isLoading: isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4 : Relancer les tests**

```bash
flutter test test/features/auth/presentation/screens/email_auth_screen_test.dart
```
Attendu : PASS (5/5).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/email_auth_screen.dart \
        test/features/auth/presentation/screens/email_auth_screen_test.dart
git commit -m "feat(auth): add EmailAuthScreen for email OTP flow"
```

---

## Task 5 — OtpVerificationScreen : mode email

**Files:**
- Modify: `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- Create: `test/features/auth/presentation/screens/otp_verification_screen_email_test.dart`

- [ ] **Step 1 : Écrire les tests failing pour le mode email**

```dart
// test/features/auth/presentation/screens/otp_verification_screen_email_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Widget _buildEmail({required AuthBloc bloc}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const OtpVerificationScreen(
              mode: OtpMode.email,
              contact: 'user@example.com',
            ),
          ),
        ),
        GoRoute(path: '/onboarding/role', builder: (_, __) => const Scaffold(body: Text('Role Screen'))),
        GoRoute(path: '/auth/local', builder: (_, __) => const Scaffold(body: Text('Local Auth'))),
      ],
    ),
  );
}

void main() {
  late MockAuthBloc mockBloc;

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(AuthEmailOtpSent('user@example.com'));
  });

  testWidgets('mode email — affiche "Vérifie ton email" et l\'adresse', (tester) async {
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump();
    expect(find.text('Vérifie ton email'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('mode email — dispatche AuthEmailOtpVerifyRequested sur vérifier', (tester) async {
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump();

    // Saisir 6 chiffres
    final fields = find.byType(TextFormField);
    for (int i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '$i');
    }
    await tester.tap(find.text('Vérifier'));

    verify(() => mockBloc.add(
          AuthEmailOtpVerifyRequested(email: 'user@example.com', code: '012345'),
        )).called(1);
  });

  testWidgets('mode email — navigue vers /onboarding/role quand AuthEmailOtpVerified', (tester) async {
    whenListen(
      mockBloc,
      Stream.fromIterable([
        const AuthLoading(),
        AuthEmailOtpVerified('user@example.com'),
      ]),
      initialState: AuthEmailOtpSent('user@example.com'),
    );
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pumpAndSettle();

    expect(find.text('Role Screen'), findsOneWidget);
  });

  testWidgets('mode email — affiche le timer du state AuthEmailOtpSent', (tester) async {
    when(() => mockBloc.state)
        .thenReturn(AuthEmailOtpSent('user@example.com', secondsLeft: 42));
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump();

    expect(find.textContaining('42'), findsOneWidget);
  });
}
```

- [ ] **Step 2 : Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/auth/presentation/screens/otp_verification_screen_email_test.dart
```
Attendu : FAIL — `OtpMode` n'existe pas, `OtpVerificationScreen` n'a pas `mode`/`contact`.

- [ ] **Step 3 : Modifier `otp_verification_screen.dart`**

**3a — Ajouter l'enum `OtpMode` avant la classe :**

```dart
enum OtpMode { phone, email }
```

**3b — Mettre à jour le constructeur et les champs :**

```dart
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    this.mode = OtpMode.phone,
    this.contact = '',
  });

  final OtpMode mode;
  final String contact;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}
```

**3c — Mettre à jour `_verify()` :**

```dart
void _verify() {
  if (_otpCode.length != 6) {
    DonySnackbar.show(context,
        message: 'Entrez le code à 6 chiffres',
        type: DonySnackbarType.error);
    return;
  }
  if (widget.mode == OtpMode.email) {
    context.read<AuthBloc>().add(AuthEmailOtpVerifyRequested(
          email: widget.contact,
          code: _otpCode,
        ));
  } else {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthOtpSent) {
      DonySnackbar.show(context,
          message: 'Session expirée, veuillez recommencer',
          type: DonySnackbarType.error);
      return;
    }
    context.read<AuthBloc>().add(AuthPhoneVerified(
          verificationId: state.verificationId,
          smsCode: _otpCode,
        ));
  }
}
```

**3d — Mettre à jour `_resend()` :**

```dart
void _resend() {
  for (final c in _controllers) c.clear();
  if (widget.mode == OtpMode.email) {
    context.read<AuthBloc>().add(AuthEmailOtpSendRequested(widget.contact));
  } else {
    final state = context.read<AuthBloc>().state;
    final phoneNumber = state is AuthOtpSent ? state.phoneNumber : '';
    context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
  }
}
```

**3e — Mettre à jour le BlocConsumer listener :**

```dart
listener: (context, state) {
  if (widget.mode == OtpMode.phone) {
    if (state is AuthOtpVerified) {
      context.read<AuthBloc>().add(const AuthRegisterRequested());
    } else if (state is AuthAuthenticated) {
      context.go('/auth/local');
    } else if (state is AuthError) {
      ErrorPresenter.show(context, state.error);
    }
  } else {
    if (state is AuthEmailOtpVerified) {
      context.go('/onboarding/role', extra: {
        'initialRole': 'SENDER',
        'pendingEmail': state.email,
      });
    } else if (state is AuthAuthenticated) {
      context.go('/auth/local');
    } else if (state is AuthError) {
      ErrorPresenter.show(context, state.error);
    }
  }
},
```

**3f — Mettre à jour les variables `secondsLeft` et `contact` dans le builder :**

Remplacer dans le `builder` :
```dart
// AVANT
final secondsLeft = state is AuthOtpSent ? state.secondsLeft : 60;

// APRÈS
final secondsLeft = state is AuthOtpSent
    ? state.secondsLeft
    : (state is AuthEmailOtpSent ? state.secondsLeft : 60);
final contact = widget.mode == OtpMode.email
    ? widget.contact
    : (state is AuthOtpSent ? state.phoneNumber : '');
```

**3g — Mettre à jour le texte de contact dans le builder :**

Remplacer le `Text.rich` qui affiche le numéro de téléphone :
```dart
Text.rich(
  TextSpan(
    style: tt.bodyLarge?.copyWith(
        color: cs.onSurfaceVariant, height: 1.5),
    children: [
      TextSpan(
        text: widget.mode == OtpMode.email
            ? 'Code envoyé à '
            : 'Code envoyé au ',
      ),
      TextSpan(
        text: contact,
        style: tt.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    ],
  ),
),
```

**3h — Mettre à jour le titre selon le mode :**

Remplacer `Text('Entrez le code', ...)` par :
```dart
Text(
  widget.mode == OtpMode.email ? 'Vérifie ton email' : 'Entrez le code',
  style: tt.displayLarge?.copyWith(
    color: cs.onSurface,
    letterSpacing: -0.8,
  ),
),
```

- [ ] **Step 4 : Relancer les tests**

```bash
flutter test test/features/auth/presentation/screens/otp_verification_screen_email_test.dart
```
Attendu : PASS (4/4).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/otp_verification_screen.dart \
        test/features/auth/presentation/screens/otp_verification_screen_email_test.dart
git commit -m "feat(auth): adapt OtpVerificationScreen for email mode"
```

---

## Task 6 — RoleSelectionScreen : mode pendingEmail

**Files:**
- Modify: `lib/features/auth/presentation/screens/role_selection_screen.dart`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter dans `test/features/auth/presentation/screens/role_selection_screen_test.dart` un groupe `pendingEmail mode` :

```dart
group('pendingEmail mode (post-auth)', () {
  testWidgets('dispatche AuthRegisterWithEmailRequested sur Continuer', (tester) async {
    final mockBloc = MockAuthBloc();
    final mockRoleCubit = MockActiveRoleCubit();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockRoleCubit.state).thenReturn(ActiveRole.sender);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: mockBloc),
                BlocProvider<ActiveRoleCubit>.value(value: mockRoleCubit),
              ],
              child: const RoleSelectionScreen(
                initialRole: 'SENDER',
                pendingEmail: 'test@gmail.com',
              ),
            ),
          ),
          GoRoute(path: '/auth/local', builder: (_, __) => const Scaffold(body: Text('Local'))),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuer'));

    verify(() => mockBloc.add(
          const AuthRegisterWithEmailRequested(
            email: 'test@gmail.com',
            roles: ['SENDER'],
          ),
        )).called(1);
    // Ne doit PAS naviguer vers /auth/phone directement
    verifyNever(() => mockBloc.add(const OnboardingCompleted()));
  });

  testWidgets('navigue vers /auth/local quand AuthAuthenticated émis', (tester) async {
    final mockBloc = MockAuthBloc();
    final mockRoleCubit = MockActiveRoleCubit();
    whenListen(
      mockBloc,
      Stream.fromIterable([const AuthLoading(), AuthAuthenticated(fakeUser)]),
      initialState: const AuthInitial(),
    );
    when(() => mockRoleCubit.state).thenReturn(ActiveRole.sender);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: mockBloc),
                BlocProvider<ActiveRoleCubit>.value(value: mockRoleCubit),
              ],
              child: const RoleSelectionScreen(
                initialRole: 'SENDER',
                pendingEmail: 'test@gmail.com',
              ),
            ),
          ),
          GoRoute(path: '/auth/local', builder: (_, __) => const Scaffold(body: Text('Local Auth'))),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Auth'), findsOneWidget);
  });
});
```

- [ ] **Step 2 : Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/auth/presentation/screens/role_selection_screen_test.dart
```
Attendu : FAIL — `RoleSelectionScreen` n'a pas de paramètre `pendingEmail`.

- [ ] **Step 3 : Modifier `role_selection_screen.dart`**

**3a — Ajouter `pendingEmail` au constructeur :**

```dart
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.initialRole,
    this.pendingEmail,
  });

  final String initialRole;
  final String? pendingEmail;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}
```

**3b — Modifier `_proceed()` :**

```dart
void _proceed() {
  if (_selectedRole == 'TRAVELER') {
    context.read<ActiveRoleCubit>().switchToTraveler();
  } else {
    context.read<ActiveRoleCubit>().switchToSender();
  }

  if (widget.pendingEmail != null) {
    // Mode post-auth (email OTP ou OAuth)
    context.read<AuthBloc>().add(AuthRegisterWithEmailRequested(
      email: widget.pendingEmail!,
      roles: [_selectedRole],
    ));
  } else {
    // Mode pré-auth (onboarding classique)
    context.read<AuthBloc>().add(const OnboardingCompleted());
    context.go('/auth/phone');
  }
}
```

**3c — Ajouter un BlocListener conditionnel dans `build()`**

Remplacer le `return Scaffold(...)` par :

```dart
final scaffold = Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  body: /* ... contenu existant inchangé ... */,
);

if (widget.pendingEmail == null) return scaffold;

return BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      context.go('/auth/local');
    } else if (state is AuthError) {
      ErrorPresenter.show(context, state.error);
    }
  },
  child: scaffold,
);
```

- [ ] **Step 4 : Relancer les tests**

```bash
flutter test test/features/auth/presentation/screens/role_selection_screen_test.dart
```
Attendu : PASS (tous les tests, nouveaux inclus).

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/role_selection_screen.dart \
        test/features/auth/presentation/screens/role_selection_screen_test.dart
git commit -m "feat(auth): RoleSelectionScreen supports pendingEmail post-auth mode"
```

---

## Task 7 — Router : nouvelles routes + extra Map

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`

- [ ] **Step 1 : Ajouter les imports dans `router.dart`**

Ajouter parmi les imports existants :

```dart
import 'package:dony/features/auth/presentation/screens/email_auth_screen.dart';
```

- [ ] **Step 2 : Mettre à jour `_publicRoutes`**

Remplacer le set existant :

```dart
const _publicRoutes = {
  '/splash',
  '/onboarding',
  '/onboarding/role',
  '/auth/phone',
  '/auth/otp',
  '/auth/email',
  '/auth/email-otp',
  '/auth/pin-setup',
  '/auth/local',
};
```

- [ ] **Step 3 : Mettre à jour le builder de `/onboarding/role`**

Remplacer :
```dart
GoRoute(
  path: '/onboarding/role',
  builder: (context, state) {
    final initialRole = state.extra as String? ?? 'SENDER';
    return RoleSelectionScreen(initialRole: initialRole);
  },
),
```

Par :
```dart
GoRoute(
  path: '/onboarding/role',
  builder: (context, state) {
    final extra = state.extra;
    String initialRole = 'SENDER';
    String? pendingEmail;

    if (extra is String) {
      // Format hérité depuis OnboardingScreen (fallback)
      initialRole = extra;
    } else if (extra is Map) {
      initialRole = (extra['initialRole'] as String?) ?? 'SENDER';
      pendingEmail = extra['pendingEmail'] as String?;
    }

    return RoleSelectionScreen(
      initialRole: initialRole,
      pendingEmail: pendingEmail,
    );
  },
),
```

- [ ] **Step 4 : Mettre à jour le builder de `/auth/otp`**

Remplacer :
```dart
GoRoute(
  path: '/auth/otp',
  builder: (context, state) => const OtpVerificationScreen(),
),
```

Par :
```dart
GoRoute(
  path: '/auth/otp',
  builder: (context, state) => const OtpVerificationScreen(mode: OtpMode.phone),
),
```

- [ ] **Step 5 : Ajouter les 2 nouvelles routes après `/auth/otp`**

```dart
GoRoute(
  path: '/auth/email',
  builder: (context, state) => const EmailAuthScreen(),
),
GoRoute(
  path: '/auth/email-otp',
  builder: (context, state) {
    final extra = state.extra as Map? ?? {};
    return OtpVerificationScreen(
      mode: OtpMode.email,
      contact: (extra['email'] as String?) ?? '',
    );
  },
),
```

- [ ] **Step 6 : Mettre à jour `OnboardingScreen._goToRole()`**

Dans `lib/features/auth/presentation/screens/onboarding_screen.dart`, remplacer :

```dart
void _goToRole(BuildContext context, String role) {
  context.go('/onboarding/role', extra: role);
}
```

Par :

```dart
void _goToRole(BuildContext context, String role) {
  context.go('/onboarding/role', extra: {'initialRole': role});
}
```

- [ ] **Step 7 : Vérifier que l'app compile**

```bash
flutter analyze
```
Attendu : pas d'erreurs.

- [ ] **Step 8 : Commit**

```bash
git add lib/app/router.dart \
        lib/features/auth/presentation/screens/onboarding_screen.dart
git commit -m "feat(auth): add /auth/email and /auth/email-otp routes, extra as Map"
```

---

## Task 8 — PhoneAuthScreen : lien email + handle AuthOAuthNewUser

**Files:**
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`
- Modify: `test/features/auth/presentation/screens/phone_auth_screen_test.dart`

- [ ] **Step 1 : Écrire les tests failing**

Ajouter dans le fichier de test existant `phone_auth_screen_test.dart` :

```dart
testWidgets('affiche le lien "Continuer avec une adresse email"', (tester) async {
  when(() => mockBloc.state).thenReturn(const AuthInitial());
  await tester.pumpWidget(_buildScreen(bloc: mockBloc));
  await tester.pump();

  expect(find.text('Continuer avec une adresse email'), findsOneWidget);
});

testWidgets('tap sur le lien email navigue vers /auth/email', (tester) async {
  when(() => mockBloc.state).thenReturn(const AuthInitial());
  await tester.pumpWidget(_buildScreen(bloc: mockBloc));
  await tester.pump();

  await tester.tap(find.text('Continuer avec une adresse email'));
  await tester.pumpAndSettle();

  expect(find.text('Email Screen'), findsOneWidget);
});

testWidgets('AuthOAuthNewUser → navigue vers /onboarding/role avec pendingEmail', (tester) async {
  whenListen(
    mockBloc,
    Stream.fromIterable([const AuthLoading(), const AuthOAuthNewUser('u@google.com')]),
    initialState: const AuthInitial(),
  );
  await tester.pumpWidget(_buildScreen(bloc: mockBloc));
  await tester.pumpAndSettle();

  expect(find.text('Role Screen'), findsOneWidget);
});
```

> Le helper `_buildScreen` doit inclure les routes `/auth/email` (→ "Email Screen") et `/onboarding/role` (→ "Role Screen") dans le GoRouter de test.

- [ ] **Step 2 : Lancer les tests — vérifier qu'ils échouent**

```bash
flutter test test/features/auth/presentation/screens/phone_auth_screen_test.dart
```
Attendu : FAIL.

- [ ] **Step 3 : Modifier `phone_auth_screen.dart`**

**3a — Ajouter `AuthOAuthNewUser` dans le BlocConsumer listener** (après le handler `AuthError`) :

```dart
} else if (state is AuthOAuthNewUser) {
  context.go('/onboarding/role', extra: {
    'initialRole': 'SENDER',
    'pendingEmail': state.email,
  });
}
```

**3b — Ajouter le lien email** dans la partie scroll du builder, entre le champ téléphone et la section "ou" :

```dart
// Ajouter juste après le champ téléphone (le TextFormField)
const SizedBox(height: DonySpacing.sm),
Center(
  child: TextButton(
    onPressed: () => context.push('/auth/email'),
    style: TextButton.styleFrom(
      foregroundColor: cs.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base, vertical: DonySpacing.sm),
    ),
    child: Text(
      'Continuer avec une adresse email',
      style: tt.bodyMedium?.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary,
      ),
    ),
  ),
),
const SizedBox(height: DonySpacing.base),
```

- [ ] **Step 4 : Relancer les tests**

```bash
flutter test test/features/auth/presentation/screens/phone_auth_screen_test.dart
```
Attendu : PASS.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/phone_auth_screen.dart \
        test/features/auth/presentation/screens/phone_auth_screen_test.dart
git commit -m "feat(auth): PhoneAuthScreen — email link and AuthOAuthNewUser navigation"
```

---

## Task 9 — Vérification finale : tests + couverture ≥ 90 %

- [ ] **Step 1 : Lancer tous les tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test --coverage
```
Attendu : 0 tests en rouge.

- [ ] **Step 2 : Générer le rapport de couverture**

```bash
genhtml coverage/lcov.info -o coverage/html
```

- [ ] **Step 3 : Vérifier les fichiers clés ≥ 90 %**

Fichiers à vérifier manuellement dans le rapport HTML :
- `lib/features/auth/bloc/auth_bloc.dart`
- `lib/features/auth/bloc/auth_event.dart`
- `lib/features/auth/bloc/auth_state.dart`
- `lib/features/auth/presentation/screens/email_auth_screen.dart`
- `lib/features/auth/presentation/screens/otp_verification_screen.dart`
- `lib/features/auth/presentation/screens/role_selection_screen.dart`
- `lib/features/auth/presentation/screens/phone_auth_screen.dart`

- [ ] **Step 4 : Si couverture < 90 % sur un fichier — ajouter les tests manquants**

Cas typiques à couvrir si manquants :
- `AuthEmailOtpSendRequested` + timer tick sur `AuthEmailOtpSent`
- `_resend()` en mode email dans OtpVerificationScreen
- BlocListener `AuthError` dans EmailAuthScreen et RoleSelectionScreen pendingEmail mode

- [ ] **Step 5 : Commit final**

```bash
git add -A
git commit -m "test(auth): achieve ≥90% coverage on email OTP and OAuth flows"
```
