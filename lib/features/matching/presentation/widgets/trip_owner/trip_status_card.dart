import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// États du trajet qui ont une carte d'explication sur l'écran du
/// propriétaire, sous le billet. Un trajet `ACTIVE` n'en a pas.
enum TripStatusCardKind {
  draft,
  full,
  inProgress,
  completed,
  cancelled,
  removedByAdmin,
}

/// Carte à montrer pour le statut back [status] d'un trajet, `null` pour
/// `ACTIVE` et pour un statut inconnu de l'app (aucune carte plutôt qu'un
/// texte faux).
TripStatusCardKind? tripStatusCardKindFor(String status) => switch (status) {
  'DRAFT' => TripStatusCardKind.draft,
  'FULL' => TripStatusCardKind.full,
  'IN_PROGRESS' => TripStatusCardKind.inProgress,
  'COMPLETED' => TripStatusCardKind.completed,
  'CANCELLED' => TripStatusCardKind.cancelled,
  'REMOVED_BY_ADMIN' => TripStatusCardKind.removedByAdmin,
  _ => null,
};

/// Carte d'information courte de l'état du trajet (écran du propriétaire),
/// sans titre de section, avec le composant d'information habituel
/// ([DonyStatusBanner]), comme les cartes d'information de la fiche colis.
///
/// Le brouillon garde le bandeau d'avant (titre et message) ; un trajet
/// complet dit que l'annulation passe par le support (le back refuse
/// d'annuler un trajet `FULL`) et que le report reste possible.
class TripStatusCard extends StatelessWidget {
  const TripStatusCard({super.key, required this.kind});

  final TripStatusCardKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyStatusBanner(
      key: Key('trip-status-card-${kind.name}'),
      type: switch (kind) {
        TripStatusCardKind.draft ||
        TripStatusCardKind.full ||
        TripStatusCardKind.cancelled ||
        TripStatusCardKind.removedByAdmin => DonyStatusBannerType.warning,
        TripStatusCardKind.inProgress ||
        TripStatusCardKind.completed => DonyStatusBannerType.info,
      },
      iconAsset: switch (kind) {
        TripStatusCardKind.draft => null,
        TripStatusCardKind.full => 'calendar-sync',
        TripStatusCardKind.inProgress => 'plane',
        TripStatusCardKind.completed => 'circle-check',
        TripStatusCardKind.cancelled => 'circle-x',
        TripStatusCardKind.removedByAdmin => 'triangle-alert',
      },
      title: kind == TripStatusCardKind.draft
          ? l.tripOwnerDraftBannerTitle
          : null,
      message: switch (kind) {
        TripStatusCardKind.draft => l.tripOwnerDraftBannerMessage,
        TripStatusCardKind.full => l.tripStatusFullMessage,
        TripStatusCardKind.inProgress => l.tripStatusInProgressMessage,
        TripStatusCardKind.completed => l.tripStatusCompletedMessage,
        TripStatusCardKind.cancelled => l.tripStatusCancelledMessage,
        TripStatusCardKind.removedByAdmin => l.tripStatusRemovedMessage,
      },
    );
  }
}
