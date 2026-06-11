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
    final amount = bid.totalAmountEur;
    final amountLabel = amount != null ? '${amount.toStringAsFixed(2)} €' : '—';

    Widget body;

    if (bid.paymentMethod == BidPaymentMethod.stripe) {
      body = _stripeBody(context, cs, tt, amountLabel);
    } else {
      // Cash / Wave / Orange Money — règlement en personne
      body = Row(
        children: [
          Icon(Icons.payments_outlined, color: cs.warning, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              'À régler en espèces à la remise : $amountLabel',
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
    String amountLabel,
  ) {
    final status = bid.status;

    if (_terminalStatuses.contains(status)) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              '$amountLabel libéré au voyageur ✓',
              style: tt.bodySmall?.copyWith(color: cs.success),
            ),
          ),
        ],
      );
    }

    if (_cancelledStatuses.contains(status)) {
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
              '$amountLabel remboursé',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    // Default — en séquestre
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, color: cs.primary, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            '$amountLabel séquestré — libéré à la livraison',
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
