import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_requests_list_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class WalletRefundRequestsScreen extends StatefulWidget {
  const WalletRefundRequestsScreen({super.key});

  @override
  State<WalletRefundRequestsScreen> createState() =>
      _WalletRefundRequestsScreenState();
}

class _WalletRefundRequestsScreenState
    extends State<WalletRefundRequestsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletRefundRequestsListCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Mes remboursements'),
      ),
      body:
          BlocBuilder<
            WalletRefundRequestsListCubit,
            WalletRefundRequestsListState
          >(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DonySpacing.lg),
                    child: Text(
                      'Impossible de charger vos demandes de remboursement.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              if (state.requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.lg,
                    ),
                    child: Text(
                      'Aucune demande de remboursement pour l\'instant.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    context.read<WalletRefundRequestsListCubit>().load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(DonySpacing.lg),
                  itemCount: state.requests.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DonySpacing.sm),
                  itemBuilder: (context, i) =>
                      _RefundRequestTile(request: state.requests[i]),
                ),
              );
            },
          ),
    );
  }
}

class _RefundRequestTile extends StatelessWidget {
  const _RefundRequestTile({required this.request});

  final WalletRefundRequestModel request;

  String get _statusLabel => switch (request.status) {
    'PENDING' || 'PROCESSING' => 'En cours',
    'RESOLVED' || 'REFUNDED' => 'Remboursé',
    'FAILED' => 'Échoué',
    _ => request.status,
  };

  Color _statusColor(ColorScheme cs) => switch (request.status) {
    'RESOLVED' || 'REFUNDED' => DonyColors.success500,
    'FAILED' => DonyColors.terra600,
    _ => cs.primary,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(request.currency);
    final date = DateFormat('dd MMM yyyy', 'fr_FR').format(request.requestedAt);
    final statusColor = _statusColor(cs);

    return DonyCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Icon(Icons.receipt_long, color: statusColor, size: 20),
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.format(request.amount, currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              _statusLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
