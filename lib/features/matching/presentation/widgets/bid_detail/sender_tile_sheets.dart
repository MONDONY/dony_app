import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_entry_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
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

  final (title, child, stickyBottom) = switch (tile) {
    SenderTile.prevenir => (
      l.recipientNotifyTitle(PrevenirDestinataire.displayName(l, bid)),
      PrevenirDestinataireBody(bid: bid),
      Builder(
        builder: (sheetContext) => DonyButton(
          label: PrevenirDestinataire.buttonLabel(l, bid),
          iconAsset: 'message-circle',
          onPressed: () => PrevenirDestinataire.notify(sheetContext, bid),
        ),
      ),
    ),
    SenderTile.suivi => (
      l.senderTileSuivi,
      _SuiviContent(bid: bid),
      Builder(
        builder: (sheetContext) => DonyButton(
          label: l.travelerTrackingOpenTimeline,
          variant: DonyButtonVariant.secondary,
          onPressed: () => _closeThen(sheetContext, context, () {
            _logTimelineOpened(bid);
            openSenderTrackingTimeline(context, bid);
          }),
        ),
      ),
    ),
    SenderTile.lieux => (
      l.senderTileLieux,
      _RoundedMiniMap(child: ParcelLocationsCard(bid: bid, framed: false)),
      null,
    ),
    SenderTile.colis => (
      l.senderTileColis,
      ColisDestinataireCard(bid: bid, framed: false),
      AmendmentEntryCard.shouldShow(bid)
          ? Builder(
              builder: (sheetContext) => DonyButton(
                label: l.amendmentEntryButton,
                iconAsset: 'plus',
                variant: DonyButtonVariant.secondary,
                onPressed: () => _closeThen(
                  sheetContext,
                  context,
                  () => unawaited(AmendmentEntryCard.open(context, bid)),
                ),
              ),
            )
          : null,
    ),
    SenderTile.details => (
      l.bidDetailMoreDetails,
      BidDetailsContent(bid: bid),
      null,
    ),
  };

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
    child: child,
  );
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

/// Ouverture de la frise depuis le sheet Suivi : même événement et même
/// propriété `status` que le lien de [TravelerTrackingCard], qui est masqué
/// ici (`framed: false`). Sans carte de suivi, il n'y a pas de statut à
/// mesurer : seule la frise s'ouvre.
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

/// Contenu du sheet Suivi : où en est le voyageur, puis les lieux.
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
        if (showTracking)
          TravelerTrackingCard(
            tracking: bid.travelerTracking!,
            bidId: bid.id,
            bidStatus: bid.status,
            departureCity: bid.departureCity,
            arrivalCity: bid.arrivalCity,
            // Sans cadre, la carte n'affiche pas son lien vers la frise : le
            // bouton du bas du sheet s'en charge.
            onOpenTimeline: () {},
            framed: false,
          ),
        if (showTracking && showLocations)
          const SizedBox(height: DonySpacing.base),
        if (showLocations)
          _RoundedMiniMap(child: ParcelLocationsCard(bid: bid, framed: false)),
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
    borderRadius: BorderRadius.circular(DonyRadius.md),
    child: child,
  );
}
