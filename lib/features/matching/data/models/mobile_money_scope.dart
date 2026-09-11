import 'package:equatable/equatable.dart';

/// Ce que paie un dépôt mobile money : la demande d'un trajet (bid) ou le fil
/// de négociation d'un colis. Les deux rails du back exposent le même contrat
/// (`initiate` / `status`) sous deux préfixes ; la portée choisit le préfixe,
/// la route de l'écran d'attente et l'écran de repli quand la pile est vide.
sealed class MobileMoneyScope extends Equatable {
  const MobileMoneyScope(this.id);

  /// UUID du bid ou du fil.
  final String id;

  const factory MobileMoneyScope.bid(String bidId) = BidMobileMoneyScope;
  const factory MobileMoneyScope.negotiation(String threadId) =
      NegotiationMobileMoneyScope;

  String get _prefix;

  String get statusPath => '$_prefix/$id/mobile-money/status';
  String get initiatePath => '$_prefix/$id/mobile-money/initiate';

  /// Route GoRouter de l'écran d'attente pour cette portée.
  String get awaitingRoute => '$_prefix/$id/mobile-money/awaiting';

  /// Écran ouvert quand l'écran d'attente n'a rien à dépiler (lien profond,
  /// notification) : le détail de l'envoi ou le fil.
  String get fallbackRoute => '$_prefix/$id';

  /// Libellé analytics (`bid` / `negotiation`).
  String get analyticsName;

  @override
  List<Object?> get props => [runtimeType, id];
}

final class BidMobileMoneyScope extends MobileMoneyScope {
  const BidMobileMoneyScope(super.id);
  @override
  String get _prefix => '/bids';
  @override
  String get analyticsName => 'bid';
}

final class NegotiationMobileMoneyScope extends MobileMoneyScope {
  const NegotiationMobileMoneyScope(super.id);
  @override
  String get _prefix => '/negotiations';
  @override
  String get analyticsName => 'negotiation';
}
