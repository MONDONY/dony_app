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

/// Ombre douce commune — remplace les bordures dures sur les cartes du hub
/// (principe « ombres > bordures » : rendu plus fluide, moins chargé).
List<BoxShadow> _softShadow({double strength = 1}) => [
      BoxShadow(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.05 * strength),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.06 * strength),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ];

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
              // Clé par trajet : au changement de trajet, hero + liste colis
              // font un fondu-glissé (AnimatedSwitcher) au lieu d'un swap sec.
              final tripKey = ValueKey<String>(state.selectedTripId);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  100 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Entrée en cascade : chaque section apparaît en fondu-glissé,
                  // décalée de 55 ms (joue une fois, structure stable).
                  children: <Widget>[
                    if (onTrackParcel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DonySpacing.lg),
                        child: SecondaryActivityEntry(
                          iconAsset: 'package',
                          label: 'Suivre un colis',
                          onTap: onTrackParcel!,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: DonySpacing.base),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: _fadeSlide,
                        child: _TripHeroCompact(
                          key: tripKey,
                          state: state,
                        ),
                      ),
                    ),
                    _SyncBanner(state: state),
                    const Padding(
                      padding: EdgeInsets.only(bottom: DonySpacing.xl),
                      child: _EtapesSection(),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: _fadeSlide,
                      child: Padding(
                        key: tripKey,
                        padding: const EdgeInsets.only(bottom: DonySpacing.xl),
                        child: _ColisListSection(bids: state.selectedTripBids),
                      ),
                    ),
                    _ScanHistorySection(history: state.scanHistory),
                  ]
                      .animate(interval: 55.ms)
                      .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                ),
              );
          }
        },
      ),
    );
  }
}

/// Transition fondu + léger glissé pour AnimatedSwitcher (changement de trajet).
Widget _fadeSlide(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

String _formatDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'fr').format(date);
}

// ── Hero trajet compact = sélecteur de trajet ────────────────────────────────

class _TripHeroCompact extends StatelessWidget {
  const _TripHeroCompact({super.key, required this.state});
  final ScanHubLoaded state;

  void _openPicker(BuildContext context) {
    // La feuille s'ouvre sur le root navigator (hors provider) → on capture le
    // cubit ici, où il reste accessible.
    final cubit = context.read<ScanHubCubit>();
    DonyBottomSheet.show<void>(
      context,
      title: 'Choisir un trajet',
      child: _TripPicker(
        trips: state.trips,
        selectedTripId: state.selectedTripId,
        onSelect: cubit.selectTrip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final trip = state.selectedTrip;
    final multi = state.trips.length > 1;

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
          ),
          // Bandeau explicite « Changer de trajet » (seulement si plusieurs).
          if (multi)
            Container(
              key: const Key('trip_switcher'),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.md,
              ),
              color: DonyColors.neutral0.withValues(alpha: 0.16),
              child: Row(
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    color: DonyColors.neutral0,
                    size: 18,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    'Changer de trajet',
                    style: tt.labelLarge?.copyWith(
                      color: DonyColors.neutral0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${state.trips.length}',
                    style: tt.labelLarge?.copyWith(
                      color: DonyColors.neutral0.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: DonyColors.neutral0,
                    size: 20,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (!multi) return card;
    return DonyPressable(onTap: () => _openPicker(context), child: card);
  }
}

// ── Sélecteur de trajet (volet) ──────────────────────────────────────────────

class _TripPicker extends StatelessWidget {
  const _TripPicker({
    required this.trips,
    required this.selectedTripId,
    required this.onSelect,
  });

  final List<AnnouncementModel> trips;
  final String selectedTripId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final trip in trips)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.xs),
            child: DonyPressable(
              key: Key('trip_option_${trip.id}'),
              onTap: () {
                onSelect(trip.id);
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.md,
                ),
                decoration: BoxDecoration(
                  color: trip.id == selectedTripId
                      ? cs.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(DonyRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Icon(
                        Icons.flight_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trip.departureCity} → ${trip.arrivalCity}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatDate(trip.departureDate),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trip.id == selectedTripId)
                      Icon(Icons.check_rounded, color: cs.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
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
            boxShadow: _softShadow(),
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
        // 3 cartes séparées en ombre douce (pas de cadre bordé unique).
        Row(
          children: [
            for (var i = 0; i < _etapes.length; i++) ...[
              if (i > 0) const SizedBox(width: DonySpacing.sm),
              Expanded(child: _EtapeChip(etape: _etapes[i])),
            ],
          ],
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
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: _softShadow(),
        ),
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
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: _softShadow(),
        ),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      // Le segment « fait » se remplit de gauche à droite (effet progression).
      child: done
          ? Container(color: cs.success).animate().scaleX(
                begin: 0,
                end: 1,
                alignment: Alignment.centerLeft,
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              )
          : null,
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
