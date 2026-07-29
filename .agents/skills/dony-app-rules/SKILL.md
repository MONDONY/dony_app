---
name: dony-app-rules
description: Règles obligatoires pour l'app Flutter Yadony (repo technique dony_app). À lire AVANT toute modification du frontend. Couvre branding, architecture feature-first, BLoC, GoRouter, Dio, GetIt, flux d'authentification et patterns obligatoires.
---

# Règles Flutter dony_app

> Lire ce fichier INTÉGRALEMENT avant toute modification de l'app Flutter.
> Référence complémentaire : `/home/a-diakite/Desktop/MyProject/my_app/dony_app/.ai-instructions.md`

---

## Branding public — RÈGLE ABSOLUE

- Le nom public de l'application et de la marque est **Yadony**.
- Toute copie visible par l'utilisateur doit écrire **Yadony**, avec cette casse exacte. Ne jamais afficher « Dony » pour désigner l'application ou la marque.
- `dony_app`, les symboles `Dony*` et le schème `dony://` restent des identifiants techniques historiques. Ne pas les confondre avec le nom public et ne pas les renommer sans migration dédiée.
- Vérifier les textes, titres, semantics et libellés d'accessibilité de tout écran créé ou modifié.

---

## Stack

- **Framework :** Flutter (Dart) — iOS 14+ / Android 8.0+ (API 26)
- **State management :** `flutter_bloc` — **JAMAIS `setState` dans les features**
- **Navigation :** GoRouter — **JAMAIS `Navigator.push()` directement**
- **HTTP :** Dio — **JAMAIS le package `http`**
- **DI :** GetIt — **JAMAIS instanciation directe dans les widgets**
- **Stockage local :** Hive (offline queue QR) + `flutter_secure_storage` (PIN)
- **Auth :** Firebase Authentication (Phone Auth)
- **Paiements :** Stripe SDK
- **Notifications :** Firebase Cloud Messaging
- **Monitoring :** Sentry Flutter

---

## Structure obligatoire (Feature-First)

```
lib/
├── main.dart
├── app/
│   ├── app.dart           # MaterialApp + MultiBlocProvider
│   ├── router.dart        # GoRouter — TOUTES les routes ici
│   └── theme.dart
├── core/
│   ├── di/injection.dart  # GetIt — toutes les dépendances
│   ├── network/
│   │   ├── api_client.dart       # Instance Dio unique
│   │   └── auth_interceptor.dart # Auto-inject Firebase token
│   ├── storage/hive_service.dart
│   ├── error/app_exception.dart
│   └── widgets/           # Widgets partagés (DonyKeypad, etc.)
└── features/
    ├── auth/
    │   ├── bloc/          # auth_bloc.dart, auth_event.dart, auth_state.dart
    │   │                  # local_auth_bloc.dart, local_auth_event.dart, local_auth_state.dart
    │   ├── data/
    │   │   ├── models/user_model.dart
    │   │   ├── repositories/auth_repository.dart
    │   │   ├── datasources/auth_remote_datasource.dart
    │   │   └── services/local_auth_service.dart
    │   └── presentation/screens/
    │       ├── phone_auth_screen.dart
    │       ├── otp_verification_screen.dart
    │       ├── role_selection_screen.dart
    │       ├── pin_setup_screen.dart
    │       └── local_auth_screen.dart
    ├── splash/
    ├── home/
    ├── profile/
    ├── announcements/
    ├── kyc/
    ├── matching/
    ├── cancellation/      # FEATURE DÉDIÉE
    ├── tracking/
    ├── payments/
    ├── notifications/
    ├── disputes/
    └── admin/
```

**RÈGLE ABSOLUE :** Chaque feature DOIT avoir exactement 3 sous-dossiers :
- `bloc/` — State management
- `data/` — Models, repositories, datasources
- `presentation/` — Screens et widgets

---

## State Management (flutter_bloc)

### Structure obligatoire

```dart
// ─── Event ───────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
  @override List<Object?> get props => [];
}

// Conventions de nommage :
// Events   → suffixe "Requested"  (ex: BidCreateRequested)
// States   → Initial, Loading, Success/Authenticated, Error

// ─── State ───────────────────────────────────────────
abstract class AuthState extends Equatable {
  const AuthState();
}

class AuthInitial extends AuthState { const AuthInitial(); }
class AuthLoading extends AuthState { const AuthLoading(); }

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
  @override List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getProfile();
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        emit(const AuthInitial()); // Pas inscrit
      } else {
        emit(AuthError('Erreur réseau. Réessayez.'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
```

---

## Navigation (GoRouter)

```dart
// TOUJOURS ces méthodes — JAMAIS Navigator.push()
context.go('/home');              // Remplace toute la stack
context.push('/announcements/1'); // Empile (permet pop())
context.pop();                    // Retour
context.go('/auth/phone');        // Navigation après logout

// Routes définies dans lib/app/router.dart UNIQUEMENT
```

### Routes actuelles du projet

| Route | Screen |
|-------|--------|
| `/splash` | SplashScreen |
| `/auth/phone` | PhoneAuthScreen |
| `/auth/otp` | OtpVerificationScreen |
| `/auth/role` | RoleSelectionScreen |
| `/auth/pin-setup` | PinSetupScreen |
| `/auth/local` | LocalAuthScreen (PIN) |
| `/home` | HomeScreen (shell) |
| `/announcements/create` | CreateAnnouncementScreen |
| `/profile` | ProfileScreen |

---

## HTTP Client (Dio)

```dart
// lib/core/network/auth_interceptor.dart
// Le token Firebase est injecté automatiquement sur chaque requête

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// Utilisation dans les datasources :
class AuthRemoteDatasource {
  final ApiClient _apiClient;
  AuthRemoteDatasource(this._apiClient);

  Future<UserModel> getProfile() async {
    final response = await _apiClient.dio.get('/auth/me');
    return UserModel.fromJson(response.data);
  }
}
```

