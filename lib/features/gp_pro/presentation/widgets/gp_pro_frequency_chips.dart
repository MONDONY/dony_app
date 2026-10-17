import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Choix de la fréquence de voyage GP Pro (formulaire du profil et case de
/// l'inscription).
class GpProFrequencyChips extends StatelessWidget {
  const GpProFrequencyChips({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final GpProFrequency? selected;
  final ValueChanged<GpProFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyChipGroup<GpProFrequency>(
      options: GpProFrequency.values,
      labelBuilder: l.gpProFrequency,
      selected: {?selected},
      onChanged: (selection) {
        if (selection.isEmpty) return;
        onChanged(selection.first);
      },
    );
  }
}
