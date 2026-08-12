import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/delivery_address_picker_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/pickup_address_picker_sheet.dart';
import 'package:flutter/material.dart';

enum AddressSelectorType { remise, livraison }

class AddressSelectorField extends StatelessWidget {
  const AddressSelectorField({
    super.key,
    required this.type,
    required this.onChanged,
    this.value,
  });

  final AddressSelectorType type;
  final ValueChanged<AddressData?> onChanged;
  final AddressData? value;

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
        color: color,
        containerColor: containerColor,
        tt: tt,
        cs: cs,
        onTap: () => _openSheet(context),
      );
    }

    return _EmptyCard(
      label: _isRemise
          ? 'Choisir une adresse de remise'
          : 'Choisir une adresse de livraison',
      subtitle: _isRemise
          ? 'Où tu récupères les colis des expéditeurs'
          : 'Où tu déposes les colis à destination',
      color: color,
      containerColor: containerColor,
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
  });

  final String label;
  final String subtitle;
  final Color color;
  final Color containerColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
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
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
  });

  final AddressData value;
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
        padding: const EdgeInsets.all(DonySpacing.base),
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
              child: Text(
                value.label,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
