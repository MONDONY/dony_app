import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:equatable/equatable.dart';

/// Les écrans de « Ma demande » (spec §3). Chargement et erreur sont des états du cubit.
enum RequestScreenCase {
  draft,
  noOffers,
  noTravelers,
  offersReceived,
  firmCandidates,
  cashCommissionPending,
  toFinalize,
  accepted,
  delivered,
  expired,
  cancelled,
}

/// Statuts de bid qui autorisent encore la frise de progression côté
/// expéditeur (`RequestProgressTimeline`) : le trajet est toujours en cours.
/// Tout le reste (CANCELLED, NO_SHOW, PARCEL_REFUSED, REJECTED, EXPIRED…)
/// signifie que le trajet n'a pas abouti — miroir de `sender_sticky_bar.dart`
/// côté bid, qui distingue déjà ces statuts pour son propre bouton.
const _bidOnTrackStatuses = {
  'ACCEPTED',
  'PAYMENT_ESCROWED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
};

bool isBidOnTrack(String status) => _bidOnTrackStatuses.contains(status);

const _chosenStatuses = {
  NegotiationThreadStatus.awaitingTrip,
  NegotiationThreadStatus.awaitingPayment,
  NegotiationThreadStatus.awaitingDeposit,
};

RequestScreenCase resolveRequestScreenCase({
  required PackageRequest request,
  required List<NegotiationThread> threads,
  bool cancelledLocally = false,
  BidModel? materializedBid,
  List<AnnouncementModel>? compatibleTrips,
}) {
  // Le back soft-delete une demande annulée : l'état n'existe qu'au moment du geste.
  if (cancelledLocally || request.status == PackageRequestStatus.cancelled) {
    return RequestScreenCase.cancelled;
  }
  switch (request.status) {
    case PackageRequestStatus.draft:
      return RequestScreenCase.draft;
    case PackageRequestStatus.expired:
      return RequestScreenCase.expired;
    case PackageRequestStatus.completed:
      return RequestScreenCase.delivered;
    case PackageRequestStatus.accepted:
      // Aucun code back ne passe une demande en COMPLETED : la livraison se lit sur le bid.
      return materializedBid?.status == 'COMPLETED'
          ? RequestScreenCase.delivered
          : RequestScreenCase.accepted;
    case PackageRequestStatus.open:
    case PackageRequestStatus.negotiating:
    case PackageRequestStatus.cancelled:
      break;
  }
  if (threads.any((t) => _chosenStatuses.contains(t.status))) {
    return RequestScreenCase.toFinalize;
  }
  if (threads.any(
    (t) => t.status == NegotiationThreadStatus.awaitingCommission,
  )) {
    return RequestScreenCase.cashCommissionPending;
  }
  if (threads.any((t) => t.status.isActive)) {
    return request.negotiable
        ? RequestScreenCase.offersReceived
        : RequestScreenCase.firmCandidates;
  }
  if (compatibleTrips != null && compatibleTrips.isEmpty) {
    return RequestScreenCase.noTravelers;
  }
  return RequestScreenCase.noOffers;
}

enum RequestPrimaryAction {
  publish,
  share,
  openThread,
  pay,
  waitTrip,
  trackParcel,
  rate,
  republish,
  publishSimilar,
}

enum RequestMenuAction { unpublish, duplicate, cancel }

class RequestScreenActions extends Equatable {
  const RequestScreenActions({
    required this.primary,
    this.showEdit = false,
    this.showMessage = false,
    this.menu = const [],
  });

  final RequestPrimaryAction primary;
  final bool showEdit;
  final bool showMessage;
  final List<RequestMenuAction> menu;

  @override
  List<Object?> get props => [primary, showEdit, showMessage, menu];
}

