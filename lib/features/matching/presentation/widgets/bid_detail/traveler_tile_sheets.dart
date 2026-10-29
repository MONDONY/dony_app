import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/live_bid.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le bottom sheet de [tile] pour [bid] (grille « Votre transport » de
/// la fiche colis, vue voyageur) et compte l'ouverture.
///
/// Le sheet s'ouvre sur le navigateur racine : les BLoCs de l'écran n'y sont
/// pas visibles. Le contenu ne lit que le `BidBloc` (rechargement du colis
/// après une demande de remplacement du destinataire), reposé ici par
/// `BlocProvider.value` quand l'écran le fournit. Les autres BLoCs (contact
/// destinataire, remplacement) sont créés par les cartes elles-mêmes.
///
/// Aucun sheet n'a de bouton propre : les actions des cartes (contacter le
/// destinataire, demander un autre destinataire) vivent dans leur carte.
Future<void> openTravelerTileSheet(
  BuildContext context,
  BidModel bid,
  TravelerTile tile,
) {
  final l = context.l10n;
  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(
      AnalyticsEvents.bidDetailTileOpened,
      properties: {'tile': tile.name, 'role': 'traveler'},
    ),
  );

  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }

  final title = switch (tile) {
    TravelerTile.lieux => l.travelerTileLieux,
    TravelerTile.colis => l.travelerTileColis,
    TravelerTile.details => l.bidDetailMoreDetails,
  };

  final screenBidBloc = bidBloc;
  return DonyBottomSheet.show<void>(
    context,
    title: title,
    analyticsName: 'bid-detail/traveler-${tile.name}',
    wrapper: screenBidBloc == null
        ? null
        : (content) =>
              BlocProvider<BidBloc>.value(value: screenBidBloc, child: content),
    child: LiveBid(
      bid: bid,
      live: screenBidBloc != null,
      builder: (_, current) => switch (tile) {
        TravelerTile.lieux => _PlacesContent(bid: current),
        TravelerTile.colis => _ParcelContent(bid: current),
        TravelerTile.details => BidDetailsContent(
          bid: current,
          showTrackingLink: false,
        ),
      },
    ),
  );
}

/// Contenu du sheet Lieux : le dépôt du colis, la récupération à l'arrivée,
/// puis les consignes de retrait. Chaque adresse s'ouvre dans l'app Cartes.
/// Pas de mini-carte : `ParcelLocationsCard` est conçue pour l'expéditeur.
class _PlacesContent extends StatelessWidget {
  const _PlacesContent({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final handover = bid.handoverAddress;
    final delivery = bid.deliveryAddress;
    final handoverText = bid.handoverLocation?.trim() ?? '';
    final hasHandover = handover != null || handoverText.isNotEmpty;
    final handedOver = kParcelHandedOverStatuses.contains(bid.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (handover != null)
          AddressLocationRow(
            key: const Key('traveler-place-handover'),
            iconAsset: handedOver ? 'check' : 'upload',
            iconColor: handedOver ? cs.success : cs.primary,
            iconBackground: handedOver
                ? cs.success.withValues(alpha: 0.12)
                : cs.primaryContainer,
            title: l.listingPickupParcelTitle,
            address: handover,
          )
        else if (handoverText.isNotEmpty)
          Padding(
            key: const Key('traveler-place-handover'),
            padding: const EdgeInsets.all(DonySpacing.md),
            child: InfoRow(
              label: l.listingPickupParcelTitle,
              value: handoverText,
            ),
          ),
        if (hasHandover && delivery != null)
          Divider(height: 1, color: cs.surfaceContainerHighest),
        if (delivery != null)
          AddressLocationRow(
            key: const Key('traveler-place-delivery'),
            iconAsset: 'download',
            iconColor: DonyColors.accent,
            iconBackground: DonyColors.accentSoft,
            title: l.listingDeliveryPickupTitle,
            address: delivery,
          ),
        if (ArrivalInstructionsCard.hasText(bid.arrivalInstructions)) ...[
          if (hasHandover || delivery != null)
            const SizedBox(height: DonySpacing.base),
          ArrivalInstructionsCard(instructions: bid.arrivalInstructions!),
        ],
      ],
    );
  }
}

/// Contenu du sheet Colis et destinataire : la carte colis (sans cadre), puis
/// le contact du destinataire. Mêmes conditions que l'ancien corps : la carte
/// de contact une fois le colis retiré, la note d'attente tant que le colis
/// est accepté sans être retiré, rien avant l'acceptation ni si le
/// destinataire a refusé.
class _ParcelContent extends StatelessWidget {
  const _ParcelContent({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColisDestinataireCard(bid: bid, isSender: false, framed: false),
        if (TravelerRecipientContactCard.shouldShow(bid)) ...[
          const SizedBox(height: DonySpacing.base),
          TravelerRecipientContactCard(bid: bid),
        ] else if (TravelerRecipientContactPendingNote.shouldShow(bid)) ...[
          const SizedBox(height: DonySpacing.base),
          const TravelerRecipientContactPendingNote(),
        ],
      ],
    );
  }
}
