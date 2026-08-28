import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/billing/bloc/subscription_bloc.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/pro_portal_copy.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_banner.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_status_card.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ── Copie sous contrat ──────────────────────────────────────────────────────
// Les tarifs sont écrits une seule fois. L'économie annuelle est chiffrée en
// euros et ne doit jamais être traduite en mois offerts : 11,98 € valent
// 2,4 mois d'abonnement, tout arrondi en mois entiers serait faux.

const String _kMonthlyPrice = '4,99 € par mois';
const String _kYearlyPrice = '47,90 € par an';
const String _kYearlySaving = "Soit 11,98 € d'économie sur l'année.";
const String _kPortalHint =
    "L'abonnement se souscrit sur le site Yadony PRO, dans votre navigateur.";
const String _kPortalButtonLabel = "S'abonner sur le site Yadony PRO";

/// Où gérer et résilier un abonnement, et à quoi s'attendre en arrivant.
///
/// La mention de la connexion n'est pas du remplissage : la page de vente est
/// publique, la page de gestion ne l'est pas. Sans cet avertissement,
/// l'utilisateur tombe sur une demande de code sans y avoir été préparé.
const String _kManageGuidance =
    'La gestion et la résiliation de votre abonnement se font sur le site '
    'Yadony PRO, dans votre navigateur. Une connexion vous y sera demandée.';

/// Message opposé au refus `409 active-stripe-subscription`. Le serveur ne
/// laisse pas résilier un abonnement Stripe encore actif depuis l'app : le
/// dire, plutôt que de rendre l'erreur brute, est la seule sortie utile.
const String _kDowngradeBlockedMessage =
    'Votre abonnement PRO est toujours actif. $_kManageGuidance';

/// Le serveur n'accorde plus l'accès, alors que le drapeau PRO local dit
/// encore le contraire. Voir `_loaded` sur pourquoi c'est `active` qui fait
/// foi ici.
const String _kAccessEndedMessage =
    "Votre accès PRO n'est plus actif. Vous pouvez reprendre un abonnement "
    'sur le site Yadony PRO.';

/// `none` ne dit pas « votre accès a pris fin », il dit « aucun abonnement ».
/// L'utilisateur n'en a peut-être jamais eu : lui annoncer une fin lui
/// raconterait un passé qui n'a pas eu lieu.
const String _kNoSubscriptionMessage =
    "Vous n'avez pas d'abonnement PRO. Vous pouvez en souscrire un sur le "
    'site Yadony PRO.';

/// Écran « compte PRO », en deux vues :
///
///   • non abonné : page de vente purement informative, qui renvoie au
///     portail web. Aucun formulaire : `POST /auth/me/upgrade-to-pro`
///     n'accorde plus le statut PRO côté serveur, et `UserResponse` ne rend
///     ni `companyName` ni `siret` (les champs Dart correspondants sont donc
///     toujours nuls). Un formulaire local ne collecterait qu'une donnée que
///     l'application ne peut pas relire.
///   • abonné : état réel de l'abonnement, gestion sur le portail quand elle
///     existe, retour au compte standard quand il est possible.
///
/// La route `/profile/upgrade-to-pro` et ce nom de classe sont conservés :
/// cinq écrans y renvoient.
class UpgradeToProScreen extends StatelessWidget {
  const UpgradeToProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UpgradeToProBloc>(
          create: (_) => getIt<UpgradeToProBloc>(),
        ),
        BlocProvider<SubscriptionBloc>(
          // Construction NON paresseuse, et c'est une garantie, pas un
          // détail. Le `BlocListener<AuthBloc>` ci-dessous lit ce BLoC pour
          // lui envoyer sa demande ; si le BLoC n'existait pas encore à cet
          // instant, cette lecture le construirait, `create` relirait un état
          // déjà PRO et enverrait une PREMIÈRE demande, immédiatement suivie
          // de celle du listener. Deux appels réseau. Le cas est écarté
          // aujourd'hui parce qu'un autre listener force la création dès la
          // première image, mais s'appuyer là-dessus ferait réapparaître le
          // doublon le jour où ce listener disparaîtrait.
          lazy: false,
          create: (_) {
            final bloc = getIt<SubscriptionBloc>();
            // Cas du compte déjà PRO au montage. La bascule ultérieure est
            // couverte séparément, par le `BlocListener<AuthBloc>` de
            // `_UpgradeToProView` : décider ici et seulement ici figerait la
            // décision à la construction, alors que le rendu, lui, suit
            // l'état d'authentification en continu.
            //
            // `GET /billing/subscription` répond 200 même sans abonnement,
            // mais rien de ce qu'il rend n'est affiché à un non-abonné : la
            // vue de vente n'a aucun état à montrer. Interroger l'endpoint
            // pour eux serait une requête inutile.
            if (_isPro(context.read<AuthBloc>().state)) {
              bloc.add(const SubscriptionRequested());
            }
            return bloc;
          },
        ),
      ],
      child: const _UpgradeToProView(),
    );
  }
}

