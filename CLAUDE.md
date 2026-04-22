# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project: dony Mobile App (Flutter)

**dony_app** est l'application mobile Flutter de la marketplace P2P dony, permettant aux voyageurs et expéditeurs de la diaspora africaine de se connecter pour le transport de colis vers l'Afrique.

**Stack:**
- Framework: Flutter (Dart)
- Min SDK: iOS 14+ / Android 8.0+ (API 26)
- State Management: flutter_bloc
- Navigation: GoRouter
- HTTP Client: Dio
- Local Storage: Hive
- Auth: Firebase Authentication (Phone Auth)
- Payments: Stripe SDK
- Notifications: Firebase Cloud Messaging (FCM)
- Monitoring: Sentry Flutter

---

## Démarrage rapide — Connexion émulateur Android (WSL2 + Windows)

> À suivre **à chaque démarrage de WSL** (l'IP WSL2 change à chaque redémarrage).

### Pourquoi c'est complexe

Spring Boot tourne dans WSL2. L'émulateur Android tourne sur Windows. Ils ne partagent pas le même `localhost` — `localhost` dans l'émulateur = l'émulateur lui-même, pas WSL2. La solution retenue : utiliser l'IP WSL2 directement dans `env.dev.json`.

> **Config déjà faite une fois** (ne pas refaire) : `android/app/src/debug/AndroidManifest.xml` autorise le HTTP cleartext en debug. Android 9+ bloque HTTP par défaut — cette config le permet pour le dev.

---

### Étape 1 — Démarrer Spring Boot (terminal WSL dédié)

```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony-back
./mvnw spring-boot:run -Dspring.profiles.active=dev
```

Attends de voir `Started ... in X seconds` avant de continuer. **Garde ce terminal ouvert.**

### Étape 2 — Récupérer l'IP WSL2 et mettre à jour env.dev.json

```bash
hostname -I | awk '{print $1}'
```

Copie l'IP affichée (ex: `172.19.53.150`), puis ouvre `dony_app/env.dev.json` et remplace la valeur de `API_BASE_URL` :

```json
{
  "API_BASE_URL": "http://<IP-WSL2>:8080/api/v1",
  "FIREBASE_PROJECT_ID": "dony-dev",
  "STRIPE_PUBLISHABLE_KEY": "pk_test_REPLACE_ME",
  "SENTRY_DSN": ""
}
```

Ou en une seule commande depuis le dossier `dony_app/` :

```bash
WSL_IP=$(hostname -I | awk '{print $1}') && \
sed -i "s|\"API_BASE_URL\": \"http://[^\"]*\"|\"API_BASE_URL\": \"http://$WSL_IP:8080/api/v1\"|" env.dev.json && \
echo "API_BASE_URL mis à jour → http://$WSL_IP:8080/api/v1"
```

### Étape 3 — Vérifier que l'émulateur est visible

```bash
adb devices
```

Tu dois voir `emulator-XXXX   device`. Si `offline`, redémarre l'émulateur depuis Android Studio.

### Étape 4 — Lancer Flutter (nouveau terminal WSL)

```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d emulator-5554
```

Remplace `emulator-5554` par le nom exact affiché à l'étape 3.

### Vérification : le back reçoit-il les requêtes ?

Depuis WSL, teste que l'IP est bien joignable par l'émulateur :

```bash
curl -s http://$(hostname -I | awk '{print $1}'):8080/api/v1/actuator/health
# Attendu : {"status":"UP"}
```

Si l'app fait un appel API, tu dois voir des logs dans le terminal Spring Boot.

---

### Dépannage

| Problème | Cause | Solution |
|----------|-------|----------|
| `Connection refused` dans l'app | Spring Boot pas démarré | Faire l'étape 1 |
| `Connection refused` dans l'app | IP WSL2 périmée | Refaire l'étape 2 |
| `emulator offline` | ADB désynchronisé | `adb kill-server && adb start-server` |
| HTTP bloqué (cleartext) | Config Android manquante | Vérifier `android/app/src/debug/AndroidManifest.xml` |
| App ANR / Lost connection | `flutter run` lancé en fond | Toujours garder `flutter run` dans un terminal dédié |
| Back ne reçoit rien | Spring Boot écoute sur mauvaise interface | Vérifier `server.address=0.0.0.0` dans `application-dev.yml` |

---

## Commands

### Development

```bash
# Run in dev mode with environment variables
flutter run --dart-define-from-file=env.dev.json

# Run on specific device
flutter devices
flutter run -d <device-id> --dart-define-from-file=env.dev.json

# Hot reload (press 'r' in terminal while running)
# Hot restart (press 'R' in terminal while running)

# Run with verbose logging
flutter run --dart-define-from-file=env.dev.json -v

# Clear cache and run
flutter clean && flutter pub get && flutter run --dart-define-from-file=env.dev.json
```

### Code Analysis & Testing

```bash
# Analyze code for issues
flutter analyze

# Fix auto-fixable issues
dart fix --apply

# Format code
dart format lib/ test/

# Run all tests
flutter test

# Run specific test file
flutter test test/features/auth/bloc/auth_bloc_test.dart

# Run tests with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Build

```bash
# Build Android APK (dev)
flutter build apk --dart-define-from-file=env.dev.json

# Build Android APK (production)
flutter build apk --dart-define-from-file=env.prod.json --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --dart-define-from-file=env.prod.json --release

# Build iOS (requires macOS)
flutter build ios --dart-define-from-file=env.prod.json --release
```

### Code Generation

```bash
# Generate Hive adapters, JSON serialization, etc.
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on file changes)
flutter pub run build_runner watch --delete-conflicting-outputs

