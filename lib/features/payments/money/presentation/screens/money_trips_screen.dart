import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/bloc/money_trips_cubit.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_trip_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// « Mes trajets » de « Mon argent » (FLUTTER-HV, maquette D) : une carte par
/// trajet, du plus proche au plus lointain, avec barre d'avancement et
/// compteurs ; dépliée, la liste des colis. [announcementId] filtre l'écran
/// sur un trajet (lien « Détail des N colis »), déplié d'office.
class MoneyTripsScreen extends StatelessWidget {
  const MoneyTripsScreen({super.key, this.announcementId});

  final String? announcementId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DonyAppBar(title: l.moneyTripsTitle),
      body: BlocConsumer<MoneyOverviewBloc, MoneyOverviewState>(
        listenWhen: (_, s) => s is MoneyOverviewLoaded,
        listener: (context, state) {
          if (state is MoneyOverviewLoaded) {
            context.read<MoneyTripsCubit>().trackViewed(
              tripCount: state.schedule.trips.length,
              filtered: announcementId != null,
            );
          }
        },
        builder: (context, state) => switch (state) {
          MoneyOverviewInitial() || MoneyOverviewLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          MoneyOverviewError(:final error) => MoneyErrorView(error: error),
          MoneyOverviewLoaded(:final schedule) => _TripsList(
            schedule: schedule,
            announcementId: announcementId,
          ),
        },
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList({required this.schedule, required this.announcementId});

  final MoneySchedule schedule;
  final String? announcementId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final id = announcementId;
    final focused = id == null ? null : schedule.tripFor(id);
    void showAll() => context.replace(kMoneyTripsRoute);

    if (id != null && focused == null) {
      // Bouton pleine largeur hors de l'état vide : son libellé se réduit
      // au lieu de déborder (grand texte, écran étroit).
      return ListView(
        padding: const EdgeInsets.all(DonySpacing.lg),
        children: [
          DonyEmptyState(
            key: const Key('money-trip-not-found'),
            iconAsset: 'hourglass', // i18n-ignore : nom d'icône
            title: l.moneyTripNotFoundTitle,
          ),
          const SizedBox(height: DonySpacing.base),
          DonyButton(
            key: const Key('money-trips-all'),
            label: l.moneyTripsShowAll,
            variant: DonyButtonVariant.secondary,
            onPressed: showAll,
          ),
        ],
      );
    }
    final trips = focused == null ? schedule.trips : [focused];
    if (trips.isEmpty) {
      return Center(
        child: DonyEmptyState(
          key: const Key('money-trips-empty'),
          iconAsset: 'wallet', // i18n-ignore : nom d'icône
          title: l.moneyTripsEmptyTitle,
          description: l.moneyTripsEmptyBody,
        ),
      );
    }

    return BlocBuilder<MoneyTripsCubit, MoneyTripsViewState>(
      builder: (context, view) {
        final visible = trips.take(view.visibleCount).toList();
        final hasMore = trips.length > visible.length;
        final trailing = hasMore || focused != null;
        return RefreshIndicator(
          onRefresh: () => refreshMoney(context),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.sm,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            itemCount: visible.length + 1 + (trailing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                  child: Text(
                    l.moneyTripsSubtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              final i = index - 1;
              if (i == visible.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.base),
                  child: hasMore
                      ? DonyButton(
                          key: const Key('money-trips-more'),
                          label: l.moneyTripsShowMore,
                          variant: DonyButtonVariant.secondary,
                          onPressed: context.read<MoneyTripsCubit>().showMore,
                        )
                      : DonyButton(
                          key: const Key('money-trips-all'),
                          label: l.moneyTripsShowAll,
                          variant: DonyButtonVariant.ghost,
                          onPressed: showAll,
                        ),
                );
              }
              final trip = visible[i];
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : DonySpacing.md - 2),
                child:
                    MoneyTripCard(
                          trip: trip,
                          expanded: view.isExpanded(trip.key),
                          onToggle: () =>
                              context.read<MoneyTripsCubit>().toggle(trip.key),
                          onOpenParcel: (item) => unawaited(
                            pushAndRefreshMoney(context, '/bids/${item.bidId}'),
                          ),
                        )
                        .animate()
                        .fadeIn(
                          delay: Duration(
                            milliseconds: 60 * (i % 10).clamp(0, 6),
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),
              );
            },
          ),
        );
      },
    );
  }
}
