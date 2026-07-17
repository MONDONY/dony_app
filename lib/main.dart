import 'dart:async';

import 'package:dony/app/app.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_bloc_observer.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
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

const _posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');

const _posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://eu.i.posthog.com',
);

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
  // E2E_ALLOW_HTTP (dart-define, jamais en release) : autorise un API_BASE_URL
  // http en build profile pour les tests perf locaux (flutter drive --profile
  // contre le backend dev). Faux par défaut → garde-fou release intact ; un
  // flag compile-time explicite ne peut pas survenir dans un vrai build store.
  const allowHttp = bool.fromEnvironment('E2E_ALLOW_HTTP');
  if (!kDebugMode) {
    if (!allowHttp && !_apiBaseUrl.startsWith('https://')) {
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
  // Apple Pay : merchant ID Apple (effectif une fois le certificat Apple créé).
  Stripe.merchantIdentifier = 'merchant.app.dony';
  // Retour de redirection PayPal vers l'app (scheme déjà déclaré natif).
  Stripe.urlScheme = 'dony';
  await Stripe.instance.applySettings();

  await setupDependencies(apiBaseUrl: _apiBaseUrl);
  // Hive doit être ouvert avant runApp : AppPreferencesBloc accède à
  // userPrefs dès le premier build() de DonyApp.
  await getIt<HiveService>().init();

  // PostHog : init manuelle (clé via --dart-define-from-file).
  // Clé absente (ex: build dev sans variable) → service reste no-op, pas de crash.
  if (_posthogApiKey.isNotEmpty) {
    final config = PostHogConfig(_posthogApiKey)
      ..host = _posthogHost
      ..debug = kDebugMode
      // Opt-out par défaut : on bascule en opt-in uniquement après consentement.
      ..optOut = true
      ..sessionReplay = true
      ..sessionReplayConfig.maskAllTexts = true
      ..sessionReplayConfig.maskAllImages = true;
    await Posthog().setup(config);
    // Rétablit l'état opt-in/out selon le consentement déjà stocké dans Hive.
    await getIt<AnalyticsService>().onConfigured();
    Bloc.observer = AnalyticsBlocObserver(getIt<AnalyticsService>());
  }

  // NB : on ne déconnecte plus au démarrage sur un « appareil non enregistré ».
  // Ce contrôle était fail-dangerous : l'enregistrement d'appareil dépend d'un
  // token FCM (cf. NotificationService.uploadCurrentToken), or sur iOS sans APNs
  // ce token est null → l'appareil n'est jamais enregistré → « non enregistré »
  // était interprété à tort comme « révoqué » → signOut() à chaque ouverture →
  // OTP redemandé en boucle. La révocation cross-device doit être ré-appliquée
  // côté backend (rejet du token → 401), pas par une heuristique cliente.

  // Show UI immediately — splash screen handles loading state
  runApp(const DonyApp());

  // Heavy async init runs after UI is displayed (no ANR risk)
  getIt<OfflineSyncService>().startListening();
  await getIt<NotificationService>().initialize();

  // Taux de commission Dony (SOURCE UNIQUE : dony.commission.rate côté backend) :
  // chargé une fois pour que les prix calculés côté app (aperçu checkout, repli des
  // surfaces sans champ *Display) suivent automatiquement. Non bloquant.
  unawaited(_loadDonyCommissionRate());

  // Seuil d'urgence Dony (SOURCE UNIQUE : dony.urgency.threshold-days côté backend) :
  // chargé une fois pour que le badge « urgent » suive automatiquement. Non bloquant.
  unawaited(_loadUrgencyThreshold());
}

Future<void> _loadDonyCommissionRate() async {
  try {
    setDonyCommissionRate(await getIt<IConfigRepository>().getCommissionRate());
  } catch (_) {
    // Repli sur kDonyCommissionRateDefault conservé — non bloquant.
  }
}

Future<void> _loadUrgencyThreshold() async {
  try {
    setUrgencyThresholdDays(
      await getIt<IConfigRepository>().getUrgencyThresholdDays(),
    );
  } catch (_) {
    // Repli sur kUrgencyThresholdDaysDefault conservé — non bloquant.
  }
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
