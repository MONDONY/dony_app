import 'dart:async';
import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_gain_content.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_gain.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_parcels_line.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_parcels_search.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sheets de l'activité du trajet vu par son voyageur, ouverts par
/// `openTripActivitySheet`.
///
/// Le nom sert de valeur `tile` à `bid_detail_tile_opened` (`role:
/// trip_owner`) et au nom du sheet (`trip-owner/activity-` suivi du nom) : ne
/// pas le renommer sans migrer PostHog.
enum TripActivity {
  /// Demandes à traiter : le sheet les liste, avec Refuser et Accepter.
  /// Ouvert par le lien « Voir les N demandes » de la carte de réponse
  /// directe.
  requests,

  /// Colis embarqués : le gain estimé en tête, puis tous les colis,
  /// filtrables par statut. Ouvert par la ligne Colis du corps
  /// (`TripParcelsLine`).
  parcels,
}

/// D'où s'ouvre un sheet de l'activité du trajet : valeur `source` de
/// `bid_detail_tile_opened`. Ne pas renommer sans migrer PostHog.
enum TripActivitySource {
  /// Ligne Colis du corps (`TripParcelsLine`).
  tile,

  /// Lien « Voir les N demandes » de la carte de réponse directe
  /// (`TripDirectRequestCard`), qui ouvre le sheet des demandes.
  card,
}

/// Ouvre le bottom sheet [activity] du trajet [trip] (écran du trajet, vue
/// du voyageur propriétaire) et compte l'ouverture (`bid_detail_tile_opened`,
/// `role: trip_owner`, `source` : [source], `tile` pour la ligne Colis,
/// `card` pour le lien de la carte de réponse directe). Nom du sheet :
/// `trip-owner/activity-` suivi du nom de [activity].
///
/// Comme les sheets « À traiter » (`openTripTodoSheet`) : le sheet s'ouvre
/// sur le navigateur racine, les blocs de l'écran trouvés sous [context]
/// (trajet, colis, compte de paiement, `TripDepartCubit`) y sont reposés par
/// le `wrapper`, avec le [TripBidAnswerScope] de l'écran
/// (exigé pour [TripActivity.requests]). Contenu et titre suivent les mêmes
/// données que l'écran ([TripTodoLive] ; [bids] : derniers colis connus de
/// l'écran, repris pendant un rechargement), et les demandes traitées depuis
/// l'écran. Le sheet se ferme seul quand il n'a plus lieu d'être
/// ([tripActivityShown] : plus de demandes sur le trajet, ligne Colis
/// disparue), jamais par-dessus une confirmation.
///
/// - [TripActivity.requests] : une ligne par demande à traiter, avec Refuser
///   et Accepter (même réponse que la carte directe) ; la ligne ouvre la
///   fiche du colis ;
/// - [TripActivity.parcels] : en tête, le gain estimé des colis récupérés
///   (en ligne, en espèces, total, [tripGainOf]) quand il est positif ; puis
///   tous les colis embarqués, résumé, champ de recherche (expéditeur,
///   destinataire, numéro de suivi visible, [tripParcelMatches]), puces de
///   filtre par statut dès deux statuts, une ligne par colis vers sa fiche,
///   et « Ouvrir la liste des colis » dans le pied ; `trip_parcels_viewed`
///   part à l'ouverture.
///
/// Les actions qui mènent à un autre écran ferment d'abord le sheet, puis
/// poussent la route depuis [context] (l'écran, contexte stable) et relisent
/// ses colis et le trajet au retour ([openTripParcel],
/// [openTripParcelsList]).
Future<void> openTripActivitySheet(
  BuildContext context,
  AnnouncementModel trip,
  TripActivity activity, {
  List<BidModel>? bids,
  TripActivitySource source = TripActivitySource.tile,
}) {
  final blocs = TripTodoBlocs.of(context);
  final answer = TripBidAnswerScope.maybeOf(context);
  assert(
    activity != TripActivity.requests || answer != null,
    'TripBidAnswerScope missing above context',
  );
  logBidDetailTileOpened(
    tile: activity.name,
    role: 'trip_owner',
    source: source.name,
  );

  Widget follow(Widget Function(BuildContext, TripTodoLiveData) builder) =>
      TripTodoLive(
        trip: trip,
        blocs: blocs,
        initialBids: bids,
        builder: builder,
      );

  /// Ferme le sheet avant d'agir depuis l'écran. Faux quand il n'est plus
  /// au premier plan (second appui, confirmation par-dessus) ou que l'écran
  /// n'est plus monté.
  bool closeForAction(BuildContext sheetContext) =>
      closeSheetIfOnTop(sheetContext) && context.mounted;

  void openParcel(BuildContext sheetContext, String bidId) {
    if (!closeForAction(sheetContext)) return;
    unawaited(openTripParcel(context, tripId: trip.id, bidId: bidId));
  }

  return DonyBottomSheet.show<void>(
    context,
    titleWidget: follow(
      (sheetContext, live) =>
          Text(_activitySheetTitle(sheetContext.l10n, activity)),
    ),
    analyticsName: 'trip-owner/activity-${activity.name}',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
        // Suivi par `TripTodoLive` dès que l'écran le fournit : sans lui
        // sous le navigateur racine, le contenu ne se construirait pas.
        if (blocs.depart case final b?)
          BlocProvider<TripDepartCubit>.value(value: b),
      ];
      final provided = providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
      return answer == null
          ? provided
          : TripBidAnswerScope.provide(answer, provided);
    },
    stickyBottom: activity == TripActivity.parcels
        ? Builder(
            builder: (sheetContext) => DonyButton(
              key: const Key('trip-activity-parcels-open-list'),
              label: sheetContext.l10n.tripActivityParcelsOpenList,
              onPressed: () {
                if (!closeForAction(sheetContext)) return;
                unawaited(openTripParcelsList(context, trip.id));
              },
            ),
          )
        : null,
    child: follow(
      (sheetContext, live) => _FollowAnswered(
        answer: answer,
        builder: (sheetContext, answered) => CloseTripSheetWhenGone(
          gone: !tripActivityShown(activity, live, answered),
          child: KeyedSubtree(
            key: Key('trip-activity-${activity.name}-content'),
            child: switch (activity) {
              TripActivity.requests => _RequestsContent(
                live: live,
                answered: answered,
                onOpenParcel: (id) => openParcel(sheetContext, id),
              ),
              TripActivity.parcels => _ParcelsContent(
                tripId: live.trip.id,
                // Mêmes colis embarqués que la ligne Colis du corps.
                bids: tripBidsAfterAnswers(live.bids, answered),
                gain: tripGainOf(live.trip, live.bids),
                onOpenParcel: (id) => openParcel(sheetContext, id),
              ),
            },
          ),
        ),
      ),
    ),
  );
}

