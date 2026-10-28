import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_active_currency_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/wallet_tx_label.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_balances_sheet.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_confirm_sheet.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_currency_sheet.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_selection_sheet.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/l10n.dart';
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
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Chargement et erreur n'ont pas le héros du portefeuille : sans cet
        // en-tête, ni retour ni scarabée sur un écran d'erreur persistant.
        appBar: state is WalletLoaded
            ? null
            : DonyAppBar(title: context.l10n.walletTitle),
        body: switch (state) {
          WalletInitial() || WalletLoading() => const _LoadingView(),
          WalletError(:final error) => _ErrorView(
            message: ErrorPresenter.resolve(error, l10n: context.l10n).message,
          ),
          WalletLoaded(:final wallet) => _LoadedView(
            wallet: wallet,
            topupBanner: _topupBanner,
          ),
          _ => const SizedBox.shrink(),
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
              label: context.l10n.commonRetry,
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
    final l = context.l10n;
    final transactions = wallet.transactions;
    final activeCurrency = SupportedCurrency.fromCodeOrDefault(wallet.currency);
    // Une devise non active à solde 0 ne bloque rien : on ne l'affiche pas
    // comme "verrouillée", ça n'a rien de réel à protéger.
    final lockedBalances = wallet.balances
        .where((b) => !b.active && b.balance != 0)
        .toList();

    return _ActiveCurrencyListener(
      child: RefreshIndicator(
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
                l.walletTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: DonyColors.neutral0,
                  fontSize: 17,
                ),
              ),
              actions: [
                _BalancesButton(wallet: wallet),
                IconButton(
                  tooltip: l.walletInfoTooltip,
                  onPressed: () => DonyBottomSheet.show(
                    context,
                    title: l.walletInfoTitle,
                    child: const _WalletInfoContent(),
                  ),
                  icon: const DonyIcon(
                    'circle-alert',
                    color: DonyColors.neutral0,
                    size: 22,
                  ),
                ),
                const DonyFeedbackButton(),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _HeroHeader(
                  balance: wallet.balance,
                  currency: activeCurrency,
                  refundEligible: wallet.refundEligible,
                  refundableAmount: wallet.activeBalance?.refundableAmount,
                  nonRefundableAmount:
                      wallet.activeBalance?.nonRefundableAmount,
                  refundFeeAmount: wallet.activeBalance?.refundFeeAmount,
                  refundNetAmount: wallet.activeBalance?.refundNetAmount,
                  estimatedTotal: wallet.estimatedTotal,
                  estimateComplete: wallet.estimateComplete,
                  multiCurrency: wallet.heldBalances.length > 1,
                  eligibleBalances: wallet.eligibleBalances,
                  onChangeCurrency: () =>
                      unawaited(_openWalletBalances(context, wallet)),
                ),
              ),
            ),

            // ── À quoi sert le solde ─────────────────────────────────────────────
            // Une ligne, toujours visible : des expéditeurs rechargeaient pour
            // payer un envoi, ce que le portefeuille ne fait pas (FLUTTER-DS).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  0,
                ),
                child: Text(
                  l.walletPurposeNote,
                  key: const Key('wallet-purpose-note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                      message: l.walletTopupConfirmed(
                        CurrencyFormatter.format(status.amount, topupCurrency),
                        topupCurrency.name(l),
                        status.providerLabel,
                      ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.lg,
                    DonySpacing.lg,
                    0,
                  ),
                  child: DonyStatusBanner(
                    key: const Key('wallet-refund-absorbed-by-fees'),
                    type: DonyStatusBannerType.info,
                    iconAsset: 'circle-alert',
                    message: l.walletRefundAbsorbedByFees,
                  ),
                ),
              ),

            // ── Ancien contrat back : tuiles des devises non actives ───────────
            // Avec le nouveau contrat, l'argent de chaque devise vit dans la feuille
            // « Mes soldes » (bouton de l'en-tête).
            if (!wallet.hasEstimate && lockedBalances.isNotEmpty)
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
                          l.walletEmptyTransactions,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                    l.walletHistorySectionTitle,
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
              const SliverToBoxAdapter(
                child: SizedBox(height: DonySpacing.huge),
              ),
            ],
          ],
        ),
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
    required this.onChangeCurrency,
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

  /// Ouvre la feuille « Mes soldes » (lien « Changer » sous le total).
  final VoidCallback onChangeCurrency;

  /// Somme estimée de tous les portefeuilles dans [currency], `null` sur
  /// l'ancien contrat (l'en-tête retombe alors sur « Solde disponible »).
  final double? estimatedTotal;

  /// `false` quand une devise détenue n'a pas de taux du jour : le sous-titre
  /// avertit que l'estimation est partielle.
  final bool estimateComplete;

  /// Plus d'une devise réellement détenue : seul ce cas affiche « Total
  /// estimé » et le sous-titre, sinon rien à estimer.
  final bool multiCurrency;

  /// « Rembourser » apparaît dès qu'une devise, active ou non, a un montant
  /// remboursable connu et positif (`WalletModel.eligibleBalances`). Sur
  /// l'ancien contrat back (liste toujours vide, aucun montant exposé),
  /// repli sur la règle historique : `refundEligible` seul sur la devise
  /// active.
  bool get _canRefund =>
      eligibleBalances.isNotEmpty ||
      (refundEligible && (refundNetAmount ?? refundableAmount ?? 1) > 0);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      // Bleu foncé uni, même teinte que la carte Solde du profil : le blanc
      // des libellés y reste lisible dans les deux thèmes.
      color: DonyColors.blue700,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.huge,
            DonySpacing.lg,
            DonySpacing.xl,
          ),
          // `SingleChildScrollView` en `reverse: true` : le contenu se
          // colle au bas de la zone disponible (comme le faisait
          // `mainAxisAlignment.end`) quand il tient, et se laisse
          // simplement scroller sans erreur `RenderFlex overflowed` quand
          // une grande police système le dépasse (`NeverScrollableScrollPhysics`
          // désactive le geste, même protection que la ligne d'actions
          // horizontale ci-dessous).
          child: SingleChildScrollView(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  estimatedTotal != null && multiCurrency
                      ? l.walletHeroTotalInLabel(currency.code)
                      : l.walletAvailableBalanceLabel,
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: estimateComplete
                              ? l.walletEstimateCompleteNote
                              : l.walletEstimatePartialNote,
                        ),
                        const TextSpan(text: ' '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: _ChangeLink(onTap: onChangeCurrency),
                        ),
                      ],
                    ),
                    key: estimateComplete
                        ? null
                        : const Key('wallet-estimate-partial'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                          SnackBar(
                            content: Text(
                              context.l10n.walletRefundRequestSentSnackbar,
                            ),
                          ),
                        );
                        context.read<WalletBloc>().add(
                          WalletRefreshRequested(),
                        );
                      }
                      if (state.error != null) {
                        ErrorPresenter.show(context, state.error);
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
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final l = context.l10n;
    final actions = [
      _HeroAction(
        iconAsset: 'plus',
        label: l.walletActionTopUp,
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
          label: l.walletActionRefund,
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
            // Une seule devise éligible : `WalletModel.eligibleBalances` ne
            // retient que les montants remboursables connus, direct vers la
            // confirmation, active ou non. Sinon (ancien contrat : le champ
            // `refundEligible` existe mais pas encore les montants), repli
            // sur les champs historiques de la devise active ci-dessous.
            if (eligibleBalances.length == 1) {
              _openConfirm(context, eligibleBalances.first);
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
                WalletRefundSelectionSheet.show(
                  context,
                  currency: currency.code,
                ),
              );
            }
          },
        ),
      _HeroAction(
        iconAsset: 'history',
        label: l.walletActionRequests,
        onTap: () => context.push('/payments/wallet/refunds'),
      ),
    ];
    return _actionsRow(actions);
  }

  void _openConfirm(BuildContext context, WalletCurrencyBalanceModel b) {
    WalletRefundConfirmSheet.show(
      context,
      currency: b.currency,
      refundableAmount: b.refundableAmount ?? 0,
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

// ─── Lien « Changer » sous le total ────────────────────────────────────────────

/// Lien discret sous le total estimé : ouvre « Mes soldes » pour choisir la
/// devise du total. Zone de toucher agrandie sans gonfler la ligne.
class _ChangeLink extends StatelessWidget {
  const _ChangeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.walletActiveCurrencyChange;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('wallet-change-link'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DonyColors.neutral0,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: DonyColors.neutral0,
          ),
        ),
      ),
    );
  }
}

