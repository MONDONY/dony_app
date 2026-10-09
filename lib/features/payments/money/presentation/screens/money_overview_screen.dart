import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_parcel_card.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_summary_cards.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Mon argent » (FLUTTER-HV, maquette B « Frise de libération ») :
/// soldes disponibles, argent bloqué jusqu'à livraison, puis une carte par
/// colis avec la frise Payé → Remis → Livré → Versé et la condition ou la
/// date de versement. Lien vers l'historique des mouvements du portefeuille.
class MoneyOverviewScreen extends StatelessWidget {
  const MoneyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(title: l.moneyTitle),
      body: BlocBuilder<MoneyOverviewBloc, MoneyOverviewState>(
        builder: (context, state) => switch (state) {
          MoneyOverviewInitial() || MoneyOverviewLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          MoneyOverviewError(:final error) => _ErrorView(error: error),
          MoneyOverviewLoaded() => _Content(state: state),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final presentation = ErrorCatalog.lookup(error, l10n: l);
    return Center(
      child: DonyEmptyState(
        type: DonyEmptyStateType.error,
        title: presentation.title,
        description: presentation.message,
        actionLabel: l.commonRetry,
        onAction: () => context.read<MoneyOverviewBloc>().add(
          const MoneyOverviewLoadRequested(),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final MoneyOverviewLoaded state;

  Future<void> _openParcel(BuildContext context, MoneyItemModel item) async {
    await context.push('/bids/${item.bidId}');
    if (context.mounted) {
      context.read<MoneyOverviewBloc>().add(
        const MoneyOverviewRefreshRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final overview = state.overview;
    final bloc = context.read<MoneyOverviewBloc>();

    Widget section(String title, List<MoneyItemModel> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DonySpacing.xl - 2),
        Text(title, style: tt.headlineMedium),
        const SizedBox(height: DonySpacing.md - 2),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.md),
          MoneyParcelCard(
                item: items[i],
                onTap: () => _openParcel(context, items[i]),
              )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 60 * i.clamp(0, 6)),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              )
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ],
      ],
    );

    final children = <Widget>[
      MoneySummaryCards(
        overview: overview,
        showBlocked: state.upcomingAvailable,
      ),
      if (!state.upcomingAvailable)
        Padding(
          padding: const EdgeInsets.only(top: DonySpacing.xl),
          child: DonyEmptyState(
            key: const Key('money-unavailable'),
            iconAsset: 'hourglass', // i18n-ignore : nom d'icône
            title: l.moneyUnavailableTitle,
            description: l.moneyUnavailableBody,
          ),
        )
      else if (overview.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: DonySpacing.xl),
          child: DonyEmptyState(
            key: const Key('money-empty'),
            iconAsset: 'wallet', // i18n-ignore : nom d'icône
            title: l.moneyEmptyTitle,
            description: l.moneyEmptyBody,
          ),
        )
      else ...[
        if (overview.travelerItems.isNotEmpty)
          section(l.moneyWhenSection, overview.travelerItems),
        if (overview.senderItems.isNotEmpty)
          section(l.moneySenderSection, overview.senderItems),
      ],
      const SizedBox(height: DonySpacing.base),
      _HistoryLink(onTap: () => context.push('/payments/wallet')),
    ];

    return RefreshIndicator(
      onRefresh: () {
        final completer = Completer<void>();
        bloc.add(MoneyOverviewRefreshRequested(completer: completer));
        return completer.future;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        children: children,
      ),
    );
  }
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: DonyPressable(
        onTap: onTap,
        child: Container(
          key: const Key('money-history-link'),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.moneyHistoryLink,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(DonyIcons.chevron, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
