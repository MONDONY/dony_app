import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
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
    String? rail,
    String? destinationMasked,
  }) {
    final refundCubit = context.read<WalletRefundRequestCubit>();
    final displayCurrency = SupportedCurrency.fromCodeOrDefault(currency);

    return DonyBottomSheet.show<bool>(
      context,
      title: 'Rembourser mon solde',
      wrapper: (child) => BlocProvider.value(value: refundCubit, child: child),
      child: _ConfirmContent(
        currency: displayCurrency,
        refundableAmount: refundableAmount,
        nonRefundableAmount: nonRefundableAmount,
        feeAmount: feeAmount,
        netAmount: netAmount,
        rail: rail,
        destinationMasked: destinationMasked,
      ),
      stickyBottom: _ConfirmStickyBottom(
        currencyCode: currency,
        label:
            'Rembourser ${CurrencyFormatter.format(netAmount ?? refundableAmount, displayCurrency)}',
      ),
    );
  }
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.currency,
    required this.refundableAmount,
    required this.nonRefundableAmount,
    this.feeAmount,
    this.netAmount,
    this.rail,
    this.destinationMasked,
  });

  final SupportedCurrency currency;
  final double refundableAmount;
  final double nonRefundableAmount;
  final double? feeAmount;
  final double? netAmount;
  final String? rail;
  final String? destinationMasked;

  bool get _isPawapay => rail == 'PAWAPAY';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fee = feeAmount;
    final hasFeeInfo = feeAmount != null || netAmount != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Remboursable sur ${_isPawapay ? 'mobile money' : 'votre carte'} : '
          '${CurrencyFormatter.format(refundableAmount, currency)}',
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          _isPawapay
              ? (destinationMasked != null
                    ? 'Le montant repart vers $destinationMasked. Votre '
                          'solde est gelé le temps du traitement.'
                    : 'Le montant repart vers votre compte mobile money. '
                          'Votre solde est gelé le temps du traitement.')
              : 'Le montant revient sur la carte utilisée pour la recharge, '
                    'sous 5 à 10 jours selon votre banque. Votre solde est '
                    'gelé le temps du traitement.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        if (fee != null) ...[
          const SizedBox(height: DonySpacing.base),
          DonyInfoRow(
            label: 'Frais de remboursement',
            value: fee > 0
                ? CurrencyFormatter.format(fee, currency)
                : 'Offerts',
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
                'Vous recevrez',
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
            message:
                '${CurrencyFormatter.format(nonRefundableAmount, currency)} '
                'de bonus ne sont pas remboursables et restent sur votre '
                'portefeuille.',
          ),
        ],
        if (fee != null && fee > 0) ...[
          const SizedBox(height: DonySpacing.base),
          DonyStatusBanner(
            type: DonyStatusBannerType.warning,
            iconAsset: 'circle-alert',
            message:
                'Des frais de ${CurrencyFormatter.format(fee, currency)} sont '
                'retenus par l\'opérateur pour ce remboursement.',
          ),
        ],
      ],
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
