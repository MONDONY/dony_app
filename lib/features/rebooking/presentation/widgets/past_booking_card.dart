import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/rebooking/data/rebooking_repository.dart';
import 'package:dony/features/rebooking/presentation/widgets/rebook_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PastBookingCard extends StatelessWidget {
  const PastBookingCard({
    super.key,
    required this.booking,
    required this.onRebook,
    this.isRebooking = false,
  });

  final PastBookingItem booking;
  final VoidCallback onRebook;
  final bool isRebooking;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyAvatar(name: booking.travelerName),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.travelerName, style: tt.titleLarge),
                    Text(
                      '${booking.departureCity} → ${booking.arrivalCity}',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (booking.travelerBadge != null)
                DonyBadge(label: booking.travelerBadge!),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Dernier envoi le ${DateFormat('dd MMM yyyy', 'fr_FR').format(booking.lastTripDate)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (booking.completedTripsWithThisTraveler > 1) ...[
            const SizedBox(height: DonySpacing.xxs),
            Row(
              children: [
                Icon(Icons.local_shipping_rounded,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  '${booking.completedTripsWithThisTraveler} envois réalisés ensemble',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          RebookButton(
            onPressed: isRebooking ? null : onRebook,
            isLoading: isRebooking,
          ),
        ],
      ),
    );
  }
}
