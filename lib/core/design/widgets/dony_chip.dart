import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Chip de filtre/sélection dony.
///
/// Usage simple :
/// ```dart
/// DonyChip(label: 'Paris', selected: _city == 'Paris', onTap: () => _city = 'Paris')
/// ```
///
/// Groupe de chips :
/// ```dart
/// DonyChipGroup<String>(
///   options: ['Paris', 'Lyon', 'Marseille'],
///   labelBuilder: (v) => v,
///   selected: _selectedCities,
///   onChanged: (v) => setState(() => _selectedCities = v),
/// )
/// ```
class DonyChip extends StatelessWidget {
  const DonyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final bg = selected ? cs.primaryContainer : DonyColors.surface;
    final fg = selected ? cs.primary : DonyColors.textMuted;
    final border = selected ? cs.primary : DonyColors.borderDefault;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: DonyDuration.micro,
          curve: DonyCurve.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DonyRadius.full),
            border: Border.all(color: border, width: selected ? 1.5 : 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: DonySpacing.xs),
              ],
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: fg,
                  letterSpacing: 0,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groupe de chips mono ou multi-sélection.
class DonyChipGroup<T> extends StatelessWidget {
  const DonyChipGroup({
    super.key,
    required this.options,
    required this.labelBuilder,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    this.iconBuilder,
    this.spacing = DonySpacing.sm,
  });

  final List<T> options;
  final String Function(T) labelBuilder;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelect;
  final IconData? Function(T)? iconBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: DonySpacing.sm,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return DonyChip(
          label: labelBuilder(opt),
          selected: isSelected,
          icon: iconBuilder?.call(opt),
          onTap: () {
            if (multiSelect) {
              final next = Set<T>.from(selected);
              isSelected ? next.remove(opt) : next.add(opt);
              onChanged(next);
            } else {
              onChanged({opt});
            }
          },
        );
      }).toList(),
    );
  }
}
