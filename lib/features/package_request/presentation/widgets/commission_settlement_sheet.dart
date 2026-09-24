import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/commission_shortfall.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Feuille affichée quand le voyageur tente de régler la commission Yadony
/// d'un accord en espèces mais que son portefeuille ne couvre pas le montant
/// requis (état `NegotiationCommissionInsufficientWallet`).
///
/// Reprend l'UX déjà éprouvée de `_showWalletInsufficientSheet`
/// (`lib/features/matching/presentation/screens/bid_detail_screen.dart`) :
/// recharger le portefeuille, ou payer directement par carte. Contrairement à
/// ce flux jumeau, l'accord est déjà acquis (l'expéditeur a accepté l'offre) :
/// aucun bouton de refus ici, seulement des chemins pour compléter le
/// règlement. [onRetry] relance le règlement (`useCard: true` force la carte,
/// `false` retente le portefeuille après une recharge réussie).
Future<void> showCommissionSettlementSheet(
  BuildContext context, {
  required double requiredCommission,
  required double availableBalance,
  required bool hasCard,
  required String currency,
  required void Function({required bool useCard}) onRetry,
  CommissionShortfall? breakdown,
}) {
  final cs = Theme.of(context).colorScheme;
  final l = context.l10n;
  return DonyBottomSheet.show<void>(
    context,
    title: l.negotiationCommissionSettlementTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, line) in commissionShortfallLines(
          l,
          breakdown: breakdown,
          requiredCommission: requiredCommission,
          availableBalance: availableBalance,
          currency: currency,
        ).indexed) ...[
          if (i > 0) const SizedBox(height: 4),
          Text(
            line,
            style: i == 0
                ? Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurface)
                : Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l.negotiationCommissionSettlementHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ),
    stickyBottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          label: l.negotiationCommissionSettlementTopupButton,
          onPressed: () async {
            context.pop();
            // /topup/method est le point d'entrée correct : il compose le
            // WalletTopupMethodSelection attendu en extra par
            // /topup/amount, qui crasherait sans lui.
            final recharged = await context.push<bool>(
              '/payments/wallet/topup/method',
            );
            if ((recharged ?? false) && context.mounted) {
              onRetry(useCard: false);
            }
          },
        ),
        if (hasCard) ...[
          const SizedBox(height: 8),
          DonyButton(
            label: l.negotiationCommissionSettlementPayCardButton,
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              context.pop();
              onRetry(useCard: true);
            },
          ),
        ] else ...[
          const SizedBox(height: 8),
          DonyButton(
            label: l.negotiationCommissionSettlementAddCardButton,
            variant: DonyButtonVariant.secondary,
            onPressed: () async {
              context.pop();
              await context.push('/payments/commission-method');
            },
          ),
        ],
      ],
    ),
  );
}
