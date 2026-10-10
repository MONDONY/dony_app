import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_parcel_line.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_payout_group.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_upcoming_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route de « Mes trajets » (écran D) ; `?announcementId=` la filtre sur un
/// trajet.
const kMoneyTripsRoute = '/payments/money/trips';

/// Nombre de colis versés récemment montrés sur l'écran principal ; le reste
/// est sur « Mes trajets ».
const int _kRecentlyPaidShown = 5;

/// Écran « Mon argent » (FLUTTER-HV, maquette F) : l'argent des colis, jamais
/// le solde du portefeuille Yadony. Carte « À venir » avec quatre tuiles
/// d'échéance, puis les prochains versements groupés par échéance (versements
/// datés, trajets à leur arrivée, litiges, vérifications), l'entrée « Tous mes
/// trajets » (écran D), les colis versés récemment et les envois payés.
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
          MoneyOverviewError(:final error) => MoneyErrorView(error: error),
          MoneyOverviewLoaded() => _Content(state: state),
        },
      ),
    );
  }
}

/// Erreur de chargement de l'aperçu, avec « Réessayer ».
class MoneyErrorView extends StatelessWidget {
  const MoneyErrorView({super.key, required this.error});

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

/// Pousse [location] puis rafraîchit l'aperçu au retour (un colis ou un
/// trajet a pu changer d'état).
Future<void> pushAndRefreshMoney(BuildContext context, String location) async {
  await context.push(location);
  if (context.mounted) {
    context.read<MoneyOverviewBloc>().add(
      const MoneyOverviewRefreshRequested(),
    );
  }
}

/// Pull-to-refresh : attend la fin de la requête.
Future<void> refreshMoney(BuildContext context) {
  final completer = Completer<void>();
  context.read<MoneyOverviewBloc>().add(
    MoneyOverviewRefreshRequested(completer: completer),
  );
  return completer.future;
}

/// Devise du « 0 » quand rien n'est attendu : la devise active, sinon celle
/// du premier colis.
String zeroCurrencyOf(MoneyOverviewModel overview) =>
    overview.activeCurrency ??
    [
      ...overview.travelerItems,
      ...overview.senderItems,
    ].map((i) => i.currency).whereType<String>().firstOrNull ??
    'EUR'; // i18n-ignore : code ISO de repli

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final MoneyOverviewLoaded state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final overview = state.overview;
    final schedule = state.schedule;

    void openParcel(MoneyItemModel item) =>
        unawaited(pushAndRefreshMoney(context, '/bids/${item.bidId}'));
    void openTrip(MoneyTrip trip) {
      final id = trip.announcementId;
      unawaited(
        pushAndRefreshMoney(
          context,
          id == null
              ? kMoneyTripsRoute
              : Uri(
                  path: kMoneyTripsRoute,
                  queryParameters: {'announcementId': id},
                ).toString(),
        ),
      );
    }

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(
        top: DonySpacing.xl - 2,
        bottom: DonySpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: tt.headlineMedium),
      ),
    );

    final zeroCurrency = zeroCurrencyOf(overview);
    final blocks = <Widget>[];
    if (!state.upcomingAvailable) {
      blocks.add(
        DonyEmptyState(
          key: const Key('money-unavailable'),
          iconAsset: 'hourglass', // i18n-ignore : nom d'icône
          title: l.moneyUnavailableTitle,
          description: l.moneyUnavailableBody,
        ),
      );
    } else if (overview.isEmpty) {
      blocks.add(
        DonyEmptyState(
          key: const Key('money-empty'),
          iconAsset: 'wallet', // i18n-ignore : nom d'icône
          title: l.moneyEmptyTitle,
          description: l.moneyEmptyBody,
        ),
      );
    } else {
      if (overview.travelerItems.isNotEmpty) {
        blocks.add(
          MoneyUpcomingCard.traveler(
            schedule: schedule,
            label: l.moneyUpcomingLabel(schedule.upcomingCount),
            zeroCurrency: zeroCurrency,
          ),
        );
      } else if (overview.senderBlockedCount > 0) {
        blocks.add(
          MoneyUpcomingCard(
            label: l.moneySenderHeroLabel(overview.senderBlockedCount),
            amounts: overview.senderBlocked,
            zeroCurrency: zeroCurrency,
          ),
        );
      }
      if (overview.truncated) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.sm),
            child: Text(
              l.moneyTruncatedNote,
              key: const Key('money-truncated'),
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      if (schedule.groups.isNotEmpty) {
        blocks.add(sectionTitle(l.moneyNextPayoutsSection));
        for (var i = 0; i < schedule.groups.length; i++) {
          blocks.add(
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : DonySpacing.base),
              child: MoneyPayoutGroup(
                group: schedule.groups[i],
                onOpenParcel: openParcel,
                onOpenTrip: openTrip,
              ),
            ),
          );
        }
      }
      if (schedule.trips.isNotEmpty) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.base),
            child: _AllTripsEntry(
              onTap: () =>
                  unawaited(pushAndRefreshMoney(context, kMoneyTripsRoute)),
            ),
          ),
        );
      }
      if (schedule.recentlyPaid.isNotEmpty) {
        blocks
          ..add(sectionTitle(l.moneyRecentlyPaidSection))
          ..add(
            _LineList(
              items: schedule.recentlyPaid.take(_kRecentlyPaidShown).toList(),
              onOpenParcel: openParcel,
            ),
          );
      }
      if (overview.senderItems.isNotEmpty) {
        blocks
          ..add(sectionTitle(l.moneySenderSection))
          ..add(
            _LineList(items: overview.senderItems, onOpenParcel: openParcel),
          );
      }
    }
    blocks.add(_WalletLink(onTap: () => context.push('/payments/wallet')));

    return RefreshIndicator(
      onRefresh: () => refreshMoney(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        children: [
          for (var i = 0; i < blocks.length; i++)
            blocks[i]
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 60 * i.clamp(0, 6)),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                )
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

/// Liste compacte de colis dans une carte (versés récemment, envois).
class _LineList extends StatelessWidget {
  const _LineList({required this.items, required this.onOpenParcel});

  final List<MoneyItemModel> items;
  final ValueChanged<MoneyItemModel> onOpenParcel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            _line(items[i], l),
          ],
        ],
      ),
    );
  }

  Widget _line(MoneyItemModel item, AppLocalizations l) {
    final state = shortStateFor(item, l);
    return MoneyParcelLine(
      item: item,
      onTap: () => onOpenParcel(item),
      details: [?routeOf(item.departureCity, item.arrivalCity)],
      status: state.text,
      tone: state.tone,
    );
  }
}

/// Entrée « Tous mes trajets » vers l'écran D.
class _AllTripsEntry extends StatelessWidget {
  const _AllTripsEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: DonyPressable(
        onTap: onTap,
        child: Container(
          key: const Key('money-all-trips'),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.flight_rounded, size: 20, color: cs.primary),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  context.l10n.moneyAllTripsLink,
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

/// Lien discret vers le solde Yadony (`/payments/wallet`) : un autre argent,
/// libellé distinct, jamais mêlé aux montants des colis.
class _WalletLink extends StatelessWidget {
  const _WalletLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xl),
      child: Center(
        child: Semantics(
          link: true,
          child: DonyPressable(
            onTap: onTap,
            child: Container(
              key: const Key('money-wallet-link'),
              color: Colors.transparent,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.moneyWalletLink,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
