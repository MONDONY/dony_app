import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/delivery_address_picker_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/pickup_address_picker_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum AddressSelectorType { remise, livraison }

class AddressSelectorField extends StatelessWidget {
  const AddressSelectorField({
    super.key,
    required this.type,
    required this.onChanged,
    this.value,
    this.dense = false,
    this.caption,
  });

  final AddressSelectorType type;
  final ValueChanged<AddressData?> onChanged;
  final AddressData? value;

  /// Carte compacte, chaque texte sur une ligne (feuille d'une étape,
  /// FLUTTER-HN) : sur 360 dp l'adresse et l'aide passaient sur deux lignes.
  final bool dense;

  /// Légende au-dessus de l'adresse choisie, pour dire ce qu'elle désigne
  /// quand aucun titre de section ne le fait.
  final String? caption;

  bool get _isRemise => type == AddressSelectorType.remise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _isRemise ? cs.primary : cs.secondary;
    final containerColor = _isRemise
        ? cs.primaryContainer
        : cs.secondaryContainer;

    if (value != null) {
      return _FilledCard(
        value: value!,
        dense: dense,
        caption: caption,
        color: color,
        containerColor: containerColor,
        tt: tt,
        cs: cs,
        onTap: () => _openSheet(context),
      );
    }

    final l10n = context.l10n;
    return _EmptyCard(
      label: _isRemise
          ? l10n.addressSelectorDropoffLabel
          : l10n.addressSelectorDeliveryLabel,
      subtitle: _isRemise
          ? l10n.addressSelectorDropoffSubtitle
          : l10n.addressSelectorDeliverySubtitle,
      color: color,
      containerColor: containerColor,
      dense: dense,
      onTap: () => _openSheet(context),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final AddressData? result;
    if (_isRemise) {
      result = await PickupAddressPickerSheet.show(context, current: value);
    } else {
      result = await DeliveryAddressPickerSheet.show(context, current: value);
    }
    if (result != null && context.mounted) {
      onChanged(result);
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.containerColor,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final String subtitle;
  final Color color;
  final Color containerColor;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(dense ? DonySpacing.md : DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: DonyIcon('map-pin', color: color, size: 20),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: dense ? 1 : null,
                    overflow: dense ? TextOverflow.ellipsis : null,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: dense ? 1 : null,
                    overflow: dense ? TextOverflow.ellipsis : null,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            DonyIcon('chevron-right', color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard({
    required this.value,
    required this.color,
    required this.containerColor,
    required this.tt,
    required this.cs,
    required this.onTap,
    this.dense = false,
    this.caption,
  });

  final AddressData value;
  final bool dense;
  final String? caption;
  final Color color;
  final Color containerColor;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(dense ? DonySpacing.md : DonySpacing.base),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: DonyIcon('map-pin', color: color, size: 20),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null)
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    value.label,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: dense ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const DonyIcon('check', color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
