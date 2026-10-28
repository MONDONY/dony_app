import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Carte « Suivi du voyageur » de la fiche colis (vue expéditeur) : où en est
/// le voyageur, de façon approximative (ville la plus proche, avancement), et
/// les dernières villes traversées. Pas de carte géographique.
///
/// Neutre quand le suivi n'est pas activé ou que la position est ancienne :
/// aucune couleur d'alerte, l'expéditeur n'a rien à faire.
class TravelerTrackingCard extends StatelessWidget {
  const TravelerTrackingCard({
    super.key,
    required this.tracking,
    required this.onOpenTimeline,
    this.departureCity,
    this.arrivalCity,
    this.now,
  });

  final TravelerTrackingModel tracking;

  /// Ouvre la frise complète du colis (étapes, photos, villes).
  final VoidCallback onOpenTimeline;
  final String? departureCity;
  final String? arrivalCity;

  /// Horloge injectable pour les tests ; l'heure du téléphone par défaut.
  final DateTime Function()? now;

  /// Statuts où le back sert `travelerTracking` à l'expéditeur.
  static const _servedStatuses = <String>{
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
    'COMPLETED',
  };

  /// Absent (ancien back, colis pas encore porté) : la carte n'existe pas.
  static bool shouldShow(BidModel bid) =>
      bid.travelerTracking != null && _servedStatuses.contains(bid.status);

  /// Nombre de villes montrées dans la carte ; la frise les montre toutes.
  static const _maxHistoryRows = 3;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TravelerTrackingCardCubit>(
      // `lazy: false` : l'affichage est compté à la création, une seule fois.
      lazy: false,
      create: (_) => getIt<TravelerTrackingCardCubit>()..viewed(tracking),
      child: _CardBody(
        tracking: tracking,
        onOpenTimeline: onOpenTimeline,
        departureCity: departureCity,
        arrivalCity: arrivalCity,
        now: (now ?? DateTime.now)(),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.tracking,
    required this.onOpenTimeline,
    required this.now,
    this.departureCity,
    this.arrivalCity,
  });

  final TravelerTrackingModel tracking;
  final VoidCallback onOpenTimeline;
  final DateTime now;
  final String? departureCity;
  final String? arrivalCity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final status = tracking.status;
    final updated = tracking.lastUpdatedAt?.toLocal();
    final age = updated == null ? null : travelerTrackingAge(l, updated, now);
    // Âge du marqueur « Dernière position » : repli sur l'heure de la dernière
    // ville quand le back ne sert pas lastUpdatedAt.
    final markerTime =
        (tracking.lastUpdatedAt ?? tracking.history.lastOrNull?.at)?.toLocal();
    final markerAge = markerTime == null
        ? null
        : travelerTrackingAge(l, markerTime, now);
    final city = tracking.nearestCity;
    final pct = tracking.progressPct;
    final showPosition = status != TravelerTrackingStatus.notActivated;
    final points =
        tracking.history.length > TravelerTrackingCard._maxHistoryRows
        ? tracking.history.sublist(
            tracking.history.length - TravelerTrackingCard._maxHistoryRows,
          )
        : tracking.history;

    final (badgeLabel, positive) = switch (status) {
      TravelerTrackingStatus.enRoute => (l.travelerTrackingBadgeEnRoute, true),
      TravelerTrackingStatus.arrived => (l.travelerTrackingBadgeArrived, true),
      TravelerTrackingStatus.stale => (
        l.travelerTrackingBadgeStale(age ?? '').trim(),
        false,
      ),
      TravelerTrackingStatus.notActivated => (
        l.travelerTrackingBadgeNotActivated,
        false,
      ),
    };

    return Container(
      key: const Key('traveler-tracking-card'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.travelerTrackingTitle,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _StatusPill(label: badgeLabel, positive: positive),
          ),
          if (status == TravelerTrackingStatus.notActivated) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.travelerTrackingNotActivatedHint,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (showPosition && pct != null) ...[
            const SizedBox(height: DonySpacing.md),
            _ProgressBar(
              pct: pct,
              muted: status == TravelerTrackingStatus.stale,
              from: departureCity,
              to: arrivalCity,
            ),
          ],
          if (showPosition && city != null) ...[
            const SizedBox(height: DonySpacing.md),
            Row(
              children: [
                DonyIcon('map-pin', size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    l.travelerTrackingNearCity(city),
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (showPosition &&
              age != null &&
              status != TravelerTrackingStatus.stale) ...[
            const SizedBox(height: DonySpacing.xxs),
            Text(
              l.travelerTrackingUpdated(age),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (points.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.md),
            for (var i = 0; i < points.length; i++)
              _HistoryRow(
                point: points[i],
                marker: i == points.length - 1
                    ? switch (status) {
                        TravelerTrackingStatus.enRoute => l.travelerTrackingNow,
                        TravelerTrackingStatus.stale =>
                          markerAge == null
                              ? null
                              : l.travelerTrackingLastPosition(markerAge),
                        _ => null,
                      }
                    : null,
              ),
          ],
          const SizedBox(height: DonySpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('traveler-tracking-open-timeline'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                context.read<TravelerTrackingCardCubit>().timelineOpened(
                  tracking,
                );
                onOpenTimeline();
              },
              child: Text(l.travelerTrackingOpenTimeline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'état : verte quand le voyageur est en route ou arrivé, grise et
/// neutre sinon (suivi non activé, position ancienne). Pas d'alerte.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.positive})
    : super(key: const Key('traveler-tracking-badge'));

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = positive ? cs.successLight : cs.surfaceWarm;
    final fg = positive ? cs.success : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(
          color: positive ? fg.withValues(alpha: 0.3) : cs.outline,
        ),
      ),
      child: Text(
        label,
        style: tt.labelLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Avancement du trajet : barre unie (aucun dégradé), pourcentage à droite,
/// villes de départ et d'arrivée dessous.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.pct,
    required this.muted,
    this.from,
    this.to,
  });

  final int pct;
  final bool muted;
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final fromCity = from?.trim() ?? '';
    final toCity = to?.trim() ?? '';
    return Semantics(
      label: l.travelerTrackingProgressSemantics(pct),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                    child: SizedBox(
                      key: const Key('traveler-tracking-progress'),
                      height: 6,
                      child: Stack(
                        children: [
                          Positioned.fill(child: ColoredBox(color: cs.outline)),
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: pct / 100,
                              child: ColoredBox(
                                color: muted ? cs.onSurfaceVariant : cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  l.travelerTrackingProgressPct(pct),
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (fromCity.isNotEmpty && toCity.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      fromCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Flexible(
                    child: Text(
                      toCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ville de l'historique : « Près de {ville} », son heure à droite, et
/// sous la ville la marque « Maintenant » ou « Dernière position, … ».
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.point, this.marker});

  final TravelerTrackingPoint point;
  final String? marker;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final at = point.at?.toLocal();
    return Padding(
      key: const Key('traveler-tracking-history-row'),
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ExcludeSemantics(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: marker == null ? cs.outline : cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.travelerTrackingNearCity(point.city),
                  style: tt.bodyMedium,
                ),
                if (marker != null)
                  Text(
                    marker!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (at != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Text(
              DateFormat.MMMd(l.localeName).add_Hm().format(at),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
