import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Groupe de boutons radio stylisés Yadony.
///
/// Usage :
/// ```dart
/// DonyRadioGroup<String>(
///   label: 'Rôle',
///   value: _role,
///   onChanged: (v) => setState(() => _role = v),
///   options: [
///     DonyRadioOption(value: 'SENDER',   label: 'Expéditeur'),
///     DonyRadioOption(value: 'TRAVELER', label: 'Voyageur',
///                     subtitle: 'Je transporte des colis'),
///   ],
/// )
/// ```
class DonyRadioOption<T> {
  const DonyRadioOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
}

class DonyRadioGroup<T> extends StatelessWidget {
  const DonyRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.direction = Axis.vertical,
  });

  final List<DonyRadioOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? label;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final items = options.map(
      (opt) => _DonyRadioTile<T>(
        option: opt,
        groupValue: value,
        onChanged: onChanged,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        if (direction == Axis.vertical)
          Column(children: items.toList())
        else
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: items.toList(),
          ),
      ],
    );
  }
}

class _DonyRadioTile<T> extends StatelessWidget {
  const _DonyRadioTile({
    required this.option,
    required this.groupValue,
    required this.onChanged,
  });

  final DonyRadioOption<T> option;
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  bool get _selected => groupValue == option.value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: option.enabled ? () => onChanged(option.value) : null,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      // Une option sans sous-titre descendait à 37 px. Le plancher ne change
      // rien aux options déjà plus hautes.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DonySpacing.sm,
            horizontal: DonySpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: option.subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              _RadioDot(selected: _selected, enabled: option.enabled),
              const SizedBox(width: DonySpacing.xs),
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 18,
                  color: _selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: DonySpacing.xs),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: _selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: option.enabled
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        option.subtitle!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.enabled});
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = selected ? cs.primary : cs.onSurfaceVariant;
    final fillColor = selected ? cs.primary : Colors.transparent;

    return AnimatedContainer(
      duration: DonyDuration.micro,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? borderColor : cs.outline.withValues(alpha: 0.5),
          width: selected ? 0 : 1.5,
        ),
        color: enabled ? fillColor : Colors.transparent,
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
