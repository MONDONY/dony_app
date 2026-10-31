import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Compteurs « Activité du trajet » de l'écran du trajet vu par son
/// voyageur, chacun ouvrant son bottom sheet (`openTripActivitySheet`).
///
/// Le nom sert de valeur `tile` à `bid_detail_tile_opened` (`role:
/// trip_owner`) et au nom du sheet (`trip-owner/activity-` suivi du nom) : ne pas
/// le renommer sans migrer PostHog.
enum TripActivity {
  /// Demandes à traiter : le sheet les liste, avec Refuser et Accepter.
  requests,

  /// Colis embarqués : le sheet les liste tous, filtrables par statut.
  parcels,

  /// Gain estimé du trajet : le sheet en donne le détail.
  gain,
}

/// Valeur d'un compteur quand elle n'est pas connue (liste des colis pas
/// encore chargée, aucun gain) : un trait, jamais un zéro qui affirmerait
/// « rien ».
const kTripActivityUnknown = '-';

/// Une case « Activité du trajet » : son gros chiffre [value], son libellé
/// [label] et la pastille [dot] (quelque chose attend le voyageur).
typedef TripActivityCell = ({
  TripActivity activity,
  String value,
  String label,
  bool dot,
});

/// Statuts sans compteur du tout : un brouillon (pas encore visible des
/// expéditeurs), un trajet retiré par l'équipe (le back refuse de retirer un
/// trajet qui a des colis en vol).
const _noActivityStatuses = {'DRAFT', 'REMOVED_BY_ADMIN'};

/// Cases « Activité du trajet » de [trip], dans l'ordre de la ligne.
/// Fonction pure : l'écran la rappelle à chaque rechargement, et un sheet
/// ouvert s'en sert pour se fermer quand sa case disparaît.
///
/// - [bids] : colis chargés par l'écran (`BidListLoaded`), `null` tant que
///   la liste n'a pas répondu ;
/// - [answered] : demandes traitées depuis l'écran
///   ([TripBidAnswerController.answered]) : celles que la liste montre
///   encore en attente sont ôtées ([tripBidsAfterAnswers]).
///
/// Règles :
/// - aucune case pour DRAFT et REMOVED_BY_ADMIN ;
/// - Demandes : nombre de demandes à traiter ([tripPendingRequestCount],
///   repli `pendingBidCount` sans liste), pastille dès qu'il y en a une ;
///   statuts de [tripRequestsShown] (absente d'un trajet terminé, annulé,
///   d'un trajet parti sans demande, d'un statut inconnu) ;
/// - Colis : total des colis embarqués ([tripEmbarkedParcels], même source
///   que le sheet « Colis »), libellé « N en route » (remis ou en transit),
///   sinon « N à récupérer » (acceptés pas encore remis), sinon « colis ».
///   Sur un trajet annulé, seulement s'il a des colis (embarqués dans la
///   liste, ou comptés par le détail : `confirmedParcelCount`,
///   `parcelsSummary`) : ses colis remis suivent la procédure de retour, la
///   case reste leur chemin ;
/// - Gain : gain estimé net servi par le détail (`parcelsSummary`) quand il
///   est positif, sinon [kTripActivityUnknown]. Sur un trajet annulé,
///   seulement si des colis ont été remis (`parcelsSummary.count > 0`).
List<TripActivityCell> tripActivityFor({
  required AnnouncementModel trip,
  required List<BidModel>? bids,
  required AppLocalizations l,
  Set<String> answered = const {},
}) {
  if (_noActivityStatuses.contains(trip.status)) return const [];
  final visible = tripBidsAfterAnswers(bids, answered);
  final pending = tripPendingRequestCount(trip, visible);
  final pendingKnown = tripPendingRequestCountKnown(trip, visible);
  final embarked = tripEmbarkedParcels(visible);
  final counts = embarked == null ? null : tripParcelsCounts(embarked);
  final summary = trip.parcelsSummary;
  final handedOver = (summary?.count ?? 0) > 0;
  final cancelled = trip.status == 'CANCELLED';
  final parcelsShown =
      !cancelled ||
      (embarked?.isNotEmpty ?? false) ||
      trip.confirmedParcelCount > 0 ||
      handedOver;
  return [
    if (tripRequestsShown(trip, visible))
      (
        activity: TripActivity.requests,
        value: pendingKnown ? '$pending' : kTripActivityUnknown,
        label: pending > 0
            ? l.tripActivityRequestsPending
            : l.tripActivityRequestsNone,
        dot: pending > 0,
      ),
    if (parcelsShown)
      (
        activity: TripActivity.parcels,
        value: embarked == null ? kTripActivityUnknown : '${embarked.length}',
        label: counts != null && counts.inTransit > 0
            ? l.tripActivityParcelsInTransit(counts.inTransit)
            : counts != null && counts.toCollect > 0
            ? l.tripActivityParcelsToCollect(counts.toCollect)
            : l.tripActivityParcelsLabel(embarked?.length ?? 0),
        dot: false,
      ),
    if (!cancelled || handedOver)
      (
        activity: TripActivity.gain,
        value: summary != null && summary.netAmount > 0
            ? CurrencyFormatter.format(
                summary.netAmount,
                SupportedCurrency.fromCodeOrDefault(summary.currency),
              )
            : kTripActivityUnknown,
        label: l.tripActivityGainLabel,
        dot: false,
      ),
  ];
}