# Clean generated files
flutter pub run build_runner clean
```

### Dependencies

```bash
# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated
```

---

## Architecture

### Project Structure (Feature-First)

```
lib/
├── main.dart                    # Entry point
├── app/
│   ├── app.dart                # MaterialApp configuration
│   ├── router.dart             # GoRouter - ALL routes defined here
│   └── theme.dart              # App theme (colors, typography)
├── core/
│   ├── di/
│   │   └── injection.dart      # GetIt - dependency injection setup
│   ├── network/
│   │   ├── api_client.dart     # Single Dio instance
│   │   └── auth_interceptor.dart  # Auto-inject Firebase token
│   ├── storage/
│   │   └── hive_service.dart   # Hive initialization
│   ├── error/
│   │   ├── app_exception.dart
│   │   └── error_handler.dart
│   └── constants/
│       ├── api_endpoints.dart
│       └── app_constants.dart
└── features/
    ├── auth/
    │   ├── bloc/
    │   │   ├── auth_bloc.dart
    │   │   ├── auth_event.dart
    │   │   └── auth_state.dart
    │   ├── data/
    │   │   ├── models/
    │   │   │   └── user_model.dart
    │   │   ├── repositories/
    │   │   │   └── auth_repository.dart
    │   │   └── datasources/
    │   │       └── auth_remote_datasource.dart
    │   └── presentation/
    │       ├── screens/
    │       │   ├── phone_auth_screen.dart
    │       │   └── otp_verification_screen.dart
    │       └── widgets/
    ├── kyc/
    │   ├── bloc/
    │   ├── data/
    │   └── presentation/
    ├── matching/
    │   ├── bloc/
    │   │   ├── announcement_bloc.dart
    │   │   └── bid_bloc.dart
    │   ├── data/
    │   └── presentation/
    │       ├── screens/
    │       │   ├── announcement_list_screen.dart
    │       │   ├── announcement_detail_screen.dart
    │       │   ├── create_announcement_screen.dart
    │       │   └── bid_list_screen.dart
    │       └── widgets/
    ├── cancellation/            # DEDICATED feature (not in matching/)
    │   ├── bloc/
    │   ├── data/
    │   └── presentation/
    ├── tracking/
    │   ├── bloc/
    │   ├── data/
    │   │   ├── models/
    │   │   │   └── offline_scan_entry.dart
    │   │   └── repositories/
    │   │       └── offline_queue.dart  # Hive - offline QR sync
    │   └── presentation/
    │       ├── screens/
    │       │   ├── qr_scanner_screen.dart
    │       │   └── tracking_timeline_screen.dart
    │       └── widgets/
    ├── payments/
    │   ├── bloc/
    │   ├── data/
    │   └── presentation/
    │       ├── screens/
    │       │   ├── payment_screen.dart
    │       │   └── payment_confirmation_screen.dart
    │       └── widgets/
    ├── notifications/
    │   ├── bloc/
    │   ├── data/
    │   └── presentation/
    ├── disputes/
    │   ├── bloc/
    │   ├── data/
    │   └── presentation/
    └── admin/
        ├── bloc/
        ├── data/
        └── presentation/
```

**Règle fondamentale:** Chaque feature DOIT avoir exactement 3 sous-dossiers:
- `bloc/` - State management
- `data/` - Models, repositories, datasources
- `presentation/` - Screens et widgets

---

## Core Principles

### 1. State Management (flutter_bloc)

**TOUJOURS utiliser flutter_bloc** - JAMAIS `setState` pour gérer l'état d'une feature.

```dart
// Event
abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phoneNumber;
  AuthLoginRequested(this.phoneNumber);
}

class AuthLogoutRequested extends AuthEvent {}

// State (sealed class pattern)
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(event.phoneNumber);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }
}

