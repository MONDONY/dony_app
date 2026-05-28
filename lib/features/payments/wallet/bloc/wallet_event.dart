part of 'wallet_bloc.dart';

abstract class WalletEvent {}

class WalletLoadRequested extends WalletEvent {}

class WalletTopupRequested extends WalletEvent {
  final double amount;
  final String paymentMethod; // 'STRIPE' | 'WAVE' | 'ORANGE_MONEY'

  WalletTopupRequested({required this.amount, required this.paymentMethod});
}