/// Bouton de l'en-tête qui ouvre « Mes soldes ». Pendant l'enregistrement d'un
/// changement de devise du total, il laisse place à un indicateur : le geste
/// n'est pas relançable (le cubit ignore d'ailleurs un second changement).
class _BalancesButton extends StatelessWidget {
  const _BalancesButton({required this.wallet});

  final WalletModel wallet;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      WalletActiveCurrencyCubit,
      WalletActiveCurrencyState,
      bool
    >(
      selector: (state) => state.isSwitching,
      builder: (context, switching) {
        if (switching) {
          return const SizedBox(
            key: Key('wallet-balances-switching'),
            width: kDonyMinTapTarget,
            height: kDonyMinTapTarget,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DonyColors.neutral0,
                ),
              ),
            ),
          );
        }
        return IconButton(
          key: const Key('wallet-balances-button'),
          tooltip: context.l10n.walletBalancesButtonTooltip,
          onPressed: () => unawaited(_openWalletBalances(context, wallet)),
          icon: const DonyIcon('wallet', color: DonyColors.neutral0, size: 22),
        );
      },
    );
  }
}

/// Ouvre « Mes soldes » puis, si une autre devise du total est choisie, la
/// fait enregistrer : aucun solde n'est converti. Le retour (snackbar,
/// resynchro des préférences et des soldes) vit dans [_ActiveCurrencyListener].
Future<void> _openWalletBalances(
  BuildContext context,
  WalletModel wallet,
) async {
  final cubit = context.read<WalletActiveCurrencyCubit>();
  if (cubit.state.isSwitching) return;
  final chosen = await WalletBalancesSheet.show(
    context,
    activeCurrency: wallet.currency,
    balances: wallet.balances,
    estimatedTotal: wallet.estimatedTotal,
  );
  if (chosen == null || !context.mounted) return;
  unawaited(cubit.switchTo(chosen));
}

