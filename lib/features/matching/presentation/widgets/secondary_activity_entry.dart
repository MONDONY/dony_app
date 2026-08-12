import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Additive entry to the other activity (Suivre un colis / Scanner un trajet).
/// Shown only for profiles that need it (gated by caller).
///
/// Style « carte neutre » : surface + bordure douce + icône en pastille
/// (primaryContainer) + libellé foncé + chevron discret.
class SecondaryActivityEntry extends StatelessWidget {
  const SecondaryActivityEntry({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconAsset,
  }) : assert(icon != null || iconAsset != null, 'Fournir icon ou iconAsset.');

  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  /// SVG teintable (`assets/icons/<name>.svg`) prioritaire sur [icon] dans la
  /// pastille colorée. Null = utilise [icon].
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: DonyColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.md),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                  ),
                  child: iconAsset != null
                      ? DonyIcon(iconAsset!, size: 20, color: cs.primary)
                      : Icon(icon, size: 20, color: cs.primary),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: tt.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
