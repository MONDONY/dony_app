import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class AddressLabelChips extends StatelessWidget {
  const AddressLabelChips({
    super.key,
    required this.controller,
    required this.chips,
    required this.accentColor,
    required this.onSelected,
  });

  final TextEditingController controller;
  final List<String> chips;
  final Color accentColor;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: chips.map((label) {
        final selected = controller.text.trim() == label;
        return GestureDetector(
          onTap: () {
            controller.text = label;
            onSelected();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md, vertical: DonySpacing.sm),
            decoration: BoxDecoration(
              color: selected ? accentColor.withValues(alpha: 0.12) : cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.xl),
              border: Border.all(
                  color: selected ? Colors.transparent : cs.outline),
            ),
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? accentColor : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
