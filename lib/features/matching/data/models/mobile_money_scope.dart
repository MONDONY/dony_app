import 'package:equatable/equatable.dart';

/// Ce que paie un dépôt mobile money : la demande d'un trajet (bid), le fil
/// de négociation d'un colis, ou le supplément de prix demandé à la remise
/// d'un colis. Les rails du back exposent le même contrat (`initiate` /
/// `status`) sous des préfixes différents ; la portée choisit le préfixe, la
/// route de l'écran d'attente et l'écran de repli quand la pile est vide.
sealed class MobileMoneyScope extends Equatable {
  const MobileMoneyScope(this.id);

  /// UUID du bid, du fil ou du supplément.
  final String id;

  const factory MobileMoneyScope.bid(String bidId) = BidMobileMoneyScope;
  const factory MobileMoneyScope.negotiation(String threadId) =
      NegotiationMobileMoneyScope;
  const factory MobileMoneyScope.supplement({
    required String bidId,
    required String supplementId,
  }) = SupplementMobileMoneyScope;

  /// Préfixe REST et GoRouter de la portée (`/bids/{id}`, …).
  String get _basePath;

  String get statusPath => '$_basePath/mobile-money/status';
  String get initiatePath => '$_basePath/mobile-money/initiate';

  /// Catalogue des opérateurs du payeur (`POST …/mobile-money/providers`),
  /// ou `null` quand le back n'en expose pas pour cette portée (fil de
  /// négociation) : l'initiation est alors directe.
  String? get providersPath => '$_basePath/mobile-money/providers';

  /// Route GoRouter de l'écran d'attente pour cette portée.
  String get awaitingRoute => '$_basePath/mobile-money/awaiting';

  /// Écran ouvert quand l'écran d'attente n'a rien à dépiler (lien profond,
  /// notification) : le détail de l'envoi ou le fil.
  String get fallbackRoute => _basePath;

  /// Un `paymentStatus == 'CANCELLED'` est définitif pour cette portée
  /// (supplément refusé, expiré, retiré ou annulé) : jamais une ligne à
  /// recycler par une nouvelle initiation, contrairement au fil revenu à
  /// « à payer ».
  bool get cancelledIsFinal => false;

  /// Libellé analytics (`bid` / `negotiation` / `bid_supplement`).
  String get analyticsName;

  @override
  List<Object?> get props => [runtimeType, id];
}

final class BidMobileMoneyScope extends MobileMoneyScope {
  const BidMobileMoneyScope(super.id);
  @override
  String get _basePath => '/bids/$id';
  @override
  String get analyticsName => 'bid';
}

final class NegotiationMobileMoneyScope extends MobileMoneyScope {
  const NegotiationMobileMoneyScope(super.id);
  @override
  String get _basePath => '/negotiations/$id';

  /// Pas de catalogue côté back pour un fil (lot 2) : initiation directe.
  @override
  String? get providersPath => null;
  @override
  String get analyticsName => 'negotiation';
}

/// Supplément de prix d'un colis payé en mobile money. [id] est celui du
/// supplément. Son catalogue est dédié : celui du colis répond 409 une fois
/// le colis payé.
final class SupplementMobileMoneyScope extends MobileMoneyScope {
  const SupplementMobileMoneyScope({
    required this.bidId,
    required String supplementId,
  }) : super(supplementId);

  final String bidId;

  String get supplementId => id;

  @override
  String get _basePath => '/bids/$bidId/supplements/$id';

  /// Pas d'écran propre au supplément : le détail du colis.
  @override
  String get fallbackRoute => '/bids/$bidId';
  @override
  bool get cancelledIsFinal => true;
  @override
  String get analyticsName => 'bid_supplement';

  @override
  List<Object?> get props => [runtimeType, bidId, id];
}
