import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Bandeau cliquable affiché entre le fil de messages et la CTA bar,
/// uniquement quand le statut est [AWAITING_PAYMENT] et qu'un trajet est lié.
class LinkedTripCard extends StatelessWidget {
  const LinkedTripCard({
    required this.trip,
    required this.onTap,
    this.parcelWeightKg,
    super.key,
  });

  final LinkedTripSummary trip;
  final VoidCallback onTap;

  /// Poids du colis négocié. Le poids restant du trajet n'a pas sa place ici :
  /// il vaut toujours 0 pour un trajet dédié, et tombe à 0 une fois le colis
  /// réservé, ce qui laissait croire à l'expéditeur que son colis pesait 0 kg
  /// (FLUTTER-Q3).
  final double? parcelWeightKg;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final icon = _iconForMode(trip.transportMode);
    final parsed = DateTime.tryParse(trip.departureDate ?? '');
    final weight = parcelWeightKg;
    final meta = [
      if (parsed != null)
        DateFormat.MMMEd(l.localeName).format(parsed)
      else if (trip.departureDate != null)
        trip.departureDate!,
      if (weight != null && weight > 0)
        l.negotiationLinkedTripParcelWeight('${formatKg(l, weight)} kg'),
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: DonyColors.ink800,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.starGold.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${trip.departureCity} → ${trip.arrivalCity}',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.neutral0,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: DonyColors.neutral400,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const DonyIcon(
              'chevron-right',
              color: DonyColors.starGold,
              size: 20,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  String _iconForMode(String? mode) {
    switch (mode) {
      case 'PLANE':
        return '✈';
      case 'TRAIN':
        return '🚄';
      case 'CAR':
        return '🚗';
      default:
        return '📦';
    }
  }
}
