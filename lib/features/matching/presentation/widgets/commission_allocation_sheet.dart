import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/commission_allocation_preview.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Avant d'accepter un colis payé en espèces, dit au voyageur d'où partira la
/// commission quand elle ne vient pas du seul portefeuille de la devise du
/// colis : une ligne par portefeuille débité, avec le taux du jour des parts
/// converties. Rend `true` pour poursuivre l'acceptation, `false` si le
/// voyageur ferme la feuille.
///
/// Rend aussi `true`, sans rien afficher, pour un autre moyen de paiement,
/// quand un seul portefeuille suffit sans conversion, quand les portefeuilles
/// ne couvrent pas la commission (la feuille « Solde insuffisant » prend le
/// relais) et quand l'aperçu est indisponible (ancien back, hors ligne) : il
/// est indicatif, il ne doit jamais bloquer une acceptation.
Future<bool> confirmCashCommissionAllocation(
  BuildContext context,
  BidModel bid, {
  BidRepository? repository,
}) async {
  if (bid.paymentMethod != BidPaymentMethod.cash) return true;
  final CommissionAllocationPreview preview;
  try {
    preview = await (repository ?? getIt<BidRepository>())
        .previewCommissionAllocation(bid.id);
  } catch (_) {
    return true;
  }
  if (!preview.needsExplanation || !context.mounted) return true;
  final confirmed = await DonyBottomSheet.show<bool>(
    context,
    analyticsName: 'bid/commission-allocation',
    title: context.l10n.commissionAllocationTitle,
    child: CommissionAllocationBody(preview: preview),
    stickyBottom: Builder(
      builder: (sheetContext) => DonyButton(
        label: sheetContext.l10n.commissionAllocationConfirm,
        onPressed: () => Navigator.of(sheetContext).pop(true),
      ),
    ),
  );
  return confirmed ?? false;
}

/// Contenu de la feuille : la commission, une ligne par portefeuille débité,
/// puis la mention du taux du jour sans marge.
class CommissionAllocationBody extends StatelessWidget {
  const CommissionAllocationBody({super.key, required this.preview});

  final CommissionAllocationPreview preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bid = preview.bidCurrency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.commissionAllocationIntro(formatPriceIn(preview.commission, bid)),
          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.sm),
        for (final line in preview.lines) ...[
          Text(
            key: Key('commission-allocation-line-${line.currency}'),
            l.commissionAllocationLine(
              SupportedCurrency.fromCodeOrDefault(line.currency).name(l),
              formatPriceIn(line.debitAmount, line.currency),
            ),
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (line.converted)
            Text(
              l.commissionAllocationConverted(
                formatPriceIn(line.coveredInBid, bid),
                formatPriceIn(1, bid),
                formatPriceIn(line.rateOfTheDay!, line.currency),
              ),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: DonySpacing.xs),
        ],
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.commissionAllocationNote,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
