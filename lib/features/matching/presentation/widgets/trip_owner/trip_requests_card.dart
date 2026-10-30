import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte « Demandes » du corps de l'écran du trajet (vue du voyageur) :
/// combien de demandes attendent sa réponse, et l'accès à leur liste.
///
/// Où elle s'affiche ([shownFor], phase de [tripRequestsPhaseFor]) : toujours
/// pour un trajet publié ou complet, jamais grisée, même sans demande
/// (PROD-1N : une entrée éteinte laissait croire à une panne). Pour un trajet
/// parti, seulement s'il reste des demandes à traiter : le back les expire au
/// départ et refuse tout nouveau colis, la carte n'aurait rien à promettre.
/// Jamais pour un trajet terminé : le back y refuse toute acceptation, une
/// demande restée en attente ne se traite plus (la tuile « À traiter » est
/// absente pour la même raison). Un brouillon, un trajet annulé ou retiré
/// par l'équipe n'en a pas non plus.
///
/// Le compte ([tripPendingRequestCount]) : demandes `PENDING` /
/// `PAYMENT_ESCROWED` des colis chargés par l'écran ([bids]), à défaut
/// `pendingBidCount` du modèle tant que la liste n'a pas répondu. Compte
/// inconnu ([tripPendingRequestCountKnown] faux) : une ligne neutre, jamais
/// « Aucune demande à traiter ».
///
/// La sous-ligne dépend du statut : ACTIVE, ce qui arrive ensuite ; parti,
/// plus de nouvelle demande. Un trajet complet n'en a pas : sa carte de
/// statut le dit déjà juste au-dessus.
///
/// Un tap ouvre Activité › Demandes « À traiter » de ce trajet, puis relit
/// les colis et le trajet au retour ([openTripRequests]).
class TripRequestsCard extends StatelessWidget {
  const TripRequestsCard({super.key, required this.trip, required this.bids});

  final AnnouncementModel trip;

  /// Colis chargés par l'écran (`BidListLoaded`), `null` tant que la liste
  /// n'a pas répondu.
  final List<BidModel>? bids;

  /// La carte s'affiche-t-elle pour [trip] et ses colis [bids] ?
  static bool shownFor(AnnouncementModel trip, List<BidModel>? bids) =>
      switch (tripRequestsPhaseFor(trip.status)) {
        TripRequestsPhase.open || TripRequestsPhase.full => true,
        TripRequestsPhase.departed => tripPendingRequestCount(trip, bids) > 0,
        TripRequestsPhase.ended || null => false,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = tripPendingRequestCount(trip, bids);
    final known = tripPendingRequestCountKnown(trip, bids);
    final title = !known
        ? l.tripRequestsCardUnknown
        : count > 0
        ? l.tripRequestsCardPending(count)
        : l.tripRequestsCardEmpty;
    final hint = switch (tripRequestsPhaseFor(trip.status)) {
      TripRequestsPhase.open when !known => null,
      TripRequestsPhase.open =>
        count > 0 ? l.tripRequestsCardPendingHint : l.tripRequestsCardEmptyHint,
      TripRequestsPhase.departed => l.tripRequestsCardDepartedHint,
      TripRequestsPhase.full || TripRequestsPhase.ended || null => null,
    };
    return DetailCard(
      key: const Key('trip-requests-card'),
      title: l.tripOwnerRequestsTile,
      onTap: () => unawaited(openTripRequests(context, trip.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('trip-requests-card-count'),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    hint,
                    key: const Key('trip-requests-card-hint'),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          ExcludeSemantics(
            child: Icon(DonyIcons.chevron, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
