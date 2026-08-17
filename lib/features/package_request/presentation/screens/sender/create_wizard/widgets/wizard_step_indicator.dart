import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Indicateur 3 segments — un segment par étape, terracotta quand actif/passé.
class WizardStepIndicator extends StatelessWidget
    implements PreferredSizeWidget {
  const WizardStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep;
  final int totalSteps;

  /// 8 (padding haut) + 4 (barre) + 12 (padding bas) = 24. La valeur annoncée
  /// était 20, soit 4 px de moins que le rendu réel.
  @override
  Size get preferredSize => const Size.fromHeight(24);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.md,
      ),
      child: Row(
        children: [
          for (int i = 0; i < totalSteps; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= currentStep ? cs.primary : cs.outline,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
              ),
            ),
            if (i < totalSteps - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
