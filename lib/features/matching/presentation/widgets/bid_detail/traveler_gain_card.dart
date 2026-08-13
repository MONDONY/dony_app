import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';

/// Net reçu par le voyageur (= [BidModel.totalAmountEur], fallback
/// `pricePerKg × weightKg`). `null` si indéterminable.
double? travelerNetAmount(BidModel bid) {
  if (bid.totalAmountEur != null) {
    return bid.totalAmountEur;
  }
  if (bid.pricePerKg != null && bid.weightKg != null) {
    return bid.pricePerKg! * bid.weightKg!;
  }
  return null;
}

/// Montant net formaté dans la devise du bid, ou `—`.
String travelerAmountLabel(BidModel bid) {
  final a = travelerNetAmount(bid);
  return a != null ? formatPriceIn(a, bid.currency) : '-';
}

/// Carte gain voyageur — montant reçu + état séquestre.
class TravelerGainCard extends StatelessWidget {
  final BidModel bid;
  const TravelerGainCard({super.key, required this.bid});

  static const _terminal = {'COMPLETED', 'DELIVERED'};
  static const _cancelled = {'CANCELLED', 'REJECTED', 'NO_SHOW', 'EXPIRED'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final amount = travelerAmountLabel(bid);
    final isCash = bid.paymentMethod != BidPaymentMethod.stripe;

    late final String topLabel;
    late final Color amountColor;
    // Seul l'encaissement en espèces reformule le montant ; les autres états
    // ne diffèrent que par le libellé, la couleur et la pastille.
    var amountText = amount;
    String? note;
    _Pill? pill;

    if (isCash) {
      topLabel = 'VOUS ENCAISSEZ';
      amountText = '$amount en espèces';
      amountColor = cs.onSurface;
      note = 'Commission Yadony prélevée séparément.';
      pill = _Pill(
        label: 'ESPÈCES',
        fg: cs.onSurface,
        bg: cs.surfaceContainerHighest,
      );
    } else if (_terminal.contains(bid.status)) {
      topLabel = 'VOUS AVEZ REÇU';
      amountColor = cs.success;
      pill = _Pill(
        label: '● Reçu',
        fg: cs.success,
        bg: cs.success.withValues(alpha: 0.12),
      );
    } else if (_cancelled.contains(bid.status)) {
      topLabel = 'PAIEMENT';
      amountColor = cs.onSurfaceVariant;
      note = 'Paiement annulé.';
    } else {
      topLabel = 'VOUS RECEVEZ';
      amountColor = cs.onSurface;
      note = 'Libéré à la livraison.';
      pill = _Pill(
        label: '🔒 séquestré',
        fg: cs.primary,
        bg: cs.primary.withValues(alpha: 0.10),
      );
    }

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                // FittedBox scaleDown : le montant (ex. « 1250.00 € en
                // espèces ») reste sur une ligne et rétrécit au lieu de
                // wrapper quand le _Pill comprime la colonne ou à textScale
                // élevé — préserve la hiérarchie visuelle de la carte.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amountText,
                    maxLines: 1,
                    style: tt.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    note,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (pill != null) ...[const SizedBox(width: DonySpacing.sm), pill],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
