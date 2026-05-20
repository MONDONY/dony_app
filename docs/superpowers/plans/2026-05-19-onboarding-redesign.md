# Onboarding Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter l'écran de sélection de rôle avant l'auth, et refaire l'écran auth avec mascotte + Google/Apple sign-in (Design 2).

**Architecture:** Nouveau `RoleSelectionScreen` inséré entre `OnboardingScreen` et `PhoneAuthScreen`. `AuthBloc` reçoit deux nouveaux events (`AuthGoogleSignInRequested`, `AuthAppleSignInRequested`) qui réutilisent la logique `_onPhoneVerified`. Le choix de rôle écrit directement dans `ActiveRoleCubit` (via `switchToSender`/`switchToTraveler`) avant navigation vers l'auth.

**Tech Stack:** Flutter · GoRouter · BLoC · `google_sign_in ^6.2.1` · `sign_in_with_apple ^6.1.2` · Firebase Auth · Hive · mocktail · bloc_test

---

## Fichiers impactés

| Action | Fichier |
|--------|---------|
| **CRÉER** | `lib/features/auth/presentation/screens/role_selection_screen.dart` |
| **CRÉER** | `test/features/auth/presentation/screens/role_selection_screen_test.dart` |
| **MODIFIER** | `pubspec.yaml` |
| **MODIFIER** | `lib/features/auth/bloc/auth_event.dart` |
| **MODIFIER** | `lib/features/auth/bloc/auth_bloc.dart` |
| **MODIFIER** | `lib/features/auth/presentation/screens/onboarding_screen.dart` |
| **MODIFIER** | `lib/features/auth/presentation/screens/phone_auth_screen.dart` |
| **MODIFIER** | `lib/app/router.dart` |
| **MODIFIER** | `test/features/auth/bloc/auth_bloc_test.dart` |
| **MODIFIER** | `test/features/auth/presentation/screens/onboarding_screen_test.dart` |

> **Note :** `otp_verification_screen.dart` a déjà `DonyMascotteAnimated(type: confiant, size: md)` à la ligne 121 — aucune modification nécessaire.

---

## Task 1 : Dépendances

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1 : Ajouter les packages dans pubspec.yaml**

