import 'dart:async';

import 'package:dony/app/main_shell.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/activity_tile.dart';
import 'package:dony/features/matching/presentation/widgets/stat_tile.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/presentation/package_request_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

void _logEvent(String event) {
  unawaited(getIt<AnalyticsService>().logEvent(event));
}

/// Trace l'intention puis ouvre la destination. Partagé par le hub et sa
/// grille de tuiles, qui poussent tous deux des routes tracées.
void _openRoute(BuildContext context, String event, String route) {
  _logEvent(event);
  context.push(route);
}

/// Onglet Activités — hub unique, identique pour tous les utilisateurs.
///
/// Remplace le dispatch par rôle de l'ancien `MatchingManagementScreen` : dans
/// le modèle double rôle, chacun est à la fois expéditeur et transporteur, donc
/// les quatre domaines d'activité sont toujours visibles.
class ActivitesHubScreen extends StatelessWidget {
  const ActivitesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TripsSummaryCubit>()),
        BlocProvider(create: (_) => getIt<TravelerBidsBloc>()),
        BlocProvider(create: (_) => getIt<BidBloc>()),
        BlocProvider(create: (_) => StatsPeriodCubit()),
        BlocProvider.value(value: getIt<NegotiationListBloc>()),
      ],
      child: const _ActivitesHubView(),
    );
  }
}

/// Variante de test : les blocs sont fournis par le contexte parent.
@visibleForTesting
class ActivitesHubScreenTesting extends StatelessWidget {
  const ActivitesHubScreenTesting({super.key});

  @override
  Widget build(BuildContext context) => const _ActivitesHubView();
}

class _ActivitesHubView extends StatefulWidget {
  const _ActivitesHubView();

  @override
  State<_ActivitesHubView> createState() => _ActivitesHubViewState();
}

class _ActivitesHubViewState extends State<_ActivitesHubView> {
  late final EnvoisRefreshNotifier _refreshNotifier;

  @override
  void initState() {
    super.initState();
    // Le shell notifie ce singleton au retour sur l'onglet (main_shell.dart:49).
    _refreshNotifier = getIt<EnvoisRefreshNotifier>();
    _refreshNotifier.addListener(_onTabRefreshRequested);
    _loadAll();
  }

  @override
  void dispose() {
    _refreshNotifier.removeListener(_onTabRefreshRequested);
    super.dispose();
  }

  void _onTabRefreshRequested() {
    if (mounted) _loadAll();
  }

  void _loadAll() {
    final period = context.read<StatsPeriodCubit>().state;
    unawaited(context.read<TripsSummaryCubit>().load(period: period));
    context.read<TravelerBidsBloc>().add(
      const TravelerBidsRequested(force: true),
    );
    context.read<BidBloc>().add(BidMyListAutoRefreshRequested(force: true));
    context.read<NegotiationListBloc>().add(NegotiationListFetchRequested());
  }

