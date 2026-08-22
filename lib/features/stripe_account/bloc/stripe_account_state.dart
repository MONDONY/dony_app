part of 'stripe_account_bloc.dart';

sealed class StripeAccountState {
  const StripeAccountState();
}

class StripeAccountInitial extends StripeAccountState {
  const StripeAccountInitial();
}

class StripeAccountLoading extends StripeAccountState {
  const StripeAccountLoading();
}

class StripeAccountReady extends StripeAccountState {
  final ConnectAccountStatus accountStatus;
  const StripeAccountReady(this.accountStatus);
}

class StripeAccountLoadError extends StripeAccountState {
  const StripeAccountLoadError();
}

/// Dérivées de lecture sur l'état, pour que les écrans n'aient pas à filtrer
/// eux-mêmes les états non chargés.
extension StripeAccountAvailability on StripeAccountState {
  /// Stripe ouvre-t-il un compte connecté dans le pays de l'utilisateur ?
  ///
  /// Optimiste tant que le statut n'est pas chargé : un état autre que
  /// [StripeAccountReady] ne masque rien. C'est l'unique domicile de ce repli,
  /// pour qu'une inversion future de la règle se fasse à un seul endroit.
  bool get connectAvailableInCountry => switch (this) {
    StripeAccountReady(:final accountStatus) =>
      accountStatus.connectAvailableInCountry,
    _ => true,
  };
}
