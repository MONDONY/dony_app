import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

/// `/kyc/verify` et `/payments/onboarding` ont deux entrées possibles : le
/// parcours d'onboarding, et le profil (vérifier son identité ou activer les
/// paiements à tout moment, hors inscription). Ce query param est l'unique
/// signal qui les distingue — c'est lui qui décide si la jauge s'affiche et
/// si l'écran, une fois terminé ou passé, enchaîne sur l'étape suivante
/// plutôt que de rester sur place comme depuis le profil.
const String onboardingEntryParam = 'from';
const String onboardingEntryValue = 'onboarding';

/// Query string à coller à `OnboardingStep.identity.route` /
/// `OnboardingStep.payouts.route` pour marquer une navigation comme faisant
/// partie du parcours. `''` si [fromOnboarding] est faux, pour rester
/// concaténable sans condition au call site.
String onboardingEntrySuffix({required bool fromOnboarding}) =>
    fromOnboarding ? '?$onboardingEntryParam=$onboardingEntryValue' : '';

/// Les étapes comptées pour cet utilisateur, dans l'ordre.
///
/// L'ordre suit le parcours réel des écrans (`referral_code_screen.dart`
/// enchaîne adresse → parrainage → identité/paiements), pas l'ordre de la
/// spec §2 : l'adresse est remplie avant l'identité, donc elle doit être
/// numérotée avant elle — sans quoi la jauge annoncerait « 4/5 » sur un
/// écran atteint en 3e position (revue de bout en bout, correction du trou
/// du parcours).
///
/// « Paiements » disparaît quand Stripe n'ouvre pas de compte connecté dans le
/// pays : la jauge passe à quatre segments et l'utilisateur atteint réellement
/// 4/4. `connectAvailableInCountry` est optimiste tant que le statut n'est pas
/// chargé (`stripe_account_state.dart`), donc un segment n'est jamais perdu par
/// accident réseau.
List<OnboardingStep> onboardingSteps(StripeAccountState stripe) => [
  OnboardingStep.consent,
  OnboardingStep.country,
  OnboardingStep.address,
  OnboardingStep.identity,
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
/// Ne teste **jamais** `onboardingSeenAt` : cette fonction ne fait que
/// traduire les faits serveur en étape manquante, elle ne décide pas si le
/// parcours doit s'imposer. Ce court-circuit anti-boucle (un utilisateur qui
/// a explicitement quitté le parcours ne doit pas y être renvoyé) vit
/// uniquement dans [resolvePostSignupRoute], le seul appelant qui route
/// réellement une navigation. Le mettre ici aussi le rendrait mort (le
/// résolveur court-circuite déjà avant d'appeler cette fonction) tout en
/// mettant [nextStep] en contradiction avec [onboardingProgress] — cette
/// dernière doit continuer de refléter les étapes faites même après
/// `onboarding_seen_at`, pour que la carte de reprise (lot 4) sache quand
/// elle doit disparaître.
OnboardingStep? nextStep({
  required UserModel? user,
  required StripeAccountState stripe,
  required bool analyticsAnswered,
  String? countryFallback,
}) {
  for (final step in onboardingSteps(stripe)) {
    if (!_isDone(
      step,
      user: user,
      stripe: stripe,
      analyticsAnswered: analyticsAnswered,
      countryFallback: countryFallback,
    )) {
      return step;
    }
  }
  return null;
}

/// L'état de l'onboarding tel que la jauge doit le montrer : lesquelles sont
/// faites, laquelle est en cours, combien il en reste.
class OnboardingProgress {
  const OnboardingProgress({
    required this.steps,
    required this.done,
    this.current,
  });

  /// Les étapes comptées, dans l'ordre. Quatre ou cinq selon la couverture
  /// Stripe du pays.
  final List<OnboardingStep> steps;

  /// Celles dont le fait serveur existe.
  final Set<OnboardingStep> done;

  /// L'étape que l'écran courant remplit, ou `null` sur un écran hors décompte
  /// (parrainage).
  final OnboardingStep? current;

  int get total => steps.length;
  int get doneCount => done.length;

  /// Première étape de [steps] absente de [done], ou `null` si tout est fait.
  ///
  /// Sert à l'écran de parrainage, seul écran hors décompte : c'est le
  /// premier point du parcours où plusieurs étapes (identité, paiements)
  /// peuvent rester à faire en même temps, donc le seul où « l'étape
  /// suivante » ne peut pas être déduite de la position dans [steps] (voir
  /// [routeAfter] pour tous les autres écrans).
  OnboardingStep? get next {
    for (final step in steps) {
      if (!done.contains(step)) return step;
    }
    return null;
  }

  /// Première étape non faite située **après** [step] dans [steps], ou `null`
  /// si plus rien ne reste au-delà.
  ///
  /// Contrairement à [next], ne revient jamais en arrière. Une étape *passée*
  /// n'entre pas dans [done] par construction (« passer n'est pas terminer ») :
  /// la redésigner ferait boucler le parcours indéfiniment sur elle. Le
  /// parrainage s'en sert en partant de l'adresse, l'écran qui le précède.
  OnboardingStep? nextAfter(OnboardingStep step) {
    final index = steps.indexOf(step);
    if (index == -1) return next;
    for (final candidate in steps.skip(index + 1)) {
      if (!done.contains(candidate)) return candidate;
    }
    return null;
  }

  /// Route de l'écran qui suit [step] dans [steps], ou `/home` si [step] est
  /// la dernière (ou absente, ce qui ne devrait jamais arriver pour un écran
  /// qui s'y trouve).
  ///
  /// Positionnelle, volontairement indifférente à [done] : les écrans
  /// identité et paiements enchaînent sur le suivant qu'ils viennent de
  /// compléter l'étape ou de la passer — contrairement à [next], passer une
  /// étape ne doit jamais y faire boucler dessus.
  String routeAfter(OnboardingStep step) {
    final index = steps.indexOf(step);
    if (index == -1 || index + 1 >= steps.length) return '/home';
    return steps[index + 1].route;
  }

  /// Traduction pour `DonyOnboardingGauge`, qui ne connaît aucune étape métier.
  ///
  /// Une étape **passée reste vide** : passer n'est pas terminer (spec §4.2).
  List<DonyGaugeSegment> get segments => [
    for (final step in steps)
      if (done.contains(step))
        DonyGaugeSegment.done
      else if (step == current)
        DonyGaugeSegment.current
      else
        DonyGaugeSegment.todo,
  ];
}

/// Même déduction que [nextStep], mais rendue en entier plutôt qu'arrêtée à la
/// première étape manquante. Pure, mêmes arguments.
OnboardingProgress onboardingProgress({
  required UserModel? user,
  required StripeAccountState stripe,
  required bool analyticsAnswered,
  String? countryFallback,
  OnboardingStep? current,
}) {
  final steps = onboardingSteps(stripe);
  return OnboardingProgress(
    steps: steps,
    done: {
      for (final step in steps)
        if (_isDone(
          step,
          user: user,
          stripe: stripe,
          analyticsAnswered: analyticsAnswered,
          countryFallback: countryFallback,
        ))
          step,
    },
    current: current,
  );
}

bool _isDone(
  OnboardingStep step, {
  required UserModel? user,
  required StripeAccountState stripe,
  required bool analyticsAnswered,
  String? countryFallback,
}) => switch (step) {
  OnboardingStep.consent => analyticsAnswered,
  OnboardingStep.country =>
    _hasText(user?.country) || _hasText(countryFallback),
  OnboardingStep.identity => user?.isKycVerified ?? false,
  OnboardingStep.address => _hasText(user?.residenceStreet),
  OnboardingStep.payouts =>
    _stripeStatus(user, stripe) == 'ONBOARDING_COMPLETE',
};

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

// ─── Lecture de l'état ambiant ───────────────────────────────────────────────
//
// Seul point impur du fichier. Il vit ici plutôt que dans `router.dart` pour
// rester à côté de la règle qu'il applique, et il n'est appelé que par les
// builders du routeur : les écrans du parcours restent montables sans provider
// ambiant (cf. `residence_address_screen.dart`).

/// Lit les blocs fournis à l'échelle de l'application et rend la progression.
///
/// [countryFallback] permet à l'appelant de fournir une source plus fraîche
/// que `BusinessPrefsBloc.state.country` (repli par défaut ci-dessous) : ce
/// singleton app-wide n'est jamais resynchronisé quand
/// `CountryOnboardingCubit.select()` écrit directement dans Hive, sans jamais
/// dispatcher `CountryChanged`. `router.dart` passe donc explicitement
/// `(state.extra as String?) ?? BusinessPrefsBloc.state.country` sur les
/// routes atteintes juste après le choix du pays — sans ce paramètre, la
/// jauge afficherait l'étape « Pays » comme non faite juste après l'avoir
/// choisie, et ce jusqu'à un redémarrage à froid de l'app.
OnboardingProgress readOnboardingProgress(
  BuildContext context, {
  OnboardingStep? current,
  String? countryFallback,
}) => onboardingProgress(
  user: context.read<AuthBloc>().state.currentUser,
  stripe: context.read<StripeAccountBloc>().state,
  analyticsAnswered:
      !getIt<AnalyticsService>().isConfigured ||
      getIt<AnalyticsService>().hasAnswered,
  // `POST /auth/register` n'écrit pas `users.country` et le profil en cache
  // n'est pas rafraîchi après l'étape pays : même repli que `router.dart` pour
  // l'écran d'adresse.
  countryFallback:
      countryFallback ?? context.read<BusinessPrefsBloc>().state.country,
  current: current,
);
