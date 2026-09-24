import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Confirmation du remboursement du solde d'une devise : un seul montant
/// (tout ce qui est remboursable sur la carte, calculé côté back), sans
/// sélection de recharge. Remplace `WalletRefundSelectionSheet` dès que le
/// back expose `refundableAmount` ; l'ancienne sheet reste le repli.
abstract final class WalletRefundConfirmSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String currency,
    required double refundableAmount,
    required double nonRefundableAmount,
    double? feeAmount,
    double? netAmount,
  }) {
    final refundCubit = context.read<WalletRefundRequestCubit>();
    // Le rail (mobile money ou carte) n'est pas exposé directement sur le
    // solde : on le dérive des recharges éligibles concernées, chargées ici
    // comme le fait déjà `WalletRefundSelectionSheet`. La destination
    // (numéro masqué) reste elle inconnue avant la demande — jamais affichée
    // dans cette sheet, seulement dans « Mes remboursements ».
    final topupsCubit = getIt<WalletEligibleTopupsCubit>()..load(currency);
    final displayCurrency = SupportedCurrency.fromCodeOrDefault(currency);
    final l = context.l10n;

    return DonyBottomSheet.show<bool>(
      context,
      title: l.walletRefundConfirmTitle,
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: refundCubit),
          BlocProvider.value(value: topupsCubit),
        ],
        child: child,
      ),
      child: _ConfirmContent(
        currency: displayCurrency,
        refundableAmount: refundableAmount,
        nonRefundableAmount: nonRefundableAmount,
        feeAmount: feeAmount,
        netAmount: netAmount,
      ),
      stickyBottom: _ConfirmStickyBottom(
        currencyCode: currency,
        label: l.walletRefundConfirmCta(
          CurrencyFormatter.format(
            netAmount ?? refundableAmount,
            displayCurrency,
          ),
        ),
      ),
    ).whenComplete(() => unawaited(topupsCubit.close()));
  }
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.currency,
    required this.refundableAmount,
    required this.nonRefundableAmount,
    this.feeAmount,
    this.netAmount,
  });

  final SupportedCurrency currency;
  final double refundableAmount;
  final double nonRefundableAmount;
  final double? feeAmount;
  final double? netAmount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fee = feeAmount;
    final hasFeeInfo = feeAmount != null || netAmount != null;

    return BlocBuilder<WalletEligibleTopupsCubit, WalletEligibleTopupsState>(
      builder: (context, topupsState) {
        // Trois états, jamais deux : tant que les recharges éligibles ne
        // sont pas arrivées (chargement en cours, ou appel en échec), le
        // rail est INCONNU et la sheet n'en annonce aucun — promettre
        // « votre carte, sous 5 à 10 jours » à quelqu'un qui sera remboursé
        // sur son numéro en quelques minutes est un mensonge. Le rail n'est
        // décidé qu'une fois la liste reçue et non vide : toutes pawaPay →
        // mobile money, sinon (mix, Stripe, ou ancien contrat où
        // `paymentRef` n'est jamais renseigné) → carte.
        final railKnown =
            !topupsState.isLoading &&
            topupsState.error == null &&
            topupsState.topups.isNotEmpty;
        final isPawapay =
            railKnown && topupsState.topups.every((t) => t.isMobileMoneyTopup);

        final refundableAmountText = CurrencyFormatter.format(
          refundableAmount,
          currency,
        );
        final refundableLine = !railKnown
            ? l.walletRefundable(refundableAmountText)
            : isPawapay
            ? l.walletRefundableOnMobileMoney(refundableAmountText)
            : l.walletRefundableOnCard(refundableAmountText);
        final explainLine = !railKnown
            ? l.walletRefundExplainUnknown(currency.code)
            : isPawapay
            ? l.walletRefundExplainMobileMoney(currency.code)
            : l.walletRefundExplainCard;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              refundableLine,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              explainLine,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (fee != null) ...[
              const SizedBox(height: DonySpacing.base),
              DonyInfoRow(
                label: l.walletRefundFeeLabel,
                value: fee > 0
                    ? CurrencyFormatter.format(fee, currency)
                    : l.walletRefundFeeFreeValue,
                valueStyle: fee > 0
                    ? DonyInfoRowValueStyle.warning
                    : DonyInfoRowValueStyle.success,
              ),
            ],
            if (hasFeeInfo) ...[
              const SizedBox(height: DonySpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.walletRefundWillReceiveLabel,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    CurrencyFormatter.format(
                      netAmount ?? refundableAmount,
                      currency,
                    ),
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
            if (nonRefundableAmount > 0) ...[
              const SizedBox(height: DonySpacing.base),
              DonyStatusBanner(
                type: DonyStatusBannerType.info,
                iconAsset: 'circle-alert',
                message: l.walletRefundBonusNotice(
                  CurrencyFormatter.format(nonRefundableAmount, currency),
                ),
              ),
            ],
            if (fee != null && fee > 0) ...[
              const SizedBox(height: DonySpacing.base),
              DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                iconAsset: 'circle-alert',
                message: l.walletRefundFeeRetainedNotice,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ConfirmStickyBottom extends StatelessWidget {
  const _ConfirmStickyBottom({required this.currencyCode, required this.label});

  final String currencyCode;
  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletRefundRequestCubit, WalletRefundRequestState>(
      listenWhen: (previous, current) =>
          previous.result != current.result || previous.error != current.error,
      listener: (context, state) {
        if (state.result == null) {
          return;
        }
        // Le pop vient d'un listener de BLoC, pas d'un geste : la sheet peut
        // avoir déjà été fermée (glissement, bouton retour) ou avoir une autre
        // route empilée par-dessus quand la réponse arrive. Sans cette garde,
        // le `pop` détruirait la route du dessus.
        if (!context.mounted) {
          return;
        }
        final route = ModalRoute.of(context);
        if (route == null || !route.isCurrent) {
          return;
        }
        Navigator.of(context).pop(true);
      },
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null) ...[
            DonyStatusBanner(
              type: DonyStatusBannerType.error,
              iconAsset: 'circle-alert',
              message: state.error!.message,
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          DonyButton(
            label: label,
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting
                ? null
                : () => context.read<WalletRefundRequestCubit>().submit(
                    currencyCode,
                  ),
          ),
        ],
      ),
    );
  }
}
