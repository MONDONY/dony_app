import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// États du trajet qui ont une carte d'explication sur l'écran du
/// propriétaire, sous le billet. Un trajet `ACTIVE` n'en a pas.
enum TripStatusCardKind {
  draft,
  full,
  inProgress,

  /// IN_PROGRESS après l'arrivée : des colis attendent leurs destinataires
  /// et plus aucun n'est en route.
  arrived,
  completed,
  cancelled,
  removedByAdmin,
}

/// Carte à montrer pour le statut back [status] d'un trajet, `null` pour
/// `ACTIVE` et pour un statut inconnu de l'app (aucune carte plutôt qu'un
/// texte faux).
///
/// [bids] : colis du trajet chargés par l'écran, `null` tant que la liste
/// n'a pas répondu. « Arrivé à destination » laisse le trajet IN_PROGRESS
/// jusqu'au dernier colis livré : dès qu'un colis est `ARRIVED`
/// ([tripHasArrivedParcel]) et qu'aucun n'est plus remis ou en transit
/// ([tripCanMarkArrived] faux, ce que le pied traduit par « Prévenir les
/// destinataires »), la carte dit que les colis attendent leurs
/// destinataires. Sinon, ou tant que la liste n'a pas répondu : « en cours ».
TripStatusCardKind? tripStatusCardKindFor(
  String status, {
  List<BidModel>? bids,
}) => switch (status) {
  'DRAFT' => TripStatusCardKind.draft,
  'FULL' => TripStatusCardKind.full,
  'IN_PROGRESS'
      when bids != null &&
          tripHasArrivedParcel(bids) &&
          !tripCanMarkArrived(bids) =>
    TripStatusCardKind.arrived,
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
/// d'annuler un trajet `FULL`), et que le report reste possible seulement
/// s'il l'est ([canReschedule]). Un trajet complet ou retiré par l'équipe
/// porte le lien « Contacter le support » (`/support`) : sur ces états,
/// l'écran n'a ni pied ni entrée de menu qui y mène.
class TripStatusCard extends StatelessWidget {
  const TripStatusCard({
    super.key,
    required this.kind,
    this.canReschedule = false,
  });

  final TripStatusCardKind kind;

  /// Le trajet peut-il encore être reporté (report ouvert et pas verrouillé,
  /// comme l'entrée « Reporter » du menu) ? Ne change que le texte d'un
  /// trajet complet.
  final bool canReschedule;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final supportLink =
        kind == TripStatusCardKind.full ||
        kind == TripStatusCardKind.removedByAdmin;
    return DonyStatusBanner(
      key: Key('trip-status-card-${kind.name}'),
      type: switch (kind) {
        TripStatusCardKind.draft ||
        TripStatusCardKind.full ||
        TripStatusCardKind.cancelled ||
        TripStatusCardKind.removedByAdmin => DonyStatusBannerType.warning,
        TripStatusCardKind.inProgress ||
        TripStatusCardKind.arrived ||
        TripStatusCardKind.completed => DonyStatusBannerType.info,
      },
      iconAsset: switch (kind) {
        TripStatusCardKind.draft => null,
        TripStatusCardKind.full => 'calendar-sync',
        TripStatusCardKind.inProgress => 'plane',
        TripStatusCardKind.arrived => 'flag',
        TripStatusCardKind.completed => 'circle-check',
        TripStatusCardKind.cancelled => 'circle-x',
        TripStatusCardKind.removedByAdmin => 'triangle-alert',
      },
      title: kind == TripStatusCardKind.draft
          ? l.tripOwnerDraftBannerTitle
          : null,
      message: switch (kind) {
        TripStatusCardKind.draft => l.tripOwnerDraftBannerMessage,
        TripStatusCardKind.full =>
          canReschedule
              ? l.tripStatusFullMessage
              : l.tripStatusFullNoRescheduleMessage,
        TripStatusCardKind.inProgress => l.tripStatusInProgressMessage,
        TripStatusCardKind.arrived => l.tripStatusArrivedMessage,
        TripStatusCardKind.completed => l.tripStatusCompletedMessage,
        TripStatusCardKind.cancelled => l.tripStatusCancelledMessage,
        TripStatusCardKind.removedByAdmin => l.tripStatusRemovedMessage,
      },
      action: supportLink
          ? TextButton(
              key: const Key('trip-status-card-support'),
              onPressed: () => unawaited(context.push<void>('/support')),
              child: Text(l.supportContactCta, maxLines: 1, softWrap: false),
            )
          : null,
    );
  }
}
