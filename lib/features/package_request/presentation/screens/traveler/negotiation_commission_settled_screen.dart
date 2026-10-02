import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/return_to_thread.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Écran plein « Ce colis est à toi ! » affiché quand le voyageur a réglé la
/// commission Yadony d'un accord en espèces, route hors shell
/// `/negotiations/:id/commission-settled`.
///
/// Remplace la snackbar furtive du fil (Sentry FLUTTER-7N) : au retour d'une
/// recharge de portefeuille, le règlement aboutissait sans que le voyageur
/// ait le temps de le voir. Le CTA et le bouton fermer ramènent au fil,
/// rechargé entre-temps sur l'état accepté.
class NegotiationCommissionSettledScreen extends StatelessWidget {
  const NegotiationCommissionSettledScreen({super.key, required this.threadId});

  /// Fil de négociation dont la commission vient d'être réglée.
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonySuccessScreen(
      mascotteType: DonyMascotteType.succes,
      title: l.negotiationCommissionSettledTitle,
      subtitle: l.negotiationCommissionSettledSubtitle,
      ctaLabel: l.negotiationViewNegotiationCta,
      onCta: () => returnToNegotiationThread(context, threadId),
      onClose: () => returnToNegotiationThread(context, threadId),
      analyticsContext: 'negotiation_commission_settled',
    );
  }
}
