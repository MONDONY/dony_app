// ignore_for_file: avoid_print, unawaited_futures
import 'package:dony/app/router.dart';
import 'package:dony/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Bid IDs — injectés via --dart-define lors du lancement ───────────────────
// Voyageur (iOS) connecté en tant que VOYAGEUR sur chaque bid :
const kBidAccepted         = String.fromEnvironment('BID_ACCEPTED');
const kBidHandedOverT      = String.fromEnvironment('BID_HANDED_OVER_T');
const kBidInTransitT       = String.fromEnvironment('BID_IN_TRANSIT_T');
const kBidCompletedT       = String.fromEnvironment('BID_COMPLETED_T');
const kBidCancelledReturnT = String.fromEnvironment('BID_CANCELLED_RETURN_T');
// Expéditeur (Android) connecté en tant qu'EXPÉDITEUR sur chaque bid :
const kBidPending          = String.fromEnvironment('BID_PENDING');
const kBidHandedOverS      = String.fromEnvironment('BID_HANDED_OVER_S');
const kBidInTransitS       = String.fromEnvironment('BID_IN_TRANSIT_S');
const kBidCompletedS       = String.fromEnvironment('BID_COMPLETED_S');
const kBidCancelledReturnS = String.fromEnvironment('BID_CANCELLED_RETURN_S');

const _kPin = '123456';

// Flag global : app.main() ne doit être appelé qu'une seule fois par process.
bool _appLaunched = false;

/// Pompe des frames jusqu'à ce que [condition] soit vraie, ou jusqu'au timeout.
/// Plus robuste qu'un pumpAndSettle fixe : tolère un boot lent (restauration
/// Firebase Auth sur device physique) et les écrans avec animations continues.
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

/// Lance l'application UNE SEULE FOIS, attend l'écran PIN (jusqu'à ~45 s pour
/// tolérer la restauration de session Firebase sur device physique), le saisit,
/// puis attend la stabilisation.
Future<void> launchAndReady(WidgetTester tester) async {
  if (_appLaunched) {
    tester.takeException();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return;
  }
  _appLaunched = true;

  final originalHandler = FlutterError.onError;
  app.main();

  // Attendre activement un état post-splash : écran PIN (déverrouillage) OU
  // app déjà sur le home (bouton Options / sheet). Sur device physique la
  // restauration de session Firebase peut prendre >10 s.
  await _pumpUntil(
    tester,
    () =>
        find.text('Saisissez votre code PIN').evaluate().isNotEmpty ||
        find.byTooltip('Options').evaluate().isNotEmpty,
    maxIterations: 90, // ~45 s
  );

  FlutterError.onError = originalHandler;
  tester.takeException();

  await _handlePinIfPresent(tester);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  // Un RatingBottomSheet (notation en attente) peut s'ouvrir sur le home et
  // bloquer la navigation : on le ferme.
  await _closeOverlays(tester);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  tester.takeException();
}

/// Navigue vers l'écran de détail d'un bid via GoRouter, puis attend
/// activement que le bouton Options (signe que le bid est chargé) apparaisse.
/// Lance une [UnsupportedError] si [bidId] est vide.
Future<void> navigateToBid(WidgetTester tester, String bidId) async {
  if (bidId.isEmpty) {
    throw UnsupportedError(
      'BID non configuré — passer --dart-define=BID_XXX=<uuid> au lancement.',
    );
  }
  tester.takeException();
  // Fermer tout sheet/dialog laissé ouvert par un scénario précédent
  // (sheet Options non fermé pour les statuts non-annulables).
  await _closeOverlays(tester);
  appRouter.go('/bids/$bidId');
  // Attendre que le bid soit chargé (bouton Options présent dans l'AppBar).
  await _pumpUntil(
    tester,
    () => find.byTooltip('Options').evaluate().isNotEmpty,
    // défaut 60 itérations ≈ 30 s (skeleton → API → rendu)
  );
  await tester.pumpAndSettle(const Duration(seconds: 1));
  tester.takeException();
}

/// Ferme les routes modales (bottom sheets, dialogs) empilées sur le root
/// navigator via useRootNavigator:true. N'affecte pas les pages GoRouter
/// (un éventuel pop de page est corrigé par le appRouter.go() suivant).
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

/// Ouvre le sheet Options (bouton ⋮ dans l'AppBar).
Future<void> openOptions(WidgetTester tester) async {
  final btn = find.byTooltip('Options');
  expect(btn, findsOneWidget,
      reason: 'Bouton Options (⋮) introuvable dans l\'AppBar');
  await tester.tap(btn);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

// ── Privé ─────────────────────────────────────────────────────────────────────

Future<void> _handlePinIfPresent(WidgetTester tester) async {
  // Fermer un éventuel overlay (RatingBottomSheet) au-dessus du keypad.
  await _closeOverlays(tester);
  if (find.text('Saisissez votre code PIN').evaluate().isEmpty) {
    print('[app_driver] Pas d\'écran PIN (app déjà déverrouillée ?)');
    return;
  }
  print('[app_driver] Écran PIN détecté — saisie de $_kPin');
  // Attendre que le DonyKeypad soit rendu (la touche '1' présente).
  await _pumpUntil(
    tester,
    () => find.text('1').evaluate().isNotEmpty,
    maxIterations: 20, // ~10 s
  );
  for (final digit in _kPin.split('')) {
    // Attendre la touche au cas où le rendu traîne entre deux frappes.
    await _pumpUntil(
      tester,
      () => find.text(digit).evaluate().isNotEmpty,
      maxIterations: 10,
    );
    final key = find.text(digit);
    if (key.evaluate().isEmpty) {
      print('[app_driver] touche $digit absente — keypad indisponible, abandon');
      break;
    }
    await tester.tap(key.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle(const Duration(seconds: 3));
}
