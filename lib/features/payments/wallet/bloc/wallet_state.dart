part of 'wallet_bloc.dart';

sealed class WalletState {}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final WalletModel wallet;

  WalletLoaded(this.wallet);
}

class WalletTopupStripeReady extends WalletState {
  final String clientSecret;

  WalletTopupStripeReady(this.clientSecret);
}

class WalletTopupRedirectReady extends WalletState {
  final String redirectUrl;

  WalletTopupRedirectReady(this.redirectUrl);
}

class WalletError extends WalletState {
  final String message;

  WalletError(this.message);
}
