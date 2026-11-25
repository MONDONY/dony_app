import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/tracking_actions.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/parcel_step.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:flutter/widgets.dart';

/// Rôles du lecteur sur le colis de la fiche, avec la règle de la fiche
/// (`BidDetailScreen`) : l'expéditeur, sinon le voyageur du trajet (voyageur
/// encore inconnu du colis : la vue voyageur, comme la fiche). L'expéditeur
/// qui est son propre destinataire a aussi le rôle destinataire. Lecteur
/// inconnu, colis pas encore chargé ou ni l'un ni l'autre : aucun rôle.
Set<ParcelRole> bidViewerRoles(BidModel bid, String? viewerId) {
  if (viewerId == null || bid.isSkeleton) return const {};
  if (viewerId == bid.senderId) {
    return {ParcelRole.sender, if (bid.recipientIsSender) ParcelRole.recipient};
  }
  final travelerId = bid.travelerId;
  if (travelerId == null || travelerId == viewerId) {
    return const {ParcelRole.traveler};
  }
  return const {};
}

/// Moment d'étape du colis à l'ouverture de sa fiche, ou `null` : statut hors
/// des rails, lecteur sans rôle. Les variables portent les noms et la ville
/// du colis (vides quand ils manquent), jamais le code de retrait ; les
/// boutons du modal ouvrent les mêmes fenêtres que la fiche :
/// - expéditeur : QR du colis, « Prévenir » en mode code (seulement quand
///   le bouton du bas l'offrirait : [SenderStickyBar.canSendCode]), suivi ;
/// - voyageur : la frise du colis.
VideoModalMoment? bidParcelStepMoment(
  BidModel bid, {
  required String? viewerId,
}) {
  final trigger = VideoModalTrigger.forParcelStatus(bid.status);
  if (trigger == null) return null;
  final roles = bidViewerRoles(bid, viewerId);
  if (roles.isEmpty) return null;
  final isSender = roles.contains(ParcelRole.sender);
  return VideoModalMoment.parcelStep(
    trigger: trigger,
    bidId: bid.id,
    roles: roles,
    variables: {
      ParcelModalVariable.recipient.key: bid.recipientName ?? '',
      ParcelModalVariable.traveler.key: bid.travelerName ?? '',
      ParcelModalVariable.sender.key: bid.senderName ?? '',
      ParcelModalVariable.arrivalCity.key: bid.arrivalCity ?? '',
    },
    canSendCode: isSender && SenderStickyBar.canSendCode(bid),
    openers: isSender
        ? ParcelActionOpeners(
            qr: (context) =>
                QrSheet.show(context, bidId: bid.id, status: bid.status),
            sendCode: (context) => openSenderTileSheet(
              context,
              bid,
              SenderTile.prevenir,
              source: 'modal',
            ),
            tracking: (context) => _openSenderTracking(context, bid),
          )
        : ParcelActionOpeners(
            tracking: (context) => showTrackingTimelineSheet(
              context,
              bidId: bid.id,
              departureCity: bid.departureCity,
              arrivalCity: bid.arrivalCity,
              arrivalInstructions: bid.arrivalInstructions,
              trackingNumber: travelerVisibleTrackingNumber(bid),
              bidStatus: bid.status,
            ),
          ),
  );
}

/// Même geste que le bouton du bas « Suivi du colis » : la fenêtre de la
/// tuile Suivi, sinon la frise.
Future<void> _openSenderTracking(BuildContext context, BidModel bid) async {
  if (senderTilesFor(bid).contains(SenderTile.suivi)) {
    await openSenderTileSheet(context, bid, SenderTile.suivi, source: 'modal');
  } else {
    openSenderTrackingTimeline(context, bid);
  }
}
