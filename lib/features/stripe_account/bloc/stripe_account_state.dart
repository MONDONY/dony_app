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
