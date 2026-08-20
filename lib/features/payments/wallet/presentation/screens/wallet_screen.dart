import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(WalletLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          return switch (state) {
            WalletInitial() || WalletLoading() => const _LoadingView(),
            WalletError(:final message) => _ErrorView(message: message),
            WalletLoaded(:final wallet) => _LoadedView(wallet: wallet),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return DonyShimmer(
      child: Column(
        children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(color: DonyColors.blue700),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DonySkeletonBox(width: 100, height: 14),
                const SizedBox(height: DonySpacing.lg),
                for (var i = 0; i < 4; i++) ...[
                  const Row(
                    children: [
                      DonySkeletonCircle(diameter: 40),
                      SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DonySkeletonBox(width: 140, height: 13),
                            SizedBox(height: DonySpacing.xs),
                            DonySkeletonBox(width: 80, height: 11),
                          ],
                        ),
                      ),
                      DonySkeletonBox(width: 56, height: 14),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.lg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyMascotteAnimated(
              type: DonyMascotteType.assis,
              size: DonyMascotteSize.lg,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Réessayer',
              onPressed: () =>
                  context.read<WalletBloc>().add(WalletLoadRequested()),
              fullWidth: false,
              variant: DonyButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loaded ───────────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.wallet});

  final WalletModel wallet;

  @override
  Widget build(BuildContext context) {
    final transactions = wallet.transactions;
    final activeCurrency = SupportedCurrency.fromCodeOrDefault(wallet.currency);
    final lockedBalances = wallet.balances.where((b) => !b.active).toList();

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        final bloc = context.read<WalletBloc>();
        bloc.add(WalletRefreshRequested());
        // Attend la fin du rafraîchissement (succès ou erreur) pour masquer
        // l'indicateur de pull-to-refresh.
        await bloc.stream.firstWhere(
          (s) => s is WalletLoaded || s is WalletError,
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Hero SliverAppBar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: DonyColors.blue700,
            leading: const DonyAppBarBackButton(),
            title: Text(
              'Mon portefeuille',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: DonyColors.neutral0,
                fontSize: 17,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroHeader(
                balance: wallet.balance,
                currency: activeCurrency,
                refundEligible: wallet.refundEligible,
              ),
            ),
          ),

          // ── Locked (non-active currency) balances ────────────────────────────
          if (lockedBalances.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final locked in lockedBalances)
                      _LockedBalanceTile(balance: locked),
                  ],
                ),
              ),
            ),

          // ── Transactions list ──────────────────────────────────────────────
          if (transactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DonyMascotteAnimated(
                        type: DonyMascotteType.assis,
                        size: DonyMascotteSize.lg,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      Text(
                        'Aucune transaction pour l\'instant',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  DonySpacing.sm,
                ),
                child: Text(
                  'Historique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TxTile(
                  tx: transactions[i],
                  currency: activeCurrency,
                  index: i,
                ),
                childCount: transactions.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: DonySpacing.huge)),
          ],
        ],
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.balance,
    required this.currency,
    required this.refundEligible,
  });

  final double balance;
  final SupportedCurrency currency;
  final bool refundEligible;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DonyColors.blue900, DonyColors.blue700, DonyColors.blue500],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.huge,
            DonySpacing.lg,
            DonySpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Solde disponible',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DonyColors.neutral0.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                    CurrencyFormatter.format(balance, currency),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: DonyColors.neutral0,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
              const SizedBox(height: DonySpacing.base),
              if (refundEligible)
                BlocConsumer<
                  WalletRefundRequestCubit,
                  WalletRefundRequestState
                >(
                  listenWhen: (previous, current) =>
                      previous.result != current.result ||
                      previous.error != current.error,
                  listener: (context, state) {
                    if (state.result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Demande de remboursement envoyée.'),
                        ),
                      );
                      context.read<WalletBloc>().add(WalletRefreshRequested());
                    }
                    if (state.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.error!.message)),
                      );
                    }
                  },
                  builder: (context, refundState) =>
                      _buildActions(context, refundState),
                )
              else
                _buildActions(context, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    WalletRefundRequestState? refundState,
  ) {
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: [
        _HeroAction(
          iconAsset: 'plus',
          label: 'Recharger',
          onTap: () async {
            // Solde avant la recharge : sert de référence au polling
            // post-recharge (on s'arrête dès qu'il augmente).
            final previousBalance = balance;
            final ok = await context.push<bool>(
              '/payments/wallet/topup/method',
            );
            if (ok != true || !context.mounted) {
              return;
            }
            // Le crédit Stripe arrive de façon asynchrone via webhook :
            // on poll le solde jusqu'à ce qu'il dépasse l'ancien.
            context.read<WalletBloc>().add(
              WalletRefreshAfterTopupRequested(previousBalance),
            );
          },
        ),
        if (refundEligible)
          _HeroAction(
            iconAsset: 'arrow-up',
            label: refundState?.isSubmitting == true
                ? 'Envoi...'
                : 'Rembourser',
            enabled: refundState?.isSubmitting != true,
            onTap: () =>
                context.read<WalletRefundRequestCubit>().submit(currency.code),
          ),
        _HeroAction(
          iconAsset: 'history',
          label: 'Demandes',
          onTap: () => context.push('/payments/wallet/refunds'),
        ),
        _HeroAction(
          iconAsset: 'arrow-up',
          label: 'Utiliser',
          onTap: () => context.pop(),
        ),
      ],
    );
  }
}

// ─── Hero action button ────────────────────────────────────────────────────────

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.enabled = true,
  }) : icon = null;

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.65,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: DonyColors.neutral0.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DonyRadius.xl),
              border: Border.all(
                color: DonyColors.neutral0.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconAsset != null
                    ? DonyIcon(iconAsset!, color: DonyColors.neutral0, size: 16)
                    : Icon(icon, color: DonyColors.neutral0, size: 16),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: DonyColors.neutral0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.currency,
    required this.index,
  });

  final WalletTransactionModel tx;
  final SupportedCurrency currency;
  final int index;

  String get _label => switch (tx.type) {
    'TOP_UP' => 'Recharge',
    'BID_PAYMENT' => 'Paiement colis',
    'COMMISSION_DEDUCTED' => 'Commission',
    'REFUND' => 'Remboursement',
    'REFERRAL_REWARD' => 'Parrainage',
    _ => tx.type,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCredit = tx.isCredit;
    final amountColor = isCredit ? DonyColors.success500 : DonyColors.terra600;
    final amountPrefix = isCredit ? '+' : '';

    return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: DonySpacing.xs,
          ),
          child: DonyCard(
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCredit ? DonyColors.blue50 : DonyColors.terra50,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon(
                    isCredit ? 'arrow-down' : 'arrow-up',
                    color: isCredit ? cs.primary : DonyColors.terra500,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DonySpacing.base),
                // Label + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat(
                          'dd MMM · HH:mm',
                          'fr_FR',
                        ).format(tx.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount
                Text(
                  '$amountPrefix${CurrencyFormatter.format(tx.amount.abs(), currency)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ─── Locked (non-active currency) balance tile ─────────────────────────────────

class _LockedBalanceTile extends StatelessWidget {
  const _LockedBalanceTile({required this.balance});

  final WalletCurrencyBalanceModel balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(balance.currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Semantics(
        label:
            'Devise verrouillée ${currency.displayName}, ce solde reste '
            'disponible dans sa propre devise',
        child: DonyCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: DonySpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.format(balance.balance, currency),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(DonyRadius.sm),
                          ),
                          child: Text(
                            'verrouillé',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reste dans sa devise d\'origine (${currency.displayName}).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
