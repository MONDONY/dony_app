import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TravelerInviteState { hidden, idle, sending, invited }

class CompatibleTravelerCard extends StatelessWidget {
  const CompatibleTravelerCard({
    required this.trip,
    required this.requestWeightKg,
    required this.inviteState,
    this.onInvite,
    this.onTap,
    super.key,
  });

  final AnnouncementModel trip;
  final double requestWeightKg;
  final TravelerInviteState inviteState;
  final VoidCallback? onInvite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = trip.traveler?.displayName ?? 'Voyageur';
    final total = trip.totalKg > 0 ? trip.totalKg : trip.availableKg;
    final freeShare = total > 0 ? (trip.availableKg / total).clamp(0.0, 1.0) : 0.0;
    final needShare = total > 0 ? (requestWeightKg / total).clamp(0.0, freeShare) : 0.0;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DonyAvatar(name: name, imageUrl: trip.traveler?.avatarUrl, verified: trip.traveler?.kycVerified ?? false),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                          if (trip.traveler?.averageRating != null) ...[
                            const SizedBox(width: 4),
                            DonyIcon('star', size: 13, color: cs.warning),
                            Text(NumberFormat('0.0', 'fr').format(trip.traveler!.averageRating),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ]),
                        Text('${DateFormat('d MMM', 'fr').format(trip.departureDate)} · '
                            '${trip.departureCity} → ${trip.arrivalCity}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _InviteButton(state: inviteState, onInvite: onInvite),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(children: [
                    Container(color: cs.surfaceContainerHighest),
                    FractionallySizedBox(widthFactor: freeShare, child: Container(color: cs.primary)),
                    FractionallySizedBox(widthFactor: needShare, child: Container(color: cs.success)),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${trip.availableKg.toStringAsFixed(0)} kg libres',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('ton colis : ${requestWeightKg.toStringAsFixed(requestWeightKg % 1 == 0 ? 0 : 1)} kg',
                      style: TextStyle(fontSize: 12, color: cs.success, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.state, this.onInvite});
  final TravelerInviteState state;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (state) {
      TravelerInviteState.hidden => const SizedBox.shrink(),
      TravelerInviteState.sending => const SizedBox(
        width: 44, height: 44,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      TravelerInviteState.invited => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          DonyIcon('check', size: 14, color: cs.success),
          const SizedBox(width: 4),
          Text('Invité', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.success)),
        ]),
      ),
      TravelerInviteState.idle => TextButton(
        onPressed: onInvite,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DonyRadius.md)),
        ),
        child: const Text('Inviter', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    };
  }
}
