import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_detail_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_audience_line.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_edit.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_header.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_parcels_line.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_status_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_rows.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Corps de l'écran du trajet vu par son voyageur, en « tableau de bord »
/// (redesign du 31/10), en sections comme le corps de la fiche colis
/// (`TravelerDetailBody`).
///
/// Ordre :
/// 1. tête ([TripOwnerHeader] : billet, ligne surplus, pastilles kilos et
///    prix, jauge des valises) ;
/// 2. carte de statut ([TripStatusCard]) pour un brouillon, un trajet
///    complet, arrivé, annulé ou retiré par l'équipe ; ailleurs le badge du
///    billet suffit ;
/// 3. « À traiter », seulement si quelque chose attend le voyageur : la
///    carte de réponse directe à la première demande ([TripDirectRequestCard],
///    tuile [TripTodoTile.requests]) puis une ligne par autre geste
///    ([TripTodoRows] : « Je pars », « Ajouter la carte ») ;
/// 4. la ligne Colis ([TripParcelsLine] : avatars, « N colis · gain »,
///    résumé, vers le sheet « Colis » qui détaille le gain en tête),
///    toujours sur un trajet publié, complet ou parti, seulement avec des
///    colis sur un trajet terminé ou annulé, jamais sur un brouillon ni un
///    trajet retiré par l'équipe ([tripParcelsLineShown]) ;
/// 5. « Votre trajet » ([tripTilesFor], chaque tuile ouvrant son sheet ; les
///    étapes d'un voyage à plusieurs étapes sont dans celui de l'itinéraire,
///    l'audience du trajet est le sous-titre de la tuile « Affiche »).
///
/// L'audience est chargée ici pour le seul propriétaire confirmé
/// ([TripAudienceLoader], seulement tant que la tuile « Affiche » existe,
/// donc ACTIVE : aucun appel inutile ailleurs), comme le
/// faisait la ligne d'audience retirée du corps.
///
/// Le pied collant et le menu ⋮ sont posés par l'écran, hors du défilement.
///
/// Tant que la propriété n'est pas tranchée ([isOwner] faux : démarrage à
/// froid par un lien, visiteur sur le point d'être renvoyé vers la feuille
/// expéditeur), seuls la tête et la carte de statut s'affichent : rien du
/// voyageur ne fuit (colis, demandes, audience).
///
/// Toutes les sections lisent les mêmes données que les sheets et le pied
/// ([TripTodoLive] : dernier trajet relu, derniers colis chargés, compte de
/// paiement, départ confirmé), plus les demandes que le voyageur vient de
/// traiter ([TripBidAnswerController.answered]) : un rechargement garde
/// l'affichage, une ligne et son sheet ne divergent jamais.
///
/// Chaque section porte une clé (`KeyedSubtree`) : l'apparition ou la
/// disparition d'une section ne remonte pas les autres.
///
/// Les sheets s'ouvrent avec le contexte de ce `State` (stable, sous le
/// [TripBidAnswerScope]), jamais celui d'une carte ou d'une ligne qui
/// disparaît dès que la demande est traitée. Un second appui pendant
/// l'ouverture d'un sheet du corps est ignoré.
///
/// Requiert, au-dessus, un [TripBidAnswerScope] (posé par l'écran) et les
/// blocs de la route du trajet : `AnnouncementBloc`, `BidBloc`,
/// `TripAudienceCubit`, `TripGroupCubit` (facultatif), `StripeAccountBloc`
/// (global) et le `TripDepartCubit` fourni par l'écran.
class TripOwnerBody extends StatefulWidget {
  const TripOwnerBody({
    super.key,
    required this.trip,
    required this.isOwner,
    this.bottomPadding = 0,
  });

  /// Dernier trajet connu de l'écran (détail relu, à défaut l'`extra`).
  final AnnouncementModel trip;
  final bool isOwner;

  /// Marge basse en plus du défilement (zone sûre de l'écran).
  final double bottomPadding;

  @override
  State<TripOwnerBody> createState() => _TripOwnerBodyState();
}

class _TripOwnerBodyState extends State<TripOwnerBody> {
  /// Mesure d'affichage de « À traiter » (carte de réponse directe et
  /// lignes), une fois par tuile et par statut du trajet (et par nombre de
  /// demandes pour `requests`) pour cet écran ([tripTodoShown]).
  final _todoViews = TodoTileViewLog();

  /// Un sheet ouvert depuis le corps n'est pas encore affiché : un second
  /// appui (double tap sur la ligne Colis, une ligne ou « Voir les N demandes »)
  /// n'en ouvre pas un autre par-dessus.
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final Widget column;
    if (!widget.isOwner) {
      column = _column([
        ('header', TripOwnerHeader(a: widget.trip)),
        if (_statusCard(widget.trip, null) case final card?) ('status', card),
      ]);
    } else {
      final answered = TripBidAnswerScope.of(context).answered;
      column = TripTodoLive(
        trip: widget.trip,
        blocs: TripTodoBlocs.of(context),
        builder: (context, live) => TripAudienceLoader(
          announcementId: live.trip.id,
          status: live.trip.status,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: answered,
            builder: (context, ids, _) => _column(_ownerSections(live, ids)),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.md,
        h,
        DonySpacing.lg + widget.bottomPadding,
      ),
      child: DonyLayout.constrained(context, column),
    );
  }

