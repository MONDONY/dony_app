import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Ligne d'info label/valeur — récapitulatifs, détails de trajet, factures.
///
/// Usage :
/// ```dart
/// DonyInfoRow(label: 'Départ', value: 'Paris CDG')
/// DonyInfoRow(label: 'Prix', value: '45 €', valueStyle: ValueStyle.accent)
/// DonyInfoRow.divider()
/// ```
enum DonyInfoRowValueStyle { normal, accent, success, warning, danger, muted }

class DonyInfoRow extends StatelessWidget {
  const DonyInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueStyle = DonyInfoRowValueStyle.normal,
    this.valueWidget,
  }) : _isDivider = false;

  const DonyInfoRow.divider({super.key})
      : label = '',
        value = '',
        icon = null,
        valueStyle = DonyInfoRowValueStyle.normal,
        valueWidget = null,
        _isDivider = true;

  final String label;
  final String value;
  final IconData? icon;
  final DonyInfoRowValueStyle valueStyle;
  final Widget? valueWidget;
  final bool _isDivider;

  @override
  Widget build(BuildContext context) {
    if (_isDivider) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: DonySpacing.xs),
        child: Divider(height: 1),
      );
    }

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final valueColor = switch (valueStyle) {
      DonyInfoRowValueStyle.normal  => DonyColors.textPrimary,
      DonyInfoRowValueStyle.accent  => cs.secondary,
      DonyInfoRowValueStyle.success => DonyColors.success,
      DonyInfoRowValueStyle.warning => DonyColors.warning,
      DonyInfoRowValueStyle.danger  => cs.error,
      DonyInfoRowValueStyle.muted   => DonyColors.textMuted,
    };

    final valueFw = switch (valueStyle) {
      DonyInfoRowValueStyle.normal  => FontWeight.w500,
      DonyInfoRowValueStyle.accent  => FontWeight.w700,
      DonyInfoRowValueStyle.success => FontWeight.w600,
      DonyInfoRowValueStyle.warning => FontWeight.w600,
      DonyInfoRowValueStyle.danger  => FontWeight.w600,
      DonyInfoRowValueStyle.muted   => FontWeight.w400,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm - 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: DonyColors.textMuted),
            const SizedBox(width: DonySpacing.xs),
          ],
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          valueWidget ??
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: valueFw,
                ),
              ),
        ],
      ),
    );
  }
}
