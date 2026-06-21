import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_requests_cubit.dart';
import 'package:dony/features/favorites/bloc/favorite_trips_cubit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.favoritesOpened),
      );
      final role = context.read<ActiveRoleCubit>().state;
      context.read<FavoriteTripsCubit>().load();
      if (role == ActiveRole.traveler) {
        context.read<FavoriteRequestsCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveRoleCubit, ActiveRole>(
      builder: (context, role) {
        final isTraveler = role == ActiveRole.traveler;

        if (isTraveler) {
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: DonyAppBar(
                title: 'Mes favoris',
                bottom: TabBar(
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'Trajets'),
                    Tab(text: 'Demandes'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  _TripsTab(),
                  _RequestsTab(),
                ],
              ),
            ),
          );
        }

        // Sender role: trips only, no tab bar
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: const DonyAppBar(
            title: 'Mes favoris',
          ),
          body: const _TripsTab(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Trips tab
// ---------------------------------------------------------------------------

class _TripsTab extends StatelessWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteTripsCubit, FavoriteTripsState>(
      builder: (context, state) {
        if (state is FavoriteTripsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is FavoriteTripsEmpty) {
          return const _EmptyState(message: 'Aucun trajet favori pour l\'instant');
        }

        if (state is FavoriteTripsError) {
          return _ErrorState(
            onRetry: () => context.read<FavoriteTripsCubit>().load(),
          );
        }

        if (state is FavoriteTripsLoaded) {
          final trips = state.trips;
          return RefreshIndicator(
            onRefresh: () => context.read<FavoriteTripsCubit>().refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return TripCard(
                  announcement: trip,
                  onTap: () => context.push(
                    '/announcements/${trip.id}/trip',
                    extra: trip,
                  ),
                  index: index,
                  showFavorite: true,
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab
// ---------------------------------------------------------------------------

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoriteRequestsCubit, FavoriteRequestsState>(
      builder: (context, state) {
        if (state is FavoriteRequestsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is FavoriteRequestsEmpty) {
          return const _EmptyState(
            message: 'Aucune demande favorite pour l\'instant',
          );
        }

        if (state is FavoriteRequestsError) {
          return _ErrorState(
            onRetry: () => context.read<FavoriteRequestsCubit>().load(),
          );
        }

        if (state is FavoriteRequestsLoaded) {
          final requests = state.requests;
          return RefreshIndicator(
            onRefresh: () => context.read<FavoriteRequestsCubit>().refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return PackageRequestListCard(
                  item: request,
                  index: index,
                  showFavorite: true,
                  onTap: () => context.push(
                    '/package-requests/${request.id}/public',
                  ),
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty / error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: DonySpacing.lg),
            Text(
              'Aucun favori pour l\'instant',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(
              begin: 0.04,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: DonySpacing.lg),
            Text(
              'Une erreur est survenue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              'Impossible de charger vos favoris.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