/// L'utilisateur porté par l'état d'authentification, quel que soit l'état
/// concret qui le transporte.
UserModel? _userOf(AuthState state) => switch (state) {
  AuthAuthenticated(:final user) => user,
  AuthProfileUpdated(:final user) => user,
  _ => null,
};

bool _isPro(AuthState state) => _userOf(state)?.isProAccount ?? false;

/// Vrai quand [state] renseigne réellement sur la session, et doit donc être
/// pris en compte pour décider quoi afficher.
///
/// Le critère n'est PAS « cet état porte-t-il un utilisateur ». Un état sans
/// utilisateur peut être parfaitement informatif (`AuthInitial` après une
/// déconnexion, `AuthAccountDeleted`, `AuthLocked`), et le filtrer figerait
/// l'écran sur la vue d'abonné, carte et bouton de résiliation compris, alors
/// que la session est fermée. Le routeur ne redirige pas sur une déconnexion
/// volontaire survenant écran ouvert : rien d'autre ne rattraperait le coup.
///
/// Deux familles n'apprennent rien sur la session et ne doivent donc rien
/// changer à l'affichage :
///
///  - [AuthLoading] : état de **passage**, émis par `AuthCheckRequested`
///    entre la demande et la réponse. Le traiter comme « non PRO » ferait
///    défiler la page de vente, tarifs compris, sous les yeux d'un abonné
///    dont le profil se rafraîchit.
///  - [AuthError] : état **surchargé**, qui rapporte l'échec d'une action
///    annexe alors que l'utilisateur reste pleinement authentifié. Six
///    émetteurs dans `AuthBloc` sont dans ce cas : mise à jour de profil,
///    envoi d'avatar, ajout de téléphone, ajout d'e-mail, suppression de
///    compte, et rafraîchissement de profil. Ce n'est jamais un signal de fin
///    de session : même sur le tout premier contrôle, `_onCheckRequested`
///    s'abstient délibérément de déconnecter sur un 401/403, qui peut être
///    transitoire. Un envoi d'avatar qui échoue ne doit pas escamoter
///    l'abonnement d'un abonné valide.
///
/// Tout le reste renseigne, avec ou sans utilisateur, et provoque un rendu.
bool _informsAboutSession(AuthState state) =>
    state is! AuthLoading && state is! AuthError;

class _UpgradeToProView extends StatefulWidget {
  const _UpgradeToProView();

  @override
  State<_UpgradeToProView> createState() => _UpgradeToProViewState();
}

