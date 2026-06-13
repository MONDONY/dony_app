import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../helpers/app_driver.dart';

/// Tests E2E — annulation AVANT remise du colis.
///
/// IMPORTANT : UN SEUL testWidgets pour éviter le redémarrage de l'app par
/// IntegrationTestWidgetsFlutterBinding entre tests. Les parties voyageur et
/// expéditeur sont activées par gate selon le bid configuré (un device à la fois).
///
/// Appareil cible :
///   - Voyageur (iOS) → BID_ACCEPTED
///   - Expéditeur (Android) → BID_PENDING
///
/// Lancement voyageur :
/// ```bash
/// flutter test integration_test/cancellation/avant_remise_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_ACCEPTED=UUID \
///   -d IOS_DEVICE_ID
/// ```
///
/// Lancement expéditeur :
/// ```bash
/// flutter test integration_test/cancellation/avant_remise_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_PENDING=UUID \
///   -d emulator-5554
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('avant remise — voyageur et/ou expéditeur', (tester) async {
    await launchAndReady(tester);

    var testedCount = 0;

    // ── Voyageur / bid ACCEPTED ─────────────────────────────────────────────
    if (kBidAccepted.isNotEmpty) {
      await navigateToBid(tester, kBidAccepted);
      await openOptions(tester);

      // 1. Option "Annuler le trajet" visible avec bon sous-titre
      expect(find.text('Annuler le trajet'), findsOneWidget);
      expect(
        find.text("L'expéditeur sera remboursé automatiquement"),
        findsOneWidget,
        reason: 'Sous-titre cas ACCEPTED (avant remise)',
      );

      // 2. Taper → dialog annulation affiché
      await tester.tap(find.text('Annuler le trajet'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler cette demande ?'), findsOneWidget);
      expect(
        find.text("L'expéditeur sera remboursé automatiquement."),
        findsOneWidget,
        reason: 'Sous-titre présent dans le dialog',
      );
      expect(
        find.textContaining('Le colis a déjà été remis'),
        findsNothing,
        reason: 'Pas de warning rouge pour le cas avant remise',
      );
      expect(find.text('Motif (optionnel)'), findsOneWidget);
      expect(find.text('Garder'), findsOneWidget);

      // 3. "Garder" ferme le dialog sans déclencher d'annulation
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler cette demande ?'), findsNothing,
          reason: 'Dialog doit être fermé après "Garder"');
      testedCount++;
    }

    // ── Expéditeur / bid PENDING ────────────────────────────────────────────
    if (kBidPending.isNotEmpty) {
      await navigateToBid(tester, kBidPending);
      await openOptions(tester);

      // 1. Option "Annuler la demande" visible avec bon sous-titre
      expect(find.text('Annuler la demande'), findsOneWidget);
      expect(
        find.text('Votre paiement sera remboursé automatiquement'),
        findsOneWidget,
      );

      // 2. Dialog confirmatif affiché
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.textContaining('Voulez-vous vraiment annuler'),
        findsOneWidget,
      );
      expect(find.text('Non'), findsOneWidget);
      expect(find.text('Oui, annuler'), findsOneWidget);

      // 3. "Non" ferme le dialog sans annuler
      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Voulez-vous vraiment annuler'), findsNothing,
          reason: 'Dialog doit être fermé après "Non"');
      testedCount++;
    }

    if (testedCount == 0) {
      throw UnsupportedError(
        'Aucun BID_ACCEPTED ou BID_PENDING configuré. '
        'Passer --dart-define=BID_ACCEPTED=<uuid> ou BID_PENDING=<uuid>.',
      );
    }
  });
}