// Usage in widget
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/home');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is AuthLoading) {
          return Center(child: CircularProgressIndicator());
        }

        return LoginForm(
          onSubmit: (phone) {
            context.read<AuthBloc>().add(AuthLoginRequested(phone));
          },
        );
      },
    );
  }
}
```

**Conventions de nommage:**
- Events: suffixe `Requested` (ex: `BidCreateRequested`, `TrackingQrScannedRequested`)
- States: `Initial`, `Loading`, `Success`, `Error` (sealed class pattern)

### 2. Navigation (GoRouter)

**TOUJOURS utiliser GoRouter** - JAMAIS `Navigator.push()` directement.

```dart
// lib/app/router.dart
final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    // Auth guard
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isGoingToAuth = state.matchedLocation.startsWith('/auth');

    if (!isAuthenticated && !isGoingToAuth) {
      return '/auth/phone';
    }

    if (isAuthenticated && isGoingToAuth) {
      return '/home';
    }

    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) {
        final phoneNumber = state.extra as String;
        return OtpVerificationScreen(phoneNumber: phoneNumber);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/announcements/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AnnouncementDetailScreen(announcementId: id);
      },
    ),
    GoRoute(
      path: '/tracking/scan',
      builder: (context, state) => QrScannerScreen(),
    ),
    GoRoute(
      path: '/payment/confirm',
      builder: (context, state) {
        final paymentIntentId = state.extra as String;
        return PaymentConfirmationScreen(paymentIntentId: paymentIntentId);
      },
    ),
  ],
);

// Usage in widgets
// Navigate
context.go('/home');
context.push('/announcements/123');

// Navigate with extra data
context.push('/auth/otp', extra: phoneNumber);

// Go back
context.pop();
```

**Deep links supportés:**
- Confirmation paiement: `dony://payment/confirm?payment_intent=pi_xxx`
- Scan QR: `dony://tracking/scan?bid_id=xxx`
- Page tracking destinataire: `https://dony.app/tracking/{token}`

### 3. HTTP Client (Dio)

**TOUJOURS utiliser Dio** - JAMAIS le package `http` directement.

```dart
// lib/core/network/api_client.dart
class ApiClient {
  late final Dio _dio;

  ApiClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add auth interceptor
    _dio.interceptors.add(AuthInterceptor());

    // Add logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Dio get dio => _dio;
}

// lib/core/network/auth_interceptor.dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Auto-inject Firebase ID token
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired, refresh
      // Then retry request
    }
    handler.next(err);
  }
}

// Usage in datasource
class AnnouncementRemoteDatasource {
  final ApiClient _apiClient;

  AnnouncementRemoteDatasource(this._apiClient);

  Future<List<AnnouncementModel>> getAnnouncements({
    required String corridor,
    required int page,
  }) async {
    final response = await _apiClient.dio.get(
      '/announcements',
      queryParameters: {
        'corridor': corridor,
        'page': page,
        'size': 20,
      },
    );

    return (response.data['content'] as List)
        .map((json) => AnnouncementModel.fromJson(json))
        .toList();
  }
}
```

### 4. Environment Configuration

Fichiers de configuration (dans `.gitignore`):

**env.dev.json:**
```json
{
  "API_BASE_URL": "http://10.0.2.2:8080/api/v1",
  "FIREBASE_PROJECT_ID": "dony-dev",
  "STRIPE_PUBLISHABLE_KEY": "pk_test_xxx",
  "SENTRY_DSN": "https://xxx@sentry.io/xxx"
}
```

**env.prod.json:**
```json
{
  "API_BASE_URL": "https://api.dony.app/api/v1",
  "FIREBASE_PROJECT_ID": "dony-prod",
  "STRIPE_PUBLISHABLE_KEY": "pk_live_xxx",
  "SENTRY_DSN": "https://xxx@sentry.io/xxx"
}
```

**Usage in code:**
```dart
// main.dart
void main() {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  // Setup dependencies
  setupDependencies(
    apiBaseUrl: apiBaseUrl,
    stripeKey: stripePublishableKey,
  );

  runApp(MyApp());
}
```

### 5. Dependency Injection (GetIt)

```dart
// lib/core/di/injection.dart
final getIt = GetIt.instance;

void setupDependencies({
  required String apiBaseUrl,
  required String stripeKey,
}) {
  // Core
  getIt.registerLazySingleton(() => ApiClient(baseUrl: apiBaseUrl));
  getIt.registerLazySingleton(() => HiveService());

  // Repositories
  getIt.registerLazySingleton(() => AuthRepository(
    remoteDatasource: getIt<AuthRemoteDatasource>(),
  ));
  getIt.registerLazySingleton(() => AnnouncementRepository(
    remoteDatasource: getIt<AnnouncementRemoteDatasource>(),
  ));

  // Datasources
  getIt.registerLazySingleton(() => AuthRemoteDatasource(getIt<ApiClient>()));
  getIt.registerLazySingleton(() => AnnouncementRemoteDatasource(getIt<ApiClient>()));

  // BLoCs (factories - new instance each time)
  getIt.registerFactory(() => AuthBloc(getIt<AuthRepository>()));
  getIt.registerFactory(() => AnnouncementBloc(getIt<AnnouncementRepository>()));
}

// Usage in widgets
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AuthBloc>()),
        BlocProvider(create: (_) => getIt<AnnouncementBloc>()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }
}
```

**Règle:** Ne JAMAIS instancier un service directement dans un widget ou BLoC - toujours utiliser `getIt`.

### 6. Local Storage (Hive)

