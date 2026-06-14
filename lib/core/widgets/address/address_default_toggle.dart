import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class AddressDefaultToggle extends StatelessWidget {
  const AddressDefaultToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: value ? activeColor.withValues(alpha: 0.4) : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: value ? activeColor : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adresse par défaut',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
