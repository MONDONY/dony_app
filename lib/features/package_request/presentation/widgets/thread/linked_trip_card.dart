import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Bandeau cliquable affiché entre le fil de messages et la CTA bar,
/// uniquement quand le statut est [AWAITING_PAYMENT] et qu'un trajet est lié.
class LinkedTripCard extends StatelessWidget {
  const LinkedTripCard({
    required this.trip,
    required this.onTap,
    super.key,
  });

  final LinkedTripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForMode(trip.transportMode);
    final date = trip.departureDate ?? '';

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
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F2544)],
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: DonyColors.starGold.withValues(alpha: 0.6),
          ),
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
                  const SizedBox(height: 2),
                  Text(
                    '$date · ${trip.availableKg} kg',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontWeight: FontWeight.w500,
                          color: DonyColors.neutral400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
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
