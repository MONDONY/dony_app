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

/// Message opposé au refus `409 active-stripe-subscription`. Le serveur ne
/// laisse pas résilier un abonnement Stripe encore actif depuis l'app : le
/// dire, plutôt que de rendre l'erreur brute, est la seule sortie utile.
const String _kDowngradeBlockedMessage =
    'Votre abonnement PRO est toujours actif. Sa résiliation se fait sur le '
    'site Yadony PRO, dans votre navigateur.';

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
    // Lecture ponctuelle, uniquement pour décider de l'appel réseau. Le rendu
    // suit l'AuthBloc en continu plus bas, dans `_UpgradeToProView`.
    final isProAccount = _userOf(context.read<AuthBloc>().state)?.isProAccount;

    return MultiBlocProvider(
      providers: [
        BlocProvider<UpgradeToProBloc>(
          create: (_) => getIt<UpgradeToProBloc>(),
        ),
        BlocProvider<SubscriptionBloc>(
          create: (_) {
            final bloc = getIt<SubscriptionBloc>();
            // `GET /billing/subscription` répond 200 même sans abonnement,
            // mais rien de ce qu'il rend n'est affiché à un non-abonné : la
            // vue de vente n'a aucun état à montrer. Interroger l'endpoint
            // pour eux serait une requête inutile.
            if (isProAccount ?? false) {
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

class _UpgradeToProView extends StatefulWidget {
  const _UpgradeToProView();

  @override
  State<_UpgradeToProView> createState() => _UpgradeToProViewState();
}

class _UpgradeToProViewState extends State<_UpgradeToProView> {
  @override
  void initState() {
    super.initState();
    // Event de vue : mesure toujours la même intention (« je regarde le
    // compte PRO »), que l'écran vende ou gère l'abonnement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.upgradeToProStarted),
      );
    });
  }

  Future<void> _confirmDowngrade(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Désactiver le compte PRO',
      message:
          'Votre badge PRO et vos avantages professionnels seront retirés de '
          'votre profil.',
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed == true && context.mounted) {
      context.read<UpgradeToProBloc>().add(const DowngradeRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProAccount = _userOf(context.watch<AuthBloc>().state)?.isProAccount;

    return MultiBlocListener(
      listeners: [
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
              DonySnackbar.show(
                context,
                message:
                    "Impossible d'ouvrir la page. Vérifiez votre connexion et "
                    'réessayez.',
                type: DonySnackbarType.error,
              );
            }
          },
        ),
      ],
      child: (isProAccount ?? false)
          ? _ProSubscriberView(onDowngrade: () => _confirmDowngrade(context))
          : const _ProPitchView(),
    );
  }
}

// ── Vue non abonnée : page de vente ─────────────────────────────────────────

class _ProPitchView extends StatelessWidget {
  const _ProPitchView();

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
              onPressed: () => context.read<SubscriptionBloc>().add(
                const ProPortalOpenRequested(ProPortalTarget.upgrade),
              ),
            ).animate().fadeIn(delay: 260.ms),
          ],
        ),
      ),
    );
  }
}

// ── Vue abonnée : état réel de l'abonnement ─────────────────────────────────

class _ProSubscriberView extends StatelessWidget {
  const _ProSubscriberView({required this.onDowngrade});

  final VoidCallback onDowngrade;

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

  /// Même arbitrage que `SubscriptionBannerHost` : seule une grâce historique
  /// (jamais payé) doit atteindre la page de vente ; tout le reste mène à la
  /// gestion du moyen de paiement.
  ProPortalTarget _targetFor(ProSubscriptionStatus status) =>
      status == ProSubscriptionStatus.legacyGrace
      ? ProPortalTarget.upgrade
      : ProPortalTarget.manage;

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
                else
                  ..._loading(),
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
    DonyButton(
      label: 'Réessayer',
      variant: DonyButtonVariant.secondary,
      onPressed: () =>
          context.read<SubscriptionBloc>().add(const SubscriptionRequested()),
    ),
  ];

  List<Widget> _loaded(
    BuildContext context,
    ProSubscriptionModel subscription,
  ) {
    // La visibilité des deux gestes se décide sur `source`, seul indice
    // disponible : le serveur n'expose délibérément aucun identifiant Stripe,
    // l'application ne peut donc pas savoir autrement si un espace de gestion
    // existe.
    //
    // `null` et `unknown` ne rendent AUCUN des deux boutons. Ne jamais
    // afficher un geste dont la légitimité n'est pas établie : proposer une
    // gestion inexistante, ou une résiliation vouée au 409, est pire que de
    // ne rien proposer.
    final source = subscription.source;
    final canManage = source == ProSubscriptionSource.stripe;
    final canDowngrade =
        source == ProSubscriptionSource.adminGrant ||
        source == ProSubscriptionSource.legacyFree;

    return [
      // Rend `SizedBox.shrink()` de lui-même quand il n'y a rien à signaler.
      // L'espacement qui le suit est conditionné au même prédicat : sans
      // cela, la page s'ouvrirait sur un vide inexpliqué pour le cas le plus
      // courant, un abonnement actif dont il n'y a rien à dire.
      if (subscriptionHasVisibleAlert(subscription)) ...[
        SubscriptionStatusBanner(
          subscription: subscription,
          onAction: () => context.read<SubscriptionBloc>().add(
            ProPortalOpenRequested(_targetFor(subscription.status)),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
      ],
      SubscriptionStatusCard(
        subscription: subscription,
        onManage: canManage
            ? () => context.read<SubscriptionBloc>().add(
                const ProPortalOpenRequested(ProPortalTarget.manage),
              )
            : null,
      ).animate().fadeIn(delay: 60.ms),
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
