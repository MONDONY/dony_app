import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Additive entry to the other activity (Mes trajets / Envoyer un colis).
/// Shown only for profiles that need it (gated by caller).
class SecondaryActivityEntry extends StatelessWidget {
  const SecondaryActivityEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: DonyColors.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: DonyColors.primary),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DonyColors.primary,
                    ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: DonyColors.primary),
          ],
        ),
      ),
    );
  }
}
