import 'package:dony/app/app.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.1;
      options.environment = _environment;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      await setupDependencies(apiBaseUrl: _apiBaseUrl);
      await getIt<HiveService>().init();
      await getIt<NotificationService>().initialize();

      runApp(const DonyApp());
    },
  );
}
