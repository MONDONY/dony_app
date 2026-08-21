import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Bottom sheet de sélection des recharges à rembourser, ouverte depuis le
/// bouton "Rembourser" du portefeuille. Les recharges déjà couvertes par une
/// demande de remboursement en cours n'apparaissent jamais dans la liste
/// (filtrées côté serveur, cf. `WalletSelfRefundService.listEligibleTopups`).
abstract final class WalletRefundSelectionSheet {
  static Future<bool?> show(BuildContext context, {required String currency}) {
    final topupsCubit = getIt<WalletEligibleTopupsCubit>()..load(currency);
    final refundCubit = context.read<WalletRefundRequestCubit>();
    final selected = ValueNotifier<Set<String>>(const {});

    return DonyBottomSheet.show<bool>(
      context,
      title: 'Choisir une recharge',
      subtitle: 'Sélectionnez la ou les recharges à rembourser',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: topupsCubit),
          BlocProvider.value(value: refundCubit),
        ],
        child: child,
      ),
      child: _SelectionList(currency: currency, selected: selected),
      stickyBottom: _SelectionStickyBottom(
        currency: currency,
        selected: selected,
      ),
    ).whenComplete(() {
      unawaited(topupsCubit.close());
      selected.dispose();
    });
  }
}

class _SelectionList extends StatelessWidget {
  const _SelectionList({required this.currency, required this.selected});

  final String currency;
  final ValueNotifier<Set<String>> selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayCurrency = SupportedCurrency.fromCodeOrDefault(currency);

    return BlocBuilder<WalletEligibleTopupsCubit, WalletEligibleTopupsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.error != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Text(
              state.error!.message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }
        if (state.topups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyMascotteAnimated(type: DonyMascotteType.assis),
                const SizedBox(height: DonySpacing.base),
                Text(
                  'Aucune recharge disponible pour le remboursement pour '
                  'le moment.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selected,
          builder: (context, selectedIds, _) {
            return Column(
              children: [
                for (final topup in state.topups)
                  DonyCheckbox(
                    label: CurrencyFormatter.format(
                      topup.amount,
                      displayCurrency,
                    ),
                    subtitle: DateFormat(
                      'dd MMM yyyy · HH:mm',
                      'fr_FR',
                    ).format(topup.createdAt),
                    value: selectedIds.contains(topup.id),
                    onChanged: (_) {
                      final next = Set<String>.from(selectedIds);
                      if (!next.remove(topup.id)) {
                        next.add(topup.id);
                      }
                      selected.value = next;
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SelectionStickyBottom extends StatelessWidget {
  const _SelectionStickyBottom({
    required this.currency,
    required this.selected,
  });

  final String currency;
  final ValueNotifier<Set<String>> selected;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletRefundRequestCubit, WalletRefundRequestState>(
      listenWhen: (previous, current) => previous.result != current.result,
      listener: (context, state) {
        if (state.result != null) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, refundState) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selected,
          builder: (context, selectedIds, _) {
            final canSubmit =
                selectedIds.isNotEmpty && !refundState.isSubmitting;
            return DonyButton(
              label: selectedIds.isEmpty
                  ? 'Sélectionnez une recharge'
                  : 'Rembourser (${selectedIds.length})',
              isLoading: refundState.isSubmitting,
              onPressed: canSubmit
                  ? () => context.read<WalletRefundRequestCubit>().submit(
                      currency,
                      selectedIds.toList(),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
