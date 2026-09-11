import 'package:dony/core/design/design_system.dart';
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
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: 'Offre acceptée et payée !',
      subtitle:
          'Ton argent est bloqué et sécurisé, le voyageur ne le reçoit qu\'après confirmation de la livraison. Suis ton colis depuis le fil.',
      ctaLabel: 'Voir le suivi',
      onCta: () => context.go('/negotiations/$threadId'),
      analyticsContext: 'negotiation_payment',
    );
  }
}
