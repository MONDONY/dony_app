import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../helpers/app_driver.dart';

/// Tests E2E — flux de retour D7 (bid CANCELLED + isAwaitingReturn == true).
///
/// IMPORTANT : un seul testWidgets pour éviter le redémarrage de l'app.
/// Les parties expéditeur/voyageur sont sélectionnées selon le bid configuré.
///
/// Pré-requis backend :
///   Le bid [BID_CANCELLED_RETURN_*] doit avoir :
///     - status = CANCELLED
///     - returnDeadline != null  (annulation après remise initiée)
///     - returnedAt == null      (colis pas encore restitué)
///
/// Lancement expéditeur (Android) :
/// ```bash
/// flutter test integration_test/cancellation/flux_retour_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_CANCELLED_RETURN_S=UUID \
///   -d emulator-5554
/// ```
///
/// Lancement voyageur (iOS) :
/// ```bash
/// flutter test integration_test/cancellation/flux_retour_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_CANCELLED_RETURN_T=UUID \
///   -d IOS_DEVICE_ID
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flux retour D7 — code de retour / confirmer', (tester) async {
    await launchAndReady(tester);

    var testedCount = 0;

    // ── Expéditeur ─────────────────────────────────────────────────────────
    if (kBidCancelledReturnS.isNotEmpty) {
      await navigateToBid(tester, kBidCancelledReturnS);
      expect(
        find.text('Code de retour'),
        findsOneWidget,
        reason:
            'Expéditeur doit voir le bouton "Code de retour" '
            'quand le colis est en attente de restitution (D7)',
      );
      expect(find.text('Confirmer le retour'), findsNothing,
          reason: 'Bouton "Confirmer le retour" réservé au voyageur');
      testedCount++;
    }

    // ── Voyageur ────────────────────────────────────────────────────────────
    if (kBidCancelledReturnT.isNotEmpty) {
      await navigateToBid(tester, kBidCancelledReturnT);
      expect(
        find.text('Confirmer le retour'),
        findsOneWidget,
        reason:
            'Voyageur doit voir le bouton "Confirmer le retour" '
            'pour saisir le code de retour (D7)',
      );
      expect(find.text('Code de retour'), findsNothing,
          reason: 'Bouton "Code de retour" réservé à l\'expéditeur');
      testedCount++;
    }

    if (testedCount == 0) {
      throw UnsupportedError(
        'Aucun BID_CANCELLED_RETURN_* configuré. '
        'Passer --dart-define=BID_CANCELLED_RETURN_T=<uuid> ou BID_CANCELLED_RETURN_S=<uuid>.',
      );
    }
  });
}