String _activitySheetTitle(AppLocalizations l, TripActivity activity) =>
    switch (activity) {
      TripActivity.requests => l.tripTodoRequestsTitle,
      TripActivity.parcels => l.tripOwnerParcelsSectionTitle,
    };

/// Le sheet [activity] a-t-il encore lieu d'être sur les données [live] ?
/// Fonction pure, rappelée à chaque relecture : faux, le sheet se ferme seul.
///
/// - [TripActivity.requests] : les demandes ont leur place sur le trajet
///   ([tripRequestsShown], après les demandes traitées depuis l'écran,
///   [answered]) : toujours pour un trajet publié ou complet, pour un trajet
///   parti seulement s'il en reste ;
/// - [TripActivity.parcels] : la ligne Colis du corps s'affiche
///   ([tripParcelsLineShown]).
bool tripActivityShown(
  TripActivity activity,
  TripTodoLiveData live,
  Set<String> answered,
) => switch (activity) {
  TripActivity.requests => tripRequestsShown(
    live.trip,
    tripBidsAfterAnswers(live.bids, answered),
  ),
  TripActivity.parcels => tripParcelsLineShown(live.trip, live.bids),
};

/// Suit les demandes traitées depuis l'écran quand le scope de réponse est
/// là, sinon aucune.
class _FollowAnswered extends StatelessWidget {
  const _FollowAnswered({required this.answer, required this.builder});

  final TripBidAnswerController? answer;
  final Widget Function(BuildContext context, Set<String> answered) builder;

  @override
  Widget build(BuildContext context) {
    final answered = answer?.answered;
    if (answered == null) return builder(context, const {});
    return ValueListenableBuilder<Set<String>>(
      valueListenable: answered,
      builder: (context, ids, _) => builder(context, ids),
    );
  }
}

