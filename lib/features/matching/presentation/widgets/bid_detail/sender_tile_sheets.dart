import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_entry.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/tracking_actions.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tracking_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le bottom sheet de [tile] pour [bid] (grille « Votre envoi » de la
/// fiche colis, vue expéditeur) et compte l'ouverture.
///
/// Le sheet s'ouvre sur le navigateur racine : les BLoCs de l'écran n'y sont
/// pas visibles. Les cartes posées dans les sheets ne lisent que le `BidBloc`
/// (rechargement du colis après un changement de destinataire), reposé ici
/// par `BlocProvider.value` quand l'écran le fournit. Le suivi du voyageur et
/// la frise créent leurs propres BLoCs.
///
/// Les boutons qui ouvrent autre chose (frise, modification du colis)
/// ferment d'abord le sheet, puis agissent avec le [context] de l'écran.
Future<void> openSenderTileSheet(
  BuildContext context,
  BidModel bid,
  SenderTile tile,
) {
  final l = context.l10n;
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.bidDetailTileOpened,
      properties: {'tile': tile.name},
    ),
  );

  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }

  final title = switch (tile) {
    SenderTile.prevenir => l.recipientNotifyTitle(
      PrevenirDestinataire.displayName(l, bid),
    ),
    SenderTile.suivi => l.senderTileSuivi,
    SenderTile.lieux => l.senderTileLieux,
    SenderTile.colis => l.senderTileColis,
    SenderTile.details => l.bidDetailMoreDetails,
  };

  // Contenu et bouton du bas lisent le colis courant : le sheet reste ouvert
  // pendant les rechargements de l'écran (relevé périodique, changement de
  // destinataire fait depuis le sheet Colis).
  final live = bidBloc != null;
  final stickyBottom = _stickyBottomFor(tile, l, context, bid, live: live);

  final screenBidBloc = bidBloc;
  return DonyBottomSheet.show<void>(
    context,
    title: title,
    analyticsName: 'bid-detail/${tile.name}',
    wrapper: screenBidBloc == null
        ? null
        : (content) =>
              BlocProvider<BidBloc>.value(value: screenBidBloc, child: content),
    stickyBottom: stickyBottom,
    child: _LiveBid(
      bid: bid,
      live: live,
      builder: (_, current) => switch (tile) {
        SenderTile.prevenir => PrevenirDestinataireBody(bid: current),
        SenderTile.suivi => _SuiviContent(bid: current),
        SenderTile.lieux => _LieuxContent(bid: current),
        SenderTile.colis => ColisDestinataireCard(bid: current, framed: false),
        SenderTile.details => BidDetailsContent(bid: current),
      },
    ),
  );
}