**Utiliser Hive UNIQUEMENT pour:**
- PIN utilisateur (chiffré)
- Queue des scans QR offline

**Ne JAMAIS stocker:**
- Tokens Firebase (utiliser `FirebaseAuth.instance.currentUser`)
- Données KYC
- Données sensibles en clair

```dart
// lib/core/storage/hive_service.dart
class HiveService {
  static const String offlineQueueBox = 'offline_queue';
  static const String userPrefsBox = 'user_prefs';

  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(OfflineScanEntryAdapter());

    // Open boxes
    await Hive.openBox<OfflineScanEntry>(offlineQueueBox);
    await Hive.openBox(userPrefsBox);
  }
}

// lib/features/tracking/data/repositories/offline_queue.dart
@HiveType(typeId: 0)
class OfflineScanEntry extends HiveObject {
  @HiveField(0)
  final String bidId;

  @HiveField(1)
  final String qrCode;

  @HiveField(2)
  final double? gpsLat;

  @HiveField(3)
  final double? gpsLon;

  @HiveField(4)
  final String? photoPath;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  bool synced;

  OfflineScanEntry({
    required this.bidId,
    required this.qrCode,
    this.gpsLat,
    this.gpsLon,
    this.photoPath,
    required this.timestamp,
    this.synced = false,
  });
}

class OfflineQueue {
  final Box<OfflineScanEntry> _box;

  OfflineQueue(this._box);

  Future<void> addScan(OfflineScanEntry entry) async {
    await _box.add(entry);
  }

  List<OfflineScanEntry> getUnsyncedScans() {
    return _box.values.where((entry) => !entry.synced).toList();
  }

  Future<void> markAsSynced(int index) async {
    final entry = _box.getAt(index);
    if (entry != null) {
      entry.synced = true;
      await entry.save();
    }
  }
}
```

### 7. Offline QR Scanning (CRITIQUE)

Règle métier: Les scans QR doivent fonctionner sans connexion internet.

```dart
// lib/features/tracking/bloc/tracking_bloc.dart
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository _repository;
  final OfflineQueue _offlineQueue;
  final Connectivity _connectivity;

  TrackingBloc(this._repository, this._offlineQueue, this._connectivity)
      : super(TrackingInitial()) {
    on<TrackingQrScanned>(_onQrScanned);
    on<TrackingSyncRequested>(_onSyncRequested);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        add(TrackingSyncRequested());
      }
    });
  }

  Future<void> _onQrScanned(
    TrackingQrScanned event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      // Send immediately
      try {
        await _repository.submitQrScan(
          bidId: event.bidId,
          qrCode: event.qrCode,
          gpsLat: event.gpsLat,
          gpsLon: event.gpsLon,
          photo: event.photo,
        );
        emit(TrackingScanSuccess(synced: true));
      } catch (e) {
        // Failed online, save offline
        await _saveOffline(event);
        emit(TrackingScanSuccess(synced: false));
      }
    } else {
      // Save for later sync
      await _saveOffline(event);
      emit(TrackingScanSuccess(synced: false));
    }
  }

  Future<void> _saveOffline(TrackingQrScanned event) async {
    await _offlineQueue.addScan(OfflineScanEntry(
      bidId: event.bidId,
      qrCode: event.qrCode,
      gpsLat: event.gpsLat,
      gpsLon: event.gpsLon,
      photoPath: event.photo?.path,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _onSyncRequested(
    TrackingSyncRequested event,
    Emitter<TrackingState> emit,
  ) async {
    final unsyncedScans = _offlineQueue.getUnsyncedScans();

    for (int i = 0; i < unsyncedScans.length; i++) {
      final scan = unsyncedScans[i];
      try {
        await _repository.submitQrScan(
          bidId: scan.bidId,
          qrCode: scan.qrCode,
          gpsLat: scan.gpsLat,
          gpsLon: scan.gpsLon,
          photo: scan.photoPath != null ? File(scan.photoPath!) : null,
          offlineTimestamp: scan.timestamp,
        );

        await _offlineQueue.markAsSynced(i);
      } catch (e) {
        // Sync failed, will retry later
        print('Failed to sync scan $i: $e');
      }
    }
  }
}
```

**Règles critiques:**
- Détecter la connectivité avec `connectivity_plus`
- Si offline: stocker dans Hive, afficher "En attente de synchronisation..."
- Synchroniser automatiquement dès reconnexion
- La synchro doit se faire en < 30 secondes (NFR1)
- Le backend valide que `offlineTimestamp` n'est pas dans le futur (anti-fraude)

### 8. QR Photo with GPS

