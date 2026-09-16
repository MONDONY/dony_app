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
  }) {
    final refundCubit = context.read<WalletRefundRequestCubit>();
    final displayCurrency = SupportedCurrency.fromCodeOrDefault(currency);

    return DonyBottomSheet.show<bool>(
      context,
      title: 'Rembourser mon solde',
      wrapper: (child) =>
          BlocProvider.value(value: refundCubit, child: child),
      child: _ConfirmContent(
        currency: displayCurrency,
        refundableAmount: refundableAmount,
        nonRefundableAmount: nonRefundableAmount,
      ),
      stickyBottom: _ConfirmStickyBottom(
        currencyCode: currency,
        label:
            'Rembourser ${CurrencyFormatter.format(refundableAmount, displayCurrency)}',
      ),
    );
  }
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({
    required this.currency,
    required this.refundableAmount,
    required this.nonRefundableAmount,
  });

  final SupportedCurrency currency;
  final double refundableAmount;
  final double nonRefundableAmount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Remboursable sur votre carte : '
          '${CurrencyFormatter.format(refundableAmount, currency)}',
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Le montant revient sur la carte utilisée pour la recharge, sous 5 à '
          '10 jours selon votre banque. Votre solde est gelé le temps du '
          'traitement.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
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
        if (state.result != null) {
          Navigator.of(context).pop(true);
        }
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
                : () =>
                      context.read<WalletRefundRequestCubit>().submit(currencyCode),
          ),
        ],
      ),
    );
  }
}
