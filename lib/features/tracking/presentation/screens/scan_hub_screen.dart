import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class _EtapeInfo {
  final String code;
  final String label;
  final String? iconAsset;
  final bool photoRequired;

  const _EtapeInfo(
    this.code,
    this.label, {
    this.iconAsset,
    required this.photoRequired,
  });
}

const _etapes = [
  _EtapeInfo(
    'DEPART',
    'Départ',
    iconAsset: 'plane-takeoff',
    photoRequired: true,
  ),
  _EtapeInfo(
    'TRANSIT',
    'Transit',
    iconAsset: 'arrow-left-right',
    photoRequired: false,
  ),
  _EtapeInfo(
    'ARRIVEE',
    'Arrivée',
    iconAsset: 'plane-landing',
    photoRequired: true,
  ),
];

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key, this.onTrackParcel});

  /// Entrée additive « Suivre un colis » (voyageur pro). Null = non affichée.
  final VoidCallback? onTrackParcel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScanHubCubit>()..load(),
      child: ScanHubView(onTrackParcel: onTrackParcel),
    );
  }
}

class ScanHubView extends StatelessWidget {
  const ScanHubView({super.key, this.onTrackParcel});

  final VoidCallback? onTrackParcel;

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
        title: Text('Scan & Suivi', style: tt.headlineLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocBuilder<ScanHubCubit, ScanHubState>(
        builder: (context, state) {
          switch (state) {
            case ScanHubLoading():
              return Center(
                child: CircularProgressIndicator(color: cs.primary),
              );
            case ScanHubError(:final message):
              return _ErrorState(
                message: message,
                onRetry: () => context.read<ScanHubCubit>().load(),
              );
            case ScanHubEmpty():
              return const _NoTripState();
            case ScanHubLoaded():
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  100 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onTrackParcel != null) ...[
                      SecondaryActivityEntry(
                        iconAsset: 'package',
                        label: 'Suivre un colis',
                        onTap: onTrackParcel!,
                      ),
                      const SizedBox(height: DonySpacing.lg),
                    ],
                    if (state.trips.length > 1) ...[
                      _TripSwitcher(state: state),
                      const SizedBox(height: DonySpacing.base),
                    ],
                    _TripHeroCompact(trip: state.selectedTrip),
                    const SizedBox(height: DonySpacing.base),
                    _SyncBanner(state: state),
                    const _EtapesSection(),
                    const SizedBox(height: DonySpacing.base),
                    // Task 6 inserts _NumberEntryField here.
                    const SizedBox(height: DonySpacing.xl),
                    _ColisListSection(bids: state.selectedTripBids),
                    const SizedBox(height: DonySpacing.xl),
                    _ScanHistorySection(history: state.scanHistory),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'fr').format(date);
}

// ── Switcher multi-trajet ────────────────────────────────────────────────────

class _TripSwitcher extends StatelessWidget {
  const _TripSwitcher({required this.state});
  final ScanHubLoaded state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('trip_switcher'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.trips.length,
        separatorBuilder: (_, __) => const SizedBox(width: DonySpacing.sm),
        itemBuilder: (context, i) {
          final trip = state.trips[i];
          final active = trip.id == state.selectedTripId;
          return DonyPressable(
            onTap: () => context.read<ScanHubCubit>().selectTrip(trip.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(
                  color: active ? cs.primary : cs.outline,
                ),
              ),
              child: Text(
                '${trip.departureCity} → ${trip.arrivalCity} · '
                '${_formatDate(trip.departureDate)}',
                style: tt.labelMedium?.copyWith(
                  color: active ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Hero trajet compact ──────────────────────────────────────────────────────

class _TripHeroCompact extends StatelessWidget {
  const _TripHeroCompact({required this.trip});
  final AnnouncementModel trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trip.departureCity} → ${trip.arrivalCity}',
            style: tt.headlineMedium?.copyWith(
              color: DonyColors.neutral0,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatDate(trip.departureDate),
            style: tt.bodySmall?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04);
  }
}

// ── Bandeau synchro ──────────────────────────────────────────────────────────

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});
  final ScanHubLoaded state;

  @override
  Widget build(BuildContext context) {
    final bidIds = state.selectedTripBids.map((b) => b.id).toSet();
    final queue = getIt<HiveService>().offlineQueue;
    final pendingCount = queue.values.where((raw) {
      final entry = Map<String, dynamic>.from(raw);
      return bidIds.contains(entry['bidId']);
    }).length;

    if (pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: DonyPressable(
        key: const Key('sync_banner'),
        onTap: () => context.push('/tracking/offline-queue'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.base,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.warningLight,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.warning),
          ),
          child: Row(
            children: [
              DonyIcon('triangle-alert', color: cs.warning, size: 16),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  '$pendingCount scan${pendingCount > 1 ? 's' : ''} en '
                  'attente de synchro',
                  style: tt.bodySmall?.copyWith(
                    color: cs.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DonyIcon('chevron-right', color: cs.warning, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────

class _NoTripState extends StatelessWidget {
  const _NoTripState();

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      title: 'Aucun trajet à scanner',
      description:
          'Tu pourras scanner les colis dès qu\'une demande sera acceptée sur l\'un de tes trajets.',
      mascotte: DonyMascotteType.assis,
      actionLabel: 'Voir mes trajets',
      onAction: () => context.push('/announcements/trips'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      mascotte: DonyMascotteType.assis,
      title: 'Impossible de charger les trajets',
      description: message,
      type: DonyEmptyStateType.error,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

// ── Scan rapide (3 boutons étape) ────────────────────────────────────────────

class _EtapesSection extends StatelessWidget {
  const _EtapesSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCAN RAPIDE',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: _etapes
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e.code == 'ARRIVEE' ? 0 : DonySpacing.sm,
                    ),
                    child: _EtapeChip(etape: e),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _EtapeChip extends StatelessWidget {
  const _EtapeChip({required this.etape});
  final _EtapeInfo etape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyPressable(
      onTap: () => context.push(
        '/tracking/scan/identify',
        extra: <String, dynamic>{'etape': etape.code, 'focusNumber': false},
      ),
      child: DonyCard(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md,
          horizontal: DonySpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (etape.iconAsset) {
              'plane-takeoff' => const DonyEmoji.planeTakeoff(size: 24),
              'plane-landing' => const DonyEmoji.planeLanding(size: 24),
              final String asset => DonyIcon(asset, size: 24, color: cs.onSurface),
              _ => const SizedBox(width: 24, height: 24),
            },
            const SizedBox(height: DonySpacing.sm),
            Text(
              etape.label,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DonySpacing.xs),
            SizedBox(
              height: 20,
              width: double.infinity,
              child: etape.photoRequired
                  ? const FittedBox(fit: BoxFit.scaleDown, child: _PhotoBadge())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.errorLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('camera', size: 11, color: cs.error),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Photo',
            style: tt.labelSmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste des colis ──────────────────────────────────────────────────────────

class _ColisListSection extends StatelessWidget {
  const _ColisListSection({required this.bids});
  final List<BidModel> bids;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLIS (${bids.length})',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (bids.isEmpty)
          Text(
            'Aucun colis confirmé sur ce trajet pour l\'instant.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          ...bids.map(
            (bid) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: _ColisRow(bid: bid),
            ),
          ),
      ],
    );
  }
}

class _ColisRow extends StatelessWidget {
  const _ColisRow({required this.bid});
  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = colisStepProgress(bid);
    final nextStep = nextRequiredStep(bid);
    final label = bid.recipientName ?? bid.id;

    return DonyPressable(
      onTap: () => context.push('/bids/${bid.id}'),
      child: DonyCard(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Row(
                    children: [
                      _StepDot(done: progress.depart),
                      const SizedBox(width: DonySpacing.xxs),
                      _StepDot(done: progress.transit),
                      const SizedBox(width: DonySpacing.xxs),
                      _StepDot(done: progress.arrivee),
                    ],
                  ),
                ],
              ),
            ),
            if (nextStep != null)
              DonyPressable(
                onTap: () => context.push(
                  '/tracking/scan/identify',
                  extra: <String, dynamic>{
                    'etape': nextStep,
                    'focusNumber': false,
                  },
                ),
                // Le pill visuel reste compact ; on élargit uniquement la
                // zone tactile à 44×44 pt min (HIG) via ce ConstrainedBox.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                      child: Text(
                        'Scan',
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: Key(done ? 'step_dot_done' : 'step_dot_todo'),
      width: 18,
      height: 4,
      decoration: BoxDecoration(
        color: done ? cs.success : cs.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
    );
  }
}

// ── Historique des scans ─────────────────────────────────────────────────────

class _ScanHistorySection extends StatelessWidget {
  const _ScanHistorySection({required this.history});
  final List<TripScanHistoryEntryModel> history;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIQUE DES SCANS',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        if (history.isEmpty)
          Text(
            'Aucun scan pour l\'instant',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          )
        else
          ...history.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xs),
              child: Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(entry.scannedAt),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      entry.recipientName ?? entry.donNumber ?? '—',
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.successLight,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      switch (entry.eventType) {
                        'DEPART' => 'Départ',
                        'TRANSIT' => 'Transit',
                        'ARRIVEE' => 'Arrivée',
                        _ => entry.eventType,
                      },
                      style: tt.labelSmall?.copyWith(
                        color: cs.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
