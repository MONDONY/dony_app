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

/// Purge l'état du bloc à la frontière d'identité (logout, changement de
/// compte, suppression). Le bloc est un singleton getIt : sans reset, le
/// statut Stripe du compte précédent survit et peut s'afficher pour le
/// compte suivant (ex. « Compte bancaire connecté » pour un expéditeur
/// qui n'a jamais fait l'onboarding).
class StripeAccountReset extends StripeAccountEvent {
  const StripeAccountReset();
}
