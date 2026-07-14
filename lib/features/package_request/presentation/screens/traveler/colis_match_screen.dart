import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/package_request/bloc/trip_matching_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// « Colis sur mes trajets » — layout B : liste unifiée scorée (tous trajets
/// confondus), triée serveur par matchScore. AnnouncementBloc sert uniquement
/// à savoir s'il existe ≥1 trajet actif (sinon CTA publier).
class ColisMatchScreen extends StatelessWidget {
  const ColisMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<AnnouncementBloc>()..add(AnnouncementListRequested()),
        ),
        BlocProvider(
          create: (_) =>
              getIt<TripMatchingBloc>()..add(const TripMatchingRequested()),
        ),
      ],
      child: const _ColisMatchView(),
    );
  }
}

class _ColisMatchView extends StatelessWidget {
  const _ColisMatchView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: const DonyAppBarBackButton(),
        title: BlocBuilder<TripMatchingBloc, TripMatchingState>(
          builder: (_, state) {
            final count = state.matches.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Colis sur mes trajets', style: tt.headlineMedium),
                if (state.status == TripMatchingStatus.loaded && count > 0)
                  Text(
                    '$count colis compatible${count > 1 ? 's' : ''} · tri par pertinence',
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            );
          },
        ),
        actions: [
          // Cloche = toggle « me notifier quand un colis matche un de mes trajets ».
          BlocBuilder<TripMatchingBloc, TripMatchingState>(
            buildWhen: (a, b) => a.alertEnabled != b.alertEnabled,
            builder: (ctx, state) {
              final enabled = state.alertEnabled;
              final on = enabled ?? false;
              return IconButton(
                key: const Key('colis-match-bell'),
                tooltip: enabled == null
                    ? 'Notifications de match'
                    : on
                        ? 'Notifications activées, appuyer pour couper'
                        : 'Notifications coupées, appuyer pour activer',
                onPressed: enabled == null
                    ? null
                    : () => ctx
                        .read<TripMatchingBloc>()
                        .add(TripMatchingAlertToggled(!on)),
                icon: Icon(
                  on
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  size: 22,
                  color: on ? cs.primary : cs.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outline),
        ),
      ),
      body: BlocBuilder<TripMatchingBloc, TripMatchingState>(
        builder: (ctx, state) {
          switch (state.status) {
            case TripMatchingStatus.initial:
            case TripMatchingStatus.loading:
              return Center(
                  child: CircularProgressIndicator(color: cs.primary));
            case TripMatchingStatus.error:
              return _ErrorView(
                onRetry: () => ctx
                    .read<TripMatchingBloc>()
                    .add(const TripMatchingRequested()),
              );
            case TripMatchingStatus.loaded:
              if (state.matches.isEmpty) {
                return const _EmptyView();
              }
              return RefreshIndicator(
                color: cs.primary,
                onRefresh: () async => ctx
                    .read<TripMatchingBloc>()
                    .add(const TripMatchingRefreshRequested()),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.base,
                    DonySpacing.lg,
                    DonySpacing.huge,
                  ),
                  itemCount: state.matches.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DonySpacing.md),
                  itemBuilder: (lCtx, i) {
                    final m = state.matches[i];
                    return MatchingRequestCard(
                      match: m,
                      index: i,
                      onTap: () =>
                          lCtx.push('/package-requests/${m.id}/public'),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // AnnouncementBloc tells us if ≥1 ACTIVE/FULL trip exists.
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (ctx, annState) {
        // Guard: show a neutral spinner while announcements are still loading
        // so we never flash the "Publier un trajet" CTA for users who do have
        // active trips.
        if (annState is! AnnouncementListLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final hasActiveTrip = annState.announcements
            .any((a) => a.status == 'ACTIVE' || a.status == 'FULL');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.huge - 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyMascotteAnimated(
                  type: DonyMascotteType.assis,
                  size: DonyMascotteSize.lg,
                ),
                const SizedBox(height: DonySpacing.base),
                Text(
                  hasActiveTrip
                      ? 'Aucun colis compatible pour l\'instant'
                      : 'Aucun trajet actif',
                  textAlign: TextAlign.center,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  hasActiveTrip
                      ? 'Crée une alerte pour être prévenu dès qu\'un colis correspond.'
                      : 'Publie un trajet pour voir les colis compatibles.',
                  textAlign: TextAlign.center,
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.xl),
                if (hasActiveTrip)
                  _AlertBanner(onTap: () => ctx.push('/corridor-alerts'))
                else
                  DonyButton(
                    label: 'Publier un trajet',
                    onPressed: () => ctx.push('/announcements/create'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            children: [
              DonyIcon('bell', size: 20, color: cs.primary),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  'Créer une alerte sur ce corridor',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              DonyIcon('chevron-right', size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.huge - 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('circle-alert', size: 64, color: cs.error),
            const SizedBox(height: DonySpacing.base),
            Text('Une erreur est survenue',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
