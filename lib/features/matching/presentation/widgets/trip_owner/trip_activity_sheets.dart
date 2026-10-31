import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
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
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_row.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// D'où s'ouvre un sheet « Activité du trajet » : valeur `source` de
/// `bid_detail_tile_opened`. Ne pas renommer sans migrer PostHog.
enum TripActivitySource {
  /// Case des compteurs (`TripActivityRow`).
  tile,

  /// Lien « Voir les N demandes » de la carte de réponse directe
  /// (`TripDirectRequestCard`), qui ouvre le sheet des demandes.
  card,
}

/// Ouvre le bottom sheet de la case « Activité du trajet » [activity] du
/// trajet [trip] (écran du trajet, vue du voyageur propriétaire) et compte
/// l'ouverture (`bid_detail_tile_opened`, `role: trip_owner`, `source` :
/// [source], `tile` pour une case, `card` pour le lien de la carte de
/// réponse directe). Nom du sheet : `trip-owner/activity-` suivi du nom de
/// [activity].
///
/// Comme les sheets « À traiter » (`openTripTodoSheet`) : le sheet s'ouvre
/// sur le navigateur racine, les blocs de l'écran trouvés sous [context]
/// (trajet, colis, compte de paiement, `TripDepartCubit`) y sont reposés par
/// le `wrapper`, avec le [TripBidAnswerScope] de l'écran
/// (exigé pour [TripActivity.requests]). Contenu et titre suivent les mêmes
/// données que l'écran ([TripTodoLive] ; [bids] : derniers colis connus de
/// l'écran, repris pendant un rechargement), et les demandes traitées depuis
/// l'écran. Le sheet se ferme seul quand sa case disparaît
/// ([tripActivityFor]), jamais par-dessus une confirmation.
///
/// - [TripActivity.requests] : une ligne par demande à traiter, avec Refuser
///   et Accepter (même réponse que la carte directe) ; la ligne ouvre la
///   fiche du colis ;
/// - [TripActivity.parcels] : tous les colis embarqués, résumé, puces de
///   filtre par statut dès deux statuts, une ligne par colis vers sa fiche,
///   et « Ouvrir la liste des colis » dans le pied ; `trip_parcels_viewed`
///   part à l'ouverture ;
/// - [TripActivity.gain] : le détail du gain, en lecture seule.
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
          Text(_activitySheetTitle(sheetContext.l10n, activity, live.trip)),
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
          gone: !tripActivityFor(
            trip: live.trip,
            bids: live.bids,
            l: sheetContext.l10n,
            answered: answered,
          ).any((cell) => cell.activity == activity),
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
                // Même source que la case Colis ([tripActivityFor]).
                bids: tripBidsAfterAnswers(live.bids, answered),
                onOpenParcel: (id) => openParcel(sheetContext, id),
              ),
              TripActivity.gain => _GainContent(trip: live.trip),
            },
          ),
        ),
      ),
    ),
  );
}

String _activitySheetTitle(
  AppLocalizations l,
  TripActivity activity,
  AnnouncementModel trip,
) => switch (activity) {
  TripActivity.requests => l.tripTodoRequestsTitle,
  TripActivity.parcels => l.tripOwnerParcelsSectionTitle,
  TripActivity.gain =>
    (trip.parcelsSummary?.netAmount ?? 0) > 0 || trip.parcelsSummary == null
        ? l.tripSummaryEarningsLabel
        : l.tripSummaryTitle,
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

/// Tous les colis embarqués du trajet : résumé (sur tous, jamais sur le
/// filtre, FLUTTER-GS), puces de filtre par statut dès deux statuts, une
/// ligne par colis. Mesure l'ouverture une fois la liste connue
/// (`trip_parcels_viewed`, total des colis embarqués) et chaque filtre
/// choisi (`trip_parcels_filtered`).
///
/// Liste jamais reçue : un indicateur, ou « Réessayer » si son chargement
/// est en échec ([_BidsNotLoaded]). Après une liste déjà reçue, un échec de
/// relecture garde cette liste.
class _ParcelsContent extends StatefulWidget {
  const _ParcelsContent({
    required this.tripId,
    required this.bids,
    required this.onOpenParcel,
  });

  final String tripId;
  final List<BidModel>? bids;
  final ValueChanged<String> onOpenParcel;

  @override
  State<_ParcelsContent> createState() => _ParcelsContentState();
}

class _ParcelsContentState extends State<_ParcelsContent> {
  /// Statut filtré, `null` pour « Tous ». Seul le contenu se reconstruit.
  final _filter = ValueNotifier<String?>(null);

  /// `trip_parcels_viewed` ne part qu'une fois par ouverture du sheet, même
  /// si la liste est relue pendant qu'il est ouvert.
  bool _viewed = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
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
    final counts = <String, int>{};
    for (final b in embarked) {
      counts[b.status] = (counts[b.status] ?? 0) + 1;
    }
    final present = [
      for (final s in kTripParcelStatusOrder)
        if (counts.containsKey(s)) s,
      for (final s in counts.keys)
        if (!kTripParcelStatusOrder.contains(s)) s,
    ];
    return ValueListenableBuilder<String?>(
      valueListenable: _filter,
      builder: (context, filter, _) {
        // Filtre dont le statut a disparu (liste relue) : retour à « Tous ».
        final active = filter != null && counts.containsKey(filter)
            ? filter
            : null;
        final visible = active == null
            ? embarked
            : embarked.where((b) => b.status == active).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripParcelsSummary(bids: embarked),
              if (present.length >= 2) ...[
                StatusChipsRow<String?>(
                  selected: active,
                  onSelected: _onFilter,
                  chips: [
                    StatusChipData<String?>(
                      label: l.tripOwnerParcelsFilterAll,
                      value: null,
                      count: embarked.length,
                    ),
                    for (final s in present)
                      () {
                        final (label, color) = tripParcelStatusMeta(s, cs, l);
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
          ),
        );
      },
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

/// Détail du gain ([TripGainContent]), ou ce qu'il faut attendre pour en
/// avoir un.
class _GainContent extends StatelessWidget {
  const _GainContent({required this.trip});

  final AnnouncementModel trip;

  @override
  Widget build(BuildContext context) {
    final summary = trip.parcelsSummary;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: summary != null && summary.count > 0
          ? TripGainContent(summary: summary)
          : Text(
              context.l10n.tripActivityGainEmpty,
              key: const Key('trip-activity-gain-empty'),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
    );
  }
}
