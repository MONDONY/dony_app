import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

void showTrackingTimelineSheet(
  BuildContext context, {
  required String bidId,
  required String corridor,
}) {
  DonyBottomSheet.show(
    context,
    title: 'Suivi du colis',
    subtitle: corridor.isNotEmpty ? corridor : null,
    wrapper: (child) => BlocProvider(
      create: (_) => getIt<TrackingBloc>()..add(TrackingEventsRequested(bidId)),
      child: child,
    ),
    stickyBottom: BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        if (state is! TrackingEventsLoaded) return const SizedBox.shrink();
        return DonyButton(
          label: "J'ouvre la confirmation",
          iconAsset: 'qr-code',
          onPressed: () {},
        );
      },
    ),
    child: _TrackingTimelineContent(bidId: bidId, corridor: corridor),
  );
}

// ── Content widget ────────────────────────────────────────────────────────────

class _TrackingTimelineContent extends StatelessWidget {
  final String bidId;
  final String corridor;

  const _TrackingTimelineContent({
    required this.bidId,
    required this.corridor,
  });

  static const _cityToCodes = <String, (String, String)>{
    'Paris': ('PAR', 'CDG'),
    'Lyon': ('LYS', 'LYS'),
    'Marseille': ('MRS', 'MRS'),
    'Dakar': ('DKR', 'DSS'),
    'Abidjan': ('ABJ', 'ABJ'),
    'Bamako': ('BKO', 'BKO'),
    'Douala': ('DLA', 'DLA'),
  };

  (String, String, String, String) _parseCorridor() {
    // corridor format: "Paris → Dakar" or "Paris CDG → Dakar DSS"
    final parts = corridor.split('→').map((s) => s.trim()).toList();
    final dep = parts.isNotEmpty ? parts[0].trim() : 'Paris';
    final arr = parts.length > 1 ? parts[1].trim() : 'Dakar';

    final depCodes = _cityToCodes[dep] ??
        (
          dep.length >= 3
              ? dep.substring(0, 3).toUpperCase()
              : dep.toUpperCase(),
          dep.length >= 3
              ? dep.substring(0, 3).toUpperCase()
              : dep.toUpperCase()
        );
    final arrCodes = _cityToCodes[arr] ??
        (
          arr.length >= 3
              ? arr.substring(0, 3).toUpperCase()
              : arr.toUpperCase(),
          arr.length >= 3
              ? arr.substring(0, 3).toUpperCase()
              : arr.toUpperCase()
        );

    return (depCodes.$1, depCodes.$2, arrCodes.$1, arrCodes.$2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corridorCodes = _parseCorridor();

    return BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        if (state is TrackingEventsLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.xxl),
              child: CircularProgressIndicator(color: cs.primary),
            ),
          );
        }
        if (state is TrackingEventsError) {
          return _ErrorView(
            message: ErrorPresenter.resolve(state.error).message,
            onRetry: () => context
                .read<TrackingBloc>()
                .add(TrackingEventsRequested(bidId)),
          );
        }
        if (state is TrackingEventsLoaded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map card
              RouteMapCard(
                departureCode: corridorCodes.$1,
                arrivalCode: corridorCodes.$3,
                departureCity: corridorCodes.$2,
                arrivalCity: corridorCodes.$4,
              ),
              const SizedBox(height: DonySpacing.base),

              // Timeline
              _Timeline(events: state.events),

              const SizedBox(height: DonySpacing.base),

              // "Pas besoin d'app !" banner
              const _ApplessBanner(
                travelerName: 'le voyageur',
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final List<TrackingEventModel> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (events.isEmpty) {
      return _EmptyTimeline();
    }

    final hasArrivee = events.any((e) => e.eventType == 'ARRIVEE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPES',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isLast = index == events.length - 1;
            return _TimelineItem(event: event, isLast: isLast, index: index);
          },
        ),
        if (!hasArrivee) ...[
          const SizedBox(height: DonySpacing.base),
          _PendingConfirmationBanner(),
        ],
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TrackingEventModel event;
  final bool isLast;
  final int index;

  const _TimelineItem(
      {required this.event, required this.isLast, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color stepColor = switch (event.eventType) {
      'ARRIVEE' => cs.success,
      _ => cs.primary,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator — all recorded events are completed
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: stepColor,
                    shape: BoxShape.circle,
                  ),
                  child: const DonyIcon(
                    'check',
                    color: DonyColors.white,
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: cs.outlineVariant,
                      margin: const EdgeInsets.symmetric(
                          vertical: DonySpacing.xs),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.md),

          // Content card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : DonySpacing.base),
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.lg),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.stepLabel,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm')
                        .format(event.scannedAt.toLocal()),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (event.gpsLat != null && event.gpsLon != null) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Row(
                      children: [
                        DonyIcon('map-pin',
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          '${event.gpsLat!.toStringAsFixed(4)}, ${event.gpsLon!.toStringAsFixed(4)}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                  if (event.photoUrl != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                      child: DonyImage(
                        url: event.photoUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_) => Container(
                          height: 120,
                          color: cs.primaryContainer,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: cs.primary, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_) => Container(
                          height: 60,
                          color: cs.surfaceContainerHighest,
                          child: Center(
                              child: DonyIcon('image-off',
                                  color: cs.onSurfaceVariant)),
                        ),
                      ),
                    ),
                  ],
                  if (event.offlineTimestamp != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Row(
                      children: [
                        DonyIcon('wifi-off',
                            size: 12, color: cs.warning),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          'Lecture hors-ligne synchronisée',
                          style: tt.bodySmall?.copyWith(
                            color: cs.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 250.ms).slideX(begin: 0.04);
  }
}

class _PendingConfirmationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          DonyIcon('hourglass',
              color: cs.warning, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En attente de confirmation',
                  style: tt.titleSmall?.copyWith(color: cs.warning),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  'Le destinataire doit confirmer la réception via le code SMS.',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.lg),
            ),
            child: DonyIcon('hourglass',
                color: cs.primary, size: 32),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'En attente de la lecture au départ',
            style: tt.titleLarge,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Le voyageur lira le QR code lors de la remise du colis.',
            textAlign: TextAlign.center,
            style: tt.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── "Pas besoin d'app !" banner ───────────────────────────────────────────────

class _ApplessBanner extends StatelessWidget {
  final String travelerName;
  const _ApplessBanner({required this.travelerName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon('circle-check',
                  color: cs.secondary, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Pas besoin d\'app !',
                style: tt.titleSmall?.copyWith(
                  color: cs.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Quand $travelerName sera devant votre porte, vous confirmerez avec un QR ou un code à 4 chiffres.',
            style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('circle-alert',
                color: cs.error, size: 40),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Réessayer',
              iconAsset: 'refresh-cw',
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