```dart
// lib/features/tracking/presentation/screens/qr_scanner_screen.dart
class QrScannerScreen extends StatefulWidget {
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final Geolocator _geolocator = Geolocator();

  Future<void> _capturePhotoWithGps() async {
    // Get GPS coordinates BEFORE taking photo
    final position = await _geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Capture photo
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (photo != null) {
      // Write GPS to EXIF metadata
      final File photoFile = File(photo.path);
      await _writeGpsToExif(photoFile, position.latitude, position.longitude);

      // Submit scan
      context.read<TrackingBloc>().add(TrackingQrScanned(
        bidId: widget.bidId,
        qrCode: widget.qrCode,
        gpsLat: position.latitude,
        gpsLon: position.longitude,
        photo: photoFile,
      ));
    }
  }

  Future<void> _writeGpsToExif(File file, double lat, double lon) async {
    // Use exif package to write GPS coordinates
    // ...
  }
}
```

**Règles:**
- Capturer GPS au moment exact de la photo
- Écrire GPS dans les métadonnées EXIF
- Taille max: 10MB (valider avant upload)

### 9. Biometric Authentication (Payments)

```dart
// lib/features/payments/presentation/screens/payment_screen.dart
import 'package:local_auth/local_auth.dart';

class PaymentScreen extends StatefulWidget {
  final String bidId;
  final double amount;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> _confirmPayment() async {
    // Check if biometric is available
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();

    if (canCheckBiometrics && isDeviceSupported) {
      // Authenticate with biometrics
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Confirmez le paiement de ${widget.amount}€',
        options: AuthenticationOptions(
          biometricOnly: false,  // Allow PIN fallback
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        // User cancelled or failed auth
        return;
      }
    } else {
      // Fallback to PIN
      final pinValid = await _showPinDialog();
      if (!pinValid) return;
    }

    // Proceed with payment
    context.read<PaymentBloc>().add(PaymentCreateRequested(
      bidId: widget.bidId,
      amount: widget.amount,
    ));
  }
}
```

**Règle:** Paiement DOIT être protégé par biométrie ou PIN (NFR14).

### 10. Firebase Cloud Messaging

```dart
// lib/features/notifications/data/services/fcm_service.dart
class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiClient _apiClient;

  FcmService(this._apiClient);

  Future<void> initialize() async {
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      final token = await _fcm.getToken();

      // Send token to backend
      await _apiClient.dio.put('/users/me/fcm-token', data: {
        'fcm_token': token,
      });

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _apiClient.dio.put('/users/me/fcm-token', data: {
          'fcm_token': newToken,
        });
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show in-app notification
    // Send ACK to backend
    _sendAck(message.data['notification_id']);
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to relevant screen based on notification data
    final screen = message.data['screen'];
    final params = message.data['params'];
    // Use GoRouter to navigate
  }

  Future<void> _sendAck(String notificationId) async {
    // Acknowledge receipt of critical notification
    await _apiClient.dio.post('/notifications/$notificationId/ack');
  }
}

// Background handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background notification
  await Firebase.initializeApp();
  // Send ACK
}
```

**Règle:** Toujours envoyer un ACK au backend pour les notifications critiques (paiement, livraison, litige).

---

## Critical Rules

### NEVER:

1. ❌ Use `setState` to manage feature state (use BLoC)
2. ❌ Use `Navigator.push()` directly (use GoRouter)
3. ❌ Use `http` package (use Dio)
4. ❌ Instantiate services directly in widgets/BLoCs (use GetIt)
5. ❌ Store sensitive data in Hive unencrypted
6. ❌ Store Firebase tokens in Hive (use `FirebaseAuth.instance.currentUser`)
7. ❌ Upload photos > 10MB
8. ❌ Skip biometric/PIN auth for payments
9. ❌ Forget to write GPS to EXIF metadata
10. ❌ Hardcode API URLs or keys (use `--dart-define-from-file`)

### ALWAYS:

1. ✅ Use BLoC pattern for state management
2. ✅ Use GoRouter for navigation with auth guards
3. ✅ Use Dio with `AuthInterceptor` for HTTP
4. ✅ Store offline QR scans in Hive
5. ✅ Sync offline queue automatically on reconnection
6. ✅ Capture GPS at exact moment of photo
7. ✅ Require biometric/PIN for payments
8. ✅ Send FCM acknowledgment for critical notifications
9. ✅ Update FCM token on backend when it refreshes
10. ✅ Validate data client-side (but backend is source of truth)

---

## Feature Implementation Checklist

Before starting a feature:

- [ ] Read full story in `/docs-claude/docs/stories/epic-XX-*.md`
- [ ] Create BLoC (events + states + bloc)
- [ ] Create data models with `fromJson`/`toJson`
- [ ] Create repository and datasource
- [ ] Add routes to `lib/app/router.dart`
- [ ] Register dependencies in `lib/core/di/injection.dart`

Before marking feature complete:

- [ ] All Given/When/Then criteria covered
- [ ] BLoC pattern used (no `setState`)
- [ ] GoRouter used (no direct `Navigator`)
- [ ] Loading states handled
- [ ] Error states handled with user-friendly messages
- [ ] Offline support implemented if required
- [ ] Biometric/PIN added if required
- [ ] FCM handling added if notifications involved
- [ ] Unit tests for BLoC
- [ ] Widget tests for critical screens

---

## Testing

