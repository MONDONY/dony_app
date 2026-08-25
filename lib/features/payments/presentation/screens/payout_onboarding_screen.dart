import 'dart:async';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/connect_unavailable_view.dart';
import 'package:dony/features/stripe_account/presentation/widgets/identity_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Étape suivante depuis les paiements : `routeAfter` reste appelé (plutôt
/// que `/home` en dur) pour que l'écran suive automatiquement l'ordre réel
/// du parcours si `onboardingSteps()` change un jour — aujourd'hui toujours
/// l'accueil, les paiements étant la dernière étape comptée. Hors onboarding
/// ([progress] `null`), toujours l'accueil aussi, comme avant cette étape.
/// Pose `onboarding_seen_at` uniquement quand la destination est vraiment
/// l'accueil — même garde que `KycStatusScreen._leaveIdentityStep`.
void _leavePayoutsStep(BuildContext context, OnboardingProgress? progress) {
  final destination = progress?.routeAfter(OnboardingStep.payouts) ?? '/home';
  if (progress != null && destination == '/home') {
    unawaited(getIt<AuthRepository>().markOnboardingSeen().catchError((_) {}));
  }
  context.go(destination);
}

class PayoutOnboardingScreen extends StatefulWidget {
  const PayoutOnboardingScreen({super.key, this.progress});

  /// Non `null` seulement depuis l'onboarding (étape paiements, spec §2) —
  /// même convention que `KycStatusScreen.progress`. Construit par
  /// `router.dart` (`readOnboardingProgress`), jamais lu ici via un provider
  /// ambiant : cet écran reste montable en test sans lui.
  final OnboardingProgress? progress;

  @override
  State<PayoutOnboardingScreen> createState() => _PayoutOnboardingScreenState();
}

class _PayoutOnboardingScreenState extends State<PayoutOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // C'est l'écran qui parle du statut : on le resynchronise avec Stripe à
    // l'ouverture plutôt que de se fier au dernier webhook reçu. Sans ça, un
    // compte activé entre-temps continuait d'afficher « connectez votre compte
    // bancaire ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final bloc = context.read<StripeAccountBloc>();
      if (!bloc.isClosed) {
        bloc.add(const StripeAccountStatusRefreshed());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      builder: (context, stripeState) {
        if (stripeState is StripeAccountReady &&
            stripeState.accountStatus.isComplete) {
          return _ActiveAccountView(progress: widget.progress);
        }

        // Stripe n'ouvre pas de compte connecté dans tous les pays desservis
        // par yadony. Laisser dérouler l'inscription pour finir sur un refus
        // serveur, après un aller-retour par le navigateur, n'apporte rien.
        if (!stripeState.connectAvailableInCountry) {
          final progress = widget.progress;
          if (progress != null) {
            // `onboardingSteps()` exclut déjà les paiements pour ces pays :
            // arriver ici depuis l'onboarding ne peut être qu'une course
            // (statut optimiste au moment de router, corrigé par le
            // rafraîchissement forcé de `initState` ci-dessus). Rien à
            // proposer — on continue silencieusement, sans montrer une
            // impasse à un utilisateur qui n'aurait jamais dû l'atteindre.
            return _AutoLeavePayoutsStep(progress: progress);
          }
          return const ConnectUnavailableView(title: 'Recevoir mes paiements');
        }

        // Deuxième porte vers Stripe Connect, et donc deuxième garde : le
        // serveur refuse une identité non vérifiée (422 `kyc-required`).
        // Depuis le parcours, `OnboardingProgress` verrouille déjà l'étape ;
        // hors parcours, seule cette garde empêche l'écran de lancer une
        // création de compte vouée au refus.
        if (context.watch<AuthBloc>().state.currentUser?.kycStatus !=
            'VERIFIED') {
          return const IdentityRequiredView(title: 'Recevoir mes paiements');
        }

        // Le statut serveur, et non l'état du PaymentBloc, décide si une
        // inscription est en cours. Le PaymentBloc est recréé à chaque montage
        // de la route : en quittant l'écran puis en y revenant, il repartait de
        // zéro et l'inscription entamée devenait invisible.
        final startedOnServer =
            stripeState is StripeAccountReady &&
            stripeState.accountStatus.isOnboardingIncomplete;

        return BlocConsumer<PaymentBloc, PaymentState>(
          listener: (context, state) async {
            if (state is PaymentOnboardingUrlReady) {
              // Navigateur du système, jamais une webview : la documentation de
              // Stripe exclut explicitement son onboarding hébergé des vues web
              // embarquées. En webview, l'écran de connexion Express s'affichait
              // puis la page restait blanche, sans erreur ni message.
              //
              // Le retour se fait par deep link `yadony://stripe/onboarding/complete`,
              // que le backend produit en redirigeant depuis son endpoint HTTPS
              // (Stripe n'accepte pas de deep link comme URL de retour). Le
              // routeur récupère ce lien et ramène ici, où le statut est relu.
              final ouvert = await launchUrl(
                Uri.parse(state.url),
                mode: LaunchMode.externalApplication,
              );
              if (!ouvert && context.mounted) {
                DonySnackbar.show(
                  context,
                  message:
                      "Impossible d'ouvrir la page de configuration. Vérifie "
                      "qu'un navigateur est installé.",
                  type: DonySnackbarType.error,
                );
              }
            } else if (state is PaymentOnboardingComplete) {
              getIt<StripeAccountBloc>().add(
                const StripeAccountStatusRefreshed(),
              );
            }
          },
          builder: (context, state) {
            if (state is PaymentOnboardingComplete) {
              return _SuccessView(progress: widget.progress);
            }
            return _OnboardingView(
              state: state,
              startedOnServer: startedOnServer,
              progress: widget.progress,
            );
          },
        );
      },
    );
  }
}

