import 'package:equatable/equatable.dart';

/// Ce que paie un dépôt mobile money : la demande d'un trajet (bid), le fil
/// de négociation d'un colis, le supplément de prix demandé à la remise d'un
/// colis, ou la modification d'un colis accepté. Les rails du back exposent le
/// même contrat (`initiate` / `status`) sous des préfixes différents ; la
/// portée choisit le préfixe, la route de l'écran d'attente et l'écran de
/// repli quand la pile est vide.
sealed class MobileMoneyScope extends Equatable {
  const MobileMoneyScope(this.id);

  /// UUID du bid, du fil, du supplément ou de la modification.
  final String id;

  const factory MobileMoneyScope.bid(String bidId) = BidMobileMoneyScope;
  const factory MobileMoneyScope.negotiation(String threadId) =
      NegotiationMobileMoneyScope;
  const factory MobileMoneyScope.supplement({
    required String bidId,
    required String supplementId,
  }) = SupplementMobileMoneyScope;
  const factory MobileMoneyScope.amendment({
    required String bidId,
    required String amendmentId,
  }) = AmendmentMobileMoneyScope;

  /// Préfixe REST et GoRouter de la portée (`/bids/{id}`, …).
  String get _basePath;

  String get statusPath => '$_basePath/mobile-money/status';
  String get initiatePath => '$_basePath/mobile-money/initiate';

  /// Opérateurs acceptés par le voyageur
  /// (`GET …/mobile-money/accepted-operators`). Le supplément se paie sur le
  /// colis : il lit la route du colis (`/bids/{bidId}`).
  String get acceptedOperatorsPath =>
      '$_basePath/mobile-money/accepted-operators';

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

  /// Libellé analytics (`bid` / `negotiation` / `bid_supplement` / `bid_amendment`).
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
  @override
  String get analyticsName => 'negotiation';
}

/// Supplément de prix d'un colis payé en mobile money. [id] est celui du
/// supplément. Ses opérateurs acceptés sont ceux du colis.
final class SupplementMobileMoneyScope extends MobileMoneyScope {
  const SupplementMobileMoneyScope({
    required this.bidId,
    required String supplementId,
  }) : super(supplementId);

  final String bidId;

  String get supplementId => id;

  @override
  String get _basePath => '/bids/$bidId/supplements/$id';

  @override
  String get acceptedOperatorsPath =>
      '/bids/$bidId/mobile-money/accepted-operators';

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

/// Modification d'un colis accepté payée en mobile money. [id] est celui de
/// la modification. Calque du supplément : mêmes routes de statut et
/// d'initiation sous `/bids/{bidId}/amendments/{id}`, opérateurs acceptés du
/// colis, détail du colis comme repli, `CANCELLED` définitif.
final class AmendmentMobileMoneyScope extends MobileMoneyScope {
  const AmendmentMobileMoneyScope({
    required this.bidId,
    required String amendmentId,
  }) : super(amendmentId);

  final String bidId;

  String get amendmentId => id;

  @override
  String get _basePath => '/bids/$bidId/amendments/$id';

  @override
  String get acceptedOperatorsPath =>
      '/bids/$bidId/mobile-money/accepted-operators';

  /// Pas d'écran propre à la modification : le détail du colis.
  @override
  String get fallbackRoute => '/bids/$bidId';
  @override
  bool get cancelledIsFinal => true;
  @override
  String get analyticsName => 'bid_amendment';

  @override
  List<Object?> get props => [runtimeType, bidId, id];
}