### Unit Tests (BLoC)

```dart
// test/features/auth/bloc/auth_bloc_test.dart
void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(mockAuthRepository);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when login succeeds',
      build: () {
        when(mockAuthRepository.login(any))
            .thenAnswer((_) async => mockUser);
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthLoginRequested('1234567890')),
      expect: () => [
        AuthLoading(),
        AuthAuthenticated(mockUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when login fails',
      build: () {
        when(mockAuthRepository.login(any))
            .thenThrow(Exception('Login failed'));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthLoginRequested('invalid')),
      expect: () => [
        AuthLoading(),
        isA<AuthError>(),
      ],
    );
  });
}
```

### Widget Tests

```dart
// test/features/auth/presentation/screens/phone_auth_screen_test.dart
void main() {
  testWidgets('shows error message when phone number is invalid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => MockAuthBloc(),
          child: PhoneAuthScreen(),
        ),
      ),
    );

    // Find text field and button
    final textField = find.byType(TextField);
    final button = find.byType(ElevatedButton);

    // Enter invalid phone
    await tester.enterText(textField, '123');
    await tester.tap(button);
    await tester.pump();

    // Expect error message
    expect(find.text('Numéro de téléphone invalide'), findsOneWidget);
  });
}
```

---

## Design et UI — Human Interface Guidelines

> **RÈGLE ABSOLUE :** Tout écran implémenté DOIT être acceptable à la fois par les **Apple Human Interface Guidelines (HIG)** et les **Material Design 3 Guidelines (Android)**. Un design refusé par l'App Store ou le Play Store pour non-conformité aux guidelines est inacceptable. Appliquer les principes suivants sans exception.

---

### Bibliothèques de design (à utiliser dans TOUTES les stories)

| Package | Usage |
|---------|-------|
| `flutter_animate` | Micro-animations et transitions d'écran (chainable, code-based) |
| `google_fonts` | Police **Plus Jakarta Sans** — utilisée sur tous les textes |
| `pinput` | Champ PIN / OTP avec personnalisation avancée |
| `flutter_secure_storage` | Stockage sécurisé du PIN (Android Keystore / iOS Keychain) |

---

### Palette de couleurs dony (source de vérité : `lib/app/theme.dart`)
```dart
const kGreenPrimary  = Color(0xFF1A6B3C);  // CTA, éléments actifs
const kGreenDark     = Color(0xFF134F2D);  // gradients, header
const kGreenAccent   = Color(0xFF4CAF7D);  // accents secondaires
const kGreenLight    = Color(0xFFE8F5EE);  // backgrounds chips/badges actifs
const kBackground    = Color(0xFFF4F6F8);  // fond d'écran (jamais blanc pur)
const kSurface       = Color(0xFFFFFFFF);  // cards, champs, appbar
const kTextPrimary   = Color(0xFF0D1B2A);  // titres, corps principal
const kTextSecondary = Color(0xFF6B7A8D);  // labels, sous-titres
const kTextHint      = Color(0xFFADB5BD);  // placeholders
const kBorder        = Color(0xFFE9ECEF);  // bordures cards et inputs
const kError         = Color(0xFFE53935);  // erreurs
const kWarning       = Color(0xFFF59E0B);  // avertissements
const kSuccess       = Color(0xFF16A34A);  // succès, confirmations
```

---

### Apple Human Interface Guidelines — Règles obligatoires

Ces règles s'appliquent à CHAQUE écran. Aucune dérogation sans justification explicite.

#### 1. Typographie (HIG: Typography)
- **Police unique** : `GoogleFonts.plusJakartaSans` sur tous les textes — jamais de police système hardcodée
- **Hiérarchie stricte** :
  - Grand titre (Large Title) : `fontSize 28–32, fontWeight w800, letterSpacing -0.5`
  - Titre de navigation : `fontSize 17–18, fontWeight w700`
  - Titre section : `fontSize 15–16, fontWeight w600`
  - Corps : `fontSize 14–15, fontWeight w400`
  - Caption/label : `fontSize 12–13, fontWeight w500, color kTextSecondary`
- **Ne jamais** utiliser `fontSize < 12` (illisible, rejeté HIG)
- **Contraste minimum** : ratio 4.5:1 pour le texte normal, 3:1 pour les grands titres

#### 2. Touch Targets (HIG: Gestures & Interactivity)
- **Minimum absolu : 44×44 points** pour tout élément interactif (boutons, icônes, liens)
- Les chips et badges non-interactifs peuvent être plus petits, mais s'ils sont tappables → 44pt minimum
- Utiliser `InkWell` ou `GestureDetector` avec un padding suffisant pour atteindre 44pt

#### 3. Navigation (HIG: Navigation + Material: Navigation)
- **Back button iOS** : `Icons.arrow_back_ios_rounded` (taille 20, couleur `kGreenPrimary`)
- **Back button Android** : `Icons.arrow_back_rounded`
- **Ne jamais** bloquer la navigation arrière sans raison UX valable
- **GoRouter uniquement** — jamais `Navigator.push()` directement
- **Large Title** sur les écrans principaux : `SliverAppBar` avec `expandedHeight: 100–120`
- **Compact AppBar** sur les écrans secondaires (formulaires, détails)
- **Titre aligné à gauche** (`centerTitle: false`) — conforme HIG iOS 15+