/// Rendu quand `/payments/onboarding` est atteint depuis l'onboarding alors
/// que Stripe n'ouvre finalement pas de compte connecté dans ce pays (course
/// avec le rafraîchissement forcé de `initState`) : rien à afficher, juste
/// laisser passer vers l'étape suivante — ce n'est pas une impasse pour cet
/// utilisateur, seulement pour l'écran.
class _AutoLeavePayoutsStep extends StatefulWidget {
  const _AutoLeavePayoutsStep({required this.progress});
  final OnboardingProgress progress;

  @override
  State<_AutoLeavePayoutsStep> createState() => _AutoLeavePayoutsStepState();
}

class _AutoLeavePayoutsStepState extends State<_AutoLeavePayoutsStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leavePayoutsStep(context, widget.progress);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// ── Vue principale d'onboarding ───────────────────────────────────────────────

class _OnboardingView extends StatelessWidget {
  final PaymentState state;

  /// Le serveur dit qu'un compte Stripe existe déjà sans être complet.
  /// Survit au démontage de l'écran, contrairement à l'état du [PaymentBloc].
  final bool startedOnServer;

  /// Non `null` seulement depuis l'onboarding — voir
  /// `PayoutOnboardingScreen.progress`.
  final OnboardingProgress? progress;

  const _OnboardingView({
    required this.state,
    required this.startedOnServer,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = state is PaymentLoading;
    final isPending = state is PaymentOnboardingPending || startedOnServer;
    final error = state is PaymentError
        ? ErrorPresenter.resolve((state as PaymentError).error).message
        : null;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: Builder(
        builder: (context) {
          final h = DonyLayout.hPadding(context);
          // Contenu défilant d'un côté, actions ancrées de l'autre : le bouton
          // « Connecter mon compte bancaire » se trouvait sous la ligne de
          // flottaison, il fallait scroller pour le découvrir (retour
          // utilisateur). Il ne bouge plus.
          return DonyLayout.constrained(
            context,
            Padding(
              padding: EdgeInsets.fromLTRB(
                h,
                DonySpacing.base,
                h,
                DonySpacing.base + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null) ...[
                    AuthFlowHeader.gauge(
                      segments: progress!.segments,
                      label: 'Paiements',
                    ),
                    const SizedBox(height: DonySpacing.md),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HeroSection(),
                          const SizedBox(height: DonySpacing.lg),
                          const _BenefitsSection(),
                          const SizedBox(height: DonySpacing.lg),
                          if (isPending) ...[
                            // Ne plus dire « Stripe finalise votre compte » : dans
                            // le cas courant Stripe n'attend rien, il manque des
                            // informations que l'utilisateur seul peut fournir.
                            // Laisser croire à une attente le décourageait de
                            // reprendre.
                            const DonyStatusBanner(
                              type: DonyStatusBannerType.warning,
                              iconAsset: 'clock',
                              message:
                                  'Inscription commencée mais pas terminée. '
                                  'Reprenez-la pour pouvoir être payé, vous '
                                  'retrouverez vos informations déjà saisies.',
                            ),
                            const SizedBox(height: DonySpacing.md),
                            DonyButton(
                              label: 'Rafraîchir le statut',
                              variant: DonyButtonVariant.secondary,
                              onPressed: isLoading
                                  ? null
                                  : () => context.read<PaymentBloc>().add(
                                      const PaymentOnboardingRefreshRequested(),
                                    ),
                              iconAsset: 'refresh-cw',
                            ),
                            const SizedBox(height: DonySpacing.md),
                          ],
                          if (error != null) ...[
                            DonyStatusBanner(
                              type: DonyStatusBannerType.error,
                              message: error,
                            ),
                            const SizedBox(height: DonySpacing.md),
                          ],
                        ],
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                    ),
                  ),
                  AuthFlowActions(
                    primary: DonyButton(
                      // « Connecter » sous-entend un premier pas ; quand
                      // l'inscription est déjà entamée, c'est bien d'une
                      // reprise qu'il s'agit.
                      label: isPending
                          ? 'Reprendre mon inscription'
                          : 'Connecter mon compte bancaire',
                      onPressed: isLoading
                          ? null
                          : () => context.read<PaymentBloc>().add(
                              const PaymentConnectAccountRequested(),
                            ),
                      isLoading: isLoading,
                      iconAsset: 'landmark',
                    ),
                    // Configurer un compte bancaire est lourd (identité,
                    // IBAN) : personne ne doit être bloqué pour l'avoir remis
                    // à plus tard. Uniquement depuis l'onboarding — depuis le
                    // profil, il n'y a pas d'étape à passer.
                    skipEnabled: !isLoading,
                    onSkip: progress == null
                        ? null
                        : () => _leavePayoutsStep(context, progress),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyIconContainer(
          iconAsset: 'wallet',
          size: DonyIconContainerSize.xl,
          borderRadius: DonyRadius.xl,
          backgroundColor: cs.primaryContainer,
          iconColor: cs.primary,
        ),
        const SizedBox(height: DonySpacing.lg),
        Text(
          'Connectez votre\ncompte bancaire',
          style: tt.displayLarge?.copyWith(height: 1.2),
        ),
        const SizedBox(height: DonySpacing.md),
        Text(
          'Recevez automatiquement votre paiement dans les 24h après chaque livraison confirmée.',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    const items = [
      (
        'lock',
        'Paiement sécurisé',
        'L\'argent est bloqué et sécurisé jusqu\'à confirmation de livraison.',
      ),
      (
        'zap',
        'Virement rapide',
        'Reçu sur votre compte dans les 24h après confirmation.',
      ),
      (
        'shield-check',
        'Géré par Stripe',
        'La vérification d\'identité et la conformité sont gérées par Stripe.',
      ),
    ];

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.indexed.map((entry) {
          final (i, item) = entry;
          final (iconAsset, title, subtitle) = item;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Row(
                  children: [
                    DonyIconContainer(
                      iconAsset: iconAsset,
                      borderRadius: DonyRadius.md,
                      backgroundColor: cs.primaryContainer,
                      iconColor: cs.primary,
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: tt.titleMedium),
                          const SizedBox(height: DonySpacing.xxs),
                          Text(
                            subtitle,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1, indent: 70),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Vue compte bancaire déjà connecté ────────────────────────────────────────

class _ActiveAccountView extends StatelessWidget {
  const _ActiveAccountView({this.progress});

  /// Non `null` seulement depuis l'onboarding — voir
  /// `PayoutOnboardingScreen.progress`.
  final OnboardingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: DonyLayout.constrained(
        context,
        Padding(
          padding: EdgeInsets.fromLTRB(
            h,
            DonySpacing.base,
            h,
            DonySpacing.base + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress != null) ...[
                AuthFlowHeader.gauge(
                  segments: progress!.segments,
                  label: 'Paiements',
                ),
                const SizedBox(height: DonySpacing.md),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIconContainer(
                        iconAsset: 'circle-check',
                        size: DonyIconContainerSize.xl,
                        borderRadius: DonyRadius.xl,
                        backgroundColor: cs.success.withValues(alpha: 0.1),
                        iconColor: cs.success,
                      ),
                      const SizedBox(height: DonySpacing.md),
                      Text(
                        'Compte bancaire connecté',
                        style: tt.headlineMedium?.copyWith(height: 1.2),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        'Votre compte Stripe est actif. Après chaque livraison confirmée, '
                        'le paiement est automatiquement viré sur votre compte bancaire '
                        'sous 1 à 2 jours ouvrés.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.lg),
                      const DonyCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _InfoRow(
                              iconAsset: 'lock',
                              title: 'Paiement sécurisé',
                              subtitle:
                                  "L'argent est retenu jusqu'à confirmation de livraison.",
                            ),
                            Divider(height: 1, indent: 70),
                            _InfoRow(
                              iconAsset: 'zap',
                              title: 'Virement automatique',
                              subtitle:
                                  'Aucune action requise, Stripe vire directement sur votre RIB.',
                            ),
                            Divider(height: 1, indent: 70),
                            _InfoRow(
                              iconAsset: 'landmark',
                              title: 'Sur votre compte bancaire',
                              subtitle:
                                  "Vous recevez l'argent sur le compte lié à votre RIB/IBAN, pas dans un portefeuille Stripe.",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
                ),
              ),
              // Le compte est actif : plus rien à passer, seulement à sortir.
              // Depuis le profil (progress null), l'écran est purement
              // informatif — aucune zone d'action.
              if (progress != null)
                AuthFlowActions(
                  primary: DonyButton(
                    label: 'Continuer vers l\'accueil',
                    iconAsset: 'arrow-right',
                    onPressed: () => _leavePayoutsStep(context, progress),
                    variant: DonyButtonVariant.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String subtitle;

  const _InfoRow({required this.title, required this.subtitle, this.iconAsset})
    : icon = null;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Row(
        children: [
          DonyIconContainer(
            icon: icon,
            iconAsset: iconAsset,
            borderRadius: DonyRadius.md,
            backgroundColor: cs.primaryContainer,
            iconColor: cs.primary,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({this.progress});

  /// Non `null` seulement depuis l'onboarding — voir
  /// `PayoutOnboardingScreen.progress`.
  final OnboardingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: Builder(
        builder: (context) {
          final h = DonyLayout.hPadding(context);
          return DonyLayout.constrained(
            context,
            Padding(
              padding: EdgeInsets.fromLTRB(
                h,
                DonySpacing.base,
                h,
                DonySpacing.base + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null) ...[
                    AuthFlowHeader.gauge(
                      segments: progress!.segments,
                      label: 'Paiements',
                    ),
                    const SizedBox(height: DonySpacing.md),
                  ],
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child:
                            Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const DonyMascotteAnimated(
                                      type: DonyMascotteType.securise,
                                      size: DonyMascotteSize.lg,
                                      withGlow: true,
                                    ),
                                    const SizedBox(height: DonySpacing.lg),
                                    Text(
                                      'Paiements activés ✓',
                                      style: tt.headlineMedium,
                                    ),
                                    const SizedBox(height: DonySpacing.sm),
                                    Text(
                                      'Votre compte bancaire est connecté. Vous recevrez vos paiements automatiquement après chaque livraison.',
                                      textAlign: TextAlign.center,
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .scale(
                                  begin: const Offset(0.9, 0.9),
                                  curve: Curves.easeOutCubic,
                                ),
                      ),
                    ),
                  ),
                  if (progress != null)
                    AuthFlowActions(
                      primary: DonyButton(
                        label: 'Continuer vers l\'accueil',
                        iconAsset: 'arrow-right',
                        onPressed: () => _leavePayoutsStep(context, progress),
                        variant: DonyButtonVariant.success,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
