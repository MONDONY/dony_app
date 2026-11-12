// Widgets helpers partagés entre les étapes du formulaire CreateAnnouncement.
// Ce fichier est interne à la feature matching — ne pas importer depuis l'extérieur.
// Ca = préfixe CreateAnnouncement — widgets internes à la feature, ne pas importer ailleurs.
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

// ─── Section card (white, no border, clip) ───────────────────────────────────

class CaSectionCard extends StatelessWidget {
  final Widget child;
  const CaSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        color: cs.surface,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ─── Thin row divider ─────────────────────────────────────────────────────────

class CaRowDivider extends StatelessWidget {
  const CaRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(height: 0.5, color: cs.outline);
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class CaSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? iconAsset;
  const CaSectionLabel({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final labelWidget = Text(
      label,
      style: tt.titleMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
    if (icon == null && iconAsset == null) return labelWidget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconAsset != null
            ? DonyIcon(iconAsset!, size: 13, color: cs.onSurfaceVariant)
            : Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        // Flexible plutôt que mainAxisSize.min : un libellé long à 200 % doit
        // pouvoir passer à la ligne au lieu de déborder du Row.
        Flexible(child: labelWidget),
      ],
    );
  }
}

// ─── Stepper header ───────────────────────────────────────────────────────────

class CaStepperHeader extends StatelessWidget {
  /// Étapes affichées, dans l'ordre (de 3 à 5 selon le formulaire).
  final List<TripFormStep> steps;

  /// Étape courante ; les précédentes sont marquées faites.
  final TripFormStep current;

  const CaStepperHeader({
    super.key,
    required this.steps,
    required this.current,
  });

  static String _label(TripFormStep step, AppLocalizations l) => switch (step) {
    TripFormStep.mode => l.tripPublishStepMode,
    TripFormStep.trajet => l.tripPublishRouteSectionLabel,
    TripFormStep.capacite => l.tripPublishStepCapacity,
    TripFormStep.prix => l.tripPublishStepPrice,
    TripFormStep.conditions => l.tripPublishStepConditions,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final currentStep = math.max(0, steps.indexOf(current));
    final totalSteps = steps.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          child: Row(
            children: [
              for (int i = 0; i < totalSteps; i++) ...[
                CaStepNode(index: i, currentStep: currentStep),
                if (i < totalSteps - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: i < currentStep ? cs.primary : cs.outlineVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          children: List.generate(totalSteps, (i) {
            final label = _label(steps[i], l);
            // Une ligne : à cinq étapes, « Conditions ✓ » est plus large que
            // sa colonne à 360 dp. Le libellé rétrécit au lieu de passer à la
            // ligne et de décaler la rangée.
            return Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  i < currentStep ? '$label ✓' : label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: i == currentStep
                        ? cs.primary
                        : i < currentStep
                        ? cs.primary.withValues(alpha: 0.7)
                        : cs.onSurfaceVariant,
                    fontWeight: i == currentStep
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class CaStepNode extends StatelessWidget {
  final int index;
  final int currentStep;
  const CaStepNode({super.key, required this.index, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = index < currentStep;
    final isActive = index == currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone || isActive ? cs.primary : cs.surfaceContainerHighest,
        border: isActive
            ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 4)
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? DonyIcon('check', size: 14, color: cs.onPrimary)
            : Text(
                '${index + 1}',
                style: tt.labelSmall?.copyWith(
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