#### 4. Modales et Bottom Sheets (HIG: Modality)
- **Bottom sheets** pour : filtres, tri, actions secondaires, confirmation légère
- **Dialog** uniquement pour : actions destructives irréversibles (suppression, déconnexion)
- **Handle** obligatoire sur chaque bottom sheet : `Container(width: 40, height: 4, color: kBorder)`
- **`isScrollControlled: true`** sur les sheets avec contenu variable
- **`backgroundColor: Colors.transparent`** + `borderRadius: BorderRadius.vertical(top: Radius.circular(20))`
- Respecter `MediaQuery.of(context).viewInsets.bottom` pour éviter le chevauchement clavier

#### 5. Couleurs et contraste (HIG: Color + Material: Color)
- **Jamais de blanc pur** (`0xFFFFFFFF`) comme fond d'écran — utiliser `kBackground`
- **Gradients** : uniquement sur les hero cards et headers. Jamais sur les boutons texte
- **Couleur sémantique** : vert = succès/actif, orange = avertissement, rouge = erreur/destructif
- **Dark mode** : non requis pour le MVP, mais ne pas hardcoder de couleurs incompatibles

#### 6. Espacement et mise en page (HIG: Layout + Material: Spacing)
- **Padding horizontal écran** : 20pt (pas 24 — plus naturel sur petits écrans)
- **Espacement vertical** entre sections : 24–28pt
- **Espacement interne cards** : 16pt
- **Border radius** : cards 16pt, boutons 14pt, chips 20pt, inputs 12pt, badges 8pt
- **Safe Areas** : toujours respectées via `SafeArea` ou `SliverAppBar`

#### 7. Animations (HIG: Animation + Material: Motion)
- **Durée d'entrée** : 250–300ms
- **Durée de sortie** : 150–200ms
- **Easing** : `Curves.easeOutCubic` pour les entrées, `Curves.easeInCubic` pour les sorties
- **Stagger lists** : délai de `60ms × index` entre chaque item de liste
- **Jamais d'animation > 500ms** (ressenti "lent" sur iOS)
- **`flutter_animate`** pour toutes les animations déclaratives

#### 8. États des composants (HIG: Controls + Material: Interaction States)
- **Loading** : `CircularProgressIndicator(color: kGreenPrimary)` centré — jamais de skeleton vide
- **Erreur** : icône + titre + description + bouton "Réessayer" — jamais un message seul
- **Vide** : illustration (icône dans cercle coloré) + titre + description + CTA si applicable
- **Désactivé** : opacité 0.4 sur le composant, jamais de couleur grise hardcodée

#### 9. Formulaires (HIG: Text Input + Material: Text Fields)
- **Labels flottants** via `InputDecoration(labelText: ...)` — jamais de labels fixes au-dessus
- **Feedback immédiat** : validation à la perte de focus (`onChanged` ou `validator`)
- **Clavier adapté** : `TextInputType.numberWithOptions` pour les chiffres/prix
- **`suffixText`** pour les unités (€, kg) — jamais de texte dans le placeholder pour les unités
- **Bouton submit** : désactivé (`onPressed: null`) pendant le loading, jamais caché

#### 10. Accessibilité (HIG: Accessibility + Material: Accessibility)
- **`Semantics`** sur les icônes sans label visible
- **`tooltip`** sur les `IconButton`
- **Contraste** vérifié pour les couleurs personnalisées
- **Ne jamais** transmettre l'information uniquement par la couleur (ajouter icône ou texte)

---

### Material Design 3 — Règles complémentaires (Android)

- **`useMaterial3: true`** dans le `ThemeData` — déjà configuré
- **`ElevatedButton`** : `elevation: 0, shadowColor: Colors.transparent` — pas d'ombre Material 2
- **`CardThemeData`** : `elevation: 0`, border `kBorder` — pas de shadow Material 2 sur les cards
- **`SnackBarBehavior.floating`** avec `borderRadius: 12` — conforme Material 3
- **`AppBar`** : `scrolledUnderElevation: 0` — évite le tint automatique Material 3 indésirable
- **`FloatingActionButton.extended`** pour les actions principales en bas d'écran liste

---

### PIN input — standard dony
```dart
PinTheme(
  width: 56, height: 64,
  decoration: BoxDecoration(
    color: kGreenLight,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: kGreenPrimary, width: 2),
  ),
)
```
Utiliser `DonyKeypad` (`lib/core/widgets/dony_keypad.dart`) — ne jamais recréer le clavier.

---

### Structure type d'un écran secondaire
```dart
Scaffold(
  backgroundColor: kBackground,
  appBar: AppBar(
    title: Text('Titre', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
    backgroundColor: kSurface,
    elevation: 0,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1),
    ),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
    child: Column(
      children: [ /* contenu */ ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  ),
)
```

