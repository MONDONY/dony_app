import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';

/// Carte « Paiement » (vue expéditeur).
///
/// Affiche l'état du paiement selon la méthode ([BidPaymentMethod]) et le
/// statut du bid.
///
/// — Stripe :
///   • COMPLETED / DELIVERED → montant libéré au voyageur (check vert)
///   • CANCELLED / REJECTED / NO_SHOW / EXPIRED → remboursé
///   • sinon → séquestré, libéré à la livraison (lock)
///
/// — Cash / Wave / Orange Money : paiement en personne à la remise.
class PaiementCard extends StatelessWidget {
  final BidModel bid;

  const PaiementCard({super.key, required this.bid});

  static const _terminalStatuses = {'COMPLETED', 'DELIVERED'};

  static const _cancelledStatuses = {
    'CANCELLED',
    'REJECTED',
    'NO_SHOW',
    'EXPIRED',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // senderLabel : ce que paie l'expéditeur (brut séquestré/remboursé, ou net
    // en cash). On n'affiche jamais le net du voyageur à l'expéditeur.
    final senderLabel = _fmt(
      bid.totalSenderAmountEur ?? bid.totalAmountEur,
      bid.currency,
    );

    Widget body;

    if (bid.paymentMethod == BidPaymentMethod.stripe) {
      body = _stripeBody(context, cs, tt, senderLabel);
    } else {
      // Cash / Wave / Orange Money — règlement en personne (net voyageur)
      body = Row(
        children: [
          DonyIcon('banknote', color: cs.warning, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'À régler en espèces à la remise : $senderLabel',
              style: tt.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          const DonyBadge(label: 'CASH', type: DonyBadgeType.warning),
        ],
      );
    }

    return DetailCard(title: 'Paiement', child: body);
  }

  Widget _stripeBody(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    String senderLabel,
  ) {
    final status = bid.status;

    if (_terminalStatuses.contains(status)) {
      // Affiché à l'expéditeur : son paiement (brut) a été libéré. On ne
      // montre jamais le net que touche le voyageur.
      return Row(
        children: [
          DonyIcon('circle-check', color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'Paiement libéré ✓',
              style: tt.bodySmall?.copyWith(color: cs.success),
            ),
          ),
        ],
      );
    }

    if (_cancelledStatuses.contains(status)) {
      // L'expéditeur récupère ce qu'il a payé = net + commission.
      return Row(
        children: [
          DonyIcon('refresh-cw', color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              '$senderLabel remboursé',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    // Default — en séquestre : montant payé par l'expéditeur (net + commission).
    return Row(
      children: [
        DonyIcon('lock', color: cs.primary, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            '$senderLabel séquestré : libéré à la livraison',
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  static String _fmt(double? v, String currency) =>
      v != null ? formatPriceIn(v, currency) : '-';
}