Ouvrir `pubspec.yaml` et ajouter sous `dependencies:` (garder l'ordre alphabétique) :

```yaml
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.2
```

- [ ] **Step 2 : Télécharger les packages**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter pub get
```

Résultat attendu : `Resolving dependencies... Got dependencies!`

- [ ] **Step 3 : Vérifier qu'aucune erreur d'analyse n'est introduite**

```bash
flutter analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Step 4 : Commit**

```bash
git checkout -b feat/onboarding-redesign
git add pubspec.yaml pubspec.lock
git commit -m "feat(auth): add google_sign_in and sign_in_with_apple dependencies"
```

---

## Task 2 : Events Google/Apple + handlers AuthBloc (TDD)

**Files:**
- Modify: `lib/features/auth/bloc/auth_event.dart`
- Modify: `lib/features/auth/bloc/auth_bloc.dart`
- Modify: `test/features/auth/bloc/auth_bloc_test.dart`

- [ ] **Step 1 : Écrire les tests en échec**

Ouvrir `test/features/auth/bloc/auth_bloc_test.dart` et ajouter à la fin du fichier (avant la dernière accolade fermante de `main()`) :

```dart
  // ─── AuthGoogleSignInRequested ───────────────────────────────────────────────

  group('AuthGoogleSignInRequested', () {
    late MockGoogleSignIn mockGoogleSignIn;
    late MockGoogleSignInAccount mockGoogleAccount;
    late MockGoogleSignInAuthentication mockGoogleAuth;

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();
      mockGoogleAccount = MockGoogleSignInAccount();
      mockGoogleAuth = MockGoogleSignInAuthentication();

      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockGoogleAccount);
      when(() => mockGoogleAccount.authentication)
          .thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.accessToken).thenReturn('access-token');
      when(() => mockGoogleAuth.idToken).thenReturn('id-token');
    });

    AuthBloc buildGoogleBloc() => AuthBloc(
          mockRepo,
          mockLocalAuth,
          firebaseAuth: mockFirebaseAuth,
          googleSignIn: mockGoogleSignIn,
        );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] quand compte existant',
      build: buildGoogleBloc,
      setUp: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, OtpVerified] quand nouveau compte (404)',
      build: buildGoogleBloc,
      setUp: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: ''),
            ),
          ),
        );
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [
        const AuthLoading(),
        isA<AuthOtpVerified>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Initial] quand utilisateur annule Google sign-in',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
      ),
      setUp: () {
        when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);
      },
      act: (b) => b.add(const AuthGoogleSignInRequested()),
      expect: () => [const AuthLoading(), const AuthInitial()],
    );
  });

  // ─── AuthAppleSignInRequested ────────────────────────────────────────────────

  group('AuthAppleSignInRequested', () {
    blocTest<AuthBloc, AuthState>(
      'émet [Loading, Authenticated] quand compte existant',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => FakeAppleCredential(),
      ),
      setUp: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenAnswer((_) async => testUser);
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'émet [Loading, OtpVerified] quand nouveau compte (404)',
      build: () => AuthBloc(
        mockRepo,
        mockLocalAuth,
        firebaseAuth: mockFirebaseAuth,
        appleSignIn: (_) async => FakeAppleCredential(),
      ),
      setUp: () {
        when(() => mockFirebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => MockUserCredential());
        when(() => mockRepo.getProfile()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: ''),
            ),
          ),
        );
      },
      act: (b) => b.add(const AuthAppleSignInRequested()),
      expect: () => [const AuthLoading(), isA<AuthOtpVerified>()],
    );
  });
```

Ajouter les mocks et fakes manquants en haut du fichier de test (après les classes Mock existantes) :

```dart
// Google mocks
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

// Apple fake
class FakeAppleCredential extends Fake implements AuthorizationCredentialAppleID {
  @override
  String? get identityToken => 'fake-id-token';
  @override
  String get authorizationCode => 'fake-auth-code';
  @override
  String? get givenName => null;
  @override
  String? get familyName => null;
  @override
  String? get email => null;
  @override
  String get userIdentifier => 'fake-user-id';
  @override
  String? get state => null;
}
```

Ajouter les imports nécessaires en haut du fichier de test :

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
```

- [ ] **Step 2 : Vérifier que les tests échouent (symboles non définis)**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/auth/bloc/auth_bloc_test.dart 2>&1 | tail -20
```

Résultat attendu : erreurs de compilation (`AuthGoogleSignInRequested` non défini, etc.)

- [ ] **Step 3 : Ajouter les deux events dans auth_event.dart**

Ouvrir `lib/features/auth/bloc/auth_event.dart` et ajouter à la fin du fichier :

```dart
class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

class AuthAppleSignInRequested extends AuthEvent {
  const AuthAppleSignInRequested();
}
```

- [ ] **Step 4 : Ajouter les handlers dans auth_bloc.dart**

**4a — Imports** : ajouter en haut de `lib/features/auth/bloc/auth_bloc.dart` :

```dart
import 'package:firebase_auth/firebase_auth.dart' show OAuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
```

**4b — Typedef** : ajouter juste avant la classe `AuthBloc` :

```dart
typedef AppleSignInCallback = Future<AuthorizationCredentialAppleID> Function(
  List<AppleIDAuthorizationScopes> scopes,
);
```

**4c — Champ et constructeur** : modifier le constructeur de `AuthBloc` :

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final LocalAuthService _localAuthService;
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final AppleSignInCallback _appleSignIn;

  String? _pendingPhoneNumber;
  Timer? _otpTimer;

  AuthBloc(
    this._authRepository,
    this._localAuthService, {
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AppleSignInCallback? appleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _appleSignIn = appleSignIn ?? SignInWithApple.getAppleIDCredential,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthPhoneVerified>(_onPhoneVerified);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);
    on<OnboardingCompleted>(_onOnboardingCompleted);
    on<AuthDialCodeChanged>(_onDialCodeChanged);
    on<AuthOtpTimerTicked>(_onOtpTimerTicked);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);  // NEW
    on<AuthAppleSignInRequested>(_onAppleSignInRequested);    // NEW
  }
