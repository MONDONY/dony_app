import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/kg_sold_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
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
    return DonyBottomSheet.show<String>(
      context,
      title: 'Kg vendus',
      subtitle: period.detailLabel,
      wrapper: (child) => BlocProvider<KgSoldCubit>(
        create: (_) => getIt<KgSoldCubit>()..load(period),
        child: child,
      ),
      child: KgSoldSheet(period: period),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const DonyEmptyState(
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Détail indisponible',
              description:
                  'Impossible de charger vos kg vendus. Vérifiez votre connexion, puis réessayez.',
              padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
            ),
            // Un DonyChip et non un DonyButton : un bouton n'a sa place que
            // dans le pied collant d'une feuille, et cet état-là n'en a pas
            // besoin.
            DonyChip(
              key: const Key('kg-retry'),
              label: 'Réessayer',
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

String _kg(double v) {
  // Arrondir d'abord à une décimale, puis juger l'entier sur la valeur
  // arrondie : sinon 2.04 (arrondi ultérieur à 1 décimale donnerait 2.0)
  // passait le test `v % 1 == 0` sur la valeur brute et s'affichait « 2,0 kg ».
  final rounded = double.parse(v.toStringAsFixed(1));
  final text = rounded % 1 == 0
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kg';
}

String _parcels(int count) => count == 1 ? '1 colis' : '$count colis';

String _trips(int count) => count == 1 ? '1 trajet' : '$count trajets';

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.model});

  final KgSoldModel model;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (model.trips.isEmpty) {
      return const DonyEmptyState(
        iconAsset: 'scale',
        title: 'Aucune livraison sur la période',
        description:
            'Les kg vendus apparaissent ici une fois vos colis livrés.',
        padding: EdgeInsets.symmetric(vertical: DonySpacing.xl),
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
                _kg(model.totalKg),
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
                      '${_parcels(model.parcels)} livrés',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    // Le sous-titre de la feuille est statique : le nombre de
                    // trajets (spec) se lit ici, à côté du total.
                    Text(
                      _trips(model.trips.length),
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
    final date = DateFormat('d MMM', 'fr').format(trip.date);

    return DonyListTile(
      key: Key('kg-trip-${trip.tripId}'),
      label: '${trip.departureCity} → ${trip.arrivalCity}',
      subtitle: 'Départ le $date · ${_parcels(trip.parcels)}',
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _kg(trip.kg),
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
