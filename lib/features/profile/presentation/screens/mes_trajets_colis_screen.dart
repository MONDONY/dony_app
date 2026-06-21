import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran hub "Mes trajets et colis".
///
/// Deux sections PLATES (style liste iOS/WhatsApp) : header + lignes sur le
/// fond du scaffold, séparateurs fins — pas de carte bordée.
/// - **VOYAGEUR · TRAJETS** (toujours) : trajets, colis reçus, alertes colis,
///   modèles de trajet, adresses.
/// - **EXPÉDITEUR · COLIS** (si [isSender]) : alertes trajets, destinataires.
class MesTrajetsColisScreen extends StatelessWidget {
  const MesTrajetsColisScreen({
    super.key,
    this.upcomingCount = 0,
    this.isSender = false,
  });

  final int upcomingCount;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // ── Section VOYAGEUR — icônes primary (bleu) ─────────────────────────────
    final travelerTiles = <DonyListTile>[
      DonyListTile(
        iconAsset: 'plane',
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
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
        onTap: () => context.go('/announcements'),
      ),
      DonyListTile(
        iconAsset: 'inbox',
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Colis sur mes trajets',
        onTap: () => context.push('/package-requests/match'),
      ),
      DonyListTile(
        iconAsset: 'bell',
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Mes alertes colis',
        onTap: () => context.push(
          '/corridor-alerts',
          extra: AlertDirection.travelerWantsPackages,
        ),
      ),
      DonyListTile(
        iconAsset: 'bookmark',
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Mes modèles de trajet',
        onTap: () => context.push('/trip-templates'),
      ),
      DonyListTile(
        iconAsset: 'map-pin',
        iconColor: cs.primary,
        iconBgColor: cs.primaryContainer,
        label: 'Mes adresses',
        showDivider: false,
        onTap: () => context.push('/profile/addresses'),
      ),
    ];

    // ── Section EXPÉDITEUR — icônes secondary (terracotta) ───────────────────
    final senderTiles = <DonyListTile>[
      DonyListTile(
        iconAsset: 'bell',
        iconColor: cs.secondary,
        iconBgColor: cs.secondaryContainer,
        label: 'Mes alertes trajets',
        // Direction trajets : l'expéditeur est alerté quand un trajet matche.
        onTap: () => context.push(
          '/corridor-alerts',
          extra: AlertDirection.senderWantsTrips,
        ),
      ),
      DonyListTile(
        iconAsset: 'contact',
        iconColor: cs.secondary,
        iconBgColor: cs.secondaryContainer,
        label: 'Mes destinataires',
        showDivider: false,
        onTap: () => context.push('/profile/recipients'),
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
        children: [
          _FlatSection(title: 'Voyageur · Trajets', tiles: travelerTiles)
              .animate()
              .fadeIn(delay: 60.ms, duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          if (isSender) ...[
            const SizedBox(height: DonySpacing.xl),
            _FlatSection(title: 'Expéditeur · Colis', tiles: senderTiles)
                .animate()
                .fadeIn(delay: 140.ms, duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ],
        ],
      ),
    );
  }
}

/// Section plate : header uppercase + lignes sur le fond (aucune carte).
class _FlatSection extends StatelessWidget {
  const _FlatSection({required this.title, required this.tiles});

  final String title;
  final List<DonyListTile> tiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: DonySpacing.xs,
            bottom: DonySpacing.xs,
          ),
          child: Text(
            title.toUpperCase(),
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        ...tiles,
      ],
    );
  }
}