class _UpgradeToProViewState extends State<_UpgradeToProView>
    with WidgetsBindingObserver {
  /// Vrai entre le moment où cet écran envoie l'utilisateur dans le
  /// navigateur et son retour dans l'application. Sans ce drapeau, il
  /// faudrait rafraîchir le profil à CHAQUE reprise, c'est-à-dire à chaque
  /// bascule d'application, pour rien.
  bool _hasLaunchedBrowser = false;

  /// Dernière PRO-ness **réellement connue**. `null` tant qu'aucun état
  /// d'authentification informatif n'est passé (démarrage à froid).
  bool? _lastKnownIsPro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Aligné sur ce que `create` a déjà décidé pour le BLoC d'abonnement :
    // si l'utilisateur est déjà PRO au montage, la demande est partie, et
    // l'écouteur ne doit pas la doubler au premier état reçu.
    final state = context.read<AuthBloc>().state;
    if (_informsAboutSession(state)) {
      _lastKnownIsPro = _isPro(state);
    }
    // Event de vue : mesure toujours la même intention (« je regarde le
    // compte PRO »), que l'écran vende ou gère l'abonnement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.upgradeToProStarted),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Le parcours nominal du lot se termine **hors de l'application** : on
  /// s'abonne sur le portail web, puis on revient. Rien dans l'app ne
  /// rafraîchit le profil à ce moment-là — l'observateur de cycle de vie
  /// global ne recharge que le compte Stripe Connect, et cet écran est une
  /// route hors du shell qui le porte. Sans ce rappel, l'abonné qui revient
  /// retrouve la page de vente et son unique bouton, qui le renvoie au
  /// portail qu'il vient de quitter : il boucle, et seul un redémarrage
  /// complet corrige l'affichage.
  ///
  /// `AuthProfileRefreshRequested` et non `AuthCheckRequested` : le premier
  /// recharge le profil **sans émettre `AuthLoading`**, donc sans faire
  /// clignoter l'écran au retour.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_hasLaunchedBrowser) {
      return;
    }
    _hasLaunchedBrowser = false;
    if (!mounted) return;
    context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
    // Et l'abonnement lui-même, systématiquement. Le conditionner à l'état du
    // BLoC (« ne recharger que si rien n'a jamais été chargé ») neutralisait
    // ce rappel pour tout le monde sauf les non-abonnés : l'impayé qui vient
    // de payer, l'accès fermé qui vient de se réabonner et la résiliation
    // faite sur le portail restaient tous invisibles au retour. Ce qui
    // justifie de recharger n'est pas « rien n'a été chargé », c'est « je
    // reviens d'un portail où l'abonnement a pu changer ».
    context.read<SubscriptionBloc>().add(const SubscriptionRequested());
  }

  /// Point de passage unique de toutes les ouvertures du portail, pour que le
  /// drapeau de retour ne puisse pas être oublié sur un chemin.
  void _openPortal(BuildContext context, ProPortalTarget target) {
    _hasLaunchedBrowser = true;
    context.read<SubscriptionBloc>().add(ProPortalOpenRequested(target));
  }

  Future<void> _confirmDowngrade(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Désactiver le compte PRO',
      message:
          'Votre badge PRO et vos avantages professionnels seront retirés de '
          'votre profil.',
      // Verbe explicite plutôt que « Confirmer » : sur une action
      // destructive, le bouton doit nommer ce qu'il déclenche, pas se
      // contenter d'acquiescer.
      confirmLabel: 'Désactiver',
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed == true && context.mounted) {
      context.read<UpgradeToProBloc>().add(const DowngradeRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Le compte peut devenir PRO alors que cet écran est déjà monté :
        // c'est le parcours nominal (l'utilisateur s'abonne sur le portail
        // web puis revient), et c'est aussi le démarrage à froid, où le
        // profil se résout après le premier rendu. Le rendu, lui, suit
        // l'AuthBloc en continu. Sans ce listener, la vue basculerait sur la
        // vue abonnée sans qu'aucune demande d'abonnement n'ait jamais été
        // émise, et l'écran resterait sur son état de chargement.
        // Le compte DEVIENT PRO alors que l'écran est monté : démarrage à
        // froid dont le profil se résout après le premier rendu, ou compte
        // qui bascule. La bascule se mesure sur la dernière PRO-ness
        // réellement connue, mémorisée ici, et non sur `previous` : un cycle
        // PRO → chargement → PRO se lirait sinon comme une bascule
        // « non PRO vers PRO » et redemanderait un abonnement déjà chargé.
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => _informsAboutSession(current),
          listener: (context, state) {
            final isPro = _isPro(state);
            final wasPro = _lastKnownIsPro;
            _lastKnownIsPro = isPro;
            // `wasPro != true` couvre aussi le cas « jamais rien su »
            // (`null`), c'est-à-dire le démarrage à froid, où le montage n'a
            // rien pu demander.
            if (isPro && wasPro != true) {
              context.read<SubscriptionBloc>().add(
                const SubscriptionRequested(),
              );
            }
          },
        ),
        BlocListener<UpgradeToProBloc, UpgradeToProState>(
          listener: (context, state) {
            if (state is DowngradeSuccess) {
              context.read<AuthBloc>().add(const AuthCheckRequested());
              DonySnackbar.show(
                context,
                message: 'Compte PRO désactivé.',
                type: DonySnackbarType.success,
              );
              if (context.canPop()) context.pop();
            } else if (state is DowngradeError) {
              // Filet de sécurité : le bouton de retour au compte standard
              // est masqué pour une source Stripe, mais un abonnement peut
              // avoir été souscrit sur le web pendant que cet écran était
              // déjà ouvert. Le refus se reconnaît au `code` du ProblemDetail,
              // jamais au titre ni au détail, qui sont de la copie serveur.
              if (state.error.code == kActiveStripeSubscriptionCode) {
                DonySnackbar.show(
                  context,
                  message: _kDowngradeBlockedMessage,
                  type: DonySnackbarType.warning,
                );
              } else {
                unawaited(ErrorPresenter.show(context, state.error));
              }
            }
          },
        ),
        BlocListener<SubscriptionBloc, SubscriptionState>(
          listener: (context, state) {
            // État transitoire de signalement (voir sa documentation) :
            // traité ici, jamais dans un builder.
            if (state is SubscriptionPortalLaunchFailed) {
              // Aucun navigateur n'a été ouvert : le drapeau de retour ne doit
              // pas rester armé, sinon la prochaine reprise déclencherait un
              // rafraîchissement de profil sans raison.
              _hasLaunchedBrowser = false;
              DonySnackbar.show(
                context,
                message: kProPortalOpenFailedMessage,
                type: DonySnackbarType.error,
              );
            }
          },
        ),
      ],
      // Le critère est `_informsAboutSession`, et surtout PAS « cet état
      // porte-t-il un utilisateur ». Voir sa documentation.
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) => _informsAboutSession(current),
        builder: (context, state) {
          final user = _userOf(state);
          if (user == null) {
            // Démarrage à froid : l'authentification n'a encore rien affirmé.
            // Montrer la page de vente affirmerait « vous n'êtes pas
            // abonné » sans le savoir.
            return const _ProAuthPendingView();
          }
          return user.isProAccount
              ? _ProSubscriberView(
                  onDowngrade: () => _confirmDowngrade(context),
                  onOpenPortal: (target) => _openPortal(context, target),
                )
              : _ProPitchView(
                  onOpenPortal: (target) => _openPortal(context, target),
                );
        },
      ),
    );
  }
}

