import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/core/design/design_system.dart';
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

    final depCodes = _cityToCodes[dep] ?? (dep.length >= 3 ? dep.substring(0, 3).toUpperCase() : dep.toUpperCase(), dep.length >= 3 ? dep.substring(0, 3).toUpperCase() : dep.toUpperCase());
    final arrCodes = _cityToCodes[arr] ?? (arr.length >= 3 ? arr.substring(0, 3).toUpperCase() : arr.toUpperCase(), arr.length >= 3 ? arr.substring(0, 3).toUpperCase() : arr.toUpperCase());

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
    final tt = Theme.of(context).textTheme;
    final corridorCodes = _parseCorridor();

    return Scaffold(
      backgroundColor: DonyColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Custom header (no AppBar) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.base,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "dony." wordmark with green dot
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'dony',
                          style: DonyTypography.caveat(
                            fontSize: 24,
                            color: DonyColors.ink900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '.',
                          style: DonyTypography.caveat(
                            fontSize: 24,
                            color: DonyColors.green400,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  // Greeting — corridor city as context
                  Text(
                    'Bonjour 👋',
                    style: DonyTypography.caveat(
                      fontSize: 28,
                      color: DonyColors.ink900,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    'Un colis vous est envoyé depuis ${corridorCodes.$2}.',
                    style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<TrackingBloc, TrackingState>(
                builder: (context, state) {
                  if (state is TrackingEventsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: DonyColors.green400),
                    );
                  }
                  if (state is TrackingEventsError) {
                    return _ErrorView(
                      message: state.message,
                      onRetry: () => context.read<TrackingBloc>().add(
                          TrackingEventsRequested(widget.bidId)),
                    );
                  }
                  if (state is TrackingEventsLoaded) {
                    return RefreshIndicator(
                      color: DonyColors.green400,
                      onRefresh: () async {
                        context.read<TrackingBloc>().add(
                            TrackingEventsRequested(widget.bidId));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.md,
                          DonySpacing.lg,
                          DonySpacing.huge,
                        ),
                        child: Column(
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
                            _ApplessBanner(
                              travelerName: 'le voyageur',
                            ),
                          ],
                        ).animate().fadeIn(duration: 300.ms).slideY(
                            begin: 0.04, curve: Curves.easeOutCubic),
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
            color: DonyColors.grey400,
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

  Color get _stepColor => switch (event.eventType) {
        'ARRIVEE' => DonyColors.success,
        _ => DonyColors.green400,
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
                    color: _stepColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: DonyColors.white,
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: DonyColors.grey200,
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
              margin: EdgeInsets.only(
                  bottom: isLast ? 0 : DonySpacing.base),
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: DonyColors.white,
                borderRadius: BorderRadius.circular(DonyRadius.lg),
                border: Border.all(color: DonyColors.grey200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.stepLabel,
                    style: tt.titleSmall?.copyWith(color: DonyColors.ink900),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm')
                        .format(event.scannedAt.toLocal()),
                    style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                  ),
                  if (event.gpsLat != null && event.gpsLon != null) ...[
                    const SizedBox(height: DonySpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: DonyColors.grey400),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          '${event.gpsLat!.toStringAsFixed(4)}, ${event.gpsLon!.toStringAsFixed(4)}',
                          style: tt.bodySmall
                              ?.copyWith(color: DonyColors.grey400),
                        ),
                      ],
                    ),
                  ],
                  if (event.photoUrl != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(DonyRadius.sm),
                      child: Image.network(
                        event.photoUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 120,
                            color: DonyColors.green100,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: DonyColors.green400,
                                  strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 60,
                          color: DonyColors.grey100,
                          child: const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: DonyColors.grey400)),
                        ),
                      ),
                    ),
                  ],
                  if (event.offlineTimestamp != null) ...[
                    const SizedBox(height: DonySpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 12, color: DonyColors.warning),
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          'Scan offline synchronisé',
                          style: tt.bodySmall?.copyWith(
                            color: DonyColors.warning,
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
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        border: Border.all(color: DonyColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: DonyColors.warning, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En attente de confirmation',
                  style: tt.titleSmall?.copyWith(color: DonyColors.warning),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  'Le destinataire doit confirmer la réception via le code SMS.',
                  style: tt.bodySmall
                      ?.copyWith(color: DonyColors.grey400, height: 1.4),
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
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.grey200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: DonyColors.green100,
              borderRadius: BorderRadius.circular(DonyRadius.lg),
            ),
            child: const Icon(Icons.hourglass_empty_rounded,
                color: DonyColors.green400, size: 32),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'En attente du scan de départ',
            style: tt.titleLarge,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Le voyageur scannera le QR code lors de la remise du colis.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: DonyColors.grey400, height: 1.4),
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
              const Icon(Icons.check_circle_outline_rounded,
                  color: DonyColors.terra500, size: 20),
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
            'Quand $travelerName sera devant votre porte, vous confirmerez avec un QR ou un code à 4 chiffres.',
            style: tt.bodySmall
                ?.copyWith(color: DonyColors.ink900, height: 1.4),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'J\'ouvre la confirmation',
            icon: Icons.qr_code_rounded,
            onPressed: () {},
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
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: DonyColors.error, size: 40),
            const SizedBox(height: DonySpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
