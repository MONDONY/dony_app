import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Checkbox stylisé Yadony avec label.
///
/// Usage :
/// ```dart
/// DonyCheckbox(
///   label: "J'accepte les conditions",
///   value: _accepted,
///   onChanged: (v) => setState(() => _accepted = v ?? false),
/// )
/// ```
class DonyCheckbox extends StatelessWidget {
  const DonyCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.tristate = false,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final String? subtitle;
  final bool enabled;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled
          ? () {
              if (tristate) {
                onChanged(value == null ? true : value! ? false : null);
              } else {
                onChanged(!(value ?? false));
              }
            }
          : null,
      borderRadius: BorderRadius.circular(DonyRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.sm,
          horizontal: DonySpacing.xs,
        ),
        child: Row(
          crossAxisAlignment:
              subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  tristate: tristate,
                  activeColor: cs.primary,
                  checkColor: cs.onPrimary,
                  side: BorderSide(
                    color: value == true ? cs.primary : cs.outline,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DonyRadius.xs),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyMedium?.copyWith(
                      color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