/// Demandes à traiter, une par ligne : qui, quoi, combien, puis Refuser et
/// Accepter. Vide : une phrase. Liste pas encore chargée : le nombre servi
/// par la liste des trajets s'il en annonce, sinon un indicateur ; liste en
/// échec ([_BidsNotLoaded]) : « Réessayer ».
class _RequestsContent extends StatelessWidget {
  const _RequestsContent({
    required this.live,
    required this.answered,
    required this.onOpenParcel,
  });

  final TripTodoLiveData live;
  final Set<String> answered;
  final ValueChanged<String> onOpenParcel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pending = tripRequestsToAnswer(live.bids, answered);
    final Widget body;
    if (pending == null) {
      body = _BidsNotLoaded(
        tripId: live.trip.id,
        errorKey: const Key('trip-activity-requests-load-error'),
        loading: live.trip.pendingBidCount > 0
            ? Text(
                l.tripTodoRequestsSummary(live.trip.pendingBidCount),
                style: tt.bodyMedium,
              )
            : Padding(
                padding: const EdgeInsets.all(DonySpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(color: cs.primary),
                ),
              ),
      );
    } else if (pending.isEmpty) {
      body = Text(
        l.tripActivityRequestsEmpty,
        key: const Key('trip-activity-requests-empty'),
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, bid) in pending.indexed) ...[
            if (i > 0) Divider(height: DonySpacing.xl, color: cs.outline),
            InkWell(
              key: Key('trip-activity-request-${bid.id}'),
              onTap: () => onOpenParcel(bid.id),
              borderRadius: BorderRadius.circular(DonyRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
                child: TripRequestIdentity(bid: bid),
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            TripRequestAnswerButtons(bid: bid),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: body,
    );
  }
}

/// Contenu du sheet « Colis » : le gain estimé en tête ([gain], seulement
/// s'il est positif : en ligne, en espèces, total, [TripGainContent]), puis
/// tous les colis embarqués du trajet : résumé (sur tous, jamais sur le
/// filtre ni la recherche, FLUTTER-GS), champ de recherche dès un colis
/// (filtrage local, [tripParcelsMatching] ; « N colis trouvés » ; aucun
/// résultat : une phrase et « Effacer la recherche »), puces de filtre par
/// statut dès deux statuts parmi les colis trouvés, une ligne par colis.
/// Mesure l'ouverture une fois la liste connue (`trip_parcels_viewed`, total
/// des colis embarqués), chaque filtre choisi (`trip_parcels_filtered`) et
/// chaque recherche après une pause de saisie (`trip_parcels_searched`).
///
/// Liste jamais reçue : un indicateur, ou « Réessayer » si son chargement
/// est en échec ([_BidsNotLoaded]). Après une liste déjà reçue, un échec de
/// relecture garde cette liste.
class _ParcelsContent extends StatefulWidget {
  const _ParcelsContent({
    required this.tripId,
    required this.bids,
    required this.gain,
    required this.onOpenParcel,
  });

  final String tripId;
  final List<BidModel>? bids;

  /// Gain estimé des colis récupérés ([tripGainOf]), même calcul que le
  /// titre de la ligne Colis.
  final TripGain gain;
  final ValueChanged<String> onOpenParcel;

  @override
  State<_ParcelsContent> createState() => _ParcelsContentState();
}

class _ParcelsContentState extends State<_ParcelsContent> {
  /// Statut filtré, `null` pour « Tous ». Seul le contenu se reconstruit.
  final _filter = ValueNotifier<String?>(null);

  /// Texte de la recherche. Vit ici, jamais dans le `whenComplete` du
  /// sheet : il survit aux relectures des colis et repart à vide à la
  /// prochaine ouverture.
  final _search = TextEditingController();

  /// Dernier texte vu par [_onSearchChanged] : un simple déplacement du
  /// curseur ne relance pas la mesure.
  String _searchText = '';

  /// Mesure de la recherche en attente d'une pause de saisie.
  Timer? _searchLog;

  /// Dernier terme mesuré (`trip_parcels_searched`), oublié quand le champ
  /// est vidé : un même terme n'est mesuré qu'une fois de suite.
  String? _searchLogged;

  /// `trip_parcels_viewed` ne part qu'une fois par ouverture du sheet, même
  /// si la liste est relue pendant qu'il est ouvert.
  bool _viewed = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchLog?.cancel();
    _search.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _search.text;
    if (text == _searchText) return;
    _searchText = text;
    _searchLog?.cancel();
    final key = tripParcelsSearchKey(text);
    if (key.isEmpty) {
      _searchLogged = null;
      return;
    }
    _searchLog = Timer(kTripParcelsSearchLogDelay, () => _logSearch(key));
  }