```

**4d — Handler Google** : ajouter après `_onOtpTimerTicked` :

```dart
  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Utilisateur a annulé
        emit(const AuthInitial());
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
      _pendingPhoneNumber = _firebaseAuth.currentUser?.email ?? '';
      await _checkProfileAfterOAuth(emit);
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  Future<void> _onAppleSignInRequested(
    AuthAppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final appleCredential = await _appleSignIn([
        AppleIDAuthorizationScopes.email,
      ]);
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await _firebaseAuth.signInWithCredential(oauthCredential);
      _pendingPhoneNumber = _firebaseAuth.currentUser?.email ?? '';
      await _checkProfileAfterOAuth(emit);
    } catch (e) {
      emit(AuthError(_friendlyError(e)));
    }
  }

  // Logique partagée après Firebase OAuth (Google ou Apple)
  Future<void> _checkProfileAfterOAuth(Emitter<AuthState> emit) async {
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
      } else {
        emit(AuthError(unwrapDioError(e)));
      }
    } catch (_) {
      emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
    }
  }
```

- [ ] **Step 5 : Vérifier que les tests passent**

```bash
flutter test test/features/auth/bloc/auth_bloc_test.dart --reporter=expanded 2>&1 | tail -30
```

Résultat attendu : tous les tests `PASS`.

- [ ] **Step 6 : Commit**

```bash
git add lib/features/auth/bloc/auth_event.dart \
        lib/features/auth/bloc/auth_bloc.dart \
        test/features/auth/bloc/auth_bloc_test.dart
git commit -m "feat(auth): add Google and Apple sign-in to AuthBloc"
```

---

## Task 3 : RoleSelectionScreen (TDD)

**Files:**
- Create: `lib/features/auth/presentation/screens/role_selection_screen.dart`
- Create: `test/features/auth/presentation/screens/role_selection_screen_test.dart`

- [ ] **Step 1 : Écrire les tests en échec**

Créer `test/features/auth/presentation/screens/role_selection_screen_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockHiveService extends Mock implements HiveService {}

GoRouter _buildRouter({
  required AuthBloc authBloc,
  required ActiveRoleCubit roleCubit,
  required String initialRole,
}) =>
    GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<ActiveRoleCubit>.value(value: roleCubit),
          ],
          child: RoleSelectionScreen(initialRole: initialRole),
        ),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const Scaffold(body: Text('Phone Auth')),
      ),
    ]);

Future<void> _pump(
  WidgetTester tester, {
  required AuthBloc authBloc,
  required ActiveRoleCubit roleCubit,
  String initialRole = 'SENDER',
}) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: _buildRouter(
      authBloc: authBloc,
      roleCubit: roleCubit,
      initialRole: initialRole,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late MockAuthBloc mockAuthBloc;
  late ActiveRoleCubit roleCubit;
  late MockHiveService mockHiveService;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    mockHiveService = MockHiveService();
    // Simuler une Hive box vide pour ActiveRoleCubit
    final fakeBox = <dynamic, dynamic>{};
    when(() => mockHiveService.userPrefs).thenReturn(
      // On retourne un mock de Box<dynamic>
      // mais ActiveRoleCubit._load() appelle .get('active_role')
      // Utiliser FakeBox en-dessous
      _FakeBox(fakeBox),
    );
    roleCubit = ActiveRoleCubit(hiveService: mockHiveService);

    registerFallbackValue(const OnboardingCompleted());
    registerFallbackValue(const AuthInitial());
  });

  tearDown(() => roleCubit.close());

  group('RoleSelectionScreen — affichage initial', () {
    testWidgets('affiche mascotte tenantColis quand initialRole = SENDER', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      // La mascotte tenantColis doit être présente
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.tenantColis),
        findsOneWidget,
      );
    });

    testWidgets('affiche mascotte enCourse quand initialRole = TRAVELER', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'TRAVELER');
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.enCourse),
        findsOneWidget,
      );
    });

    testWidgets('carte Expéditeur active quand initialRole = SENDER', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      expect(find.text('Expéditeur'), findsOneWidget);
      expect(find.text('Voyageur'), findsOneWidget);
    });
  });

  group('RoleSelectionScreen — interaction', () {
    testWidgets('clic Voyageur → mascotte change en enCourse', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Voyageur'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byWidgetPredicate((w) =>
            w is DonyMascotteAnimated && w.type == DonyMascotteType.enCourse),
        findsOneWidget,
      );
    });

    testWidgets('clic Continuer navigue vers /auth/phone', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Phone Auth'), findsOneWidget);
    });

    testWidgets('clic Voyageur + Continuer appelle switchToTraveler', (tester) async {
      await _pump(tester, authBloc: mockAuthBloc, roleCubit: roleCubit, initialRole: 'SENDER');
      await tester.tap(find.text('Voyageur'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(roleCubit.state, ActiveRole.traveler);
    });
  });
}

