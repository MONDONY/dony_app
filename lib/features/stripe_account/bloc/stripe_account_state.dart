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

  /// Faut-il redemander le statut à Stripe au retour au premier plan ?
  ///
  /// Seulement si le statut peut encore changer : inscription en cours ou
  /// compte suspendu. Un compte complet est tenu à jour par le webhook
  /// `account.updated`, un compte absent ferait répondre 409, et chaque appel
  /// coûte environ 400 ms d'aller-retour Stripe côté serveur.
  bool get shouldResyncOnResume => switch (this) {
    StripeAccountReady(:final accountStatus) =>
      accountStatus.connectAvailableInCountry &&
          (accountStatus.isOnboardingIncomplete || accountStatus.isDisabled),
    StripeAccountLoadError() => true,
    _ => false,
  };
}