  /// `trip_parcels_searched` après une pause de saisie : nombre de colis
  /// trouvés et total, jamais le texte, un nom ni un numéro.
  void _logSearch(String key) {
    if (!mounted || key == _searchLogged) return;
    final embarked = tripEmbarkedParcels(widget.bids);
    if (embarked == null) return;
    _searchLogged = key;
    final matches = tripParcelsMatching(context.l10n, embarked, key).length;
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.tripParcelsSearched,
        properties: {'matches': matches, 'total': embarked.length},
      ),
    );
  }

  void _logViewed(int count) {
    if (_viewed) return;
    _viewed = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(
        getItSafe<AnalyticsService>()?.logEvent(
          AnalyticsEvents.tripParcelsViewed,
          properties: {'count': count},
        ),
      ),
    );
  }

  void _onFilter(String? status) {
    if (_filter.value == status) return;
    _filter.value = status;
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.tripParcelsFiltered,
        properties: {'status': status ?? 'all'},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gain = widget.gain;
    // Même arbre avec ou sans gain : un gain qui apparaît à une relecture ne
    // recrée pas le champ de recherche (saisie et clavier gardés).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gain.hasGain) _GainBlock(gain: gain),
        KeyedSubtree(
          key: const ValueKey('trip-activity-parcels-list'),
          child: _parcels(context),
        ),
      ],
    );
  }

  Widget _parcels(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final bids = widget.bids;
    if (bids == null) {
      return _BidsNotLoaded(
        tripId: widget.tripId,
        errorKey: const Key('trip-activity-parcels-load-error'),
        loading: Padding(
          padding: const EdgeInsets.all(DonySpacing.lg),
          child: Center(child: CircularProgressIndicator(color: cs.primary)),
        ),
      );
    }
    final embarked = tripEmbarkedParcels(bids)!;
    _logViewed(embarked.length);
    if (embarked.isEmpty) {
      return DonyEmptyState(
        key: const Key('trip-activity-parcels-empty'),
        iconAsset: 'inbox',
        title: l.tripOwnerNoParcelsMessage,
        description: l.tripOwnerParcelsEmptyDescription,
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
      );
    }
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_search, _filter]),
      builder: (context, _) {
        final query = _search.text.trim();
        final searching = tripParcelsSearchKey(query).isNotEmpty;
        // Recherche ET statut : les puces comptent les colis trouvés ; le
        // résumé, lui, compte toujours tous les colis (FLUTTER-GS).
        final matched = tripParcelsMatching(l, embarked, query);
        final counts = <String, int>{};
        for (final b in matched) {
          counts[b.status] = (counts[b.status] ?? 0) + 1;
        }
        final present = [
          for (final s in kTripParcelStatusOrder)
            if (counts.containsKey(s)) s,
          for (final s in counts.keys)
            if (!kTripParcelStatusOrder.contains(s)) s,
        ];
        // Filtre dont le statut a disparu (liste relue, recherche) : retour
        // à « Tous ».
        final filter = _filter.value;
        final active = filter != null && counts.containsKey(filter)
            ? filter
            : null;
        final visible = active == null
            ? matched
            : matched.where((b) => b.status == active).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripParcelsSummary(bids: embarked),
              DonySearchField(
                key: const Key('trip-activity-parcels-search'),
                controller: _search,
                hint: l.tripParcelsSearchHint,
              ),
              // Pendant une recherche, la zone sous le champ (compteur,
              // résultats) garde la plus grande hauteur atteinte : la feuille
              // ne rapetisse pas sous le doigt à chaque lettre, le champ ne
              // bouge pas.
              _KeepHeight(
                hold: searching,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (searching && matched.isNotEmpty) ...[
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        l.tripParcelsSearchResults(matched.length),
                        key: const Key('trip-activity-parcels-search-count'),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    const SizedBox(height: DonySpacing.md),
                    if (matched.isEmpty)
                      _SearchEmpty(query: query, onClear: _search.clear)
                    else ...[
                      if (present.length >= 2) ...[
                        StatusChipsRow<String?>(
                          selected: active,
                          onSelected: _onFilter,
                          chips: [
                            StatusChipData<String?>(
                              label: l.tripOwnerParcelsFilterAll,
                              value: null,
                              count: matched.length,
                            ),
                            for (final s in present)
                              () {
                                final (label, color) = tripParcelStatusMeta(
                                  s,
                                  cs,
                                  l,
                                );
                                return StatusChipData<String?>(
                                  label: label,
                                  value: s,
                                  count: counts[s],
                                  dotColor: color,
                                );
                              }(),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.md),
                      ],
                      for (final (i, bid) in visible.indexed) ...[
                        if (i > 0) const SizedBox(height: DonySpacing.sm),
                        TripParcelRow(
                          key: Key('trip-activity-parcel-${bid.id}'),
                          bid: bid,
                          onTap: () => widget.onOpenParcel(bid.id),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Aucun colis ne répond à la recherche [query] : une phrase qui la cite et
/// le lien « Effacer la recherche » ([onClear]). Lien texte, pas de
/// `DonyButton` : le seul bouton du sheet reste celui du pied.
class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      key: const Key('trip-activity-parcels-search-empty'),
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
      child: Column(
        children: [
          DonyIcon('search-x', size: 32, color: cs.onSurfaceVariant),
          const SizedBox(height: DonySpacing.md),
          Text(
            l.tripParcelsSearchEmpty(query),
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xs),
          TextButton(
            key: const Key('trip-activity-parcels-search-clear'),
            onPressed: onClear,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(
              l.tripParcelsSearchClear,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste des colis du trajet jamais reçue par l'écran ([TripTodoLive]) :
/// [loading] tant qu'elle peut encore arriver ; chargement en échec
/// (`BidError` du `BidBloc` de l'écran : hors ligne au premier chargement) :
/// « Erreur de chargement » et « Réessayer », qui la redemande en
/// rechargement visible. Sans quoi le sheet tournerait sans fin et plus
/// aucun chemin ne mènerait aux demandes ni aux colis du trajet (l'écran
/// n'a pas de « tirer pour rafraîchir »).
class _BidsNotLoaded extends StatelessWidget {
  const _BidsNotLoaded({
    required this.tripId,
    required this.errorKey,
    required this.loading,
  });

  final String tripId;
  final Key errorKey;
  final Widget loading;

  @override
  Widget build(BuildContext context) {
    final bloc = maybeRead<BidBloc>(context);
    if (bloc == null) return loading;
    final l = context.l10n;
    return BlocBuilder<BidBloc, BidState>(
      bloc: bloc,
      builder: (context, state) => state is BidError
          ? DonyEmptyState(
              key: errorKey,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: l.commonLoadError,
              actionLabel: l.commonRetry,
              onAction: () => bloc.add(BidListRequested(tripId)),
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
            )
          : loading,
    );
  }
}

/// Bloc « Gain estimé » en tête du sheet « Colis » : son titre, le détail
/// ([TripGainContent] : en ligne, en espèces, total, seulement les lignes
/// positives), puis un séparateur avant les colis. Monté seulement quand le
/// gain est positif.
class _GainBlock extends StatelessWidget {
  const _GainBlock({required this.gain});

  final TripGain gain;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      key: const Key('trip-activity-parcels-gain'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.tripSummaryEarningsLabel,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        TripGainContent(gain: gain),
        const SizedBox(height: DonySpacing.base),
        Divider(height: 1, color: cs.outline),
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

/// Garde à [child] la plus grande hauteur atteinte tant que [hold] est vrai
/// (recherche en cours dans le sheet « Colis ») : la feuille, qui épouse son
/// contenu et reste collée au bas de l'écran, ne rapetisse pas à chaque
/// lettre. [hold] faux : la hauteur du contenu, de nouveau mémorisée.
class _KeepHeight extends SingleChildRenderObjectWidget {
  const _KeepHeight({required this.hold, required super.child});

  final bool hold;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderKeepHeight(hold);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderKeepHeight renderObject,
  ) {
    renderObject.hold = hold;
  }
}

class _RenderKeepHeight extends RenderProxyBox {
  _RenderKeepHeight(this._hold);

  bool _hold;
  double _kept = 0;

  set hold(bool value) {
    if (value == _hold) return;
    _hold = value;
    markNeedsLayout();
  }

  double _height(double child) => _hold ? math.max(child, _kept) : child;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final s = child?.getDryLayout(constraints) ?? constraints.smallest;
    return constraints.constrain(Size(s.width, _height(s.height)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    _kept = _height(c.size.height);
    size = constraints.constrain(Size(c.size.width, _kept));
  }
}
