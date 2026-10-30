import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/owner_action_grid.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_button.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_consent_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le bottom sheet de la tuile « À traiter » [tile] du trajet [trip]
/// (écran du trajet, vue du voyageur propriétaire) et compte l'ouverture
/// (`bid_detail_tile_opened`, `role: trip_owner`, avec [source]).
///
/// Comme `openTravelerTodoSheet` de la fiche colis : le sheet s'ouvre sur le
/// navigateur racine, les blocs de l'écran y sont reposés par le `wrapper`
/// (`BlocProvider.value`) quand [context] les fournit : `AnnouncementBloc`
/// (trajet relu), `BidBloc` (colis du trajet), `StripeAccountBloc` (compte
/// de paiement par carte) et `TripDepartCubit` (« Je pars »). Pour la tuile
/// [TripTodoTile.depart], un `TripDepartCubit` est créé par le `wrapper` si
/// l'écran n'en fournit pas. Contenu et pied suivent les données relues ; le
/// bouton vit dans le `stickyBottom`.
///
/// Le sheet se ferme seul dès que les données relues ne justifient plus
/// [tile] ([tripTodoTilesFor]) : départ confirmé, dernière demande traitée,
/// carte ajoutée. Une confirmation ou une erreur ouverte par-dessus n'est
/// jamais refermée à sa place.
///
/// Les boutons qui mènent à un autre écran ferment d'abord le sheet, puis
/// poussent la route depuis [context] (l'écran, jamais la tuile qui peut
/// disparaître) et relisent l'écran au retour.
Future<void> openTripTodoSheet(
  BuildContext context,
  AnnouncementModel trip,
  TripTodoTile tile, {
  TodoSource source = TodoSource.tile,
}) {
  logBidDetailTileOpened(
    tile: tile.name,
    role: 'trip_owner',
    source: source.name,
  );

  final blocs = _TripTodoBlocs(
    announcement: maybeRead<AnnouncementBloc>(context),
    bids: maybeRead<BidBloc>(context),
    stripe: maybeRead<StripeAccountBloc>(context),
    depart: maybeRead<TripDepartCubit>(context),
  );
  final cardReady = tripCardPaymentsReady(
    blocs.stripe?.state ?? const StripeAccountInitial(),
  );
  final createDepart = tile == TripTodoTile.depart && blocs.depart == null;

  return DonyBottomSheet.show<void>(
    context,
    title: tripTodoTitle(context.l10n, tile, cardReady: cardReady),
    analyticsName: 'trip-owner/todo-${tile.name}',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
        if (blocs.depart case final b?)
          BlocProvider<TripDepartCubit>.value(value: b)
        else if (createDepart)
          BlocProvider<TripDepartCubit>(
            create: (_) => getIt<TripDepartCubit>(param1: trip.id),
          ),
      ];
      return providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
    },
    stickyBottom: _LiveTripTodo(
      trip: trip,
      blocs: blocs,
      hasDepart: blocs.depart != null || createDepart,
      builder: (sheetContext, live) =>
          _TripTodoFooter(tile: tile, live: live, screenContext: context),
    ),
    child: _LiveTripTodo(
      trip: trip,
      blocs: blocs,
      hasDepart: blocs.depart != null || createDepart,
      builder: (sheetContext, live) => CloseTripSheetWhenGone(
        gone: !live.tiles.contains(tile),
        child: _TripTodoContent(tile: tile, live: live),
      ),
    ),
  );
}

/// Blocs de l'écran trouvés à l'ouverture du sheet, à reposer dans le sheet.
class _TripTodoBlocs {
  const _TripTodoBlocs({
    required this.announcement,
    required this.bids,
    required this.stripe,
    required this.depart,
  });

  final AnnouncementBloc? announcement;
  final BidBloc? bids;
  final StripeAccountBloc? stripe;
  final TripDepartCubit? depart;
}

