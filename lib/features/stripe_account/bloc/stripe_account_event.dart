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

/// Revient à [StripeAccountInitial], comme un `StripeAccountBloc` tout neuf.
///
/// `StripeAccountBloc` est un `lazySingleton` GetIt : `AuthBloc` ne le
/// recrée jamais. Sans cet event, le bloc continuerait de porter le statut
/// Connect (potentiellement `ONBOARDING_COMPLETE`) du compte précédent après
/// une déconnexion, un changement de compte ou une nouvelle inscription —
/// faisant croire à `nextStep` que l'étape « paiements » du nouveau compte
/// est déjà faite. Dispatché depuis `app.dart`
/// (`AccountResetGuard.shouldResetAccountScopedBlocs`), jamais depuis un
/// autre bloc (cf. `lib/features/auth/account_reset_guard.dart`).
class StripeAccountReset extends StripeAccountEvent {
  const StripeAccountReset();
}
