import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Écran plein « Demande acceptée ! » affiché quand le voyageur accepte une
/// demande, route hors shell `/bids/:bidId/accepted`.
///
/// Remplace la snackbar furtive de l'écran « À traiter » : la demande
/// acceptée quittait aussitôt la liste, l'écran tombait sur « Aucune demande
/// à traiter » et le voyageur, de retour d'une recharge de portefeuille,
/// n'avait pas le temps de comprendre ce qui s'était passé (Sentry
/// FLUTTER-7N). Le CTA ouvre la demande à la place de cet écran (le retour
/// ramène alors à la liste) ; le bouton fermer revient à l'écran d'origine.
class BidAcceptedSuccessScreen extends StatelessWidget {
  const BidAcceptedSuccessScreen({super.key, required this.bidId});

  /// Demande acceptée, cible du CTA « Voir la demande ».
  final String bidId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.succes,
      title: l.bidAcceptedSuccessTitle,
      subtitle: l.bidAcceptedSuccessSubtitle,
      ctaLabel: l.bidAcceptedSuccessCta,
      onCta: () => context.pushReplacement('/bids/$bidId'),
      onClose: () => context.canPop() ? context.pop() : context.go('/home'),
      analyticsContext: 'bid_accepted',
    );
  }
}
