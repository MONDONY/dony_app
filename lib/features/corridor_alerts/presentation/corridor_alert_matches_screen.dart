import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_matches_cubit.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/corridor_alert_form_sheet.dart';
import 'package:dony/features/corridor_alerts/presentation/widgets/trip_match_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CorridorAlertMatchesScreen extends StatelessWidget {
  const CorridorAlertMatchesScreen({super.key, required this.alert});

  final CorridorAlertModel alert;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CorridorAlertMatchesCubit>(
        param1: alert.id,
        param2: alert.direction,
      )..load(),
      child: _CorridorAlertMatchesView(alert: alert),
    );
  }
}

class _CorridorAlertMatchesView extends StatelessWidget {
  const _CorridorAlertMatchesView({required this.alert});

  final CorridorAlertModel alert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTrip = alert.direction == AlertDirection.senderWantsTrips;

    // Resolve role flags for the edit sheet.
    // watch ensures build() re-runs on auth state change so the edit callback captures fresh flags.
    final authState = context.watch<AuthBloc>().state;
    final isTraveler = switch (authState) {
      final AuthAuthenticated s => s.user.isTraveler,
      final AuthProfileUpdated s => s.user.isTraveler,
      _ => false,
    };
    final isSender = switch (authState) {
      final AuthAuthenticated s => s.user.isSender,
      final AuthProfileUpdated s => s.user.isSender,
      _ => false,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '${alert.departureCity} → ${alert.arrivalCity}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Modifier l\'alerte',
            icon: DonyIcon('square-pen', size: 22, color: cs.primary),
            onPressed: () => CorridorAlertFormSheet.show(
              context,
              alert: alert,
              isTraveler: isTraveler,
              isSender: isSender,
            ),
          ),
        ],
      ),
      body: BlocBuilder<CorridorAlertMatchesCubit, CorridorAlertMatchesState>(
        builder: (ctx, state) {
          switch (state.status) {
            case CorridorAlertMatchesStatus.initial:
            case CorridorAlertMatchesStatus.loading:
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.lg,
                  DonySpacing.huge,
                ),
                itemCount: 4,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DonySpacing.md),
                itemBuilder: (_, _) => isTrip
                    ? const DonyTripCardSkeleton()
                    : const DonyTicketCardSkeleton(),
              );
            case CorridorAlertMatchesStatus.error:
              return DonyEmptyState(
                mascotte: DonyMascotteType.erreurLegere,
                type: DonyEmptyStateType.error,
                iconAsset: 'circle-alert',
                title: 'Erreur de chargement',
                description: state.errorMessage ?? 'Une erreur est survenue.',
                actionLabel: 'Réessayer',
                onAction: () => ctx.read<CorridorAlertMatchesCubit>().load(),
              );
            case CorridorAlertMatchesStatus.empty:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.huge,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DonyMascotteAnimated(
                        type: DonyMascotteType.aucunResultat,
                        size: DonyMascotteSize.lg,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      Text(
                        isTrip
                            ? 'Aucun trajet pour l\'instant'
                            : 'Aucun colis pour l\'instant',
                        textAlign: TextAlign.center,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        isTrip
                            ? 'Aucun trajet ne correspond à cette alerte pour l\'instant.'
                            : 'Aucun colis ne correspond à cette alerte pour l\'instant.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case CorridorAlertMatchesStatus.loaded:
              if (isTrip) {
                final trips = state.result!.trips;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg,
                        DonySpacing.base,
                        DonySpacing.lg,
                        DonySpacing.sm,
                      ),
                      child: Text(
                        '${trips.length} trajet${trips.length != 1 ? 's' : ''}',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          0,
                          DonySpacing.lg,
                          DonySpacing.huge,
                        ),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: DonySpacing.md),
                        itemBuilder: (lCtx, i) {
                          final trip = trips[i];
                          return TripMatchCard(
                            key: ValueKey(trip.announcementId),
                            match: trip,
                            index: i,
                            onTap: () =>
                                lCtx.push('/traveler/${trip.announcementId}'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              // Colis direction: render package matches.
              final packages = state.result!.packages;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      DonySpacing.base,
                      DonySpacing.lg,
                      DonySpacing.sm,
                    ),
                    child: Text(
                      '${packages.length} colis',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.lg,
                        0,
                        DonySpacing.lg,
                        DonySpacing.huge,
                      ),
                      itemCount: packages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: DonySpacing.md),
                      itemBuilder: (lCtx, i) {
                        final m = packages[i];
                        return MatchingRequestCard(
                              key: ValueKey(m.id),
                              match: m,
                              index: i,
                              onTap: () =>
                                  lCtx.push('/package-requests/${m.id}/public'),
                            )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 60 * i),
                              duration: 280.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.04,
                              delay: Duration(milliseconds: 60 * i),
                              duration: 280.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }
}