/// Attente de l'état d'authentification, avant toute affirmation sur le
/// compte. Ce n'est pas une impasse : l'utilisateur garde le bouton de retour
/// de la barre de navigation, et l'attente porte sur l'AuthBloc global, que
/// cet écran ne pilote pas.
class _ProAuthPendingView extends StatelessWidget {
  const _ProAuthPendingView();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const DonyAppBar(title: 'Compte PRO'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: DonySpacing.lg),
            // Une ligne accompagne l'indicateur : nu, il se lit comme un
            // plantage. Elle décrit le cas pour lequel cette vue existe, le
            // démarrage à froid, où un chargement est réellement en cours —
            // affirmer une indisponibilité y serait faux, et contredirait
            // l'indicateur juste au-dessus. Le cas de la déconnexion écran
            // ouvert reste couvert par l'ambiguïté connue d'`AuthInitial`,
            // que ce lot ne prétend pas lever.
            Text(
              'Chargement de votre compte.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue non abonnée : page de vente ─────────────────────────────────────────

class _ProPitchView extends StatelessWidget {
  const _ProPitchView({required this.onOpenPortal});

  final void Function(ProPortalTarget target) onOpenPortal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Compte PRO'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xl,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: DonyMascotteAnimated(
                type: DonyMascotteType.confiant,
                size: DonyMascotteSize.lg,
              ),
            ),
            const SizedBox(height: DonySpacing.xl),

            Text(
              'Passez en compte PRO',
              style: tt.displayLarge,
            ).animate().fadeIn(delay: 60.ms),
            const SizedBox(height: DonySpacing.md),
            Text(
              'Le compte PRO met en avant votre activité de transporteur et '
              'vous donne accès aux avantages réservés aux professionnels.',
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xxl),

            const _SectionLabel('CE QUE COMPREND LE COMPTE PRO'),
            const SizedBox(height: DonySpacing.md),
            const _AdvantageRow(label: 'Badge Pro'),
            const SizedBox(height: DonySpacing.sm),
            const _AdvantageRow(label: 'Volume illimité'),
            const SizedBox(height: DonySpacing.sm),
            const _AdvantageRow(label: 'Priorité de mise en relation'),
            const SizedBox(height: DonySpacing.sm),
            const _AdvantageRow(label: 'Support dédié'),
            const SizedBox(height: DonySpacing.xxl),

