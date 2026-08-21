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

/// Porte l'`AppException` entière, comme `BidError` : n'en garder que le
/// `message` jetait le code métier, et l'`ErrorCatalog` retombait alors
/// systématiquement sur son message générique — les entrées dédiées
/// (`wallet-topup-stripe-error`, `unsupported-currency`, …) étaient
/// inatteignables, et le serveur expliquait quoi faire dans le vide.
class WalletError extends WalletState {
  final AppException error;

  WalletError(this.error);

  /// Détail brut du serveur. À NE JAMAIS afficher tel quel : passer l'état
  /// (ou `error`) à `ErrorPresenter`, qui résout le code via `ErrorCatalog`.
  String get message => error.message;
}
