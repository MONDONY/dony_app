import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_routes.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le sheet de l'action par colis [kind] du trajet [trip]
/// ([TripTodoKind.perParcel] : présence, récupération, modification,
/// supplément, absence de l'expéditeur, restitution, remise, destinataire
/// refusé, notation) et compte l'ouverture (`bid_detail_tile_opened`, `tile`
/// = nom du type, `role: trip_owner`, `source` = [source]). Nom du sheet :
/// `trip-owner/todo-<type>`.
///
/// Le sheet ne refait aucun geste : il dit l'échéance et ce qui arrive sans
/// rien faire (bandeau orange, [tripTodoDueBanner]), puis liste les colis
/// concernés (avatar, expéditeur, contenu · poids, échéance du colis). Une
/// ligne ferme le sheet et ouvre la fiche du colis (`/bids/:id`), où le
/// geste existe déjà ; colis et trajet sont relus en silence au retour
/// ([openTripParcel]). Pour [TripTodoKind.scan], le pied propose aussi
/// « Lire le QR du colis » : Suivi › Valider sur ce trajet ([openTripScan]),
/// comme le pied de la fiche colis.
///
/// Comme les autres sheets de l'écran : blocs de l'écran reposés par le
/// `wrapper`, contenu sur les mêmes données que la section ([TripTodoLive],
/// [bids] repris pendant un rechargement), fermeture d'elle-même quand
/// l'action n'a plus lieu d'être ([TripTodoLiveData.todo]).
Future<void> openTripTodoParcelsSheet(
  BuildContext context,
  AnnouncementModel trip,
  TripTodoKind kind, {
  required TripTodoSource source,
  List<BidModel>? bids,
}) {
  assert(kind.perParcel, 'openTripTodoParcelsSheet: per-parcel kinds only');
  final blocs = TripTodoBlocs.of(context);
  logBidDetailTileOpened(
    tile: kind.name,
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

  TripTodoItem? itemOf(TripTodoLiveData live) {
    for (final item in live.todo()) {
      if (item.kind == kind) return item;
    }
    return null;
  }

  /// Ferme le sheet avant d'agir depuis l'écran. Faux quand il n'est plus
  /// au premier plan (second appui, confirmation par-dessus) ou que l'écran
  /// n'est plus monté.
  bool closeForAction(BuildContext sheetContext) =>
      closeSheetIfOnTop(sheetContext) && context.mounted;

  return DonyBottomSheet.show<void>(
    context,
    titleWidget: follow((sheetContext, live) {
      final item = itemOf(live) ?? TripTodoItem(kind: kind, count: 1);
      return Text(
        tripTodoTitle(sheetContext.l10n, item, cardReady: live.cardReady),
      );
    }),
    analyticsName: 'trip-owner/todo-${kind.name}',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
        if (blocs.depart case final b?)
          BlocProvider<TripDepartCubit>.value(value: b),
      ];
      return providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
    },
    stickyBottom: kind == TripTodoKind.scan
        ? Builder(
            builder: (sheetContext) => DonyButton(
              key: const Key('trip-todo-parcels-scan-button'),
              label: sheetContext.l10n.bidDetailScanParcelQr,
              iconAsset: 'scan-line',
              onPressed: () {
                if (!closeForAction(sheetContext)) return;
                unawaited(openTripScan(context, trip.id));
              },
            ),
          )
        : null,
    child: follow((sheetContext, live) {
      final item = itemOf(live);
      return CloseTripSheetWhenGone(
        gone: item == null,
        child: item == null
            ? const SizedBox.shrink()
            : _ParcelsTodoContent(
                item: item,
                live: live,
                onOpenParcel: (bidId) {
                  if (!closeForAction(sheetContext)) return;
                  unawaited(
                    openTripParcel(context, tripId: trip.id, bidId: bidId),
                  );
                },
              ),
      );
    }),
  );
}

/// Bandeau d'échéance puis une ligne par colis concerné, dans l'ordre de
/// l'action (échéance la plus proche d'abord).
class _ParcelsTodoContent extends StatelessWidget {
  const _ParcelsTodoContent({
    required this.item,
    required this.live,
    required this.onOpenParcel,
  });

  final TripTodoItem item;
  final TripTodoLiveData live;
  final ValueChanged<String> onOpenParcel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final now = tripTodoNow();
    final banner = tripTodoDueBanner(
      l,
      item,
      now: now,
      trip: live.trip,
      bids: live.bids,
    );
    final byId = {for (final b in live.bids ?? const <BidModel>[]) b.id: b};
    final parcels = [for (final id in item.bidIds) ?byId[id]];
    return Padding(
      key: Key('trip-todo-parcels-${item.kind.name}'),
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (banner != null) ...[
            DonyStatusBanner(
              key: const Key('trip-todo-parcels-banner'),
              type: DonyStatusBannerType.warning,
              iconAsset: 'clock',
              message: banner,
            ),
            const SizedBox(height: DonySpacing.md),
          ],
          for (final (i, bid) in parcels.indexed) ...[
            if (i > 0) Divider(height: 1, color: cs.outline),
            _ParcelTodoRow(
              bid: bid,
              due: tripTodoDueLabel(
                l,
                item.dueAtByBid[bid.id],
                now: now,
                trip: live.trip,
              ),
              consequence: tripTodoParcelConsequence(
                l,
                item,
                bid,
                bids: live.bids,
              ),
              onTap: () => onOpenParcel(bid.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un colis de l'action : avatar (initiales), expéditeur, « contenu ·
/// poids » ([tripRequestDetails]), son échéance en orange et, dans une
/// action qui mêle les paiements, sa conséquence ([tripTodoParcelConsequence]),
/// chevron. Lue d'un seul tenant ; un tap ouvre la fiche du colis.
class _ParcelTodoRow extends StatelessWidget {
  const _ParcelTodoRow({
    required this.bid,
    required this.due,
    required this.consequence,
    required this.onTap,
  });

  final BidModel bid;
  final String? due;
  final String? consequence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = bid.senderDisplayName(l);
    final details = tripRequestDetails(l, bid);
    final due = this.due;
    final consequence = this.consequence;
    return Semantics(
      button: true,
      label: [name, details, ?due, ?consequence].join('. '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('trip-todo-parcel-${bid.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
            child: Row(
              children: [
                DonyAvatar(name: name, imageUrl: bid.senderAvatarUrl),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (due != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          due,
                          style: tt.labelMedium?.copyWith(
                            color: cs.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (consequence != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          consequence,
                          key: Key('trip-todo-parcel-consequence-${bid.id}'),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
