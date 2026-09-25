import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/kg_sold_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Feuille « Kg vendus » du hub Activités : le total de la période, puis le
/// poids livré trajet par trajet. Une ligne rend son `tripId` par le
/// `Future` de [show] ; c'est le hub qui navigue (la feuille vit sur le
/// navigateur racine, sans GoRouter dans son contexte).
class KgSoldSheet extends StatelessWidget {
  const KgSoldSheet({super.key, required this.period});

  final StatsPeriod period;

  static Future<String?> show(
    BuildContext context, {
    required StatsPeriod period,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<String>(
      context,
      title: l.activityKgSoldTitle,
      subtitle: period.detailLabel(l),
      wrapper: (child) => BlocProvider<KgSoldCubit>(
        create: (_) => getIt<KgSoldCubit>()..load(period),
        child: child,
      ),
      child: KgSoldSheet(period: period),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<KgSoldCubit, KgSoldState>(
      builder: (context, state) => switch (state.status) {
        KgSoldStatus.initial || KgSoldStatus.loading => const Column(
          children: [
            DonyListCardSkeleton(),
            SizedBox(height: DonySpacing.base),
            DonyListCardSkeleton(),
          ],
        ),
        KgSoldStatus.error => Column(
          children: [
            DonyEmptyState(
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: l.activityDetailUnavailable,
              description: l.activityKgSoldErrorBody,
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            ),
            // Un DonyChip et non un DonyButton : un bouton n'a sa place que
            // dans le pied collant d'une feuille, et cet état-là n'en a pas
            // besoin.
            DonyChip(
              key: const Key('kg-retry'),
              label: l.commonRetry,
              selected: false,
              onTap: () => context.read<KgSoldCubit>().load(period),
            ),
            const SizedBox(height: DonySpacing.base),
          ],
        ),
        KgSoldStatus.loaded => _LoadedBody(model: state.details!),
      },
    );
  }
}

String _kg(AppLocalizations l, double v) => formatWeightKg(l, v);

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.model});

  final KgSoldModel model;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    if (model.trips.isEmpty) {
      return DonyEmptyState(
        iconAsset: 'scale',
        title: l.activityEmptyPeriodTitle,
        description: l.activityKgSoldEmptyBody,
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs,
            DonySpacing.sm,
            DonySpacing.xs,
            DonySpacing.base,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _kg(l, model.totalKg),
                style: tt.displayLarge?.copyWith(
                  color: cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Padding(
                padding: const EdgeInsets.only(bottom: DonySpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.activityKgSoldParcelsDelivered(model.parcels),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    // Le sous-titre de la feuille est statique : le nombre de
                    // trajets (spec) se lit ici, à côté du total.
                    Text(
                      l.activityKgSoldTrips(model.trips.length),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < model.trips.length; i++)
                _TripRow(
                  trip: model.trips[i],
                  showDivider: i < model.trips.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip, required this.showDivider});

  final KgSoldTripModel trip;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final date = DateFormat.MMMd(l.localeName).format(trip.date);

    return DonyListTile(
      key: Key('kg-trip-${trip.tripId}'),
      label: '${trip.departureCity} → ${trip.arrivalCity}',
      subtitle:
          '${l.activityKgSoldTripDeparture(date)} · '
          '${l.activityKgSoldParcels(trip.parcels)}',
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _kg(l, trip.kg),
            style: tt.bodyMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: () => Navigator.of(context).pop(trip.tripId),
    );
  }
}
