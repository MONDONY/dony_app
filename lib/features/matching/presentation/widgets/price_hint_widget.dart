import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';

class PriceHintWidget extends StatelessWidget {
  final double? marketMedianPrice;
  final PriceWarning? warning;

  const PriceHintWidget({
    super.key,
    this.marketMedianPrice,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (warning == PriceWarning.tooLow) {
      return _buildWarning(
        tt: tt,
        icon: Icons.warning_amber_rounded,
        color: cs.warning,
        message: 'Prix bas — risque de méfiance de l\'expéditeur',
      );
    }
    if (warning == PriceWarning.tooHigh) {
      return _buildWarning(
        tt: tt,
        icon: Icons.warning_amber_rounded,
        color: cs.warning,
        message: 'Prix élevé — peu de demandes attendues',
      );
    }
    if (marketMedianPrice != null) {
      return Padding(
        padding: const EdgeInsets.only(top: DonySpacing.xs),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${marketMedianPrice!.toStringAsFixed(0)} €/kg — prix du marché',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildWarning({
    required TextTheme tt,
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