            const _SectionLabel('TARIFS'),
            const SizedBox(height: DonySpacing.md),
            DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _kMonthlyPrice,
                    style: tt.titleLarge?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    _kYearlyPrice,
                    style: tt.titleLarge?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    _kYearlySaving,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 180.ms),
            const SizedBox(height: DonySpacing.lg),

            const DonyStatusBanner(
              type: DonyStatusBannerType.info,
              iconAsset: 'info',
              message: _kPortalHint,
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: DonySpacing.xl),

            DonyButton(
              label: _kPortalButtonLabel,
              iconRightAsset: 'external-link',
              onPressed: () => onOpenPortal(ProPortalTarget.upgrade),
            ).animate().fadeIn(delay: 260.ms),
          ],
        ),
      ),
    );
  }
}

// ── Vue abonnée : état réel de l'abonnement ─────────────────────────────────

class _ProSubscriberView extends StatelessWidget {
  const _ProSubscriberView({
    required this.onDowngrade,
    required this.onOpenPortal,
  });

  final VoidCallback onDowngrade;
  final void Function(ProPortalTarget target) onOpenPortal;

  /// L'abonnement porté par l'état, quand il est connu.
  ///
  /// [SubscriptionPortalLaunchFailed] est traité ici aussi : il transporte le
  /// dernier abonnement chargé et n'est émis qu'un instant avant la
  /// restauration de l'état précédent. Sans ce cas, l'écran clignoterait vers
  /// son état de chargement à chaque échec d'ouverture du portail.
  ProSubscriptionModel? _subscriptionOf(SubscriptionState state) =>
      switch (state) {
        SubscriptionLoaded(:final subscription) => subscription,
        SubscriptionPortalLaunchFailed(:final subscription) => subscription,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Mon compte PRO'),
      body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          final subscription = _subscriptionOf(state);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (subscription != null)
                  ..._loaded(context, subscription)
                else if (state is SubscriptionError)
                  ..._failed(context)
                else if (state is SubscriptionLoading)
                  // Une demande est en vol : elle se résoudra en `Loaded` ou
                  // en `Error`, qui offrent tous deux une suite. Ce n'est
                  // donc jamais une impasse.
                  ..._loading()
                else
                  // `SubscriptionInitial` : aucune demande en vol. Cet état
                  // ne devrait pas durer (il est traité au montage et à
                  // chaque bascule d'authentification), mais s'il survient,
                  // un indicateur seul enfermerait l'utilisateur sur un
                  // écran sans issue. Il porte donc sa propre sortie.
                  ..._idle(context),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _loading() => const [
    SizedBox(height: DonySpacing.xxl),
    Center(child: CircularProgressIndicator()),
    SizedBox(height: DonySpacing.xxl),
  ];

  /// **Aucune demande en vol.** Pas d'indicateur d'activité ici : il dirait
  /// « attends » à côté d'un bouton qui dit « agis », alors que rien n'est
  /// effectivement en train de se charger. Même forme que la branche
  /// d'erreur, message neutre plutôt qu'alarmiste : rien n'a échoué, l'état
  /// n'a simplement pas encore été demandé.
  List<Widget> _idle(BuildContext context) => [
    const DonyStatusBanner(
      type: DonyStatusBannerType.info,
      message: "L'état de votre abonnement n'a pas encore été chargé.",
    ),
    const SizedBox(height: DonySpacing.lg),
    _retryButton(context),
  ];

  /// L'échec de chargement n'efface pas l'écran : le titre reste, le message
  /// est explicite, et une seule action est proposée. Masquer la page entière
  /// pour un appel raté priverait l'abonné de tout repère.
  List<Widget> _failed(BuildContext context) => [
    const DonyStatusBanner(
      type: DonyStatusBannerType.error,
      message:
          "Impossible de charger l'état de votre abonnement pour le moment.",
    ),
    const SizedBox(height: DonySpacing.lg),
    _retryButton(context),
  ];

  Widget _retryButton(BuildContext context) => DonyButton(
    label: 'Réessayer',
    variant: DonyButtonVariant.secondary,
    onPressed: () =>
        context.read<SubscriptionBloc>().add(const SubscriptionRequested()),
  );

  List<Widget> _loaded(
    BuildContext context,
    ProSubscriptionModel subscription,
  ) {
    // `active` est le seul signal FRAIS dont dispose cet écran. Le drapeau PRO
    // local, lui, n'est rechargé qu'au démarrage à froid ou au retour du
    // navigateur : il reste vrai des jours après la fermeture d'un abonnement
    // côté serveur. Sans lui, un abonné résilié voyait « Résilié », aucun
    // bandeau, et aucun chemin vers la page de vente, qui n'est gouvernée que
    // par ce drapeau périmé.
    final accessGranted = subscription.active;

    // La visibilité des gestes se décide sur `source`, seul indice
    // disponible : le serveur n'expose délibérément aucun identifiant Stripe,
    // l'application ne peut donc pas savoir autrement si un espace de gestion
    // existe.
    //
    // `null` et `unknown` ne rendent AUCUN des deux boutons. Ne jamais
    // afficher un geste dont la légitimité n'est pas établie : proposer une
    // gestion inexistante, ou une résiliation vouée au 409, est pire que de
    // ne rien proposer. Ces utilisateurs reçoivent en revanche la phrase qui
    // dit où gérer et résilier, sans quoi ils n'auraient ni action ni
    // explication.
    final source = subscription.source;
    // `proPortalManageIsLegitimate` plutôt que `source == stripe` réécrit ici :
    // c'est cette duplication qui avait fait diverger le bandeau de la carte.
    // Et l'accès doit encore être accordé — sinon « Gérer mon abonnement » et
    // « S'abonner » s'affichaient côte à côte, vers deux pages différentes,
    // sur un abonnement résilié.
    final canManage =
        accessGranted && proPortalManageIsLegitimate(subscription);
    final canDowngrade =
        accessGranted &&
        (source == ProSubscriptionSource.adminGrant ||
            source == ProSubscriptionSource.legacyFree);
    final needsGuidance = accessGranted && !canManage && !canDowngrade;

    return [
      // Rend `SizedBox.shrink()` de lui-même quand il n'y a rien à signaler.
      // L'espacement qui le suit est conditionné au même prédicat : sans
      // cela, la page s'ouvrirait sur un vide inexpliqué pour le cas le plus
      // courant, un abonnement actif dont il n'y a rien à dire.
      if (subscriptionHasVisibleAlert(subscription)) ...[
        SubscriptionStatusBanner(
          subscription: subscription,
          // Même règle que le bouton de gestion de la carte, dix lignes plus
          // bas : une action qui mène à la gestion exige une source Stripe.
          // Les deux ouvrent la même page ; les gouverner par deux règles
          // opposées offrait « Régler » à un impayé de source inconnue tout
          // en lui masquant « Gérer mon abonnement ».
          onAction: proPortalActionIsLegitimate(subscription)
              ? () => onOpenPortal(proPortalTargetFor(subscription.status))
              : null,
        ),
        const SizedBox(height: DonySpacing.lg),
      ],
      SubscriptionStatusCard(
        subscription: subscription,
        onManage: canManage ? () => onOpenPortal(ProPortalTarget.manage) : null,
      ).animate().fadeIn(delay: 60.ms),
      if (!accessGranted) ...[
        const SizedBox(height: DonySpacing.lg),
        DonyStatusBanner(
          type: DonyStatusBannerType.info,
          message: subscription.status == ProSubscriptionStatus.none
              ? _kNoSubscriptionMessage
              : _kAccessEndedMessage,
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: _kPortalButtonLabel,
          iconRightAsset: 'external-link',
          onPressed: () => onOpenPortal(ProPortalTarget.upgrade),
        ),
      ],
      if (needsGuidance) ...[
        const SizedBox(height: DonySpacing.lg),
        const DonyStatusBanner(
          type: DonyStatusBannerType.info,
          message: _kManageGuidance,
        ),
      ],
      if (canDowngrade) ...[
        const SizedBox(height: DonySpacing.xxl),
        BlocBuilder<UpgradeToProBloc, UpgradeToProState>(
          builder: (context, state) {
            final isLoading = state is UpgradeToProLoading;
            return DonyButton(
              label: 'Revenir en compte standard',
              variant: DonyButtonVariant.destructive,
              isLoading: isLoading,
              onPressed: isLoading ? null : onDowngrade,
            );
          },
        ).animate().fadeIn(delay: 100.ms),
      ],
    ];
  }
}

// ── Composants privés ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _AdvantageRow extends StatelessWidget {
  const _AdvantageRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyIcon('check', color: cs.primary, size: 18),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
