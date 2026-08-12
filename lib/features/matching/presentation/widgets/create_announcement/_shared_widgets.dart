// Widgets helpers partagés entre les étapes du formulaire CreateAnnouncement.
// Ce fichier est interne à la feature matching — ne pas importer depuis l'extérieur.
// Ca = préfixe CreateAnnouncement — widgets internes à la feature, ne pas importer ailleurs.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Field card (thin white container for a single field) ─────────────────────

class CaFieldCard extends StatelessWidget {
  final Widget child;
  const CaFieldCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      // Material ancestor so any ListTile in the card paints ink above the
      // colored Container (Flutter 3.44 ListTile-in-ColoredBox assertion).
      child: Container(
        color: cs.surface,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ─── Field icon (styled prefix icon for form fields) ─────────────────────────

class CaFieldIcon extends StatelessWidget {
  final IconData icon;
  const CaFieldIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(icon, size: 20, color: cs.primary);
  }
}

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

// ─── Inline add row (no wrapper) ─────────────────────────────────────────────

class CaInlineAddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final Color accentColor;

  const CaInlineAddRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onAdd,
    this.accentColor = DonyColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style:
                  tt.bodyMedium?.copyWith(color: cs.onSurface),
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DonySpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Semantics(
            label: 'Ajouter un article',
            button: true,
            child: Tooltip(
              message: 'Ajouter',
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const DonyIcon('plus',
                      size: 18, color: DonyColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Removable chip ──────────────────────────────────────────────────────────

class CaRemovableChip extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onRemove;

  const CaRemovableChip({
    super.key,
    required this.label,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(
        left: DonySpacing.md,
        right: DonySpacing.xs,
        top: DonySpacing.xs,
        bottom: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: 'Retirer \$label',
            child: GestureDetector(
            onTap: onRemove,
            child: DonyIcon('x', size: 14, color: accentColor),
          )
          ),
        ],
      ),
    );
  }
}

// ─── Rangée heure ─────────────────────────────────────────────────────────────

class CaTimeRow extends StatelessWidget {
  final bool isDeparture;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const CaTimeRow({
    super.key,
    required this.isDeparture,
    required this.time,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = isDeparture ? cs.primary : DonyColors.accent;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            DonyIcon('clock',
                size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                time == null
                    ? isDeparture
                        ? 'Heure de départ (optionnel)'
                        : 'Heure d\'arrivée (optionnel)'
                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: tt.bodyMedium?.copyWith(
                  fontWeight:
                      time != null ? FontWeight.w600 : FontWeight.w400,
                  color: time != null
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            if (time != null && onClear != null)
              Semantics(
                button: true,
                container: true,
                excludeSemantics: true,
                label: "Effacer l'heure",
                child: GestureDetector(
                onTap: onClear,
                  child: DonyIcon('x',
                      size: 16, color: cs.onSurfaceVariant),
                ),
              )
            else
              DonyIcon('chevron-right',
                  size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Stepper header ───────────────────────────────────────────────────────────

class CaStepperHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const CaStepperHeader(
      {super.key, required this.currentStep, required this.totalSteps});

  static const _labels = ['Trajet', 'Lieux & capacité', 'Prix & conditions'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
            return Expanded(
              child: Text(
                i < currentStep ? '${_labels[i]} ✓' : _labels[i],
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: i == currentStep
                      ? cs.primary
                      : i < currentStep
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant,
                  fontWeight:
                      i == currentStep ? FontWeight.w800 : FontWeight.w500,
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
            ? [BoxShadow(color: cs.primary.withValues(alpha: 0.25), blurRadius: 8)]
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

// ─── Rangée date ──────────────────────────────────────────────────────────────

class CaDateRow extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;

  const CaDateRow({super.key, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            DonyIcon('calendar',
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                date == null
                    ? 'Date de départ'
                    : DateFormat('EEE d MMM yyyy', 'fr').format(date!),
                style: tt.bodyMedium?.copyWith(
                  fontWeight:
                      date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            DonyIcon('chevron-right',
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