/// Réagit au changement de devise du total : erreur, ou succès (préférences
/// locales resynchronisées depuis le serveur, soldes rechargés, snackbar).
class _ActiveCurrencyListener extends StatelessWidget {
  const _ActiveCurrencyListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocListener<WalletActiveCurrencyCubit, WalletActiveCurrencyState>(
      listenWhen: (previous, current) =>
          previous.switchCount != current.switchCount ||
          (current.error != null && previous.error != current.error),
      listener: (context, state) {
        final error = state.error;
        if (error != null) {
          ErrorPresenter.show(context, error);
          return;
        }
        final switched = SupportedCurrency.fromCodeOrDefault(state.switchedTo);
        // Les préférences locales (Hive) portent la devise active lue par les
        // recharges et les créations : on les resynchronise depuis le serveur,
        // puis on recharge les soldes pour déplacer la pastille.
        context.read<BusinessPrefsBloc>().add(
          const BusinessPrefsSyncRequested(),
        );
        context.read<WalletBloc>().add(WalletRefreshRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.walletActiveCurrencySwitchedSnackbar(switched.name(l)),
            ),
          ),
        );
      },
      child: child,
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

  String _label(AppLocalizations l) => walletTxLabel(l, tx);

  /// Ouvre la fiche du colis de la ligne (FLUTTER-QP), la même que « Mon
  /// argent » : `/bids/{bidId}`, qui sert l'expéditeur comme le voyageur.
  /// Au retour, le solde se recharge sans spinner : une action sur le colis
  /// (annulation, remboursement) a pu le changer.
  Future<void> _openParcel(BuildContext context, String bidId) async {
    if (getIt.isRegistered<AnalyticsService>()) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.walletTxParcelOpened,
          properties: {'type': tx.type},
        ),
      );
    }
    await context.push('/bids/$bidId');
    if (context.mounted) {
      context.read<WalletBloc>().add(WalletRefreshRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final isCredit = tx.isCredit;
    final isRefundProcessing = tx.isRefundProcessing;
    final amountColor = isCredit ? DonyColors.success500 : DonyColors.terra600;
    final amountPrefix = isCredit ? '+' : '';
    // La ligne porte sa propre devise (une recharge XOF dans un portefeuille
    // actif EUR reste en F CFA). Sans devise (ancien contrat back) : devise
    // active ; code inconnu : repli signalé de `fromCodeOrDefault`.
    final lineCurrency = tx.currency == null
        ? currency
        : SupportedCurrency.fromCodeOrDefault(tx.currency);
    final bidId = tx.bidId;

    final card = DonyCard(
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
                  _label(l),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isRefundProcessing
                      ? l.walletRefundProcessingNote
                      : [
                          DateFormat(
                            l.walletTxDateTimePattern,
                            l.localeName,
                          ).format(tx.createdAt),
                          // Commission prélevée sur un autre portefeuille que
                          // celui du colis : le montant d'origine (jamais le
                          // taux, recalculé sur des montants arrondis).
                          if (tx.hasSource)
                            l.walletTxSourceNote(
                              CurrencyFormatter.format(
                                tx.sourceAmount!,
                                SupportedCurrency.fromCodeOrDefault(
                                  tx.sourceCurrency,
                                ),
                              ),
                            ),
                        ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isRefundProcessing
                        ? cs.warning
                        : cs.onSurfaceVariant,
                    fontWeight: isRefundProcessing ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Text(
            '$amountPrefix${CurrencyFormatter.format(tx.amount.abs(), lineCurrency)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Ligne liée à un colis : chevron discret, la fiche s'ouvre.
          if (bidId != null) ...[
            const SizedBox(width: DonySpacing.xs),
            DonyIcon('chevron-right', color: cs.onSurfaceVariant, size: 16),
          ],
        ],
      ),
    );

    return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: DonySpacing.xs,
          ),
          child: bidId == null
              ? card
              : Semantics(
                  button: true,
                  hint: l.walletTxOpenParcelHint,
                  child: DonyPressable(
                    key: ValueKey('wallet-tx-parcel-$bidId'),
                    onTap: () => unawaited(_openParcel(context, bidId)),
                    child: card,
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
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(balance.currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Semantics(
        label: l.walletLockedCurrencySemantics(currency.name(l)),
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
                            l.walletLockedBadge,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.walletLockedCurrencyNote(currency.name(l)),
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
    final l = context.l10n;
    return Column(
      children: [
        _WalletInfoRow(
          iconAsset: 'wallet',
          title: l.walletAvailableBalanceLabel,
          description: l.walletInfoBalanceDesc,
        ),
        _WalletInfoRow(
          iconAsset: 'plus',
          title: l.walletActionTopUp,
          description: l.walletInfoTopUpDesc,
        ),
        _WalletInfoRow(
          iconAsset: 'arrow-up',
          title: l.walletActionRefund,
          description: l.walletInfoRefundDesc,
        ),
        _WalletInfoRow(
          iconAsset: 'history',
          title: l.walletActionRequests,
          description: l.walletInfoRequestsDesc,
        ),
        _WalletInfoRow(
          iconAsset: 'wallet',
          title: l.walletInfoMultiCurrencyTitle,
          description: l.walletInfoMultiCurrencyDesc,
        ),
        _WalletInfoRow(
          iconAsset: 'lock',
          title: l.walletInfoChangeCurrencyTitle,
          description: l.walletInfoChangeCurrencyDesc,
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
