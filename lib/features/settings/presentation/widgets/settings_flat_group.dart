import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Conteneur « liste groupée plate » iOS : surface blanche arrondie SANS
/// bordure ni ombre. Remplace les cards bordées (DonyListSection / DonyCard /
/// Container Border.all) dans les écrans de Paramètres.
class SettingsFlatGroup extends StatelessWidget {
  const SettingsFlatGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