// Helper: FakeBox pour HiveService mock
class _FakeBox implements Box<dynamic> {
  _FakeBox(this._data);
  final Map<dynamic, dynamic> _data;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

- [ ] **Step 2 : Vérifier l'échec des tests**

```bash
flutter test test/features/auth/presentation/screens/role_selection_screen_test.dart 2>&1 | tail -10
```

Résultat attendu : erreur de compilation (`RoleSelectionScreen` non défini).

- [ ] **Step 3 : Créer RoleSelectionScreen**

Créer `lib/features/auth/presentation/screens/role_selection_screen.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.initialRole});
  final String initialRole; // 'SENDER' | 'TRAVELER'

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  void _proceed() {
    if (_selectedRole == 'TRAVELER') {
      context.read<ActiveRoleCubit>().switchToTraveler();
    } else {
      context.read<ActiveRoleCubit>().switchToSender();
    }
    context.read<AuthBloc>().add(const OnboardingCompleted());
    context.go('/auth/phone');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final mascotType = _selectedRole == 'TRAVELER'
        ? DonyMascotteType.enCourse
        : DonyMascotteType.tenantColis;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DonyLayout.constrained(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: animation, child: child),
                          ),
                          child: DonyMascotteAnimated(
                            key: ValueKey(mascotType),
                            type: mascotType,
                            size: DonyMascotteSize.md,
                          ),
                        ),
                      ),
                      const SizedBox(height: DonySpacing.lg),
                      Text(
                        'Comment tu utilises dony ?',
                        style: tt.headlineLarge?.copyWith(color: cs.onSurface),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        'Ton profil principal — tu peux changer à tout moment',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                      ).animate().fadeIn(delay: 60.ms),
                      const SizedBox(height: DonySpacing.xl),
                      _RoleCard(
                        title: 'Expéditeur',
                        description: "J'envoie des colis à ma famille en Afrique",
                        icon: Icons.inventory_2_outlined,
                        isSelected: _selectedRole == 'SENDER',
                        onTap: () => setState(() => _selectedRole = 'SENDER'),
                      ).animate().fadeIn(delay: 120.ms).slideX(begin: 0.03),
                      const SizedBox(height: DonySpacing.sm),
                      _RoleCard(
                        title: 'Voyageur',
                        description: 'Je voyage et peux transporter des colis',
                        icon: Icons.flight_outlined,
                        isSelected: _selectedRole == 'TRAVELER',
                        onTap: () => setState(() => _selectedRole = 'TRAVELER'),
                      ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.03),
                      const SizedBox(height: DonySpacing.sm),
                      Center(
                        child: Text(
                          'Tu auras accès aux deux modes',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                padding: EdgeInsets.fromLTRB(h, DonySpacing.base, h, DonySpacing.md + bottom),
                child: DonyButton(
                  label: 'Continuer',
                  onPressed: _proceed,
                ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.05),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: DonyShadow.xs,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: DonySpacing.icon,
              height: DonySpacing.icon,
              decoration: BoxDecoration(
                color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Icon(
                icon,
                size: DonySpacing.iconSm,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall?.copyWith(color: cs.onSurface)),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(description, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4 : Vérifier que les tests passent**

```bash
flutter test test/features/auth/presentation/screens/role_selection_screen_test.dart --reporter=expanded 2>&1 | tail -20
```

Résultat attendu : tous `PASS`.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/role_selection_screen.dart \
        test/features/auth/presentation/screens/role_selection_screen_test.dart
git commit -m "feat(auth): add RoleSelectionScreen with animated mascot"
```

---

## Task 4 : Routing — ajouter /onboarding/role

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1 : Mettre à jour _publicRoutes**

Dans `lib/app/router.dart`, modifier le set `_publicRoutes` :

```dart
const _publicRoutes = {
  '/splash',
  '/onboarding',
  '/onboarding/role',  // ← NEW
  '/auth/phone',
  '/auth/otp',
  '/auth/pin-setup',
  '/auth/local',
};
```

- [ ] **Step 2 : Ajouter la route**

Ajouter l'import en haut du fichier (avec les autres imports auth) :

```dart
import 'package:dony/features/auth/presentation/screens/role_selection_screen.dart';
```

Ajouter la route après la route `/onboarding` existante :

```dart
    GoRoute(
      path: '/onboarding/role',
      builder: (context, state) {
        final initialRole = state.extra as String? ?? 'SENDER';
        return RoleSelectionScreen(initialRole: initialRole);
      },
    ),
```

- [ ] **Step 3 : Vérifier l'analyse**

```bash
flutter analyze lib/app/router.dart
```

Résultat attendu : `No issues found!`

- [ ] **Step 4 : Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(router): add /onboarding/role route"
```

---

## Task 5 : OnboardingScreen — navigation vers RoleScreen

**Files:**
- Modify: `lib/features/auth/presentation/screens/onboarding_screen.dart`
- Modify: `test/features/auth/presentation/screens/onboarding_screen_test.dart`

- [ ] **Step 1 : Mettre à jour le test existant**

Dans `test/features/auth/presentation/screens/onboarding_screen_test.dart`, mettre à jour le router de test pour inclure la route `/onboarding/role` :

Trouver la fonction `_buildRouter` et la modifier ainsi :

```dart
GoRouter _buildRouter(AuthBloc authBloc) => GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/role',
        builder: (_, __) => const Scaffold(body: Text('Role Screen')),
      ),
    ]);
