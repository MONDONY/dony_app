import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:equatable/equatable.dart';

sealed class BidNegotiationEvent extends Equatable {
  const BidNegotiationEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement du fil complet (ouverture de l'écran, retour d'une action).
class BidNegotiationFetchRequested extends BidNegotiationEvent {
  final String bidId;

  const BidNegotiationFetchRequested(this.bidId);

  @override
  List<Object?> get props => [bidId];
}

/// L'expéditeur ouvre le mode négociation depuis le détail du trajet.
/// N'appelle aucun endpoint : sert uniquement à mesurer l'entonnoir.
class BidNegotiationOpenRequested extends BidNegotiationEvent {
  final String announcementId;

  const BidNegotiationOpenRequested(this.announcementId);

  @override
  List<Object?> get props => [announcementId];
}

/// Première proposition de l'expéditeur sur un trajet négociable.
class BidNegotiationProposeRequested extends BidNegotiationEvent {
  final String announcementId;
  final double? weightKg;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  final double proposedTotalEur;
  final BidPaymentMethod paymentMethod;
  final String? phoneNumber;
  final String? countryCode;
  final List<String>? photoKeys;
  final List<Map<String, dynamic>>? customItems;
  final List<Map<String, dynamic>>? gridItems;

  const BidNegotiationProposeRequested({
    required this.announcementId,
    required this.weightKg,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
    required this.proposedTotalEur,
    this.paymentMethod = BidPaymentMethod.stripe,
    this.phoneNumber,
    this.countryCode,
    this.photoKeys,
    this.customItems,
    this.gridItems,
  });

  @override
  List<Object?> get props => [
    announcementId,
    weightKg,
    description,
    contentCategory,
    recipientName,
    recipientPhone,
    proposedTotalEur,
    paymentMethod,
    phoneNumber,
    countryCode,
    photoKeys,
    customItems,
    gridItems,
  ];
}

/// Contre-offre de l'une des deux parties.
class BidNegotiationCounterRequested extends BidNegotiationEvent {
  final String bidId;
  final double proposedTotalEur;
  final String? body;

  const BidNegotiationCounterRequested(
    this.bidId, {
    required this.proposedTotalEur,
    this.body,
  });

  @override
  List<Object?> get props => [bidId, proposedTotalEur, body];
}

class BidNegotiationAcceptRequested extends BidNegotiationEvent {
  final String bidId;

  const BidNegotiationAcceptRequested(this.bidId);

  @override
  List<Object?> get props => [bidId];
}

class BidNegotiationRejectRequested extends BidNegotiationEvent {
  final String bidId;

  const BidNegotiationRejectRequested(this.bidId);

  @override
  List<Object?> get props => [bidId];
}

class BidNegotiationCancelRequested extends BidNegotiationEvent {
  final String bidId;

  const BidNegotiationCancelRequested(this.bidId);

  @override
  List<Object?> get props => [bidId];
}

/// Marque le fil comme lu (badge de non-lus). Sans état ni erreur visible.
class BidNegotiationReadRequested extends BidNegotiationEvent {
  final String bidId;

  const BidNegotiationReadRequested(this.bidId);

  @override
  List<Object?> get props => [bidId];
}