RequestScreenActions requestActionsFor(
  RequestScreenCase screenCase, {
  required PackageRequest request,
  required List<NegotiationThread> threads,
  BidModel? materializedBid,
}) {
  // Miroirs des gardes serveur : unpublish exige OPEN sans aucun fil (409 has-offers),
  // cancel refuse ACCEPTED/COMPLETED, update refuse hors DRAFT/OPEN/NEGOTIATING.
  final canUnpublish =
      request.status == PackageRequestStatus.open && threads.isEmpty;
  const inProgressMenu = [
    RequestMenuAction.duplicate,
    RequestMenuAction.cancel,
  ];
  return switch (screenCase) {
    RequestScreenCase.draft => const RequestScreenActions(
      primary: RequestPrimaryAction.publish,
      showEdit: true,
      menu: [RequestMenuAction.duplicate],
    ),
    RequestScreenCase.noOffers ||
    RequestScreenCase.noTravelers => RequestScreenActions(
      primary: RequestPrimaryAction.share,
      showEdit: true,
      menu: [if (canUnpublish) RequestMenuAction.unpublish, ...inProgressMenu],
    ),
    RequestScreenCase.offersReceived ||
    RequestScreenCase.firmCandidates => const RequestScreenActions(
      primary: RequestPrimaryAction.share,
      showEdit: true,
      menu: inProgressMenu,
    ),
    RequestScreenCase.cashCommissionPending => const RequestScreenActions(
      primary: RequestPrimaryAction.openThread,
      menu: inProgressMenu,
    ),
    RequestScreenCase.toFinalize => RequestScreenActions(
      primary:
          threads.any((t) => t.status == NegotiationThreadStatus.awaitingTrip)
          ? RequestPrimaryAction.waitTrip
          : RequestPrimaryAction.pay,
      menu: inProgressMenu,
    ),
    // Bid annulé/absent/refusé/no-show entre-temps : le trajet n'a pas abouti,
    // « Suivre mon colis » n'a plus de sens → même action logique suivante
    // que expired/cancelled (publier une demande similaire).
    RequestScreenCase.accepted =>
      materializedBid != null && !isBidOnTrack(materializedBid.status)
          ? const RequestScreenActions(
              primary: RequestPrimaryAction.publishSimilar,
              menu: [RequestMenuAction.duplicate],
            )
          : const RequestScreenActions(
              primary: RequestPrimaryAction.trackParcel,
              showMessage: true,
              menu: [RequestMenuAction.duplicate],
            ),
    // Déjà noté (sender_sticky_bar.dart respecte la même garde côté bid) :
    // proposer de noter à nouveau n'a pas de sens, l'action suivante logique
    // est de publier une demande similaire.
    RequestScreenCase.delivered =>
      materializedBid?.senderHasRated ?? false
          ? const RequestScreenActions(
              primary: RequestPrimaryAction.publishSimilar,
              menu: [RequestMenuAction.duplicate],
            )
          : const RequestScreenActions(
              primary: RequestPrimaryAction.rate,
              menu: [RequestMenuAction.duplicate],
            ),
    RequestScreenCase.expired => const RequestScreenActions(
      primary: RequestPrimaryAction.republish,
    ),
    RequestScreenCase.cancelled => const RequestScreenActions(
      primary: RequestPrimaryAction.publishSimilar,
    ),
  };
}

NegotiationThread? focusThreadFor(
  RequestScreenCase screenCase,
  List<NegotiationThread> threads,
) {
  NegotiationThread? first(bool Function(NegotiationThread) test) {
    for (final t in threads) {
      if (test(t)) return t;
    }
    return null;
  }

  return switch (screenCase) {
    RequestScreenCase.toFinalize => first(
      (t) => _chosenStatuses.contains(t.status),
    ),
    RequestScreenCase.cashCommissionPending => first(
      (t) => t.status == NegotiationThreadStatus.awaitingCommission,
    ),
    RequestScreenCase.accepted || RequestScreenCase.delivered =>
      first((t) => t.materializedBidId != null) ??
          first((t) => t.status == NegotiationThreadStatus.accepted),
    _ => null,
  };
}