### Structure type d'un écran principal avec Large Title
```dart
Scaffold(
  backgroundColor: kBackground,
  body: CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        expandedHeight: 110,
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text('Grand titre', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700)),
          expandedTitleScale: 1.5,
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kBorder, height: 1)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        sliver: SliverList(delegate: SliverChildListDelegate([ /* contenu */ ])),
      ),
    ],
  ),
)
```

---

## Performance Guidelines

1. **Image optimization:**
   - Max 10MB per image
   - Compress to 85% quality
   - Max dimensions: 1920x1080

2. **List performance:**
   - Use `ListView.builder` for long lists
   - Use `CachedNetworkImage` for images
   - Implement pagination (20 items per page)

3. **State management:**
   - Dispose BLoCs properly
   - Unsubscribe from streams
   - Cancel timers in `dispose()`

4. **Network:**
   - Cache responses when appropriate
   - Implement retry logic with exponential backoff
   - Timeout: 10s connect, 30s receive

---

## Security Checklist

Before deploying:

- [ ] No API keys or secrets in code
- [ ] Environment variables used (`--dart-define-from-file`)
- [ ] Biometric/PIN for payments
- [ ] Firebase token auto-refreshed
- [ ] HTTPS only for API calls
- [ ] SSL certificate pinning (production)
- [ ] ProGuard/R8 enabled (Android release)
- [ ] Code obfuscation enabled (iOS/Android)
- [ ] No sensitive data in logs (production)
- [ ] Sentry configured for crash reporting

---

## Documentation obligatoire à la fin de chaque story

**INSTRUCTION IMPÉRATIVE:** À la fin de l'implémentation de chaque story (quand elle est complète à 100%), Claude DOIT créer un fichier de documentation dans le dossier `docs/stories-done/` décrivant ce qui a été fait côté **frontend Flutter**.

### Nom du fichier
`docs/stories-done/story-<epic>.<numero>-<slug>.md`

Exemple: `docs/stories-done/story-2.1-phone-auth.md`

### Contenu obligatoire du fichier

```markdown
# Story <epic>.<numero> — <Titre de la story> (Flutter)

**Date:** YYYY-MM-DD
**Status:** ✅ Complète

## Résumé
Une ou deux phrases décrivant ce qui a été implémenté et pourquoi.

## Fichiers créés
- `lib/features/.../fichier.dart` — rôle du fichier dans l'architecture

## Fichiers modifiés
- `lib/features/.../fichier.dart` — ce qui a changé et pourquoi

## Comment ça fonctionne (pour la maintenance)

### Vue d'ensemble du flux utilisateur
Décrire étape par étape ce que voit et fait l'utilisateur, et ce qui se passe dans le code :
1. L'utilisateur fait X → l'écran Y réagit
2. Le BLoC reçoit l'event Z, appelle le repository
3. L'état S est émis → l'UI se met à jour
4. Navigation vers l'écran W

### BLoC : events et states
- **Events** : lister chaque event, quand il est déclenché, ce qu'il transporte
- **States** : lister chaque state, ce qu'il signifie pour l'UI
- **Transitions importantes** : ex. "après AuthOtpVerified, on attend AuthAuthenticated avant de naviguer"

### Écrans et widgets clés
Pour chaque écran créé ou modifié :
- Ce qu'il affiche et dans quelles conditions
- Quel BLoC il écoute et comment il réagit aux états
- La navigation qu'il déclenche (context.go vers où, et quand)

### Appels API
- Endpoint appelé, avec quel body, dans quel cas
- Comment les erreurs HTTP sont transformées en messages utilisateur

### Pièges et points d'attention
Ce qu'il faut savoir pour ne pas casser cette feature en la modifiant :
- Comportements asynchrones non évidents (ex: Completer pour Firebase callbacks)
- Dépendances entre états BLoC (ex: _pendingPhoneNumber doit être set avant register)
- Cas où GoRouter peut rediriger de façon inattendue
- Initialisation nécessaire dans initState

## Critères d'acceptation couverts
- [x] Given/When/Then 1 — comment c'est implémenté
- [x] Given/When/Then 2 — comment c'est implémenté

## Décisions techniques
Pour chaque décision non triviale : le choix fait, les alternatives écartées, et pourquoi.
```

### Règles
- Ne pas créer le fichier avant que la story soit 100% complète
- Créer le dossier `docs/stories-done/` s'il n'existe pas
- Toujours inclure les critères d'acceptation de la story originale
- La section "Comment ça fonctionne" doit être assez détaillée pour qu'un développeur puisse maintenir la feature sans avoir à lire tout le code

---

## Documentation

**Référence complète:** `/docs-claude/CLAUDE.md` (règles détaillées en français)

**Architecture:** `/docs-claude/docs/planning-artifacts/architecture.md`

**Stories:** `/docs-claude/docs/stories/epic-*.md`
