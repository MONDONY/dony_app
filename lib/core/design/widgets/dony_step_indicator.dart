import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Indicateur de progression par étapes — onboarding, formulaires multi-step.
///
/// Usage :
/// ```dart
/// DonyStepIndicator(total: 4, current: 2)
///
/// DonyStepIndicator.labeled(
///   steps: ['Téléphone', 'OTP', 'Rôle', 'PIN'],
///   current: 1,
/// )
/// ```
class DonyStepIndicator extends StatelessWidget {
  const DonyStepIndicator({
    super.key,
    required this.total,
    required this.current,
    this.variant = DonyStepVariant.dots,
  }) : steps = null;

  const DonyStepIndicator.labeled({
    super.key,
    required List<String> this.steps,
    required this.current,
  })  : total = 0,
        variant = DonyStepVariant.labeled;

  final int total;
  final int current;
  final List<String>? steps;
  final DonyStepVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      DonyStepVariant.dots   => _DotsIndicator(total: total, current: current),
      DonyStepVariant.bar    => _BarIndicator(total: total, current: current),
      DonyStepVariant.labeled => _LabeledIndicator(steps: steps!, current: current),
    };
  }
}

enum DonyStepVariant { dots, bar, labeled }

// ─── Dots ────────────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: DonyDuration.base,
          curve: DonyCurve.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.outline,
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
        );
      }),
    );
  }
}

// ─── Bar ─────────────────────────────────────────────────────────────────────

class _BarIndicator extends StatelessWidget {
  const _BarIndicator({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(total, (i) {
        final done = i <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? DonySpacing.xs : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done ? cs.primary : cs.outline,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Labeled ─────────────────────────────────────────────────────────────────

class _LabeledIndicator extends StatelessWidget {
  const _LabeledIndicator({required this.steps, required this.current});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(steps.length, (i) {
        final done   = i < current;
        final active = i == current;

        final circleColor = done || active ? cs.primary : cs.outline;
        final labelColor  = active ? cs.primary : cs.onSurfaceVariant;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : null,
                        size: 14,
                        color: (done || active) ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      steps[i],
                      style: tt.labelSmall?.copyWith(
                        color: labelColor,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: DonySpacing.xl),
                    color: i < current ? cs.primary : cs.outline,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