/// Données courantes d'un sheet « À traiter » du trajet.
class _TripTodoLiveData {
  const _TripTodoLiveData({
    required this.trip,
    required this.bids,
    required this.departed,
    required this.stripe,
  });

  /// Dernier trajet relu par l'écran, à défaut celui de l'ouverture.
  final AnnouncementModel trip;

  /// Derniers colis chargés (`BidListLoaded`), `null` tant que la liste n'a
  /// pas répondu.
  final List<BidModel>? bids;
  final bool departed;
  final StripeAccountState stripe;

  int get pendingCount => tripPendingRequestCount(trip, bids);
  bool get cardReady => tripCardPaymentsReady(stripe);

  List<TripTodoTile> get tiles => tripTodoTilesFor(
    trip: trip,
    bids: bids,
    isOwner: true,
    departed: departed,
    stripe: stripe,
  );
}

/// Rend [builder] avec les données courantes : chaque bloc présent est suivi
/// (seuls ses états porteurs de données reconstruisent : un chargement garde
/// les dernières connues), un bloc absent laisse la valeur de l'ouverture.
class _LiveTripTodo extends StatelessWidget {
  const _LiveTripTodo({
    required this.trip,
    required this.blocs,
    required this.hasDepart,
    required this.builder,
  });

  final AnnouncementModel trip;
  final _TripTodoBlocs blocs;
  final bool hasDepart;
  final Widget Function(BuildContext context, _TripTodoLiveData live) builder;

  @override
  Widget build(BuildContext context) {
    return followBloc<AnnouncementBloc, AnnouncementState, AnnouncementModel>(
      present: blocs.announcement != null,
      select: (s) => tripAnnouncementIn(s, trip.id),
      builder: (context, current) =>
          followBloc<BidBloc, BidState, List<BidModel>>(
            present: blocs.bids != null,
            select: (s) => s is BidListLoaded ? s.bids : null,
            builder: (context, bids) =>
                followBloc<
                  StripeAccountBloc,
                  StripeAccountState,
                  StripeAccountState
                >(
                  present: blocs.stripe != null,
                  select: (s) => s,
                  builder: (context, stripe) =>
                      followBloc<TripDepartCubit, TripDepartState, bool>(
                        present: hasDepart,
                        select: (s) => s.departed,
                        builder: (context, departed) => builder(
                          context,
                          _TripTodoLiveData(
                            trip: current ?? trip,
                            bids: bids,
                            departed: departed ?? false,
                            stripe: stripe ?? const StripeAccountInitial(),
                          ),
                        ),
                      ),
                ),
          ),
    );
  }
}

/// Contenu du sheet, sur les données courantes.
class _TripTodoContent extends StatelessWidget {
  const _TripTodoContent({required this.tile, required this.live});

  final TripTodoTile tile;
  final _TripTodoLiveData live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final muted = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: switch (tile) {
        TripTodoTile.requests => Column(
          key: const Key('trip-todo-requests-content'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Liste pas encore chargée : le nombre servi par la liste des
            // trajets, sans les lignes.
            if (live.bids case final bids?)
              for (final bid in bids.where(isPendingBid)) ...[
                _RequestRow(bid: bid),
                const SizedBox(height: DonySpacing.sm),
              ]
            else ...[
              Text(
                l.tripTodoRequestsSummary(live.pendingCount),
                style: tt.bodyMedium,
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            Text(l.tripTodoRequestsHint, style: muted),
          ],
        ),
        TripTodoTile.depart => Column(
          key: const Key('trip-todo-depart-content'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.tripTodoDepartIntro, style: tt.bodyMedium),
            const SizedBox(height: DonySpacing.md),
            const TrackingConsentExplainer(),
          ],
        ),
        TripTodoTile.card => Text(
          live.cardReady
              ? l.listingCashOnlyCardReadyMessage
              : l.listingCashOnlyNudgeMessage,
          key: const Key('trip-todo-card-content'),
          style: tt.bodyMedium,
        ),
      },
    );
  }
}

