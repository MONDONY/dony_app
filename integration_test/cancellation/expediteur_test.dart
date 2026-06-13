import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../helpers/app_driver.dart';

/// Tests E2E — parcours EXPÉDITEUR complet (tous les statuts) en UN SEUL
/// testWidgets / UN SEUL install.
///
/// Pourquoi un fichier unique : chaque `flutter test` réinstalle l'apk, ce qui
/// finit par effacer la session Firebase du device (déconnexion). En regroupant
/// tous les statuts dans un seul fichier, l'app n'est installée et déverrouillée
/// (PIN) qu'une fois → la session connectée est préservée.
///
/// Device cible : Android, connecté en tant qu'EXPÉDITEUR (kadidia) des bids.
///
/// Lancement :
/// ```bash
/// flutter test integration_test/cancellation/expediteur_test.dart \
///   --dart-define-from-file=env.dev.json \
///   --dart-define=BID_PENDING=UUID \
///   --dart-define=BID_HANDED_OVER_S=UUID \
///   --dart-define=BID_IN_TRANSIT_S=UUID \
///   --dart-define=BID_COMPLETED_S=UUID \
///   --dart-define=BID_CANCELLED_RETURN_S=UUID \
///   -d ANDROID_DEVICE_ID
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('expéditeur — annulation selon statut', (tester) async {
    await launchAndReady(tester);

    var testedCount = 0;

    // ── PENDING — avant remise : "Annuler la demande" + dialog confirmatif ──
    if (kBidPending.isNotEmpty) {
      await navigateToBid(tester, kBidPending);
      await openOptions(tester);

      expect(find.text('Annuler la demande'), findsOneWidget,
          reason: 'PENDING : option d\'annulation visible côté expéditeur');
      expect(
        find.text('Votre paiement sera remboursé automatiquement'),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Voulez-vous vraiment annuler'), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
      expect(find.text('Oui, annuler'), findsOneWidget);

      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Voulez-vous vraiment annuler'), findsNothing);
      testedCount++;
    }

    // ── HANDED_OVER — après remise : dialog "Annuler après remise ?" ────────
    if (kBidHandedOverS.isNotEmpty) {
      await navigateToBid(tester, kBidHandedOverS);
      await openOptions(tester);

      expect(find.text('Annuler la demande'), findsOneWidget);
      expect(
        find.text('Remboursement intégral · vous récupérez votre colis'),
        findsOneWidget,
        reason: 'HANDED_OVER : sous-titre annulation après remise',
      );

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

      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Annuler après remise ?'), findsNothing);
      testedCount++;
    }

    // ── IN_TRANSIT — aucune option d'annulation (D3) ────────────────────────
    if (kBidInTransitS.isNotEmpty) {
      await navigateToBid(tester, kBidInTransitS);
      await openOptions(tester);

      expect(
        find.text('Votre paiement sera remboursé automatiquement'),
        findsNothing,
        reason: 'IN_TRANSIT : option annulation PENDING absente',
      );
      expect(
        find.text('Remboursement intégral · vous récupérez votre colis'),
        findsNothing,
        reason: 'IN_TRANSIT : option annulation afterHandover absente',
      );
      testedCount++;
    }

    // ── COMPLETED — aucune option d'annulation ──────────────────────────────
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

    // ── CANCELLED + retour D7 — bouton "Code de retour" ─────────────────────
    if (kBidCancelledReturnS.isNotEmpty) {
      await navigateToBid(tester, kBidCancelledReturnS);

      expect(find.text('Code de retour'), findsOneWidget,
          reason: 'Expéditeur voit "Code de retour" en attente de restitution (D7)');
      expect(find.text('Confirmer le retour'), findsNothing,
          reason: 'Bouton "Confirmer le retour" réservé au voyageur');
      testedCount++;
    }

    if (testedCount == 0) {
      throw UnsupportedError(
        'Aucun BID expéditeur configuré. Passer au moins '
        '--dart-define=BID_PENDING=<uuid> (et/ou les autres BID_*_S).',
      );
    }
  });
}
