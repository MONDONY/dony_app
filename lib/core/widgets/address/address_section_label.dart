import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class AddressSectionLabel extends StatelessWidget {
  const AddressSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DonySpacing.sm,
        left: DonySpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