  Future<void> _onRefresh() async {
    _loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _open(String event, String route) => _openRoute(context, event, route);

  Future<void> _onNewRequest() async {
    _logEvent(AnalyticsEvents.activitesHubRequestCreateOpened);
    await openPackageRequestWizard(context);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocListener<StatsPeriodCubit, StatsPeriod>(
          listener: (context, period) {
            _logEvent(AnalyticsEvents.activitesHubStatsPeriodChanged);
            unawaited(
              context.read<TripsSummaryCubit>().load(period: period),
            );
          },
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  // Aucune marge basse : la rangée de statistiques suit
                  // immédiatement, à la distance donnée par le SizedBox final.
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.md,
                    DonySpacing.lg,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _Header(
                        onSearch: () => _open(
                          AnalyticsEvents.activitesHubSearchOpened,
                          '/tracking/search',
                        ),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      _ActionRow(
                        onPublishTrip: () => _open(
                          AnalyticsEvents.activitesHubTripCreateOpened,
                          '/trips/create',
                        ),
                        onNewRequest: _onNewRequest,
                      ),
                      const SizedBox(height: DonySpacing.xl),
                      Text('Activités', style: tt.titleMedium),
                      const SizedBox(height: DonySpacing.md),
                      const _ActivityGrid(),
                      const SizedBox(height: DonySpacing.xl),
                      Text('Statistiques', style: tt.titleMedium),
                      const SizedBox(height: DonySpacing.md),
                      const _PeriodChips(),
                      const SizedBox(height: DonySpacing.md),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: _StatsRow()),
                SliverPadding(
                  // Le shell monte cet écran avec extendBody: true — sans
                  // cette réserve, les tuiles « Autres » passent sous la
                  // barre d'onglets.
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    MainShell.navBarContentHeight +
                        MediaQuery.paddingOf(context).bottom +
                        DonySpacing.lg,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Text('Autres', style: tt.titleMedium),
                      const SizedBox(height: DonySpacing.md),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _OtherTile(
                                iconName: 'chart-line',
                                label: 'Historique complet',
                                onTap: () => _open(
                                  AnalyticsEvents.activitesHubHistoryOpened,
                                  '/profile/shipments/history',
                                ),
                              ),
                            ),
                            const SizedBox(width: DonySpacing.md),
                            Expanded(
                              child: _OtherTile(
                                iconName: 'circle-help',
                                label: 'Aide & support',
                                onTap: () => _open(
                                  AnalyticsEvents.activitesHubHelpOpened,
                                  '/profile/help/faq',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DonySpacing.base),
                      Text(
                        'Retrouvez ici tout ce que vous envoyez et tout ce que '
                        'vous transportez.',
                        style: tt.bodySmall?.copyWith(
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
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(child: Text('Activités', style: tt.headlineLarge)),
        IconButton(
          onPressed: onSearch,
          tooltip: 'Rechercher',
          icon: DonyIcon('search', size: 20, color: cs.onSurface),
        ),
      ],
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onPublishTrip, required this.onNewRequest});

  final VoidCallback onPublishTrip;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('hub-publish-trip'),
            onPressed: onPublishTrip,
            icon: const DonyIcon('send', size: 16, color: Colors.white),
            label: const Text('Publier un trajet'),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          // Terracotta plein sur fond clair, comme la maquette : le bouton
          // contouré par défaut du thème porte une bordure grise qui le
          // rapprochait trop du fond.
          child: OutlinedButton.icon(
            key: const Key('hub-new-request'),
            onPressed: onNewRequest,
            icon: DonyIcon('package', size: 16, color: cs.secondary),
            label: const Text('Envoyer un colis'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.secondary,
              backgroundColor: cs.secondaryContainer,
              side: BorderSide(color: cs.secondary.withValues(alpha: 0.35)),
              // Le rembourrage par défaut d'OutlinedButton.icon fait passer le
              // libellé sur deux lignes une fois la largeur partagée en deux.
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Grille d'activité ────────────────────────────────────────────────────────

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Un BlocBuilder par tuile, pas un global : une erreur sur les statistiques
    // ne doit pas vider les trois autres compteurs.
    final trips = BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
      builder: (context, state) => ActivityTile(
        key: const Key('hub-tile-trips'),
        iconName: 'plane',
        iconColor: cs.primary,
        iconBackground: cs.primaryContainer,
        value: state.summary?.activeTrips ?? 0,
        label: 'Trajets actifs',
        isLoading: state.status == TripsSummaryStatus.loading,
        hasError: state.status == TripsSummaryStatus.hidden,
        onTap: () => _openRoute(
          context,
          AnalyticsEvents.activitesHubTripsOpened,
          '/announcements/trips',
        ),
      ),
    );

    final shipments = BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        final loaded = state is BidListLoaded ? state : null;
        final count = loaded == null
            ? 0
            : loaded.bids
                  .where((b) => kEnvoisEnCours.contains(b.status))
                  .length;
        return ActivityTile(
          key: const Key('hub-tile-shipments'),
          iconName: 'package',
          iconColor: cs.secondary,
          iconBackground: cs.secondaryContainer,
          value: count,
          label: 'Envois en cours',
          isLoading: state is BidLoading,
          hasError: state is BidError,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubEnvoisOpened,
            '/envois',
          ),
        );
      },
    );

    final requests = BlocBuilder<TravelerBidsBloc, TravelerBidsState>(
      builder: (context, state) {
        final loaded = state is TravelerBidsLoaded ? state : null;
        final count = loaded?.pendingCount ?? 0;
        return ActivityTile(
          key: const Key('hub-tile-requests'),
          iconName: 'bell',
          iconColor: cs.error,
          iconBackground: cs.errorContainer,
          value: count,
          label: 'Demandes',
          isLoading: state is TravelerBidsLoading,
          hasError: state is TravelerBidsError,
          showNotificationDot: count > 0,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubDemandesOpened,
            '/demandes',
          ),
        );
      },
    );

    final negotiations = BlocBuilder<NegotiationListBloc, NegotiationListState>(
      builder: (context, state) {
        final count = state.activeCount;
        return ActivityTile(
          key: const Key('hub-tile-negotiations'),
          iconName: 'arrow-left-right',
          // Violet : la seule des quatre tuiles hors palette de marque, pour
          // séparer la négociation des trois domaines bleu/terracotta/rouge.
          iconColor: DonyColors.violet,
          iconBackground: DonyColors.violetLight,
          value: count,
          label: 'Négociations',
          isLoading: state.status == NegotiationListStatus.loading,
          hasError: state.status == NegotiationListStatus.error,
          showNotificationDot: count > 0,
          onTap: () => _openRoute(
            context,
            AnalyticsEvents.activitesHubNegotiationsOpened,
            '/negotiations',
          ),
        );
      },
    );

    return Column(
      children: [
        _TileRow(left: trips, right: shipments),
        const SizedBox(height: DonySpacing.md),
        _TileRow(left: requests, right: negotiations),
      ],
    );
  }
}

