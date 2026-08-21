import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';

/// Confirme au serveur qu'un paiement Stripe vient d'être autorisé, sans jamais
/// relancer vers l'appelant.
///
/// Filet client de la promotion du bid `AWAITING_PAYMENT` → `PAYMENT_ESCROWED`,
/// doublant le webhook Stripe. Sans lui, un bid dont l'escrow est bien actif
/// reste « à payer » côté expéditeur, qui ne peut alors ni payer (409
/// `payment-already-completed`) ni reposter sur le trajet.
///
/// Deux règles d'usage, apprises d'un vrai incident :
///
/// - **Ne dépend d'aucun `BuildContext`** : la subordonner au montage d'un
///   écran (ou à un BLoC détenu par cet écran, fermé dans `dispose()`) fait
///   sauter la confirmation exactement au moment où l'écran se ferme après le
///   paiement — le cas nominal.
/// - **Doit être `await`ée avant de quitter l'écran**, jamais `unawaited` :
///   c'est cette attente qui garantit que la requête part.
///
/// L'échec ne remonte pas à l'utilisateur — deux filets serveur subsistent (le
/// webhook Stripe, et l'auto-réparation au prochain checkout, cf.
/// `BidCheckoutService.settleIfAlreadyEscrowed`) — mais il est **rapporté**,
/// sans quoi la dérive que ce code existe pour corriger redeviendrait
/// silencieuse en production.
Future<void> confirmBidPaymentSafely(String bidId) async {
  try {
    await getIt<BidRepository>().confirmPayment(bidId);
  } catch (e, stackTrace) {
    if (getIt.isRegistered<ErrorReportingService>()) {
      await getIt<ErrorReportingService>().report(
        e,
        operation: 'bid.confirmPayment',
        stackTrace: stackTrace,
      );
    }
  }
}