  Widget _column(List<(String, Widget)> sections) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (name, child) in sections)
        KeyedSubtree(
          key: ValueKey(name),
          child: Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: child,
          ),
        ),
    ],
  );

  List<(String, Widget)> _ownerSections(
    TripTodoLiveData live,
    Set<String> answered,
  ) {
    final l = context.l10n;
    final trip = live.trip;
    final bids = live.bids;

    // Carte de réponse directe : la tuile `requests` (trajet où une demande
    // se traite encore) et au moins une demande pas encore traitée depuis
    // l'écran dans la liste chargée. Sans liste, aucune demande à montrer.
    final direct =
        live.tiles.contains(TripTodoTile.requests) &&
        (tripRequestsToAnswer(bids, answered)?.isNotEmpty ?? false);
    final rows = tripTodoRowsFor(live).isNotEmpty;
    final tiles = tripTilesFor(trip: trip, bids: bids, isOwner: true);

    return [
      ('header', TripOwnerHeader(a: trip)),
      if (_statusCard(trip, bids) case final card?) ('status', card),
      if (direct || rows)
        (
          'todo',
          BidDetailSection(
            title: l.bidDetailSectionTodo,
            spacing: DonySpacing.md,
            children: [
              if (direct)
                TripDirectRequestCard(
                  trip: trip,
                  bids: bids,
                  views: _todoViews,
                  onSeeAll: () => _openActivity(
                    live,
                    TripActivity.requests,
                    source: TripActivitySource.card,
                  ),
                ),
              if (rows)
                TripTodoRows(
                  live: live,
                  views: _todoViews,
                  onOpen: (row) => _open(
                    () => openTripTodoSheet(context, trip, row, bids: bids),
                  ),
                ),
            ],
          ),
        ),
      if (tripParcelsLineShown(trip, bids))
        (
          'parcels',
          TripParcelsLine(
            trip: trip,
            bids: bids,
            onOpen: () => _openActivity(live, TripActivity.parcels),
          ),
        ),
      if (tiles.isNotEmpty)
        (
          'tiles',
          BidDetailSection(
            title: l.tripSectionYourTrip,
            spacing: DonySpacing.md,
            children: [
              DonyActionTileGrid(
                tiles: [for (final tile in tiles) _tripTile(live, tile)],
              ),
            ],
          ),
        ),
    ];
  }

  /// Carte de statut de [trip] ([tripStatusCardKindFor]) d'après ses colis
  /// chargés ([bids], `null` tant que la liste n'a pas répondu). Le report
  /// est annoncé possible sur la même règle que l'entrée « Reporter » du menu
  /// : reportable ([tripCanReschedule]) et pas verrouillé
  /// ([tripRescheduleBlockFor]).
  static Widget? _statusCard(AnnouncementModel trip, List<BidModel>? bids) {
    final kind = tripStatusCardKindFor(trip.status, bids: bids);
    if (kind == null) return null;
    return TripStatusCard(
      kind: kind,
      canReschedule:
          tripCanReschedule(trip, tripHasBids(trip, bids)) &&
          tripRescheduleBlockFor(trip, bids) == null,
    );
  }

  /// Ouvre un sheet du corps ([show]), sauf si un autre est déjà en train de
  /// s'ouvrir ou ouvert depuis le corps.
  void _open(Future<void> Function() show) {
    if (_opening) return;
    _opening = true;
    unawaited(show().whenComplete(() => _opening = false));
  }

  /// Sheet [activity], sur les derniers colis connus ; [source] : ligne
  /// Colis, ou lien de la carte de réponse directe.
  void _openActivity(
    TripTodoLiveData live,
    TripActivity activity, {
    TripActivitySource source = TripActivitySource.tile,
  }) => _open(
    () => openTripActivitySheet(
      context,
      live.trip,
      activity,
      bids: live.bids,
      source: source,
    ),
  );

  /// Tuile « Votre trajet » : ouvre la feuille de lecture, avec son bouton
  /// « Modifier » quand le trajet est modifiable. La tuile « Affiche » suit
  /// l'audience chargée (son sous-titre).
  Widget _tripTile(TripTodoLiveData live, TripTile tile) {
    final audience = tile == TripTile.poster
        ? maybeRead<TripAudienceCubit>(context)
        : null;
    if (audience == null) return _tripTileFor(live, tile, null);
    return BlocBuilder<TripAudienceCubit, TripAudienceState>(
      bloc: audience,
      builder: (context, state) => _tripTileFor(live, tile, state),
    );
  }

  Widget _tripTileFor(
    TripTodoLiveData live,
    TripTile tile,
    TripAudienceState? audience,
  ) {
    final l = context.l10n;
    return DonyActionTile(
      key: Key('trip-tile-${tile.name}'),
      iconName: tripTileIcon(tile),
      label: tripTileTitle(l, tile),
      subtitle: tripTileSubtitle(l, tile, live.trip, audience: audience),
      color: Theme.of(context).colorScheme.primary,
      onTap: () => _open(
        () => openTripTileSheet(context, live.trip, tile, bids: live.bids),
      ),
    );
  }
}
