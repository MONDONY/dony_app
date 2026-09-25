import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

void showTrackingTimelineSheet(
  BuildContext context, {
  required String bidId,
  required String corridor,
  VoidCallback? onShareTracking,
  String? arrivalInstructions,
}) {
  DonyBottomSheet.show(
    context,
    title: context.l10n.trackingTimelineTitle,
    subtitle: corridor.isNotEmpty ? corridor : null,
    wrapper: (child) => BlocProvider(
      create: (_) => getIt<TrackingBloc>()..add(TrackingEventsRequested(bidId)),
      child: child,
    ),
    stickyBottom: BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        if (state is! TrackingEventsLoaded || onShareTracking == null) {
          return const SizedBox.shrink();
        }
        return DonyButton(
          label: context.l10n.trackingTimelineShare,
          iconAsset: 'share-2',
          onPressed: onShareTracking,
        );
      },
    ),
    child: _TrackingTimelineContent(
      bidId: bidId,
      corridor: corridor,
      arrivalInstructions: arrivalInstructions,
    ),
  );
}

// ── Content widget ────────────────────────────────────────────────────────────

class _TrackingTimelineContent extends StatelessWidget {
  final String bidId;
  final String corridor;
  final String? arrivalInstructions;

  const _TrackingTimelineContent({
    required this.bidId,
    required this.corridor,
    this.arrivalInstructions,
  });

  // Noms de villes : valeur de donnée, jamais traduite (i18n-ignore).
  static const _cityToCodes = <String, (String, String)>{
    'Paris': ('PAR', 'CDG'), // i18n-ignore
    'Lyon': ('LYS', 'LYS'), // i18n-ignore
    'Marseille': ('MRS', 'MRS'), // i18n-ignore
    'Dakar': ('DKR', 'DSS'), // i18n-ignore
    'Abidjan': ('ABJ', 'ABJ'), // i18n-ignore
    'Bamako': ('BKO', 'BKO'), // i18n-ignore
    'Douala': ('DLA', 'DLA'), // i18n-ignore
  };

  (String, String, String, String) _parseCorridor() {
    // corridor format: "Paris → Dakar" or "Paris CDG → Dakar DSS"
    final parts = corridor.split('→').map((s) => s.trim()).toList();
    final dep = parts.isNotEmpty ? parts[0].trim() : 'Paris'; // i18n-ignore
    final arr = parts.length > 1 ? parts[1].trim() : 'Dakar'; // i18n-ignore

    final depCodes =
        _cityToCodes[dep] ??
        (
          dep.length >= 3
              ? dep.substring(0, 3).toUpperCase()
              : dep.toUpperCase(),
          dep.length >= 3
              ? dep.substring(0, 3).toUpperCase()
              : dep.toUpperCase(),
        );
    final arrCodes =
        _cityToCodes[arr] ??
        (
          arr.length >= 3
              ? arr.substring(0, 3).toUpperCase()
              : arr.toUpperCase(),
          arr.length >= 3
              ? arr.substring(0, 3).toUpperCase()
              : arr.toUpperCase(),
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
            message: ErrorPresenter.resolve(
              state.error,
              l10n: context.l10n,
            ).message,
            onRetry: () => context.read<TrackingBloc>().add(
              TrackingEventsRequested(bidId),
            ),
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
                  _Timeline(
                    events: state.events,
                    arrivalInstructions: arrivalInstructions,
                  ),

                  const SizedBox(height: DonySpacing.base),

                  // "Pas besoin d'app !" banner
                  const _ApplessBanner(),
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
  final String? arrivalInstructions;
  const _Timeline({required this.events, this.arrivalInstructions});

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
          context.l10n.trackingTimelineStepsHeader,
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
        ] else if ((arrivalInstructions ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: DonySpacing.md),
          DonyStatusBanner(
            type: DonyStatusBannerType.info,
            iconAsset: 'map-pin',
            title: context.l10n.tripOwnerArrivalEditingTitle,
            message: arrivalInstructions,
          ),
        ],
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TrackingEventModel event;
  final bool isLast;
  final int index;

  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final localeName = l.localeName;
    final locationLabel = event.locationLabel(l);

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
                            vertical: DonySpacing.xs,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.md),

              // Content card
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: isLast ? 0 : DonySpacing.base,
                  ),
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
                        event.stepLabel(l),
                        style: tt.titleSmall?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      Text(
                        l.commonDateAtTime(
                          DateFormat.yMd(
                            localeName,
                          ).format(event.scannedAt.toLocal()),
                          DateFormat.jm(
                            localeName,
                          ).format(event.scannedAt.toLocal()),
                        ),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (locationLabel != null) ...[
                        const SizedBox(height: DonySpacing.xs),
                        Row(
                          children: [
                            DonyIcon(
                              'map-pin',
                              size: 12,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              locationLabel,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
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
                            placeholder: (_) => Container(
                              height: 120,
                              color: cs.primaryContainer,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: cs.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_) => Container(
                              height: 60,
                              color: cs.surfaceContainerHighest,
                              child: Center(
                                child: DonyIcon(
                                  'image-off',
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (event.offlineTimestamp != null) ...[
                        const SizedBox(height: DonySpacing.sm),
                        Row(
                          children: [
                            DonyIcon('wifi-off', size: 12, color: cs.warning),
                            const SizedBox(width: DonySpacing.xs),
                            Text(
                              l.trackingOfflineScanSynced,
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
        )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.04);
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
          DonyIcon('hourglass', color: cs.warning, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.trackingAwaitingConfirmationTitle,
                  style: tt.titleSmall?.copyWith(color: cs.warning),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  context.l10n.trackingAwaitingConfirmationDesc,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
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
            child: DonyIcon('hourglass', color: cs.primary, size: 32),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(context.l10n.trackingEmptyTimelineTitle, style: tt.titleLarge),
          const SizedBox(height: DonySpacing.sm),
          Text(
            context.l10n.trackingEmptyTimelineDesc,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── "Pas besoin d'app !" banner ───────────────────────────────────────────────

class _ApplessBanner extends StatelessWidget {
  const _ApplessBanner();

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
              DonyIcon('circle-check', color: cs.secondary, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                context.l10n.trackingApplessTitle,
                style: tt.titleSmall?.copyWith(
                  color: cs.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            context.l10n.trackingApplessMessage,
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
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
            DonyIcon('circle-alert', color: cs.error, size: 40),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: context.l10n.commonRetry,
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
