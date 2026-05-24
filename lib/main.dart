import 'package:dony/app/app.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/settings/data/connected_devices_repository.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

const _environment = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'development',
);

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

Future<void> _bootstrap() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }
  // Edge-to-edge : l'app dessine derrière la barre nav Android.
  // systemNavigationBarColor transparent supprime le scrim noir par défaut.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  // Maintient la native splash visible jusqu'à ce que Flutter soit prêt
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await initializeDateFormatting('fr');

  // Fail-fast on misconfigured release builds (a release shipped without
  // --dart-define-from-file would silently call http://localhost and use
  // an empty Stripe key).
  if (!kDebugMode) {
    if (!_apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL must use https in release builds (got "$_apiBaseUrl")',
      );
    }
    if (!_stripePublishableKey.startsWith('pk_')) {
      throw StateError(
        'STRIPE_PUBLISHABLE_KEY missing or malformed in release build',
      );
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Stripe doit être initialisé avant runApp
  Stripe.publishableKey = _stripePublishableKey;
  await Stripe.instance.applySettings();

  await setupDependencies(apiBaseUrl: _apiBaseUrl);
  // Hive doit être ouvert avant runApp : AppPreferencesBloc accède à
  // userPrefs dès le premier build() de DonyApp.
  await getIt<HiveService>().init();

  // Détection de révocation : si la session est restaurée mais que cet appareil
  // a été révoqué depuis un autre appareil, on déconnecte avant runApp.
  // Avant runApp = le listener authStateChanges d'app.dart n'existe pas encore,
  // donc aucune ré-inscription concurrente n'est possible.
  // Un démarrage à froid avec currentUser != null est forcément une session
  // restaurée (le login interactif se fait après) : "non enregistré" = révoqué.
  final restoredUser = FirebaseAuth.instance.currentUser;
  if (restoredUser != null) {
    final stillRegistered = await getIt<ConnectedDevicesRepository>()
        .isCurrentDeviceRegistered()
        .timeout(const Duration(seconds: 4), onTimeout: () => true);
    if (!stillRegistered) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // Show UI immediately — splash screen handles loading state
  runApp(const DonyApp());

  // Heavy async init runs after UI is displayed (no ANR risk)
  getIt<OfflineSyncService>().startListening();
  await getIt<NotificationService>().initialize();
}

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _bootstrap();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.1;
      options.environment = _environment;
      options.sendDefaultPii = false;
    },
    appRunner: _bootstrap,
  );
}
