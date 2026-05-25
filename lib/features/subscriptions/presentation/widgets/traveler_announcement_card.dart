import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TravelerAnnouncementCard extends StatelessWidget {
  const TravelerAnnouncementCard({super.key, required this.announcement, required this.onReserve});
  final TravelerAnnouncement announcement;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('dd MMM yyyy', 'fr').format(announcement.departureDate),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.md),
          Row(
            children: [
              _dot(cs.primary),
              Expanded(child: _dashedLine(cs)),
              Icon(Icons.flight_takeoff_rounded, size: 16, color: cs.onSurfaceVariant),
              Expanded(child: _dashedLine(cs)),
              _dot(cs.onSurface),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(announcement.departureCity, style: tt.titleSmall),
              Text(announcement.arrivalCity, style: tt.titleSmall),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${announcement.pricePerKg.toStringAsFixed(0)} €',
                  style: tt.headlineSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
              Text('/kg', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('${announcement.availableKg.toStringAsFixed(0)} kg dispo',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(label: 'Réserver', onPressed: onReserve),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  Widget _dashedLine(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
        child: Container(height: 2, color: cs.outlineVariant),
      );
}
