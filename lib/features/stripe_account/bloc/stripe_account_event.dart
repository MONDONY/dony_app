part of 'stripe_account_bloc.dart';

sealed class StripeAccountEvent {
  const StripeAccountEvent();
}

class StripeAccountStatusLoaded extends StripeAccountEvent {
  const StripeAccountStatusLoaded();
}

class StripeAccountStatusRefreshed extends StripeAccountEvent {
  const StripeAccountStatusRefreshed();
}
