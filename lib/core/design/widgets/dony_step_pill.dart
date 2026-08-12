import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class DonyStepPill extends StatelessWidget {
  const DonyStepPill({
    super.key,
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '$current / $total · $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
