import 'package:dony/app/app.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Stripe doit être initialisé avant runApp
  Stripe.publishableKey = _stripePublishableKey;
  await Stripe.instance.applySettings();

  await setupDependencies(apiBaseUrl: _apiBaseUrl);

  // Show UI immediately — splash screen handles loading state
  runApp(const DonyApp());

  // Heavy async init runs after UI is displayed (no ANR risk)
  await getIt<HiveService>().init();
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
