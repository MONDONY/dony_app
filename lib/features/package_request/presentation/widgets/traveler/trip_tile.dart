import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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
    required this.onModify,
    super.key,
  });

  final AnnouncementModel announcement;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  /// `null` quand le trajet ne peut pas être modifié en sécurité
  /// (adresses incomplètes) — le bouton « Modifier » est alors désactivé.
  final VoidCallback? onModify;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cashOn =
        announcement.acceptedPaymentMethods.contains(BidPaymentMethod.cash);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                key: const Key('trip-tile-select-inkwell'),
                borderRadius: BorderRadius.circular(DonyRadius.md),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.primaryContainer,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              announcement.isKgFree
                                  ? 'Kg libre · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg'
                                  : '${announcement.availableKg} kg dispo · ${announcement.pricePerKg.toStringAsFixed(0)} €/kg',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Divider(height: 1, color: cs.outline),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ModifyButton(onTap: onModify),
                        const Spacer(),
                        _CashChip(enabled: cashOn),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: (40 * index).ms)
        .slideY(begin: 0.04);
  }
}

class _ModifyButton extends StatelessWidget {
  const _ModifyButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DonyRadius.sm),
      child: InkWell(
        key: const Key('trip-tile-modify-button'),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        onTap: onTap,
        child: Padding(
          // vertical 16 : hauteur rendue ~50pt → cible tactile ≥ 44 (HIG).
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.base,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded,
                  size: 14,
                  color: enabled ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Modifier le trajet',
                style: tt.bodySmall?.copyWith(
                  color: enabled ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashChip extends StatelessWidget {
  const _CashChip({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('trip-tile-cash-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: enabled ? cs.successLight : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.payments_rounded : Icons.payments_outlined,
            size: 13,
            color: enabled ? cs.success : cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.xs),
          Text(
            enabled ? 'Liquide activé' : 'Liquide désactivé',
            style: tt.bodySmall?.copyWith(
              color: enabled ? cs.success : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
