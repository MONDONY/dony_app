import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../helpers/app_driver.dart';

/// Tests E2E — vérifie l'ABSENCE d'options d'annulation pour les statuts
/// IN_TRANSIT et COMPLETED (règle D3 : ces statuts ne sont jamais annulables).
///
/// IMPORTANT : un seul testWidgets pour éviter le redémarrage de l'app entre
/// les statuts IN_TRANSIT et COMPLETED (même device, même run).
///
/// Lancement voyageur (iOS) :
/// ```bash
/// flutter test integration_test/cancellation/pas_annulable_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_IN_TRANSIT_T=UUID \
///   --dart-define=BID_COMPLETED_T=UUID \
///   -d IOS_DEVICE_ID
/// ```
///
/// Lancement expéditeur (Android) :
/// ```bash
/// flutter test integration_test/cancellation/pas_annulable_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_IN_TRANSIT_S=UUID \
///   --dart-define=BID_COMPLETED_S=UUID \
///   -d emulator-5554
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'IN_TRANSIT et COMPLETED — aucune option d\'annulation',
    (tester) async {
      await launchAndReady(tester);

      var testedCount = 0;

      // ── IN_TRANSIT voyageur ────────────────────────────────────────────
      if (kBidInTransitT.isNotEmpty) {
        await navigateToBid(tester, kBidInTransitT);
        await openOptions(tester);
        expect(find.text('Annuler le trajet'), findsNothing,
            reason: 'IN_TRANSIT n\'est jamais annulable côté voyageur (D3)');
        testedCount++;
      }

      // ── IN_TRANSIT expéditeur ──────────────────────────────────────────
      if (kBidInTransitS.isNotEmpty) {
        await navigateToBid(tester, kBidInTransitS);
        await openOptions(tester);
        expect(
          find.text('Votre paiement sera remboursé automatiquement'),
          findsNothing,
          reason: 'Option annulation PENDING absente pour IN_TRANSIT',
        );
        expect(
          find.text('Remboursement intégral · vous récupérez votre colis'),
          findsNothing,
          reason: 'Option annulation afterHandover absente pour IN_TRANSIT',
        );
        testedCount++;
      }

      // ── COMPLETED voyageur ─────────────────────────────────────────────
      if (kBidCompletedT.isNotEmpty) {
        await navigateToBid(tester, kBidCompletedT);
        await openOptions(tester);
        expect(find.text('Annuler le trajet'), findsNothing,
            reason: 'COMPLETED n\'est pas annulable');
        testedCount++;
      }

      // ── COMPLETED expéditeur ───────────────────────────────────────────
      if (kBidCompletedS.isNotEmpty) {
        await navigateToBid(tester, kBidCompletedS);
        await openOptions(tester);
        expect(
          find.text('Votre paiement sera remboursé automatiquement'),
          findsNothing,
        );
        expect(
          find.text('Remboursement intégral · vous récupérez votre colis'),
          findsNothing,
        );
        testedCount++;
      }

      if (testedCount == 0) {
        throw UnsupportedError(
          'Aucun BID_IN_TRANSIT_* ou BID_COMPLETED_* configuré. '
          'Passer au moins un --dart-define=BID_IN_TRANSIT_T=<uuid>.',
        );
      }
    },
  );
}
