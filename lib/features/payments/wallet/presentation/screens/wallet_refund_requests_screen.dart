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
        actions: const [DonyFeedbackButton()],
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

  /// Icône selon le rail. `null` (ancien contrat) garde l'icône générique
  /// d'avant.
  IconData get _railIcon => switch (request.rail) {
    'PAWAPAY' => Icons.smartphone_rounded,
    'STRIPE' => Icons.credit_card_rounded,
    _ => Icons.receipt_long,
  };

  /// Le back n'expose pas le nom de l'opérateur sur une demande de
  /// remboursement, seul le rail (`STRIPE`/`PAWAPAY`/`MANUAL`) : le
  /// sous-titre reste générique, jamais un nom inventé.
  String? get _railLabel => switch (request.rail) {
    'PAWAPAY' => 'Mobile money',
    'STRIPE' => 'Carte',
    'MANUAL' => 'Manuel',
    _ => null,
  };

  /// Le back n'expose pas de drapeau « versement de repli en cours » : la
  /// phrase n'apparaît que si les trois conditions vérifiables sont réunies
  /// (rail pawaPay, demande non terminale, destination connue) — jamais
  /// inventée à partir d'un statut seul.
  bool get _showFallbackNotice =>
      request.rail == 'PAWAPAY' &&
      !request.isTerminal &&
      request.destinationMasked != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(request.currency);
    final date = DateFormat('dd MMM yyyy', 'fr_FR').format(request.requestedAt);
    final statusColor = _statusColor(cs);
    final fee = request.feeAmount;
    final net = request.netAmount;
    final subtitle = [
      ?_railLabel,
      ?request.destinationMasked,
      date,
    ].join(' · ');

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(_railIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: DonySpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le net, jamais le brut : la sheet de confirmation a
                    // promis « Vous recevrez X », mettre le brut en avant
                    // ici donnerait deux chiffres pour la même demande. Le
                    // brut reste lisible dans la ligne de détail des frais.
                    Text(
                      CurrencyFormatter.format(net ?? request.amount, currency),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
          if (_showFallbackNotice) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Le remboursement part vers ${request.destinationMasked}. En '
              'cas de refus de l\'opérateur, l\'argent est renvoyé par un '
              'versement sur le même numéro.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          // `feeAmount` et `netAmount` sont nullables INDÉPENDAMMENT : sans
          // le net, annoncer « vous recevez » à partir du brut affirmerait
          // un montant faux. Le détail n'est donc écrit que lorsque les deux
          // sont connus.
          if (fee != null && fee > 0 && net != null) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              '${CurrencyFormatter.format(request.amount, currency)} '
              'remboursables, ${CurrencyFormatter.format(fee, currency)} de '
              'frais retenus, vous recevez '
              '${CurrencyFormatter.format(net, currency)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.warning),
            ),
          ],
        ],
      ),
    );
  }
}
