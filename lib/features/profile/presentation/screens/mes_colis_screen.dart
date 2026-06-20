import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran hub "Mes colis" (expéditeur uniquement).
///
/// Affiche les 2 entrées expéditeur en layout FLAT (pas de DonyCard/DonyListSection) :
/// séparateurs thin directement sur le fond du scaffold.
class MesColisScreen extends StatelessWidget {
  const MesColisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tiles = <_TileData>[
      _TileData(
        iconAsset: 'package',
        label: 'Mes demandes de colis',
        onTap: () => context.push('/package-requests/me'),
      ),
      _TileData(
        iconAsset: 'bell',
        label: 'Mes alertes corridor',
        showDivider: false,
        onTap: () => context.push('/corridor-alerts'),
      ),
    ];

    return DonyPageScaffold(
      title: 'Mes colis',
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(tiles.length, (i) {
          final t = tiles[i];
          return DonyListTile(
            iconAsset: t.iconAsset,
            iconColor: cs.secondary,
            iconBgColor: cs.secondaryContainer,
            label: t.label,
            showDivider: t.showDivider,
            onTap: t.onTap,
          )
              .animate()
              .fadeIn(
                delay: (60 * i).ms,
                duration: 300.ms,
              )
              .slideY(begin: 0.04, curve: Curves.easeOutCubic);
        }),
      ),
    );
  }
}

class _TileData {
  const _TileData({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final String iconAsset;
  final String label;
  final bool showDivider;
  final VoidCallback onTap;
}
