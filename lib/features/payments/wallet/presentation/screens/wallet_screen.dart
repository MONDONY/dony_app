import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_confirm_sheet.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_currency_sheet.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.topupConfirmed});

  /// Statut de la recharge mobile money qui vient d'aboutir, transmis par
  /// l'écran d'attente via `context.go('/payments/wallet', extra: {...})`.
  /// Affiché une seule fois (bandeau de confirmation) : jamais relu au
  /// rebuild, seul l'`initState` de cet écran le prend en compte.
  final WalletTopupStatusModel? topupConfirmed;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Vit dans ce `State`, pas dans un bottom sheet : pas de contrainte
  /// `whenComplete`. Un seul écrit possible, le tap sur la croix du
  /// bandeau, qui survient forcément avant que ce `State` ne soit détruit.
  late final ValueNotifier<WalletTopupStatusModel?> _topupBanner =
      ValueNotifier(widget.topupConfirmed);

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(WalletLoadRequested());
  }

  @override
  void dispose() {
    _topupBanner.dispose();
    super.dispose();
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
            WalletLoaded(:final wallet) => _LoadedView(
              wallet: wallet,
              topupBanner: _topupBanner,
            ),
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
  const _LoadedView({required this.wallet, required this.topupBanner});

  final WalletModel wallet;
  final ValueNotifier<WalletTopupStatusModel?> topupBanner;

  /// Il y a bien un montant remboursable, mais les frais de remboursement le
  /// ramènent à zéro : rien à demander, et la raison mérite d'être dite.
  /// `null` des deux côtés (ancien contrat back) ne déclenche jamais rien.
  static bool _refundFullyAbsorbedByFees(WalletModel wallet) {
    final balance = wallet.activeBalance;
    if (balance == null || !wallet.refundEligible) return false;
    final gross = balance.refundableAmount;
    final net = balance.refundNetAmount;
    if (gross == null || net == null) return false;
    return gross > 0 && net <= 0;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = wallet.transactions;
    final activeCurrency = SupportedCurrency.fromCodeOrDefault(wallet.currency);
    // Une devise non active à solde 0 ne bloque rien : on ne l'affiche pas
    // comme "verrouillée", ça n'a rien de réel à protéger.
    final lockedBalances = wallet.balances
        .where((b) => !b.active && b.balance != 0)
        .toList();

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
            expandedHeight: 236,
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
            actions: [
              IconButton(
                tooltip: 'Comment ça marche',
                onPressed: () => DonyBottomSheet.show(
                  context,
                  title: 'Comment fonctionne le portefeuille',
                  child: const _WalletInfoContent(),
                ),
                icon: const DonyIcon(
                  'circle-alert',
                  color: DonyColors.neutral0,
                  size: 22,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroHeader(
                balance: wallet.balance,
                currency: activeCurrency,
                refundEligible: wallet.refundEligible,
                refundableAmount: wallet.activeBalance?.refundableAmount,
                nonRefundableAmount: wallet.activeBalance?.nonRefundableAmount,
                refundFeeAmount: wallet.activeBalance?.refundFeeAmount,
                refundNetAmount: wallet.activeBalance?.refundNetAmount,
                estimatedTotal: wallet.hasEstimate
                    ? wallet.estimatedTotal
                    : null,
                estimateComplete: wallet.estimateComplete,
                multiCurrency: wallet.heldBalances.length > 1,
                eligibleBalances: wallet.eligibleBalances,
              ),
            ),
          ),

          // ── Bandeau de confirmation d'une recharge mobile money ──────────────
          SliverToBoxAdapter(
            child: ValueListenableBuilder<WalletTopupStatusModel?>(
              valueListenable: topupBanner,
              builder: (context, status, _) {
                if (status == null) {
                  return const SizedBox.shrink();
                }
                final topupCurrency = SupportedCurrency.fromCodeOrDefault(
                  status.currency,
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.lg,
                    DonySpacing.lg,
                    0,
                  ),
                  child: DonyStatusBanner(
                    type: DonyStatusBannerType.success,
                    iconAsset: 'circle-check',
                    message:
                        '+${CurrencyFormatter.format(status.amount, topupCurrency)} '
                        'sur ton portefeuille ${topupCurrency.displayName}, '
                        'confirmé par ${status.providerLabel}.',
                    onDismiss: () => topupBanner.value = null,
                  ),
                );
              },
            ),
          ),

          // ── Solde remboursable entièrement absorbé par les frais ────────────
          // Le bouton « Rembourser » disparaît dans ce cas (net à 0) : sans
          // un mot, l'utilisateur ne comprend pas pourquoi. On le dit,
          // plutôt que de masquer en silence.
          if (_refundFullyAbsorbedByFees(wallet))
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  0,
                ),
                child: DonyStatusBanner(
                  key: Key('wallet-refund-absorbed-by-fees'),
                  type: DonyStatusBannerType.info,
                  iconAsset: 'circle-alert',
                  message:
                      'Ce solde ne peut pas être remboursé : les frais du '
                      'prestataire de paiement l\'absorbent entièrement. Il '
                      'reste utilisable pour payer vos envois.',
                ),
              ),
            ),

          // ── Soldes par devise ─────────────────────────────────────────────
          // Nouveau contrat : toutes les devises détenues, chacune dans sa
          // devise, avec son équivalent estimé. Ancien contrat : tuiles des
          // devises non actives comme avant.
          if (wallet.hasEstimate && wallet.heldBalances.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  0,
                ),
                child: ValueListenableBuilder<WalletTopupStatusModel?>(
                  valueListenable: topupBanner,
                  builder: (context, status, _) => _CurrencyBalancesCard(
                    wallet: wallet,
                    highlightCurrency: status?.currency,
                  ),
                ),
              ),
            )
          else if (!wallet.hasEstimate && lockedBalances.isNotEmpty)
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
    this.refundableAmount,
    this.nonRefundableAmount,
    this.refundFeeAmount,
    this.refundNetAmount,
    this.estimatedTotal,
    this.estimateComplete = true,
    this.multiCurrency = false,
    required this.eligibleBalances,
  });

  final double balance;
  final SupportedCurrency currency;
  final bool refundEligible;
  final double? refundableAmount;
  final double? nonRefundableAmount;
  final double? refundFeeAmount;
  final double? refundNetAmount;

  /// Devises remboursables au net positif (`WalletModel.eligibleBalances`),
  /// active ou non. Vide sur l'ancien contrat back : le reste des champs
  /// ci-dessus reprend alors seul.
  final List<WalletCurrencyBalanceModel> eligibleBalances;

  /// Somme estimée de tous les portefeuilles dans [currency], `null` sur
  /// l'ancien contrat (l'en-tête retombe alors sur « Solde disponible »).
  final double? estimatedTotal;

  /// `false` quand une devise détenue n'a pas de taux du jour : le sous-titre
  /// avertit que l'estimation est partielle.
  final bool estimateComplete;

  /// Plus d'une devise réellement détenue : seul ce cas affiche « Total
  /// estimé » et le sous-titre, sinon rien à estimer.
  final bool multiCurrency;

  /// « Rembourser » n'apparaît que s'il y a quelque chose à rembourser une
  /// fois les frais retenus. `refundNetAmount` prime quand il est connu (les
  /// frais de remboursement mobile money peuvent ramener le net à zéro même
  /// si le brut est positif) ; sinon repli sur `refundableAmount` comme
  /// avant, `null` sur les deux (ancien contrat back) laissant l'affichage
  /// géré par le seul `refundEligible`.
  /// « Rembourser » apparaît dès qu'une devise, active ou non, est
  /// remboursable au net positif (`WalletModel.eligibleBalances`). Ancien
  /// contrat (liste vide) : règle historique sur la devise active.
  bool get _canRefund =>
      eligibleBalances.isNotEmpty ||
      (refundEligible && (refundNetAmount ?? refundableAmount ?? 1) > 0);

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
                estimatedTotal != null && multiCurrency
                    ? 'Total estimé'
                    : 'Solde disponible',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DonyColors.neutral0.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                    CurrencyFormatter.format(
                      estimatedTotal ?? balance,
                      currency,
                    ),
                    key: const Key('wallet-estimated-total'),
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
              if (estimatedTotal != null && multiCurrency) ...[
                const SizedBox(height: 2),
                Text(
                  estimateComplete
                      ? 'Estimation au taux du jour. Chaque devise reste séparée.'
                      : 'Estimation partielle : une devise n\'a pas de taux du jour.',
                  key: estimateComplete
                      ? null
                      : const Key('wallet-estimate-partial'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DonyColors.neutral0.withValues(alpha: 0.75),
                  ),
                ),
              ],
              const SizedBox(height: DonySpacing.base),
              if (_canRefund)
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
                  builder: (context, refundState) => _buildActions(context),
                )
              else
                _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final actions = [
      _HeroAction(
        iconAsset: 'plus',
        label: 'Recharger',
        onTap: () async {
          // Solde avant la recharge : sert de référence au polling
          // post-recharge (on s'arrête dès qu'il augmente).
          final previousBalance = balance;
          final ok = await context.push<bool>('/payments/wallet/topup/method');
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
      if (_canRefund)
        _HeroAction(
          iconAsset: 'arrow-up',
          label: 'Rembourser',
          onTap: () async {
            if (eligibleBalances.length > 1) {
              final chosen = await WalletRefundCurrencySheet.show(
                context,
                balances: eligibleBalances,
              );
              if (chosen == null || !context.mounted) return;
              unawaited(
                getIt<AnalyticsService>().logEvent(
                  AnalyticsEvents.walletRefundCurrencyChosen,
                  properties: {'currency': chosen.currency},
                ),
              );
              _openConfirm(context, chosen);
              return;
            }
            // Une seule devise éligible dont le montant remboursable est
            // déjà connu (`WalletModel.eligibleBalances`) : direct vers la
            // confirmation, active ou non. Sinon (ancien contrat : le champ
            // `refundEligible` existe mais pas encore les montants), repli
            // sur les champs historiques de la devise active ci-dessous.
            final single = eligibleBalances.length == 1
                ? eligibleBalances.first
                : null;
            if (single != null &&
                (single.refundNetAmount ?? single.refundableAmount) != null) {
              _openConfirm(context, single);
              return;
            }
            final refundable = refundableAmount;
            if (refundable != null) {
              unawaited(
                WalletRefundConfirmSheet.show(
                  context,
                  currency: currency.code,
                  refundableAmount: refundable,
                  nonRefundableAmount: nonRefundableAmount ?? 0,
                  feeAmount: refundFeeAmount,
                  netAmount: refundNetAmount,
                ),
              );
            } else {
              // Ancien contrat back : sélection de recharges intactes.
              unawaited(
                WalletRefundSelectionSheet.show(context, currency: currency.code),
              );
            }
          },
        ),
      _HeroAction(
        iconAsset: 'history',
        label: 'Demandes',
        onTap: () => context.push('/payments/wallet/refunds'),
      ),
    ];
    return _actionsRow(actions);
  }

  void _openConfirm(BuildContext context, WalletCurrencyBalanceModel b) {
    WalletRefundConfirmSheet.show(
      context,
      currency: b.currency,
      refundableAmount: b.refundableAmount ?? b.balance,
      nonRefundableAmount: b.nonRefundableAmount ?? 0,
      feeAmount: b.refundFeeAmount,
      netAmount: b.refundNetAmount,
    );
  }

  Widget _actionsRow(List<Widget> actions) {
    // Row scrollable horizontalement (jamais de retour à la ligne) : un
    // Wrap ici passerait sur 2 lignes sur les écrans étroits ou avec une
    // police système agrandie, ce qui dépasse la hauteur fixe du
    // SliverAppBar (expandedHeight) et provoque un overflow visible.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: DonySpacing.sm),
            actions[i],
          ],
        ],
      ),
    );
  }
}

