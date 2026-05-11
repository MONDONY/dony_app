import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Indicateur de progression du wizard 3 étapes.
///
/// Rendu sous l'AppBar — barre linéaire fine (3px) qui suit `currentStep / 3`.
/// Compagnon du label "Étape X / 3" rendu dans le titre de l'AppBar.
class WizardStepIndicator extends StatelessWidget
    implements PreferredSizeWidget {
  const WizardStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) {
    final progress = ((currentStep + 1) / totalSteps).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.white.withValues(alpha: 0.4),
      valueColor:
          const AlwaysStoppedAnimation<Color>(DonyColors.primary),
      minHeight: 3,
    );
  }
}
