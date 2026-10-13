import 'dart:async';

import 'package:dony/app/main_shell.dart';
import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/features/matching/presentation/widgets/kg_sold_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/revenue_details_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/stat_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

void _logEvent(String event) {
  unawaited(getIt<AnalyticsService>().logEvent(event));
}

/// Écran « Mes statistiques » (`/announcements/stats`), ouvert depuis le menu
/// ☰ d'Activités : revenus, kg vendus, trajets publiés et colis envoyés sur
/// la période choisie. Ces chiffres vivaient dans le hub, à la place qu'occupe
/// désormais le bloc « Billets d'avion ».
class ActivityStatsScreen extends StatelessWidget {
  const ActivityStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<TripsSummaryCubit>()..load()),
        BlocProvider(create: (_) => getIt<StatsPeriodCubit>()),
      ],
      child: const ActivityStatsView(),
    );
  }
}

/// Contenu de l'écran, blocs lus dans le contexte (fournis par
/// [ActivityStatsScreen], ou par le test).
@visibleForTesting
class ActivityStatsView extends StatelessWidget {
  const ActivityStatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: DonyAppBar(title: l.activityStatsTitle),
      body: BlocListener<StatsPeriodCubit, StatsPeriod>(
        listener: (context, period) {
          _logEvent(AnalyticsEvents.activitesHubStatsPeriodChanged);
          unawaited(context.read<TripsSummaryCubit>().load(period: period));
        },
        child: ListView(
          // L'écran s'ouvre dans la branche Activités, sous la barre
          // d'onglets (extendBody) : sans cette réserve, la dernière rangée
          // passerait dessous sur un petit téléphone.
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.base,
            DonySpacing.lg,
            MainShell.navBarContentHeight +
                MediaQuery.paddingOf(context).bottom +
                DonySpacing.lg,
          ),
          children: const [
            _PeriodChips(),
            SizedBox(height: DonySpacing.base),
            _StatsGrid(),
          ],
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<StatsPeriodCubit, StatsPeriod>(
      builder: (context, selected) => Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          for (final p in StatsPeriod.values)
            DonyChip(
              key: Key('stats-period-${p.apiValue}'),
              label: p.label(l),
              selected: p == selected,
              onTap: () => context.read<StatsPeriodCubit>().select(p),
            ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  /// « ≈ » dès que le backend dit avoir converti : la somme exacte, devise par
  /// devise, vit dans la feuille ouverte au tap.
  ///
  /// Le montant est formaté dans la devise annoncée par le backend
  /// (`revenueCurrency`), pas dans la devise active locale : le cache serveur
  /// n'est pas évincé au changement de devise, et pendant quelques minutes
  /// après un passage EUR → XOF le total arrive encore en euros. Repli sur la
  /// devise active seulement quand le backend ne dit rien (ancien contrat).
  String _money(TripsSummaryModel? summary) {
    final value = formatPriceIn(
      summary?.revenue ?? 0,
      summary?.revenueCurrency ?? ActiveCurrency.current?.code,
    );
    return (summary?.isRevenueConverted ?? false) ? '≈ $value' : value;
  }

  String _weight(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kg';

  /// Ouvre une liste filtrée. Au retour, le hub se recharge (bridé à 3 s),
  /// comme après une tuile du hub.
  void _openList(BuildContext context, String event, String route) {
    _logEvent(event);
    unawaited(
      context.push<Object?>(route).then((_) {
        if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
          getIt<EnvoisRefreshNotifier>().requestRefresh();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return BlocBuilder<TripsSummaryCubit, TripsSummaryState>(
      builder: (context, state) {
        final summary = state.summary;
        final loading = state.status == TripsSummaryStatus.loading;
        final period = context.read<StatsPeriodCubit>().state;

        Future<void> openKgSold() async {
          _logEvent(AnalyticsEvents.activitesHubStatsKgSoldOpened);
          final tripId = await KgSoldSheet.show(context, period: period);
          // Un modèle replié sur '' pousserait « /announcements//trip ».
          if (tripId != null && tripId.isNotEmpty && context.mounted) {
            unawaited(context.push('/announcements/$tripId/trip'));
          }
        }

        // Même code couleur que les tuiles d'activité : bleu pour le voyage
        // (kg, trajets), terracotta pour l'envoi ; le vert reste aux gains.
        final revenue = StatTile(
          iconName: 'euro',
          label: l.activityRevenueTitle,
          value: _money(summary),
          color: cs.success,
          isLoading: loading,
          width: null,
          onTap: () {
            _logEvent(AnalyticsEvents.activitesHubStatsRevenuesOpened);
            unawaited(
              RevenueDetailsSheet.show(
                context,
                period: period,
                approximateTotal: (summary?.isRevenueConverted ?? false)
                    ? _money(summary)
                    : null,
              ),
            );
          },
        );
        final kg = StatTile(
          iconName: 'scale',
          label: l.activityKgSoldTitle,
          value: _weight(summary?.kgSold ?? 0),
          color: cs.primary,
          isLoading: loading,
          width: null,
          onTap: openKgSold,
        );
        // Un backend antérieur ne renvoie pas ces deux compteurs. Afficher 0
        // laisserait croire à une absence d'activité : on montre « - »
        // (tiret court, jamais de tiret cadratin), comme les tuiles dont le
        // compteur est indisponible.
        final trips = StatTile(
          iconName: 'plane',
          label: l.activityStatTripsLabel,
          value: summary?.tripsPublished == null
              ? '-'
              : l.activityStatTripsPublished(summary!.tripsPublished!),
          color: cs.primary,
          isLoading: loading,
          width: null,
          onTap: () => _openList(
            context,
            AnalyticsEvents.activitesHubStatsTripsOpened,
            '/announcements/trips?filter=completed',
          ),
        );
        final parcels = StatTile(
          iconName: 'package',
          label: l.activityStatParcelsLabel,
          value: summary?.parcelsSent == null
              ? '-'
              : l.activityStatParcelsSent(summary!.parcelsSent!),
          color: cs.secondary,
          isLoading: loading,
          width: null,
          onTap: () => _openList(
            context,
            AnalyticsEvents.activitesHubStatsParcelsOpened,
            '/envois?status=delivered',
          ),
        );

        return Column(
          children: [
            _Pair(left: revenue, right: kg),
            const SizedBox(height: DonySpacing.md),
            _Pair(left: trips, right: parcels),
          ],
        );
      },
    );
  }
}

/// Deux tuiles de hauteur égale. `IntrinsicHeight` : dans un scroll,
/// `stretch` seul réclame une hauteur infinie.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

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
