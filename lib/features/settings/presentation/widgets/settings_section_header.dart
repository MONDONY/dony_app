import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Titre de section style iOS plat (gris, 13px). `color` optionnelle pour les
/// sections colorées (ex. « PROTECTIONS CRITIQUES » en rouge).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.sm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color ?? cs.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