/// Bouton du bas du sheet de [tile], `null` quand la tuile n'en a pas. La
/// présence du pied est décidée à l'ouverture (colis : modification autorisée
/// pour [bid]) ; le bouton lui-même suit le colis courant.
Widget? _stickyBottomFor(
  SenderTile tile,
  AppLocalizations l,
  BuildContext screenContext,
  BidModel bid, {
  required bool live,
}) {
  Widget liveBid(Widget Function(BuildContext, BidModel) builder) =>
      _LiveBid(bid: bid, live: live, builder: builder);

  return switch (tile) {
    SenderTile.prevenir => liveBid(
      (sheetContext, current) => DonyButton(
        label: PrevenirDestinataire.buttonLabel(l, current),
        iconAsset: 'message-circle',
        onPressed: () => PrevenirDestinataire.notify(sheetContext, current),
      ),
    ),
    SenderTile.suivi => liveBid(
      (sheetContext, current) => DonyButton(
        label: l.travelerTrackingOpenTimeline,
        variant: DonyButtonVariant.secondary,
        onPressed: () => _closeThen(sheetContext, screenContext, () {
          _logTimelineOpened(current);
          openSenderTrackingTimeline(screenContext, current);
        }),
      ),
    ),
    SenderTile.colis =>
      AmendmentEntry.shouldShow(bid)
          ? liveBid(
              (sheetContext, current) => AmendmentEntry.shouldShow(current)
                  ? DonyButton(
                      label: l.amendmentEntryButton,
                      iconAsset: 'plus',
                      variant: DonyButtonVariant.secondary,
                      onPressed: () => _closeThen(
                        sheetContext,
                        screenContext,
                        () => unawaited(
                          AmendmentEntry.open(screenContext, current),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            )
          : null,
    SenderTile.lieux || SenderTile.details => null,
  };
}

/// Rend [builder] avec le colis courant : le dernier [BidDetailLoaded] du
/// `BidBloc` de l'écran pour ce colis, à défaut [bid] (celui de l'ouverture).
/// Sans `BidBloc` ([live] faux), rendu statique avec [bid].
class _LiveBid extends StatelessWidget {
  const _LiveBid({
    required this.bid,
    required this.live,
    required this.builder,
  });

  final BidModel bid;
  final bool live;
  final Widget Function(BuildContext context, BidModel bid) builder;

  @override
  Widget build(BuildContext context) {
    if (!live) return builder(context, bid);
    return BlocBuilder<BidBloc, BidState>(
      buildWhen: (_, state) =>
          state is BidDetailLoaded && state.bid.id == bid.id,
      builder: (context, state) => builder(
        context,
        state is BidDetailLoaded && state.bid.id == bid.id ? state.bid : bid,
      ),
    );
  }
}

/// Ferme le sheet, puis lance [action] si l'écran est toujours là.
void _closeThen(
  BuildContext sheetContext,
  BuildContext screenContext,
  VoidCallback action,
) {
  Navigator.of(sheetContext).pop();
  if (screenContext.mounted) action();
}

/// Ouverture de la frise depuis le sheet Suivi : `traveler_tracking_timeline_opened`
/// avec le `status` de la carte de suivi. Sans carte de suivi, il n'y a pas de
/// statut à mesurer : seule la frise s'ouvre.
void _logTimelineOpened(BidModel bid) {
  final tracking = bid.travelerTracking;
  if (tracking == null || !TravelerTrackingCard.shouldShow(bid)) return;
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.travelerTrackingTimelineOpened,
      properties: {
        'status': TravelerTrackingCardCubit.statusName(tracking.status),
      },
    ),
  );
}

/// Résumé d'état complet du colis (`SenderHeroCard.statusLine`), en tête des
/// sheets Suivi et Lieux : la tuile n'en montre que deux lignes. Rien à
/// afficher quand le colis n'a pas de résumé.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final line = SenderHeroCard.statusLine(context, bid);
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Text(
        line,
        key: const Key('sender-tile-status-line'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Contenu du sheet Lieux : le résumé d'état, puis la carte et les adresses.
class _LieuxContent extends StatelessWidget {
  const _LieuxContent({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StatusLine(bid: bid),
      _RoundedMiniMap(child: ParcelLocationsCard(bid: bid)),
    ],
  );
}

/// Contenu du sheet Suivi : le résumé d'état, où en est le voyageur, puis les
/// lieux.
class _SuiviContent extends StatelessWidget {
  const _SuiviContent({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final showTracking = TravelerTrackingCard.shouldShow(bid);
    final showLocations = ParcelLocationsCard.shouldShow(bid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusLine(bid: bid),
        if (showTracking)
          TravelerTrackingCard(
            tracking: bid.travelerTracking!,
            bidId: bid.id,
            bidStatus: bid.status,
            departureCity: bid.departureCity,
            arrivalCity: bid.arrivalCity,
          ),
        if (showTracking && showLocations)
          const SizedBox(height: DonySpacing.base),
        if (showLocations)
          _RoundedMiniMap(child: ParcelLocationsCard(bid: bid)),
      ],
    );
  }
}

/// Arrondit les coins de la mini-carte des lieux : sans cadre, la carte ne
/// découpe plus son contenu.
class _RoundedMiniMap extends StatelessWidget {
  const _RoundedMiniMap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DonyRadius.card),
    child: child,
  );
}