/// Une demande à traiter : contenu, expéditeur · poids, net du voyageur
/// quand le back le sert (`totalNetAmountEur`).
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final content =
        (bid.contentCategory != null
            ? contentCategoriesDisplayName(l, bid.contentCategory!)
            : null) ??
        bid.description ??
        l.tripOwnerParcelsDefaultContent;
    final sender = bid.senderDisplayName(l);
    final w = bid.displayWeightKg;
    final weight = w == null
        ? null
        : '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg';
    final net = bid.totalAmountEur;
    return Container(
      key: Key('trip-todo-request-${bid.id}'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  weight != null ? '$sender · $weight' : sender,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (net != null) ...[
            const SizedBox(width: DonySpacing.sm),
            Text(
              formatPriceIn(net, bid.currency),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton du pied, sur les données courantes. [screenContext] : contexte de
/// l'écran qui a ouvert le sheet, pour pousser une route une fois le sheet
/// fermé.
class _TripTodoFooter extends StatelessWidget {
  const _TripTodoFooter({
    required this.tile,
    required this.live,
    required this.screenContext,
  });

  final TripTodoTile tile;
  final _TripTodoLiveData live;
  final BuildContext screenContext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return switch (tile) {
      TripTodoTile.requests => DonyButton(
        key: const Key('trip-todo-requests-button'),
        label: l.listingSeeRequestsButton(live.pendingCount),
        onPressed: () => unawaited(_openRequests(context)),
      ),
      TripTodoTile.depart => const TripDepartAction(),
      TripTodoTile.card =>
        live.cardReady
            ? DonyButton(
                key: const Key('enable-card-on-trip-cta'),
                label: l.listingEnableCardOnTripButton,
                onPressed: () => unawaited(_openEditToEnableCard(context)),
              )
            : DonyButton(
                key: const Key('activate-card-payments-cta'),
                label: l.listingActivateCardPaymentsButton,
                onPressed: () => unawaited(_openCardOnboarding(context)),
              ),
    };
  }

  /// Activité › Demandes « À traiter » de ce trajet. Au retour, les colis et
  /// le trajet sont relus : une demande acceptée ou refusée là-bas change les
  /// compteurs de l'écran.
  Future<void> _openRequests(BuildContext sheetContext) async {
    final bidBloc = maybeRead<BidBloc>(sheetContext);
    final announcementBloc = maybeRead<AnnouncementBloc>(sheetContext);
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await screenContext.push<void>(tripRequestsLocation(live.trip.id));
    // Écran quitté entre-temps : ses blocs sont fermés.
    if (!screenContext.mounted) return;
    bidBloc?.add(BidListRequested(live.trip.id));
    announcementBloc?.add(AnnouncementDetailRequested(live.trip.id));
  }

  /// Compte de paiement prêt : l'édition du trajet propose la carte, puis le
  /// trajet est relu pour que la tuile disparaisse (Sentry FLUTTER-DH), comme
  /// l'encart du corps du trajet.
  Future<void> _openEditToEnableCard(BuildContext sheetContext) async {
    final announcementBloc = maybeRead<AnnouncementBloc>(sheetContext);
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    final changed = await screenContext.push<bool>(
      '/trips/create',
      extra: CreateTripArgs(announcement: live.trip),
    );
    if ((changed ?? false) && screenContext.mounted) {
      announcementBloc?.add(AnnouncementDetailRequested(live.trip.id));
    }
  }

  /// Activation des paiements par carte. Le `StripeAccountBloc` est partagé
  /// par toute l'app et relu par le parcours d'activation lui-même : rien à
  /// recharger au retour.
  Future<void> _openCardOnboarding(BuildContext sheetContext) async {
    closeSheetIfOnTop(sheetContext);
    if (!screenContext.mounted) return;
    await screenContext.push<void>('/connect/onboarding/intro');
  }
}
