import 'package:flutter/material.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';

class SameAddressAnnouncementsSheet extends StatelessWidget {
  const SameAddressAnnouncementsSheet({
    super.key,
    required this.addressLabel,
    required this.announcements,
    required this.onTap,
  });

  final String addressLabel;
  final List<AnnouncementModel> announcements;
  final ValueChanged<AnnouncementModel> onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: DonyColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Address header
          Row(
            children: [
              Icon(Icons.place_rounded, size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  addressLabel,
                  style: tt.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            '${announcements.length} annonce${announcements.length > 1 ? "s" : ""} à cette adresse',
            style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
          ),
          const SizedBox(height: DonySpacing.md),
          // List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: announcements.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: DonyColors.borderDefault,
              ),
              itemBuilder: (_, i) {
                final a = announcements[i];
                final name = a.traveler?.displayName ?? 'Voyageur';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.luggage_rounded, color: cs.primary),
                  title: Text(name, style: tt.titleSmall),
                  subtitle: Text(
                    '${a.availableKg.toStringAsFixed(0)} kg • ${a.pricePerKg.toStringAsFixed(0)} €/kg',
                    style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onTap(a),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
