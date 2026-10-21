import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_route.dart';
import 'package:dony/features/matching/presentation/widgets/trip_stops_badge.dart';
import 'package:dony/features/matching/presentation/widgets/trip_suitcase_gauge.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Fiche trajet au format billet, comme le détail d'un colis (FLUTTER-GG) :
/// corridor en grand, dates de départ et d'arrivée, perforation, puis les
/// caractéristiques du trajet (transport, escales, kilos) en talon.
///
/// Partagée par la feuille du trajet vue par un expéditeur et le détail du
/// trajet vu par son voyageur (FLUTTER-PY : l'ancien en-tête en dégradé bleu
/// nuit faisait « généré »).
class TripBilletCard extends StatelessWidget {
  const TripBilletCard({
    super.key,
    required this.announcement,
    this.trailing,
    this.showKg = true,
    this.notchColor,
  });

  final AnnouncementModel announcement;

  /// Posé dans l'en-tête, à droite (signet des favoris, statut du trajet).
  final Widget? trailing;

  /// Kilos disponibles dans le talon. Le détail du voyageur les affiche déjà
  /// juste en dessous, en grand.
  final bool showKg;

  /// Fond derrière le billet, pour les encoches de la perforation.
  /// `null` : `cs.surface` (fond d'une feuille).
  final Color? notchColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final transportLabel = announcement.transportMode?.label(l);
    final trailing = this.trailing;
    final notch = notchColor ?? cs.surface;
    final capacity = TripCapacity.fromAnnouncement(announcement);

    // Billet blanc, bordé, avec un bandeau teinté en tête : sur le fond gris
    // clair de l'app, l'ancien ton `surfaceContainerLow` était exactement
    // celui de l'écran et le billet disparaissait (FLUTTER-Q1).
    final isLight = Theme.of(context).brightness == Brightness.light;
    const radius = DonyRadius.card;
    return Container(
      key: const Key('trip-billet-card'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outline),
        boxShadow: isLight ? DonyShadow.md : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('trip-billet-header'),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(radius - 1),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              DonySpacing.base,
              trailing != null ? DonySpacing.xs : DonySpacing.sm,
              trailing != null ? DonySpacing.xs : DonySpacing.base,
              trailing != null ? DonySpacing.xs : DonySpacing.sm,
            ),
            child: Row(
              children: [
                DonyIcon('plane', size: 16, color: cs.onPrimaryContainer),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    l.listingHeroTripLabelCaps,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          BilletRoute(
            departureCity: announcement.departureCity,
            arrivalCity: announcement.arrivalCity,
            departureDate: announcement.departureDate,
            departureTime: announcement.departureTime,
            arrivalDate: announcement.arrivalDate,
            arrivalTime: announcement.arrivalTime,
            showWeekday: true,
            notchColor: notch,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.sm,
              DonySpacing.base,
              DonySpacing.base,
            ),
            child: Wrap(
              spacing: DonySpacing.xs + 2,
              runSpacing: DonySpacing.xs,
              children: [
                if (transportLabel != null) _BilletChip(label: transportLabel),
                if (announcement.stops != null)
                  _BilletChip(
                    key: const Key('detail-stops-chip'),
                    label: tripStopsBadgeLabel(l, announcement.stops!),
                  ),
                if (showKg)
                  _BilletChip(
                    label: announcement.isKgFree
                        ? l.tripKgFree
                        : capacity != null
                        ? '${l.listingSuitcaseCapacityLabel(capacity.count, capacity.unitKg)} · ${l.listingKgAvailableLabel(announcement.availableKg.toStringAsFixed(0))}'
                        : l.listingKgAvailableLabel(
                            announcement.availableKg.toStringAsFixed(0),
                          ),
                  ),
              ],
            ),
          ),
          if (showKg && capacity != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                0,
                DonySpacing.base,
                DonySpacing.base,
              ),
              child: TripSuitcaseGauge(capacity: capacity),
            ),
        ],
      ),
    );
  }
}

class _BilletChip extends StatelessWidget {
  const _BilletChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm + DonySpacing.xxs,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurface)),
    );
  }
}
