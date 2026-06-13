import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../helpers/app_driver.dart';

/// Tests E2E — annulation APRÈS remise (bid HANDED_OVER, avant le départ).
///
/// IMPORTANT : UN SEUL testWidgets pour éviter le redémarrage de l'app par
/// IntegrationTestWidgetsFlutterBinding entre tests. Les parties voyageur et
/// expéditeur sont activées par gate selon le bid configuré (un device à la fois).
///
/// Appareil cible :
///   - Voyageur (iOS) → BID_HANDED_OVER_T
///   - Expéditeur (Android) → BID_HANDED_OVER_S
///
/// Lancement voyageur :
/// ```bash
/// flutter test integration_test/cancellation/apres_remise_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_HANDED_OVER_T=UUID \
///   -d IOS_DEVICE_ID
/// ```
///
/// Lancement expéditeur :
/// ```bash
/// flutter test integration_test/cancellation/apres_remise_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_HANDED_OVER_S=UUID \
///   -d emulator-5554
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('après remise — voyageur et/ou expéditeur', (tester) async {
    await launchAndReady(tester);

    var testedCount = 0;

    // ── Voyageur / bid HANDED_OVER ──────────────────────────────────────────
    if (kBidHandedOverT.isNotEmpty) {
      await navigateToBid(tester, kBidHandedOverT);
      await openOptions(tester);

      // 1. Option visible + sous-titre restitution
      expect(find.text('Annuler le trajet'), findsOneWidget);
      expect(
        find.text('Vous devrez restituer le colis sous 3 jours'),
        findsOneWidget,
        reason: 'Sous-titre spécifique au cas HANDED_OVER (après remise)',
      );

      // 2. Dialog afterHandover : warning rouge
      await tester.tap(find.text('Annuler le trajet'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler cette demande ?'), findsOneWidget);
      expect(
        find.textContaining('Le colis a déjà été remis'),
        findsOneWidget,
        reason: 'Warning rouge obligatoire pour CancellationKind.afterHandover',
      );
      expect(
        find.text("L'expéditeur sera remboursé automatiquement."),
        findsNothing,
      );
      expect(
        find.textContaining("Motif de l'annulation"),
        findsOneWidget,
        reason: 'Champ motif obligatoire pour afterHandover',
      );
      expect(find.text('Garder'), findsOneWidget);

      // 3. Confirmer sans motif → erreur "Motif requis"
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('Motif requis'), findsOneWidget,
          reason: 'Validation : motif obligatoire pour afterHandover');
      expect(find.text('Annuler cette demande ?'), findsOneWidget,
          reason: 'Dialog toujours ouvert après erreur de validation');

      // 4. "Garder" ferme le dialog sans annuler
      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler cette demande ?'), findsNothing);
      testedCount++;
    }

    // ── Expéditeur / bid HANDED_OVER ────────────────────────────────────────
    if (kBidHandedOverS.isNotEmpty) {
      await navigateToBid(tester, kBidHandedOverS);
      await openOptions(tester);

      // 1. Option visible + sous-titre remboursement intégral
      expect(find.text('Annuler la demande'), findsOneWidget);
      expect(
        find.text('Remboursement intégral · vous récupérez votre colis'),
        findsOneWidget,
        reason: 'Sous-titre spécifique annulation après remise côté expéditeur',
      );

      // 2. Dialog "Annuler après remise ?" affiché
      final cancelTile = find.ancestor(
        of: find.text('Remboursement intégral · vous récupérez votre colis'),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(cancelTile.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler après remise ?'), findsOneWidget);
      expect(
        find.textContaining('Le colis est déjà chez le voyageur'),
        findsOneWidget,
      );
      expect(find.text('Non'), findsOneWidget);
      expect(find.text('Oui, annuler'), findsOneWidget);

      // 3. "Non" ferme le dialog sans annuler
      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Annuler après remise ?'), findsNothing);
      testedCount++;
    }

    if (testedCount == 0) {
      throw UnsupportedError(
        'Aucun BID_HANDED_OVER_T ou BID_HANDED_OVER_S configuré. '
        'Passer --dart-define=BID_HANDED_OVER_T=<uuid> ou BID_HANDED_OVER_S=<uuid>.',
      );
    }
  });
}
