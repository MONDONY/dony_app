abstract class BidAcceptanceEvent {}

class BidAcceptRequested extends BidAcceptanceEvent {
  final String bidId;

  /// Portefeuille choisi par le voyageur pour payer, au taux du jour, ce que
  /// le portefeuille de la devise du trajet ne couvre pas (FLUTTER-CG).
  /// `null` : prélèvement par défaut (devise du trajet puis devise active).
  final String? fundingCurrency;

  BidAcceptRequested(this.bidId, {this.fundingCurrency});
}

/// Retry forcé avec la carte de commission (choisi par le voyageur après solde insuffisant).
class BidAcceptWithCardRequested extends BidAcceptanceEvent {
  final String bidId;
  BidAcceptWithCardRequested(this.bidId);
}

/// Oublie les refus définitifs mémorisés (liste rechargée par le voyageur) :
/// l'acceptation de ces demandes repart au serveur au prochain essai.
class BidAcceptanceRefusalsCleared extends BidAcceptanceEvent {}
