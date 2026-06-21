import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Écran hub "Mes trajets et colis".
///
/// Deux blocs distincts selon le rôle :
/// - **VOYAGEUR · TRAJETS** (toujours) : tout ce qui concerne les trajets du
///   voyageur — trajets, colis reçus sur ses trajets, alertes corridor,
///   modèles de trajet, adresses.
/// - **EXPÉDITEUR · COLIS** (si [isSender]) : les demandes d'envoi de
///   l'expéditeur et son carnet de destinataires.
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

    // ── Bloc VOYAGEUR — icônes primary (bleu) ────────────────────────────────
    final travelerSection = DonyListSection(
      title: 'Voyageur · Trajets',
      tiles: [
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
          onTap: () => context.push('/profile/addresses'),
        ),
      ],
    );

    // ── Bloc EXPÉDITEUR — icônes secondary (terracotta) ──────────────────────
    final senderSection = DonyListSection(
      title: 'Expéditeur · Colis',
      // « Mes demandes de colis » n'est PAS listé ici : déjà accessible via le
      // hub Envoyer (onglet « Demandes ») depuis l'onglet Activité du profil.
      tiles: [
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
          onTap: () => context.push('/profile/recipients'),
        ),
      ],
    );

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
          travelerSection
              .animate()
              .fadeIn(delay: 60.ms, duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          if (isSender) ...[
            const SizedBox(height: DonySpacing.xl),
            senderSection
                .animate()
                .fadeIn(delay: 140.ms, duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ],
        ],
      ),
    );
  }
}
