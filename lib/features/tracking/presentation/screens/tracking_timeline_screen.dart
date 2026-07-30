import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TrackingTimelineScreen extends StatefulWidget {
  final String bidId;
  final String corridor;

  const TrackingTimelineScreen({
    super.key,
    required this.bidId,
    required this.corridor,
  });

  @override
  State<TrackingTimelineScreen> createState() => _TrackingTimelineScreenState();
}

class _TrackingTimelineScreenState extends State<TrackingTimelineScreen> {
  // Parse corridor "Paris → Dakar" into city/airport codes
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
    final parts = widget.corridor.split('→').map((s) => s.trim()).toList();
    final dep = parts.isNotEmpty ? parts[0].trim() : 'Paris';
    final arr = parts.length > 1 ? parts[1].trim() : 'Dakar';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TrackingBloc>().add(TrackingEventsRequested(widget.bidId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final corridorCodes = _parseCorridor();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Custom header (no AppBar) ─────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                DonyLayout.hPadding(context),
                DonySpacing.base,
                DonyLayout.hPadding(context),
                DonySpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Yadony
                  const DonyLogo(fontSize: 39),
                  const SizedBox(height: DonySpacing.sm),
                  // Greeting — corridor city as context
                  Text(
                    'Bonjour 👋',
                    style: DonyTypography.caveat(
                      fontSize: 28,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    'Un colis vous est envoyé depuis ${corridorCodes.$2}.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<TrackingBloc, TrackingState>(
                buildWhen: (_, curr) =>
                    curr is TrackingEventsLoading ||
                    curr is TrackingEventsLoaded ||
                    curr is TrackingEventsError,
                builder: (context, state) {
                  if (state is TrackingEventsLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    );
                  }
                  if (state is TrackingEventsError) {
                    return _ErrorView(
                      message: ErrorPresenter.resolve(state.error).message,
                      onRetry: () => context.read<TrackingBloc>().add(
                        TrackingEventsRequested(widget.bidId),
                      ),
                    );
                  }
                  if (state is TrackingEventsLoaded) {
                    return RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () async {
                        context.read<TrackingBloc>().add(
                          TrackingEventsRequested(widget.bidId),
                        );
                      },
                      child: Builder(
                        builder: (context) {
                          final h = DonyLayout.hPadding(context);
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              h,
                              DonySpacing.md,
                              h,
                              DonySpacing.huge,
                            ),
                            child: DonyLayout.constrained(
                              context,
                              Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Map card
                                      RouteMapCard(
                                        departureCode: corridorCodes.$1,
                                        arrivalCode: corridorCodes.$3,
                                        departureCity: corridorCodes.$2,
                                        arrivalCity: corridorCodes.$4,
                                      ),
                                      const SizedBox(height: DonySpacing.base),

                                      // Carte tutoriel contextuelle (lecture & suivi)
                                      const ContextualTutorialCard(
                                        context: TutorialContext.tracking,
                                      ),
                                      const SizedBox(height: DonySpacing.base),

                                      // Timeline
                                      _Timeline(events: state.events),

                                      const SizedBox(height: DonySpacing.base),

                                      // "Pas besoin d'app !" banner
                                      _ApplessBanner(
                                        travelerName: 'le voyageur',
                                        bidId: widget.bidId,
                                      ),
                                    ],
                                  )
                                  .animate()
                                  .fadeIn(duration: 300.ms)
                                  .slideY(
                                    begin: 0.04,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
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

  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.index,
  });

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
                    DateFormat(
                      'dd/MM/yyyy à HH:mm',
                    ).format(event.scannedAt.toLocal()),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (event.gpsLat != null && event.gpsLon != null) ...[
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
                          '${event.gpsLat!.toStringAsFixed(4)}, ${event.gpsLon!.toStringAsFixed(4)}',
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
                        fit: BoxFit.cover,
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
          DonyIcon('hourglass', color: cs.warning, size: 22),
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
          const DonyMascotteAnimated(
            type: DonyMascotteType.attente,
            size: DonyMascotteSize.md,
          ),
          const SizedBox(height: DonySpacing.base),
          Text('En attente de la lecture au départ', style: tt.titleLarge),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Le voyageur lira le QR code lors de la remise du colis.',
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
  final String travelerName;
  final String bidId;
  const _ApplessBanner({required this.travelerName, required this.bidId});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.terra50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.terra500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DonyIcon(
                'circle-check',
                color: DonyColors.terra500,
                size: 20,
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Pas besoin d\'app !',
                style: tt.titleSmall?.copyWith(
                  color: DonyColors.terra500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Quand $travelerName sera devant votre porte, vous confirmerez avec un QR ou un code à 6 chiffres.',
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Voir mon code de livraison',
            iconAsset: 'lock-open',
            onPressed: () => _showCodeSheet(context),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  void _showCodeSheet(BuildContext context) {
    final bloc = context.read<TrackingBloc>()
      ..add(TrackingConfirmCodeRequested(bidId));

    DonyBottomSheet.show(
      context,
      title: 'Code de livraison',
      subtitle: 'Partagez ce code avec le voyageur pour confirmer la réception',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: DonyButton(
        label: 'Fermer',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      child: _ConfirmationCodeSheetBody(bidId: bidId),
    );
  }
}

// ── Confirmation code sheet body ──────────────────────────────────────────────

class _ConfirmationCodeSheetBody extends StatelessWidget {
  final String bidId;
  const _ConfirmationCodeSheetBody({required this.bidId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (_, curr) => curr is TrackingRefreshCodeError,
      listener: (context, state) {
        if (state is TrackingRefreshCodeError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      buildWhen: (_, curr) =>
          curr is TrackingConfirmCodeLoading ||
          curr is TrackingConfirmCodeLoaded ||
          curr is TrackingConfirmCodeError ||
          curr is TrackingRefreshCodeLoading,
      builder: (context, state) {
        if (state is TrackingConfirmCodeLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: DonySpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is TrackingConfirmCodeError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxl),
            child: Center(
              child: DonyButton(
                label: 'Réessayer',
                iconAsset: 'refresh-cw',
                fullWidth: false,
                onPressed: () => context.read<TrackingBloc>().add(
                  TrackingConfirmCodeRequested(bidId),
                ),
              ),
            ),
          );
        }

        final isRefreshing = state is TrackingRefreshCodeLoading;
        final loaded = state is TrackingConfirmCodeLoaded ? state : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
          child: _CodeCard(
            code: loaded?.code,
            expiresAt: loaded?.expiresAt,
            isRefreshing: isRefreshing,
            onRefresh: () => context.read<TrackingBloc>().add(
              TrackingRefreshCodeRequested(bidId),
            ),
          ),
        );
      },
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String? code;
  final DateTime? expiresAt;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _CodeCard({
    required this.code,
    required this.expiresAt,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final expiryLabel = expiresAt != null
        ? 'Expire le ${DateFormat('d MMM yyyy à HH:mm', 'fr_FR').format(expiresAt!.toLocal())}'
        : null;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.xl,
            DonySpacing.xl,
            DonySpacing.xxl,
            DonySpacing.lg,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer,
                cs.primaryContainer.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(
                code != null ? code!.split('').join('  ') : '– – – – – –',
                style: tt.displayMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              if (expiryLabel != null) ...[
                const SizedBox(height: DonySpacing.sm),
                Text(
                  expiryLabel,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Bouton glass ↻
        Positioned(
          top: DonySpacing.sm,
          right: DonySpacing.sm,
          child: _GlassRefreshButton(
            isLoading: isRefreshing,
            onTap: isRefreshing ? null : onRefresh,
          ),
        ),
      ],
    );
  }
}

class _GlassRefreshButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _GlassRefreshButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      enabled: onTap != null,
      label: 'Actualiser',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.onPrimaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.onPrimaryContainer,
                      ),
                    )
                  : DonyIcon(
                      'refresh-cw',
                      size: 18,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
            ),
          ),
        ),
      ),
    );
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
            const DonyMascotteAnimated(
              type: DonyMascotteType.assis,
              size: DonyMascotteSize.lg,
            ),
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
