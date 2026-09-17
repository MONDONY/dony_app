import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:flutter/material.dart';

class RequestSectionTitle extends StatelessWidget {
  const RequestSectionTitle(this.label, {this.count, super.key});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      count == null ? label : '$label ($count)',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class RequestTravelersList extends StatelessWidget {
  const RequestTravelersList({
    required this.trips,
    required this.requestWeightKg,
    required this.inviteStateFor,
    required this.onInvite,
    required this.onOpenTrip,
    super.key,
  });

  final List<AnnouncementModel> trips;
  final double requestWeightKg;
  final TravelerInviteState Function(String announcementId) inviteStateFor;
  final void Function(String announcementId) onInvite;
  final void Function(AnnouncementModel trip) onOpenTrip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const RequestSectionTitle('Voyageurs sur ton axe'),
      const SizedBox(height: DonySpacing.sm),
      for (final trip in trips) ...[
        CompatibleTravelerCard(
          trip: trip,
          requestWeightKg: requestWeightKg,
          inviteState: inviteStateFor(trip.id),
          onInvite: () => onInvite(trip.id),
          onTap: () => onOpenTrip(trip),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    ],
  );
}

class RequestTravelersFold extends StatelessWidget {
  const RequestTravelersFold({required this.trips, required this.label, this.onTap, super.key});

  final List<AnnouncementModel> trips;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final row = Row(
      children: [
        for (final (i, trip) in trips.take(3).indexed)
          Transform.translate(
            offset: Offset(-8.0 * i, 0),
            child: DonyAvatar(name: trip.traveler?.displayName ?? 'Voyageur',
                imageUrl: trip.traveler?.avatarUrl, size: DonyAvatarSize.sm),
          ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        // Chevron seulement si la ligne est réellement tapable : sinon elle
        // laisserait croire à un dépliage qui n'existe pas.
        if (onTap != null) DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
      ],
    );
    final content = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: DonySpacing.sm),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: cs.outline)),
      child: row,
    );
    // Sans onTap, ni Material ni InkWell : pas de ripple pour un geste qui n'existe pas.
    if (onTap == null) return content;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: content,
      ),
    );
  }
}

class RequestNoTravelersEmpty extends StatelessWidget {
  const RequestNoTravelersEmpty({
    required this.corridor,
    required this.onCreateAlert,
    required this.onWidenDates,
    super.key,
  });

  final String corridor;
  final VoidCallback onCreateAlert;
  final VoidCallback onWidenDates;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget action(String icon, String label, VoidCallback onTap) => Material(
      // sand100 ↔ sandDark100 via l'extension DonyStatusColors : équivalent
      // theme-aware exact de la primitive DonyColors.sand100 de la fiche.
      color: cs.surfaceWarm,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
          child: Row(children: [
            // terra600 = DonyColors.accent = cs.secondary (app_theme.dart) :
            // équivalent theme-aware de la primitive DonyColors.terra600.
            DonyIcon(icon, size: 18, color: cs.secondary),
            const SizedBox(width: DonySpacing.sm),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline)),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Center(child: DonyIcon('plane', size: 22, color: cs.primary)),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text('Aucun voyageur sur $corridor pour l\'instant', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Les trajets arrivent souvent la semaine du départ. On te prévient dès qu\'un voyageur publie.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: DonySpacing.md),
          action('bell', 'Être alerté des nouveaux trajets', onCreateAlert),
          const SizedBox(height: DonySpacing.sm),
          action('calendar', 'Élargir mes dates', onWidenDates),
        ],
      ),
    );
  }
}
