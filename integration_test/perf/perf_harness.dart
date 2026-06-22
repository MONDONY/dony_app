// integration_test/perf/perf_harness.dart
//
// Harness partagé pour tous les scénarios de performance UI.
// Boot, navigation, fling et dump réseau.

// ignore_for_file: avoid_print, unawaited_futures

import 'package:dony/core/network/metrics_interceptor.dart';
import 'package:dony/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ── Flag singleton : app.main() ne doit être appelé qu'une seule fois ────────
bool _appLaunched = false;

/// Pompe des frames jusqu'à ce que [condition] soit vraie ou jusqu'au timeout.
/// Identique au pattern de integration_test/helpers/app_driver.dart.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxIterations = 60,
  Duration step = const Duration(milliseconds: 500),
}) async {
  for (var i = 0; i < maxIterations; i++) {
    if (condition()) {
      return true;
    }
    await tester.pump(step);
  }
  return condition();
}

/// Ferme les routes modales (bottom sheets, dialogs) empilées sur le root
/// navigator. Même mécanique que _closeOverlays dans app_driver.dart.
Future<void> _closeOverlays(WidgetTester tester) async {
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isEmpty) {
    return;
  }
  final nav = tester.state<NavigatorState>(navFinder.first);
  var guard = 0;
  while (nav.canPop() && guard < 5) {
    nav.pop();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    guard++;
  }
}

/// Saisit le PIN digit par digit (identique à _handlePinIfPresent dans app_driver.dart).
Future<void> _handlePinIfPresent(WidgetTester tester) async {
  await _closeOverlays(tester);
  if (find.text('Saisissez votre code PIN').evaluate().isEmpty) {
    print('[perf_harness] Pas d\'écran PIN (app déjà déverrouillée ?)');
    return;
  }
  print('[perf_harness] Écran PIN détecté — saisie de 123456');
  await _pumpUntil(
    tester,
    () => find.text('1').evaluate().isNotEmpty,
    maxIterations: 20,
  );
  for (final digit in '123456'.split('')) {
    await _pumpUntil(
      tester,
      () => find.text(digit).evaluate().isNotEmpty,
      maxIterations: 10,
    );
    final key = find.text(digit);
    if (key.evaluate().isEmpty) {
      print('[perf_harness] touche $digit absente — abandon');
      break;
    }
    await tester.tap(key.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Lance l'application et attend que le home soit prêt.
///
/// Réutilise exactement la mécanique de launchAndReady() dans
/// integration_test/helpers/app_driver.dart : app.main() une seule fois,
/// attente active de l'écran PIN ou du home, saisie du PIN 123456,
/// fermeture des overlays (RatingBottomSheet, etc.).
Future<void> bootToHome(WidgetTester tester) async {
  if (_appLaunched) {
    tester.takeException();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await _closeOverlays(tester);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    tester.takeException();
    return;
  }
  _appLaunched = true;

  final originalHandler = FlutterError.onError;
  app.main();

  // Attente active : écran PIN ou home (même tolérance que app_driver.dart : ~45 s).
  await _pumpUntil(
    tester,
    () =>
        find.text('Saisissez votre code PIN').evaluate().isNotEmpty ||
        find.byTooltip('Options').evaluate().isNotEmpty ||
        find.text('Rechercher').evaluate().isNotEmpty,
    maxIterations: 90, // ~45 s
  );

  FlutterError.onError = originalHandler;
  tester.takeException();

  await _handlePinIfPresent(tester);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  // Fermer un éventuel RatingBottomSheet qui s'ouvre au démarrage.
  await _closeOverlays(tester);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  tester.takeException();
}

/// Effectue un fling sur le finder [f] avec le vecteur [offset] et
/// la vitesse [speed] (par défaut 2000 px/s).
Future<void> fling(
  WidgetTester tester,
  Finder f,
  Offset offset, {
  double speed = 2000,
}) async {
  await tester.fling(f, offset, speed);
  await tester.pumpAndSettle();
}

/// Pousse les métriques réseau du scénario [scenario] dans
/// `binding.reportData` pour que le driver host-side les écrive dans
/// `build/perf/`, puis vide le collector.
///
/// IMPORTANT : on ne peut PAS écrire de fichiers depuis l'app sur un device
/// physique (FS sandbox read-only). Tout transite par reportData, comme la
/// timeline. Le driver (test_driver/perf_driver.dart) sérialise :
///   `reportData['network-<scenario>']` (Map) → `build/perf/network-<scenario>.json`
///   `reportData['raw-<scenario>']` (List) → `build/perf/raw-<scenario>.json`
///
/// Utilise MetricsInterceptor.globalCollector (NetworkMetricsCollector).
Future<void> dumpNetwork(String scenario) async {
  final collector = MetricsInterceptor.globalCollector;
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final data = binding.reportData ??= <String, dynamic>{};
  data['network-$scenario'] = collector.toJson();
  data['raw-$scenario'] = collector.rawSamplesJson();
  collector.clear();
}
