import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Carte d'un trajet compatible dans l'écran de liaison de trajet.
class TripTile extends StatelessWidget {
  const TripTile({
    required this.announcement,
    required this.index,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AnnouncementModel announcement;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.flight_takeoff_rounded,
                    color: isSelected ? cs.onPrimary : cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE d MMM', 'fr')
                            .format(announcement.departureDate),
                        style:
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                        style:
                            Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: 12,
                                  color: kTextSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? cs.primary : kTextHint,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
  }
}
