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
  ///
  /// Route **brute**, sans marqueur d'entrée : à n'utiliser que pour comparer
  /// ou pour construire une entrée hors parcours. Toute navigation interne au
  /// parcours passe par [onboardingRoute].
  final String route;

  /// Route à emprunter **depuis le parcours**, marqueur d'entrée compris.
  ///
  /// [identity] et [payouts] ont une seconde entrée par le profil. Sans
  /// `?from=onboarding`, le routeur les construit avec `progress: null` : ni
  /// jauge, ni enchaînement vers l'étape suivante. Le parcours s'arrêtait donc
  /// en silence dès qu'on y entrait par [route], et l'utilisateur retombait à
  /// l'accueil sans jamais voir les paiements.
  ///
  /// Les autres étapes n'existent que dans le parcours : leur route brute
  /// suffit. Ce getter est l'unique point de construction, pour qu'un nouveau
  /// call site ne puisse plus oublier le marqueur.
  String get onboardingRoute => switch (this) {
    identity ||
    payouts => '$route${onboardingEntrySuffix(fromOnboarding: true)}',
    _ => route,
  };

  /// Nom montré à l'utilisateur (jauge du parcours, carte de reprise).
  String get displayLabel => switch (this) {
    consent => 'Confidentialité',
    country => 'Pays',
    identity => 'Identité',
    address => 'Adresse',
    payouts => 'Paiements',
  };
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
    this.reachedPast,
  });

  /// Les étapes comptées, dans l'ordre. Quatre ou cinq selon la couverture
  /// Stripe du pays.
  final List<OnboardingStep> steps;

  /// Celles dont le fait serveur existe.
  final Set<OnboardingStep> done;

  /// L'étape que l'écran courant remplit, ou `null` sur un écran hors décompte
  /// (parrainage).
  final OnboardingStep? current;

  /// Sur un écran hors décompte, la dernière étape comptée située **avant**
  /// lui dans le parcours (l'adresse, pour le parrainage). Sert uniquement à
  /// l'affichage : elle ancre la position quand [current] est `null`.
  final OnboardingStep? reachedPast;

  int get total => steps.length;
  int get doneCount => done.length;

  /// Les paiements sont-ils ouverts à ce compte ?
  ///
  /// Stripe Connect n'ouvre jamais de compte à une identité non vérifiée
  /// (règle produit ; le serveur refuse aussi par un 422 `kyc-required`).
  /// Une étape identité **passée** verrouille donc les paiements : le parcours
  /// se termine à l'accueil plutôt que de mener à un refus, et la carte de
  /// reprise reproposera l'identité d'abord.
  bool get payoutsUnlocked => done.contains(OnboardingStep.identity);

  bool _reachable(OnboardingStep step) =>
      step != OnboardingStep.payouts || payoutsUnlocked;

  /// Copie de cette progression où [step] compte comme faite.
  ///
  /// [done] est un instantané pris à la construction de l'écran. Quand cet
  /// écran vient précisément de faire aboutir son étape, il doit corriger
  /// l'instantané avant de demander la suite : sans ça, une identité tout
  /// juste vérifiée laisserait [payoutsUnlocked] à faux et enverrait à
  /// l'accueil au lieu des paiements.
  OnboardingProgress completing(OnboardingStep step) =>
      OnboardingProgress(steps: steps, done: {...done, step}, current: current);

  /// Première étape de [steps] absente de [done] et atteignable, ou `null` si
  /// plus rien n'est à faire.
  ///
  /// Sert à l'écran de parrainage, seul écran hors décompte : c'est le
  /// premier point du parcours où plusieurs étapes (identité, paiements)
  /// peuvent rester à faire en même temps, donc le seul où « l'étape
  /// suivante » ne peut pas être déduite de la position dans [steps] (voir
  /// [routeAfter] pour tous les autres écrans).
  OnboardingStep? get next {
    for (final step in steps) {
      if (!done.contains(step)) return _reachable(step) ? step : null;
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
      if (!done.contains(candidate)) {
        return _reachable(candidate) ? candidate : null;
      }
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
  /// étape ne doit jamais y faire boucler dessus. Seule exception, une étape
  /// **verrouillée** (voir [payoutsUnlocked]) clôt le parcours : y conduire
  /// n'offrirait qu'un refus.
  ///
  /// Rend [OnboardingStep.onboardingRoute] et non [OnboardingStep.route] :
  /// l'écran suivant doit hériter du marqueur d'entrée, sinon il s'affiche
  /// sans jauge et le parcours s'y arrête.
  String routeAfter(OnboardingStep step) {
    final index = steps.indexOf(step);
    if (index == -1 || index + 1 >= steps.length) return '/home';
    final follower = steps[index + 1];
    return _reachable(follower) ? follower.onboardingRoute : '/home';
  }

  /// Nombre d'étapes franchies **positionnellement** — l'index de l'écran
  /// courant dans le parcours, que les étapes derrière soient remplies ou
  /// passées. C'est le sens du compteur pendant le parcours : « étape 4 sur
  /// 5 », pas « 2 remplies sur 5 » (retour utilisateur : un compteur qui
  /// stagne à 2/5 sur l'identité après avoir passé l'adresse se lit comme un
  /// parcours cassé, pas comme un état de compte).
  ///
  /// `-1` quand aucune position n'est connue ([current] et [reachedPast]
  /// `null`) : hors parcours (carte de reprise du profil), l'affichage
  /// retombe sur les faits accomplis, seuls pertinents là-bas.
  int get _positionIndex {
    if (current != null) return steps.indexOf(current!);
    if (reachedPast != null) return steps.indexOf(reachedPast!) + 1;
    return -1;
  }

  /// Traduction pour `DonyOnboardingGauge`, qui ne connaît aucune étape métier.
  ///
  /// **Dans le parcours** ([current] ou [reachedPast] posé) : position — tout
  /// ce qui est derrière l'écran courant est plein, y compris une étape
  /// passée ; l'étape en cours est à demi remplie. Le libellé de la jauge
  /// (plein + en cours) donne alors « 4 / 5 · Identité » sur le 4e écran.
  ///
  /// **Hors parcours** (profil) : faits accomplis — une étape passée reste
  /// vide, car ici la jauge répond « qu'est-ce qui manque à ce compte », pas
  /// « où en suis-je dans le parcours ».
  List<DonyGaugeSegment> get segments {
    final position = _positionIndex;
    if (position < 0) {
      return [
        for (final step in steps)
          done.contains(step) ? DonyGaugeSegment.done : DonyGaugeSegment.todo,
      ];
    }
    return [
      for (var i = 0; i < steps.length; i++)
        if (i < position)
          DonyGaugeSegment.done
        else if (i == position && current != null)
          DonyGaugeSegment.current
        else
          DonyGaugeSegment.todo,
    ];
  }
}

/// Même déduction que [nextStep], mais rendue en entier plutôt qu'arrêtée à la
/// première étape manquante. Pure, mêmes arguments.
OnboardingProgress onboardingProgress({
  required UserModel? user,
  required StripeAccountState stripe,
  required bool analyticsAnswered,
  String? countryFallback,
  OnboardingStep? current,
  OnboardingStep? reachedPast,
}) {
  final steps = onboardingSteps(stripe);
  return OnboardingProgress(
    steps: steps,
    reachedPast: reachedPast,
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
    effectiveStripeStatus(user, stripe) == 'ONBOARDING_COMPLETE',
};

/// Le statut du bloc fait foi quand il est chargé ; sinon celui porté par le
/// profil. Sans ce repli, le résolveur serait aveugle pendant tout le parcours
/// post-inscription : `StripeAccountBloc` n'est chargé que par
/// `MainShell.initState`, et les routes `/auth/*` sont hors shell.
///
/// Public parce que la bannière de complétion du profil doit trancher
/// exactement de la même façon : deux règles divergentes afficheraient
/// « paiements à faire » sur un compte que le résolveur considère complet.
String effectiveStripeStatus(UserModel? user, StripeAccountState stripe) =>
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
  OnboardingStep? reachedPast,
  String? countryFallback,
}) => onboardingProgress(
  user: context.read<AuthBloc>().state.currentUser,
  stripe: context.read<StripeAccountBloc>().state,
  reachedPast: reachedPast,
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
