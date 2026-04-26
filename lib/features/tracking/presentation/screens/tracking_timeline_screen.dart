import 'package:dony/app/theme.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Suivi du colis',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18, color: kTextPrimary),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: BlocBuilder<TrackingBloc, TrackingState>(
        builder: (context, state) {
          if (state is TrackingEventsLoading) {
            return const Center(
                child: CircularProgressIndicator(color: kGreenPrimary));
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
              color: kGreenPrimary,
              onRefresh: () async {
                context.read<TrackingBloc>().add(
                    TrackingEventsRequested(widget.bidId));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CorridorHeader(corridor: widget.corridor),
                    const SizedBox(height: 24),
                    _Timeline(events: state.events),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideY(
                    begin: 0.04, curve: Curves.easeOutCubic),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CorridorHeader extends StatelessWidget {
  final String corridor;
  const _CorridorHeader({required this.corridor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 22),
          const SizedBox(width: 10),
          Text(
            corridor,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<TrackingEventModel> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyTimeline();
    }

    final hasArrivee = events.any((e) => e.eventType == 'ARRIVEE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIQUE DES SCANS',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: kTextSecondary, letterSpacing: 0.8),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isLast = index == events.length - 1;
            return _TimelineItem(
                event: event, isLast: isLast, index: index);
          },
        ),
        if (!hasArrivee) ...[
          const SizedBox(height: 16),
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
        'ARRIVEE' => kSuccess,
        'TRANSIT' => kGreenPrimary,
        _ => kGreenPrimary,
      };

  IconData get _stepIcon => switch (event.eventType) {
        'DEPART' => Icons.flight_takeoff_rounded,
        'TRANSIT' => Icons.sync_alt_rounded,
        'ARRIVEE' => Icons.flight_land_rounded,
        _ => Icons.location_on_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _stepColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _stepColor, width: 2),
                  ),
                  child: Icon(_stepIcon, color: _stepColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: kBorder,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.stepLabel,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _stepColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#{${index + 1}}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _stepColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm').format(
                        event.scannedAt.toLocal()),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: kTextSecondary),
                  ),
                  if (event.gpsLat != null && event.gpsLon != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: kTextHint),
                        const SizedBox(width: 4),
                        Text(
                          '${event.gpsLat!.toStringAsFixed(4)}, ${event.gpsLon!.toStringAsFixed(4)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: kTextHint),
                        ),
                      ],
                    ),
                  ],
                  if (event.photoUrl != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        event.photoUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 120,
                            color: kGreenLight,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: kGreenPrimary, strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 60,
                          color: kBackground,
                          child: const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: kTextHint)),
                        ),
                      ),
                    ),
                  ],
                  if (event.offlineTimestamp != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 12, color: kWarning),
                        const SizedBox(width: 4),
                        Text(
                          'Scan offline synchronisé',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: kWarning,
                              fontWeight: FontWeight.w500),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWarning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWarning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: kWarning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En attente de confirmation',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kWarning),
                ),
                const SizedBox(height: 2),
                Text(
                  'Le destinataire doit confirmer la réception via le code SMS.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: kTextSecondary, height: 1.4),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hourglass_empty_rounded,
                color: kGreenPrimary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'En attente du scan de départ',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Le voyageur scannera le QR code lors de la remise du colis.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: kTextSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: kError, size: 40),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: kTextSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kGreenPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0),
            ),
          ],
        ),
      ),
    );
  }
}