```

Mettre à jour le test qui vérifie la navigation (chercher `find.text('Phone Auth')` et remplacer par `find.text('Role Screen')`) :

```dart
    testWidgets('tapping sender button navigates to role screen', (tester) async {
      // ... setup existant ...
      await tester.tap(find.text("J'envoie un colis"));
      await tester.pumpAndSettle();
      expect(find.text('Role Screen'), findsOneWidget);
    });
```

- [ ] **Step 2 : Vérifier l'échec du test mis à jour**

```bash
flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart 2>&1 | tail -10
```

Résultat attendu : le test de navigation échoue (trouve encore `Phone Auth`).

- [ ] **Step 3 : Modifier OnboardingScreen**

Dans `lib/features/auth/presentation/screens/onboarding_screen.dart`, supprimer la méthode `_proceed` existante et la remplacer par deux méthodes distinctes :

```dart
  void _goToRole(BuildContext context, String role) {
    context.go('/onboarding/role', extra: role);
  }
```

Puis dans `_OnboardingFooter`, remplacer les callbacks :

```dart
// AVANT
class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({required this.onSender});
  final VoidCallback onSender;

// APRÈS
class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.onSender,
    required this.onTraveler,
  });
  final VoidCallback onSender;
  final VoidCallback onTraveler;
```

Dans le build de `_OnboardingFooter`, mettre à jour le bouton ghost :

```dart
          DonyButton(
            label: 'Je suis voyageur',
            onPressed: onTraveler,   // ← était onSender
            variant: DonyButtonVariant.ghost,
          )
```

Dans `OnboardingScreen.build`, mettre à jour l'appel :

```dart
              _OnboardingFooter(
                onSender: () => _goToRole(context, 'SENDER'),
                onTraveler: () => _goToRole(context, 'TRAVELER'),
              ),
```

Supprimer l'import de `auth_event.dart` et la méthode `_proceed` qui émettait `OnboardingCompleted` (l'event est maintenant émis dans `RoleSelectionScreen._proceed()`).

- [ ] **Step 4 : Vérifier que les tests passent**

```bash
flutter test test/features/auth/presentation/screens/onboarding_screen_test.dart --reporter=expanded 2>&1 | tail -20
```

Résultat attendu : tous `PASS`.

- [ ] **Step 5 : Commit**

```bash
git add lib/features/auth/presentation/screens/onboarding_screen.dart \
        test/features/auth/presentation/screens/onboarding_screen_test.dart
