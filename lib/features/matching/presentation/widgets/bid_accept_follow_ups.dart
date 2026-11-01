import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/payments/wallet/presentation/commission_funding_options.dart';
import 'package:dony/features/payments/wallet/presentation/commission_shortfall_text.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Suites d'une acceptation espèces refusée par le serveur, côté voyageur,
// communes aux écrans qui listent les demandes à traiter
// (`PendingBidsScreen`, `DemandesScreen`) et à l'écran du trajet (réponse
// directe). La fiche du colis garde les siennes, sur ses propres textes.

/// Solde insuffisant pour la commission d'une acceptation espèces
/// ([acs.BidWalletInsufficient]) : recharger le portefeuille puis relancer,
/// payer depuis un autre portefeuille au taux du jour, payer la commission
/// par carte si une carte existe, sinon en ajouter une.
///
/// Les relances passent par [acceptance]. [onRetry] est appelé juste avant
/// chaque relance (l'écran note la demande en cours) ; [onCardAdded] au
/// retour de l'ajout d'une carte de commission.
void showBidWalletInsufficientSheet(
  BuildContext context,
  acs.BidWalletInsufficient state, {
  required BidAcceptanceBloc acceptance,
  VoidCallback? onRetry,
  VoidCallback? onCardAdded,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final l = context.l10n;

  void retry(ace.BidAcceptanceEvent event) {
    onRetry?.call();
    acceptance.add(event);
  }

  DonyBottomSheet.show<void>(
    context,
    title: l.bidListWalletInsufficientTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, line) in commissionShortfallLines(
          l,
          breakdown: state.breakdown,
          requiredCommission: state.requiredCommission,
          availableBalance: state.availableBalance,
          currency: state.currency,
          fundingDetail: state.fundingDetail,
        ).indexed) ...[
          if (i > 0) const SizedBox(height: 4),
          Text(
            line,
            style: i == 0
                ? tt.bodyMedium?.copyWith(color: cs.onSurface)
                : tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l.bidListWalletInsufficientHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        CommissionFundingOptions(
          alternatives: state.alternatives,
          onSelected: (currency) {
            context.pop();
            retry(
              ace.BidAcceptRequested(state.bidId, fundingCurrency: currency),
            );
          },
        ),
      ],
    ),
    stickyBottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          label: commissionTopupLabel(
            l,
            tripCurrency: commissionTripCurrency(
              bidCurrency: state.bidCurrency,
              breakdown: state.breakdown,
              currency: state.currency,
            ),
            fallback: l.bidListWalletTopupButton,
          ),
          onPressed: () async {
            context.pop();
            final recharged = await context.push<bool>(
              '/payments/wallet/topup/method',
            );
            if ((recharged ?? false) && context.mounted) {
              retry(ace.BidAcceptRequested(state.bidId));
            }
          },
        ),
        if (state.hasCard) ...[
          const SizedBox(height: 8),
          DonyButton(
            label: l.bidListPayByCardButton,
            variant: DonyButtonVariant.secondary,
            onPressed: () {
              context.pop();
              retry(ace.BidAcceptWithCardRequested(state.bidId));
            },
          ),
        ] else ...[
          const SizedBox(height: 8),
          DonyButton(
            label: l.bidListAddCardButton,
            variant: DonyButtonVariant.secondary,
            onPressed: () async {
              context.pop();
              await context.push('/payments/commission-method');
              if (context.mounted) onCardAdded?.call();
            },
          ),
        ],
      ],
    ),
  );
}

/// Carte de commission refusée pendant une acceptation espèces
/// ([acs.BidFailed] `cardDeclined`) : le motif [message], puis changer de
/// carte de commission.
void showBidCardDeclinedSheet(BuildContext context, String message) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final l = context.l10n;
  DonyBottomSheet.show<void>(
    context,
    title: l.bidListCardDeclinedSheetTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
        const SizedBox(height: 8),
        Text(
          l.bidListCardDeclinedHint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ),
    stickyBottom: DonyButton(
      label: l.bidListChangeCommissionCardButton,
      onPressed: () {
        context.pop();
        context.push('/payments/commission-method');
      },
    ),
  );
}
