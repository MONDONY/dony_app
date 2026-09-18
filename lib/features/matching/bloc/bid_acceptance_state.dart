import 'package:dony/features/matching/data/models/commission_shortfall.dart';

abstract class BidAcceptanceState {}

class BidAcceptanceInitial extends BidAcceptanceState {}

class BidAccepting extends BidAcceptanceState {}

class BidAccepted extends BidAcceptanceState {}

class BidFailed extends BidAcceptanceState {
  final String message;
  final bool cardDeclined;
  BidFailed(this.message, {this.cardDeclined = false});
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
