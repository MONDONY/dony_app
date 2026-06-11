part of 'wallet_bloc.dart';

sealed class WalletEvent {}

class WalletLoadRequested extends WalletEvent {}

/// Après une recharge : poller le solde jusqu'à ce qu'il dépasse
/// [previousBalance] (le crédit Stripe arrive de façon asynchrone via webhook),
/// ou jusqu'à épuisement des tentatives. Évite que l'écran reste sur l'ancien
/// solde quand le webhook met quelques secondes à créditer.
class WalletRefreshAfterTopupRequested extends WalletEvent {
  final double previousBalance;

  WalletRefreshAfterTopupRequested(this.previousBalance);
}

class WalletTopupRequested extends WalletEvent {
  final double amount;
  final String paymentMethod; // 'STRIPE' | 'WAVE' | 'ORANGE_MONEY'

  WalletTopupRequested({required this.amount, required this.paymentMethod});
}
