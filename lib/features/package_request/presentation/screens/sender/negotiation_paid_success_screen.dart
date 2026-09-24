import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Écran plein « Offre acceptée et payée ! » affiché une fois le paiement
/// d'un fil de négociation séquestré, route hors shell
/// `/negotiations/:id/paid`.
///
/// Extrait du `DonySuccessScreen` que la branche carte de
/// `PaymentRecapBottomSheet` pousse encore par `Navigator.push` (code
/// antérieur à la règle GoRouter, hors périmètre du lot mobile money). La
/// branche mobile money passe par cette route ; la branche carte sera
/// ramenée dessus dans un lot ultérieur.
class NegotiationPaidSuccessScreen extends StatelessWidget {
  const NegotiationPaidSuccessScreen({super.key, required this.threadId});

  /// Fil de négociation payé, cible du CTA « Voir le suivi ».
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: l.negotiationOfferAcceptedPaidTitle,
      subtitle: l.negotiationOfferAcceptedPaidSubtitle,
      ctaLabel: l.negotiationTrackShipmentCta,
      onCta: () => context.go('/negotiations/$threadId'),
      analyticsContext: 'negotiation_payment',
    );
  }
}