/// Deux tuiles de hauteur égale.
///
/// `IntrinsicHeight` est nécessaire : dans un scroll, `stretch` seul réclame
/// une hauteur infinie et fait échouer le layout.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: DonySpacing.md),
          Expanded(child: right),
        ],
      ),
    );
  }
}

// ── Statistiques ─────────────────────────────────────────────────────────────

class _PeriodChips extends StatelessWidget {
  const _PeriodChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatsPeriodCubit, StatsPeriod>(
      builder: (context, selected) => Row(
        children: [
          for (final p in StatsPeriod.values) ...[
            DonyChip(
              key: Key('hub-period-${p.apiValue}'),
              label: p.label,
              selected: p == selected,
              onTap: () => context.read<StatsPeriodCubit>().select(p),
            ),
            if (p != StatsPeriod.values.last)
              const SizedBox(width: DonySpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  String _money(double v) => '${formatKgPrice(v)} €';

  String _weight(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kg';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
      builder: (context, state) {
        final summary = state.summary;
        final loading = state.status == TripsSummaryStatus.loading;
        final tiles = <Widget>[
          StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: _money(summary?.revenue ?? 0),
            isLoading: loading,
          ),
          StatTile(
            iconName: 'scale',
            label: 'Kg vendus',
            value: _weight(summary?.kgSold ?? 0),
            isLoading: loading,
          ),
          // Un backend antérieur ne renvoie pas ces deux compteurs. Afficher 0
          // laisserait croire à une absence d'activité : on montre « — »,
          // comme les tuiles dont le compteur est indisponible.
          StatTile(
            iconName: 'plane',
            label: 'Trajets',
            value: summary?.tripsPublished == null
                ? '—'
                : '${summary!.tripsPublished} publiés',
            isLoading: loading,
          ),
          StatTile(
            iconName: 'package',
            label: 'Envois',
            value: summary?.parcelsSent == null
                ? '—'
                : '${summary!.parcelsSent} envoyés',
            isLoading: loading,
          ),
        ];

        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
            itemCount: tiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: DonySpacing.md),
            itemBuilder: (_, i) => tiles[i],
          ),
        );
      },
    );
  }
}

// ── Autres ───────────────────────────────────────────────────────────────────

class _OtherTile extends StatelessWidget {
  const _OtherTile({
    required this.iconName,
    required this.label,
    required this.onTap,
  });

  final String iconName;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(iconName, size: 20, color: cs.onSurface),
          const SizedBox(height: DonySpacing.xl),
          Text(
            label,
            style: tt.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
