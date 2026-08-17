import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
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
}) {
  final cs = Theme.of(context).colorScheme;
  return DonyBottomSheet.show<void>(
    context,
    title: 'Solde insuffisant',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commission requise : ${formatPriceIn(requiredCommission, currency)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Solde du portefeuille : ${formatPriceIn(availableBalance, currency)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'Rechargez votre portefeuille ou payez la commission directement par carte.',
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
          label: 'Recharger mon portefeuille',
          onPressed: () async {
            context.pop();
            // /topup/method est le point d'entrée correct : sélectionne la
            // méthode avant de pousser /topup/amount avec extra (String), qui
            // crasherait si null.
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
            label: 'Payer par carte',
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              context.pop();
              onRetry(useCard: true);
            },
          ),
        ] else ...[
          const SizedBox(height: 8),
          DonyButton(
            label: 'Ajouter une carte',
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