---

## Injection de dépendances (GetIt)

```dart
// lib/core/di/injection.dart — TOUT est enregistré ici

final getIt = GetIt.instance;

void setupDependencies({required String apiBaseUrl}) {
  // Core
  getIt.registerLazySingleton(() => ApiClient(baseUrl: apiBaseUrl));
  getIt.registerLazySingleton(() => LocalAuthService());

  // Datasources
  getIt.registerLazySingleton(() => AuthRemoteDatasource(getIt<ApiClient>()));

  // Repositories
  getIt.registerLazySingleton(() => AuthRepository(getIt<AuthRemoteDatasource>()));

  // BLoCs (factory = nouvelle instance à chaque création)
  getIt.registerFactory(() => AuthBloc(
    getIt<AuthRepository>(),
    getIt<LocalAuthService>(),
  ));
  getIt.registerFactory(() => LocalAuthBloc(getIt<LocalAuthService>()));
}
```

---

## Flux d'authentification complet

### Au démarrage (SplashScreen)

```
Firebase user existe ?
├── NON  → context.go('/auth/phone')
└── OUI  → AuthCheckRequested → getProfile()
           ├── 200 (inscrit)      → context.go('/auth/local')   [écran PIN]
           ├── 404 (non inscrit)  → context.go('/auth/role')    [création compte]
           └── Erreur réseau      → Afficher erreur sur Splash (NE PAS rediriger)
```

### Après vérification OTP (_onPhoneVerified dans AuthBloc)

```
Firebase signInWithCredential() OK
  ↓ getProfile() backend
  ├── 200 → AuthAuthenticated → OTP screen → context.go('/auth/local')
  └── 404 → AuthOtpVerified   → OTP screen → context.go('/auth/role')
```

### Logout (AuthLogoutRequested)

```dart
// RÈGLE : Ne JAMAIS clearPin() au logout — le PIN persiste !
Future<void> _onLogoutRequested(...) async {
  // ❌ await _localAuthService.clearPin(); ← INTERDIT au logout
  await _firebaseAuth.signOut();
  _pendingPhoneNumber = null;
  emit(const AuthInitial());
}
// ProfileScreen listener → AuthInitial → context.go('/auth/phone')
```

### Suppression de compte (AuthDeleteAccountRequested)

```dart
// Seul cas où clearPin() est autorisé
Future<void> _onDeleteAccountRequested(...) async {
  await _authRepository.deleteAccount(); // DELETE /auth/me
  await _localAuthService.clearPin();    // ✅ ici c'est OK
  await _firebaseAuth.signOut();
  emit(const AuthAccountDeleted());
}
// ProfileScreen listener → AuthAccountDeleted → context.go('/auth/phone')
```

### Écran PIN (LocalAuthScreen / LocalAuthBloc)

```dart
// Au démarrage de l'écran PIN :
Future<void> _onStarted(...) async {
  final pinSet = await _service.isPinSet();
  if (!pinSet) {
    emit(const LocalAuthNoPinSet()); // → context.go('/auth/pin-setup')
    return;
  }
  // ... vérification biométrie puis PIN normal
}
```

### États LocalAuth

| État | Signification | Action UI |
|------|--------------|-----------|
| `LocalAuthNoPinSet` | Aucun PIN configuré | → `/auth/pin-setup` |
| `LocalAuthPinRequired` | Saisie PIN demandée | Afficher keypad |
| `LocalAuthSuccess` | PIN validé | → `/home` |
| `LocalAuthLocked` | Trop de tentatives | Afficher countdown |

---

## Stockage local

### flutter_secure_storage (PIN)

```dart
// lib/features/auth/data/services/local_auth_service.dart
class LocalAuthService {
  static const _pinKey = 'dony_pin_v1';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> savePin(String pin) async =>
    await _storage.write(key: _pinKey, value: pin);

  Future<bool> validatePin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored == pin;
  }

  Future<void> clearPin() async =>
    await _storage.delete(key: _pinKey);
}
```

### Hive (offline QR queue uniquement)

- Utiliser Hive UNIQUEMENT pour la queue des scans QR offline
- Ne JAMAIS stocker : tokens Firebase, données KYC, données sensibles en clair

---

## Offline QR Scanning

- Détecter la connectivité avec `connectivity_plus`
- Stocker les scans offline dans Hive via `offline_queue.dart`
- Auto-sync à la reconnexion (doit se terminer en < 30s)
- Backend valide `offlineTimestamp` non dans le futur (anti-fraude)

---

## Commandes utiles

```bash
# Run dev
flutter run --dart-define-from-file=env.dev.json

# Analyse statique
flutter analyze

# Tests
flutter test

# Build APK prod
flutter build apk --dart-define-from-file=env.prod.json --release

# Code generation (Hive, JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Checklist avant tout commit Flutter

- [ ] Pas de `setState` dans les features → `flutter_bloc` uniquement
- [ ] Pas de `Navigator.push()` → `context.go()` / `context.push()` uniquement
- [ ] Pas du package `http` → `Dio` uniquement
- [ ] Dépendances injectées via `GetIt` (pas de constructeur direct dans les widgets)
- [ ] Structure `bloc/` + `data/` + `presentation/` respectée
- [ ] `flutter analyze` sans erreur
- [ ] PIN NON effacé au logout (seulement à la suppression de compte)
- [ ] Navigation après OTP : compte existant → `/auth/local` / nouveau → `/auth/role`
- [ ] `LocalAuthNoPinSet` → redirection vers `/auth/pin-setup`