git commit -m "feat(onboarding): route role buttons to RoleSelectionScreen"
```

---

## Task 6 : PhoneAuthScreen — mascotte + boutons sociaux

**Files:**
- Modify: `lib/features/auth/presentation/screens/phone_auth_screen.dart`

- [ ] **Step 1 : Ajouter l'import Platform**

En haut de `lib/features/auth/presentation/screens/phone_auth_screen.dart`, ajouter :

```dart
import 'dart:io' show Platform;
```

- [ ] **Step 2 : Remplacer le header (logo + mascotte)**

Dans `_PhoneAuthScreenState.build`, dans le `SingleChildScrollView`, remplacer :

```dart
// AVANT — deux widgets séparés :
const DonyLogo(fontSize: 48),
const SizedBox(height: DonySpacing.lg),
const Center(
  child: DonyMascotteAnimated(
    type: DonyMascotteType.joyeux,
    size: DonyMascotteSize.md,
  ),
),
```

par :

```dart
// APRÈS — mascotte confiant·sm inline avec logo :
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    DonyMascotteAnimated(
      type: DonyMascotteType.confiant,
      size: DonyMascotteSize.sm,
    ),
    const SizedBox(width: DonySpacing.md),
    const DonyLogo(fontSize: 48),
  ],
),
```

- [ ] **Step 3 : Ajouter les boutons sociaux dans le footer pinné**

Dans `_PhoneAuthScreenState.build`, dans le `Container` du bas (pinned bottom), ajouter après `DonyButton("Recevoir le code")` et avant le texte CGU :

```dart
                        const SizedBox(height: DonySpacing.md),
                        // Séparateur "ou connexion rapide"
                        Row(
                          children: [
                            Expanded(child: Divider(color: cs.outline)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
                              child: Text(
                                'ou connexion rapide',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                            Expanded(child: Divider(color: cs.outline)),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.md),
                        // Boutons sociaux — conditionnels selon plateforme
                        if (Platform.isIOS)
                          Row(
                            children: [
                              Expanded(child: _SocialButton(
                                label: 'Google',
                                icon: Icons.g_mobiledata_rounded,
                                onPressed: isLoading ? null : () =>
                                    context.read<AuthBloc>().add(const AuthGoogleSignInRequested()),
                              )),
                              const SizedBox(width: DonySpacing.sm),
                              Expanded(child: _SocialButton(
                                label: 'Apple',
                                icon: Icons.apple_rounded,
                                onPressed: isLoading ? null : () =>
                                    context.read<AuthBloc>().add(const AuthAppleSignInRequested()),
                              )),
                            ],
                          )
                        else
                          _SocialButton(
                            label: 'Continuer avec Google',
                            icon: Icons.g_mobiledata_rounded,
                            fullWidth: true,
                            onPressed: isLoading ? null : () =>
                                context.read<AuthBloc>().add(const AuthGoogleSignInRequested()),
                          ),
```

- [ ] **Step 4 : Créer le widget _SocialButton**

Ajouter à la fin de `phone_auth_screen.dart` (après `_PhoneAuthScreenState`) :

```dart
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: cs.onSurface),
      label: Text(
        label,
        style: tt.labelLarge?.copyWith(color: cs.onSurface),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: cs.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
        minimumSize: fullWidth ? const Size(double.infinity, 52) : const Size(0, 52),
      ),
    );

    return button;
  }
}
```

- [ ] **Step 5 : Vérifier l'analyse**

```bash
flutter analyze lib/features/auth/presentation/screens/phone_auth_screen.dart
```

Résultat attendu : `No issues found!`

- [ ] **Step 6 : Lancer la suite de tests complète**

```bash
flutter test --reporter=expanded 2>&1 | tail -30
```

Résultat attendu : tous les tests `PASS`, couverture ≥ 90 %.

- [ ] **Step 7 : Commit final**

```bash
git add lib/features/auth/presentation/screens/phone_auth_screen.dart
git commit -m "feat(auth): redesign PhoneAuthScreen with mascot and Google/Apple sign-in"
```

---

## Task 7 : Vérification finale

- [ ] **Step 1 : Tests complets**

```bash
flutter test --coverage 2>&1 | tail -20
```

Résultat attendu : tous `PASS`.

- [ ] **Step 2 : Analyse globale**

```bash
flutter analyze lib/
```

Résultat attendu : `No issues found!`

- [ ] **Step 3 : Rapport couverture**

```bash
genhtml coverage/lcov.info -o coverage/html 2>&1 | grep "lines\|Total"
```

Résultat attendu : couverture globale ≥ 90 %.

- [ ] **Step 4 : Commit de clôture**

```bash
git add -A
git commit -m "feat(onboarding): complete onboarding redesign with role selection and social auth"
```
