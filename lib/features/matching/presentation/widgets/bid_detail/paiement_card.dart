import 'package:dony/core/design/design_system.dart';
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

  static const _terminalStatuses = {
    'COMPLETED',
    'DELIVERED',
  };

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
    // netLabel : ce que reçoit le voyageur (libéré / espèces).
    // senderLabel : ce que paie l'expéditeur = net + commission (séquestré /
    // remboursé). En cash, sender == net (la commission est prélevée au voyageur).
    final netLabel = _fmt(bid.totalAmountEur);
    final senderLabel = _fmt(bid.totalSenderAmountEur ?? bid.totalAmountEur);

    Widget body;

    if (bid.paymentMethod == BidPaymentMethod.stripe) {
      body = _stripeBody(context, cs, tt, netLabel, senderLabel);
    } else {
      // Cash / Wave / Orange Money — règlement en personne (net voyageur)
      body = Row(
        children: [
          Icon(Icons.payments_outlined, color: cs.warning, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'À régler en espèces à la remise : $netLabel',
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
    String netLabel,
    String senderLabel,
  ) {
    final status = bid.status;

    if (_terminalStatuses.contains(status)) {
      // Montant effectivement versé au voyageur = net.
      return Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              '$netLabel libéré au voyageur ✓',
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
          Icon(
            Icons.replay_rounded,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
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
        Icon(Icons.lock_outline_rounded, color: cs.primary, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            '$senderLabel séquestré — libéré à la livraison',
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }

  static String _fmt(double? v) => v != null ? '${v.toStringAsFixed(2)} €' : '—';
}
