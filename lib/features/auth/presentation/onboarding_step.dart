import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';

/// Étapes **comptées** de l'onboarding progressif.
///
/// Le parrainage n'en fait pas partie : il n'apporte rien au compte et reste
/// facultatif ; l'y compter ferait stagner un compteur que l'utilisateur croit
/// devoir remplir (spec §4.2).
///
/// Aucune progression n'est stockée : chaque étape est « faite » si le fait
/// serveur correspondant existe déjà (spec §2). C'est ce qui rend l'état juste
/// sans une ligne de synchronisation quand la vérification d'identité est faite
/// depuis le profil, quand l'onboarding Connect est terminé depuis le lien reçu
/// par e-mail, ou après une réinstallation.
enum OnboardingStep {
  consent('consent', '/auth/analytics-consent'),
  country('country', '/auth/country-selection'),
  identity('identity', '/kyc/verify'),
  address('address', '/auth/residence-address'),
  payouts('payouts', '/payments/onboarding');

  const OnboardingStep(this.wireName, this.route);

  /// Valeur envoyée dans les properties analytics. Énumération fermée, jamais
  /// de texte libre (spec §6).
  final String wireName;

  /// Route GoRouter de l'écran qui remplit l'étape.
  final String route;
}

/// Les étapes comptées pour cet utilisateur, dans l'ordre.
///
/// « Paiements » disparaît quand Stripe n'ouvre pas de compte connecté dans le
/// pays : la jauge passe à quatre segments et l'utilisateur atteint réellement
/// 4/4. `connectAvailableInCountry` est optimiste tant que le statut n'est pas
/// chargé (`stripe_account_state.dart`), donc un segment n'est jamais perdu par
/// accident réseau.
List<OnboardingStep> onboardingSteps(StripeAccountState stripe) => [
  OnboardingStep.consent,
  OnboardingStep.country,
  OnboardingStep.identity,
  OnboardingStep.address,
  if (stripe.connectAvailableInCountry) OnboardingStep.payouts,
];

/// Première étape non satisfaite, ou `null` si le compte est complet.
///
/// Fonction **pure** : ni réseau, ni widget, ni `BuildContext`. Un test par
/// combinaison d'états.
///
/// [user] est nullable : au routeur, `AuthBloc.state.currentUser` rend `null`
/// sur `AuthInitial`/`AuthLoading`.
///
/// [countryFallback] est indispensable et non optionnel dans les faits :
/// `POST /auth/register` n'écrit pas `users.country`, et le `UserModel` en
/// cache n'est jamais rafraîchi après l'étape pays. Le routeur applique déjà
/// ce même repli (`BusinessPrefsBloc.state.country`) pour l'écran d'adresse.
///
/// `onboardingSeenAt != null` est testé **avant** toute étape : `skip()` et
/// `continueAsSenderOnly()` (`CountryOnboardingCubit`) laissent volontairement
/// `country` à `null`, donc router uniquement sur les faits ci-dessous
/// renverrait indéfiniment un utilisateur qui a explicitement quitté le
/// parcours vers cet écran (spec §2, correction 3).
OnboardingStep? nextStep({
  required UserModel? user,
  required StripeAccountState stripe,
  required bool analyticsAnswered,
  String? countryFallback,
}) {
  if (user?.onboardingSeenAt != null) return null;

  for (final step in onboardingSteps(stripe)) {
    final done = switch (step) {
      OnboardingStep.consent => analyticsAnswered,
      OnboardingStep.country =>
        _hasText(user?.country) || _hasText(countryFallback),
      OnboardingStep.identity => user?.isKycVerified ?? false,
      OnboardingStep.address => _hasText(user?.residenceStreet),
      OnboardingStep.payouts =>
        _stripeStatus(user, stripe) == 'ONBOARDING_COMPLETE',
    };
    if (!done) return step;
  }
  return null;
}

/// Le statut du bloc fait foi quand il est chargé ; sinon celui porté par le
/// profil. Sans ce repli, le résolveur serait aveugle pendant tout le parcours
/// post-inscription : `StripeAccountBloc` n'est chargé que par
/// `MainShell.initState`, et les routes `/auth/*` sont hors shell.
String _stripeStatus(UserModel? user, StripeAccountState stripe) =>
    switch (stripe) {
      StripeAccountReady(:final accountStatus) => accountStatus.status,
      _ => user?.stripeAccountStatus ?? 'NOT_CREATED',
    };

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
