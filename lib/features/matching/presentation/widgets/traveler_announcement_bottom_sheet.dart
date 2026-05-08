import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void showTravelerAnnouncementSheet(
  BuildContext context, {
  required AnnouncementModel announcement,
}) {
  DonyBottomSheet.show<void>(
    context,
    title: 'Détail du trajet',
    stickyBottom: DonyButton(
      label: 'Faire une demande',
      icon: Icons.send_rounded,
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.push('/announcements/${announcement.id}');
      },
    ),
    child: _TravelerAnnouncementContent(announcement: announcement),
  );
}

class _TravelerAnnouncementContent extends StatelessWidget {
  const _TravelerAnnouncementContent({required this.announcement});

  final AnnouncementModel announcement;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final traveler = announcement.traveler;
    final rating = traveler?.averageRating;
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'fr').format(announcement.departureDate);
    final categories = announcement.acceptedContentTypes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voyageur
        Row(
          children: [
            DonyAvatar(
              name: traveler?.resolvedName ?? 'Voyageur',
              size: DonyAvatarSize.lg,
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    traveler?.resolvedName ?? 'Voyageur',
                    style: tt.titleLarge,
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: DonyColors.warning),
                      const SizedBox(width: DonySpacing.xxs),
                      Text(
                        rating != null ? '${rating.toStringAsFixed(1)}/5' : 'Nouveau',
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (traveler?.totalTrips != null && traveler!.totalTrips! > 0) ...[
                        const SizedBox(width: DonySpacing.xs),
                        Text(
                          '· ${traveler.totalTrips} trajet${traveler.totalTrips! > 1 ? 's' : ''}',
                          style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: DonySpacing.lg),
        Container(height: 1, color: DonyColors.borderDefault),
        const SizedBox(height: DonySpacing.lg),

        // Route
        Row(
          children: [
            Expanded(
              child: Text(
                announcement.departureCity,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                  Container(width: 28, height: 1.5, color: cs.primary.withValues(alpha: 0.3)),
                  Icon(Icons.flight_takeoff_rounded, size: 16, color: cs.primary),
                  Container(width: 28, height: 1.5, color: cs.primary.withValues(alpha: 0.3)),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: DonyColors.accent, shape: BoxShape.circle)),
                ],
              ),
            ),
            Expanded(
              child: Text(
                announcement.arrivalCity,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),

        const SizedBox(height: DonySpacing.lg),

        // Détails
        _InfoRow(icon: Icons.calendar_today_outlined, label: dateStr),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          label: '${announcement.availableKg.toStringAsFixed(0)} kg disponibles',
        ),
        const SizedBox(height: DonySpacing.sm),
        _InfoRow(
          icon: Icons.euro_rounded,
          label: '${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
          labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
        ),

        if (categories.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text('Types de colis acceptés', style: tt.labelMedium?.copyWith(color: DonyColors.textMuted)),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: categories.map((c) => _CategoryChip(label: c)).toList(),
          ),
        ],

        if (announcement.description != null && announcement.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.lg),
          Text('Message du voyageur', style: tt.labelMedium?.copyWith(color: DonyColors.textMuted)),
          const SizedBox(height: DonySpacing.sm),
          Text(announcement.description!, style: tt.bodyMedium),
        ],

        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.labelStyle});
  final IconData icon;
  final String label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: DonyColors.textSubtle),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            label,
            style: (tt.bodyMedium ?? const TextStyle()).merge(labelStyle),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm, vertical: DonySpacing.xxs),
      decoration: BoxDecoration(
        color: DonyColors.bgApp,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: DonyColors.borderDefault),
      ),
      child: Text(label, style: tt.labelSmall?.copyWith(color: DonyColors.textMuted)),
    );
  }
}