/// Titre lu par le lecteur d'écran avant la valeur d'une case.
String _activityTitle(AppLocalizations l, TripActivity activity) =>
    switch (activity) {
      TripActivity.requests => l.tripOwnerRequestsTile,
      TripActivity.parcels => l.tripOwnerParcelsTile,
      TripActivity.gain => l.tripSummaryEarningsLabel,
    };

/// Ligne « Activité du trajet » : trois cases côte à côte au plus
/// ([tripActivityFor]), gros chiffre et libellé, pastille sur Demandes quand
/// des demandes attendent. Un tap appelle [onOpen], qui ouvre le sheet de la
/// case (`openTripActivitySheet`) avec le contexte du corps.
///
/// Suit les demandes traitées depuis l'écran quand un [TripBidAnswerScope]
/// est au-dessus. Ne rend rien sans case.
class TripActivityRow extends StatelessWidget {
  const TripActivityRow({
    super.key,
    required this.trip,
    required this.bids,
    required this.onOpen,
  });

  final AnnouncementModel trip;

  /// Colis chargés par l'écran, `null` tant que la liste n'a pas répondu.
  final List<BidModel>? bids;
  final ValueChanged<TripActivity> onOpen;

  @override
  Widget build(BuildContext context) {
    final answered = TripBidAnswerScope.maybeOf(context)?.answered;
    if (answered == null) return _row(context, const {});
    return ValueListenableBuilder<Set<String>>(
      valueListenable: answered,
      builder: (context, ids, _) => _row(context, ids),
    );
  }

  Widget _row(BuildContext context, Set<String> answered) {
    final cells = tripActivityFor(
      trip: trip,
      bids: bids,
      l: context.l10n,
      answered: answered,
    );
    if (cells.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        key: const Key('trip-activity-row'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0) const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _ActivityCell(
                cell: cell,
                onTap: () => onOpen(cell.activity),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCell extends StatelessWidget {
  const _ActivityCell({required this.cell, required this.onTap});

  final TripActivityCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    final known = cell.value != kTripActivityUnknown;
    return Semantics(
      button: true,
      label: l.tripActivityCellSemantics(
        _activityTitle(l, cell.activity),
        known ? '${cell.value} ${cell.label}' : cell.label,
      ),
      excludeSemantics: true,
      child: Material(
        color: cs.surface,
        borderRadius: radius,
        child: InkWell(
          key: Key('trip-activity-${cell.activity.name}'),
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: cs.outline),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Montant sur une ligne : il rétrécit plutôt que de
                    // passer à la ligne, comme la carte de gain.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        cell.value,
                        key: Key('trip-activity-${cell.activity.name}-value'),
                        maxLines: 1,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cell.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                if (cell.dot)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      key: Key('trip-activity-${cell.activity.name}-dot'),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: cs.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