// ─── Hero action button ────────────────────────────────────────────────────────

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.label, required this.onTap, this.iconAsset})
    : icon = null;

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
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

  // Le back n'expose ni l'opérateur ni le numéro sur les lignes de
  // transaction (contrairement à `WalletTopupStatusModel`, propre au
  // sondage de la recharge en cours) : impossible d'afficher
  // « Recharge {providerLabel} · {msisdnMasked} », seul `isMobileMoneyTopup`
  // (dérivé du préfixe `pawapay:` du `paymentRef`) distingue le rail.
  String get _label => switch (tx.type) {
    'TOP_UP' when tx.isMobileMoneyTopup => 'Recharge mobile money',
    'TOP_UP' => 'Recharge',
    'BID_PAYMENT' => 'Paiement colis',
    'COMMISSION_DEDUCTED' => 'Commission',
    'REFUND' || 'SELF_REFUND_OUT' => 'Remboursement',
    'REFERRAL_REWARD' => 'Parrainage',
    _ => tx.type,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCredit = tx.isCredit;
    final isRefundProcessing = tx.isRefundProcessing;
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
                    color: isRefundProcessing
                        ? cs.warningLight
                        : (isCredit ? DonyColors.blue50 : DonyColors.terra50),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon(
                    isRefundProcessing
                        ? 'hourglass'
                        : (isCredit ? 'arrow-down' : 'arrow-up'),
                    color: isRefundProcessing
                        ? cs.warning
                        : (isCredit ? cs.primary : DonyColors.terra500),
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
                        isRefundProcessing
                            ? 'Remboursement en cours · sous 5 à 10 jours ouvrés'
                            : DateFormat(
                                'dd MMM · HH:mm',
                                'fr_FR',
                              ).format(tx.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isRefundProcessing
                              ? cs.warning
                              : cs.onSurfaceVariant,
                          fontWeight: isRefundProcessing
                              ? FontWeight.w600
                              : null,
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

// ─── Soldes par devise (nouveau contrat) ──────────────────────────────────────

class _CurrencyBalancesCard extends StatelessWidget {
  const _CurrencyBalancesCard({
    required this.wallet,
    required this.highlightCurrency,
  });

  final WalletModel wallet;

  /// Code devise à mettre en surbrillance brièvement (recharge qui vient
  /// d'être confirmée), `null` sinon.
  final String? highlightCurrency;

  List<WalletCurrencyBalanceModel> get _rows {
    final rows = wallet.heldBalances
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        final byEstimate = (b.estimatedInActive ?? 0).compareTo(
          a.estimatedInActive ?? 0,
        );
        // Tri secondaire par code : List.sort n'est pas stable.
        return byEstimate != 0 ? byEstimate : a.currency.compareTo(b.currency);
      });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final active = SupportedCurrency.fromCodeOrDefault(wallet.currency);
    return DonyCard(
      child: Column(
        children: [
          for (final (i, row) in _rows.indexed) ...[
            if (i > 0) const Divider(height: DonySpacing.lg),
            _CurrencyBalanceRow(
              key: Key('wallet-currency-row-${row.currency.toUpperCase()}'),
              balance: row,
              activeCurrency: active,
              highlighted:
                  highlightCurrency != null &&
                  highlightCurrency!.toUpperCase() ==
                      row.currency.toUpperCase(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrencyBalanceRow extends StatelessWidget {
  const _CurrencyBalanceRow({
    super.key,
    required this.balance,
    required this.activeCurrency,
    required this.highlighted,
  });

  final WalletCurrencyBalanceModel balance;
  final SupportedCurrency activeCurrency;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currency = SupportedCurrency.fromCodeOrDefault(balance.currency);
    final estimate = balance.estimatedInActive;

    final Widget trailing;
    if (balance.active) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
        child: Text(
          'active',
          style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer),
        ),
      );
    } else if (estimate == null) {
      trailing = Text(
        'taux indisponible',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    } else {
      trailing = Text(
        '≈ ${CurrencyFormatter.format(estimate, activeCurrency)}',
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CurrencyFormatter.format(balance.balance, currency),
                style: tt.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currency.displayName,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );

    if (!highlighted || MediaQuery.of(context).disableAnimations) {
      return row;
    }
    // Surbrillance courte de la devise qui vient d'être créditée : le fond
    // part de blue50 et s'estompe en 1,2 s. Rejouée à chaque nouvelle clé.
    return TweenAnimationBuilder<double>(
      key: ValueKey('highlight-${balance.currency}'),
      tween: Tween(begin: 1, end: 0),
      duration: 1200.ms,
      curve: Curves.easeOut,
      builder: (context, t, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(Colors.transparent, DonyColors.blue50, t),
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
        child: child,
      ),
      child: row,
    );
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

// ─── Info sheet — fonctionnement du portefeuille ───────────────────────────────

class _WalletInfoContent extends StatelessWidget {
  const _WalletInfoContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _WalletInfoRow(
          iconAsset: 'wallet',
          title: 'Solde disponible',
          description:
              'Le montant utilisable pour payer un envoi ou demander un '
              'remboursement.',
        ),
        _WalletInfoRow(
          iconAsset: 'plus',
          title: 'Recharger',
          description:
              'Ajoutez des fonds par carte bancaire. Le crédit apparaît dès '
              'la validation du paiement.',
        ),
        _WalletInfoRow(
          iconAsset: 'arrow-up',
          title: 'Rembourser',
          description:
              'Demandez le remboursement de votre solde vers votre moyen de '
              'paiement d\'origine.',
        ),
        _WalletInfoRow(
          iconAsset: 'history',
          title: 'Demandes',
          description:
              'Retrouvez le suivi de vos demandes de remboursement envoyées.',
        ),
        _WalletInfoRow(
          iconAsset: 'wallet',
          title: 'Plusieurs devises',
          description:
              'Ton argent reste dans la devise où il a été reçu. Le total en '
              'haut est une estimation au taux du jour, il ne convertit rien.',
        ),
        _WalletInfoRow(
          iconAsset: 'lock',
          title: 'Changer de devise',
          description:
              'La devise active se change dans Préférences tant que ton solde '
              'total est à zéro. Sinon, vide d\'abord tes portefeuilles.',
        ),
      ],
    );
  }
}

class _WalletInfoRow extends StatelessWidget {
  const _WalletInfoRow({
    required this.iconAsset,
    required this.title,
    required this.description,
  });

  final String iconAsset;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon(iconAsset, color: cs.onSurfaceVariant, size: 18),
          ),
          const SizedBox(width: DonySpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
