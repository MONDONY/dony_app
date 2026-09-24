import 'package:dony/features/matching/data/models/commission_shortfall.dart';

abstract class BidAcceptanceState {}

class BidAcceptanceInitial extends BidAcceptanceState {}

class BidAccepting extends BidAcceptanceState {}

class BidAccepted extends BidAcceptanceState {}

/// Raison d'un échec d'acceptation quand le serveur ne fournit pas de detail
/// exploitable (`serverMessage` vide ou absent) : `display()` choisit alors la
/// clé ARB correspondante — jamais de texte transporté par le bloc.
enum BidFailureReason { confirmFailed, bankAuthInterrupted, refused }

class BidFailed extends BidAcceptanceState {
  final String? serverMessage;
  final BidFailureReason reason;
  final bool cardDeclined;
  BidFailed({
    this.serverMessage,
    required this.reason,
    this.cardDeclined = false,
  });
}

class BidWalletInsufficient extends BidAcceptanceState {
  final double availableBalance;
  final double requiredCommission;
  final bool hasCard;
  final String bidId;
  final String? currency;
  final CommissionShortfall? breakdown;

  BidWalletInsufficient({
    required this.availableBalance,
    required this.requiredCommission,
    required this.hasCard,
    required this.bidId,
    this.currency,
    this.breakdown,
  });
}
