import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran hub "Mes trajets et colis" (voyageur uniquement).
///
/// Affiche les 4 entrées voyageur en layout FLAT (pas de DonyCard/DonyListSection) :
/// séparateurs thin directement sur le fond du scaffold.
class MesTrajetsColisScreen extends StatelessWidget {
  const MesTrajetsColisScreen({super.key, this.upcomingCount = 0});

  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final tiles = <_TileData>[
      _TileData(
        iconAsset: 'plane',
        label: 'Mes trajets',
        trailing: upcomingCount > 0
            ? Text(
                '$upcomingCount à venir',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        onTap: () => context.push('/announcements'),
      ),
      _TileData(
        iconAsset: 'inbox',
        label: 'Colis sur mes trajets',
        onTap: () => context.push('/package-requests/match'),
      ),
      _TileData(
        iconAsset: 'bell',
        label: 'Mes alertes corridor',
        onTap: () => context.push('/corridor-alerts'),
      ),
      _TileData(
        iconAsset: 'bookmark',
        label: 'Mes modèles de trajet',
        showDivider: false,
        onTap: () => context.push('/trip-templates'),
      ),
    ];

    return DonyPageScaffold(
      title: 'Mes trajets et colis',
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
            iconColor: cs.primary,
            iconBgColor: cs.primaryContainer,
            label: t.label,
            trailing: t.trailing,
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
    this.trailing,
    this.showDivider = true,
  });

  final String iconAsset;
  final String label;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback onTap;
}
