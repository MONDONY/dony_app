import 'package:dony/features/matching/data/models/bid_model.dart';

abstract class BidEvent {
  const BidEvent();
}

class BidCheckoutRequested extends BidEvent {
  final String announcementId;
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  /// Articles de la grille sélectionnés (mode MIXED). Null si aucun article.
  /// Format: [{'announcementGridItemId': String, 'quantity': int}]
  final List<Map<String, dynamic>>? gridItems;
  /// Clés S3 des photos déjà uploadées (≤ 4). Null/empty si aucune.
  final List<String>? photoKeys;

  BidCheckoutRequested({
    required this.announcementId,
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
    this.gridItems,
    this.photoKeys,
  });
}

class BidCreateRequested extends BidEvent {
  final String announcementId;
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  final BidPaymentMethod paymentMethod;
  /// Numéro de téléphone Mobile Money (requis si WAVE ou ORANGE_MONEY).
  final String? phoneNumber;
  /// Code pays ISO 3166-1 alpha-2 (requis si WAVE ou ORANGE_MONEY).
  /// Ex: 'CI', 'SN', 'ML', 'GN', 'BF', 'CM'
  final String? countryCode;
  /// Articles de la grille sélectionnés (mode MIXED). Null si aucun article.
  /// Format: [{'announcementGridItemId': String, 'quantity': int}]
  final List<Map<String, dynamic>>? gridItems;

  /// Code promo optionnel — stocké sur le bid, validé au paiement.
  final String? promoCode;
  /// Clés S3 des photos déjà uploadées (≤ 4). Null/empty si aucune.
  final List<String>? photoKeys;

  BidCreateRequested({
    required this.announcementId,
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
    this.paymentMethod = BidPaymentMethod.stripe,
    this.phoneNumber,
    this.countryCode,
    this.promoCode,
    this.gridItems,
    this.photoKeys,
  });
}

/// Calcule le devis pour un bid (net, commission, total) avec promo éventuel.
/// Supporte les trois modes : KG ([weightKg] seul), GRID ([gridItems] seuls)
/// et MIXED (les deux) — le promo est ainsi reflété quel que soit le mode.
class BidQuoteRequested extends BidEvent {
  final String announcementId;
  final double? weightKg;
  final String? promoCode;

  /// Articles de la grille : `[{'announcementGridItemId': String, 'quantity': int}]`.
  final List<Map<String, dynamic>>? gridItems;

  BidQuoteRequested({
    required this.announcementId,
    this.weightKg,
    this.promoCode,
    this.gridItems,
  });
}

class BidListRequested extends BidEvent {
  final String announcementId;
  BidListRequested(this.announcementId);
}

class BidMyListRequested extends BidEvent {}

/// Rafraîchit la liste si les données sont périmées (TTL 3 min).
/// [force] = true bypasse le TTL (pull-to-refresh manuel).
class BidMyListAutoRefreshRequested extends BidEvent {
  final bool force;
  const BidMyListAutoRefreshRequested({this.force = false});
}

class BidDetailRequested extends BidEvent {
  final String bidId;
  BidDetailRequested(this.bidId);
}

class BidAcceptRequested extends BidEvent {
  final String bidId;
  BidAcceptRequested(this.bidId);
}

class BidRejectRequested extends BidEvent {
  final String bidId;
  final String? reason;
  BidRejectRequested(this.bidId, {this.reason});
}

class BidConfirmPresenceRequested extends BidEvent {
  final String bidId;
  BidConfirmPresenceRequested(this.bidId);
}

class BidCancelRequested extends BidEvent {
  final String bidId;
  final String? reason;
  BidCancelRequested(this.bidId, {this.reason});
}

class BidHideRequested extends BidEvent {
  final String bidId;
  BidHideRequested(this.bidId);
}

class BidDeleteRequested extends BidEvent {
  final String bidId;
  BidDeleteRequested(this.bidId);
}

class BidTravelerDismissRequested extends BidEvent {
  final String bidId;
  BidTravelerDismissRequested(this.bidId);
}

/// Synchronously confirms with the backend that the Stripe PaymentIntent
/// has been authorized. Promotes the bid from AWAITING_PAYMENT to PENDING
/// without waiting for the Stripe webhook (safety net for local dev and
/// network failures).
class BidConfirmPaymentRequested extends BidEvent {
  final String bidId;
  BidConfirmPaymentRequested(this.bidId);
}
