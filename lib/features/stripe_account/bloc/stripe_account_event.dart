part of 'stripe_account_bloc.dart';

sealed class StripeAccountEvent {
  const StripeAccountEvent();
}

class StripeAccountStatusLoaded extends StripeAccountEvent {
  const StripeAccountStatusLoaded();
}

class StripeAccountStatusRefreshed extends StripeAccountEvent {
  /// Passe par [StripeAccountLoading] pendant l'appel quand le compte n'est
  /// pas déjà complet. Pour un écran qui affiche le statut : sans cela, il
  /// montrerait « non activé » le temps de la resynchronisation, alors que la
  /// réponse va peut-être dire le contraire (Sentry FLUTTER-D2). Un compte
  /// complet reste affiché tel quel pendant l'appel.
  final bool showProgress;

  const StripeAccountStatusRefreshed({this.showProgress = false});
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
