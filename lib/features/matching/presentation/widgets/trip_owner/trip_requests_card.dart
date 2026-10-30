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
/// Toujours affichée pour un trajet publié ou passé ([shownFor] : ACTIVE,
/// FULL, IN_PROGRESS, COMPLETED), jamais grisée, même sans demande
/// (PROD-1N : une entrée éteinte laissait croire à une panne). Un brouillon,
/// un trajet annulé ou retiré par l'équipe n'en a pas.
///
/// Le compte ([tripPendingRequestCount]) : demandes `PENDING` /
/// `PAYMENT_ESCROWED` des colis chargés par l'écran ([bids]), à défaut
/// `pendingBidCount` du modèle tant que la liste n'a pas répondu.
///
/// Un tap ouvre Activité › Demandes « À traiter » de ce trajet, puis relit
/// les colis et le trajet au retour ([openTripRequests]).
class TripRequestsCard extends StatelessWidget {
  const TripRequestsCard({super.key, required this.trip, required this.bids});

  final AnnouncementModel trip;

  /// Colis chargés par l'écran (`BidListLoaded`), `null` tant que la liste
  /// n'a pas répondu.
  final List<BidModel>? bids;

  static const _statuses = {'ACTIVE', 'FULL', 'IN_PROGRESS', 'COMPLETED'};

  /// Statuts où la carte s'affiche. DRAFT (invisible des expéditeurs),
  /// CANCELLED, REMOVED_BY_ADMIN et un statut inconnu de l'app : pas de carte.
  static bool shownFor(String status) => _statuses.contains(status);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = tripPendingRequestCount(trip, bids);
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
                  count > 0
                      ? l.tripRequestsCardPending(count)
                      : l.tripRequestsCardEmpty,
                  key: const Key('trip-requests-card-count'),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  count > 0
                      ? l.tripRequestsCardPendingHint
                      : l.tripRequestsCardEmptyHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
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
