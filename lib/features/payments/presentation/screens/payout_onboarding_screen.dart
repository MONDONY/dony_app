import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/change_bank_account_button.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/presentation/stripe_onboarding_return.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/connect_unavailable_view.dart';
import 'package:dony/features/stripe_account/presentation/widgets/identity_required_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// « Recevoir mes paiements » (Réglages, profil) : activer les versements
/// par carte via Stripe Connect.
class PayoutOnboardingScreen extends StatefulWidget {
  const PayoutOnboardingScreen({super.key});

  @override
  State<PayoutOnboardingScreen> createState() => _PayoutOnboardingScreenState();
}

class _PayoutOnboardingScreenState extends State<PayoutOnboardingScreen>
    with WidgetsBindingObserver {
  /// Vrai dès que le lien Stripe a été ouvert. Simple drapeau lu au retour au
  /// premier plan, jamais affiché : pas d'état d'interface, donc pas de BLoC.
  bool _launchedStripe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour du navigateur sans deep link (onglet fermé, formulaire Stripe
  /// abandonné ou terminé sans redirection) : l'écran restait figé sur le même
  /// bouton, sans rien montrer de l'inscription entamée (FLUTTER-3T). Le statut
  /// est relu, comme le fait l'écran « devenir voyageur ».
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_launchedStripe || !mounted) {
      return;
    }
    final bloc = context.read<StripeAccountBloc>();
    if (!bloc.isClosed) {
      bloc.add(const StripeAccountStatusRefreshed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      builder: (context, stripeState) {
        if (stripeState is StripeAccountReady &&
            stripeState.accountStatus.isComplete) {
          return const _ActiveAccountView();
        }

        // Stripe n'ouvre pas de compte connecté dans tous les pays desservis
        // par yadony. Laisser dérouler l'inscription pour finir sur un refus
        // serveur, après un aller-retour par le navigateur, n'apporte rien.
        if (!stripeState.connectAvailableInCountry) {
          return ConnectUnavailableView(title: l.payoutTitle);
        }

        // Deuxième porte vers Stripe Connect, et donc deuxième garde : le
        // serveur refuse une identité non vérifiée (422 `kyc-required`).
        // Cette garde empêche l'écran de lancer une création de compte vouée
        // au refus.
        final kycStatus = context
            .watch<AuthBloc>()
            .state
            .currentUser
            ?.kycStatus;
        final identityNotVerified = kycStatus != 'VERIFIED'; // i18n-ignore
        if (identityNotVerified) {
          return IdentityRequiredView(title: l.payoutTitle);
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
              // Le retour doit ramener ici, jauge d'inscription comprise, et
              // non sur l'écran « devenir voyageur ».
              StripeOnboardingReturn.remember(
                GoRouterState.of(context).uri.toString(),
              );
              _launchedStripe = true;
              final ouvert = await launchUrl(
                Uri.parse(state.url),
                mode: LaunchMode.externalApplication,
              );
              if (!ouvert && context.mounted) {
                DonySnackbar.show(
                  context,
                  message: context.l10n.payoutBrowserLaunchFailed,
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
              return const _SuccessView();
            }
            return _OnboardingView(
              state: state,
              startedOnServer: startedOnServer,
            );
          },
        );
      },
    );
  }
}

// ── Vue principale d'onboarding ───────────────────────────────────────────────

class _OnboardingView extends StatelessWidget {
  final PaymentState state;

  /// Le serveur dit qu'un compte Stripe existe déjà sans être complet.
  /// Survit au démontage de l'écran, contrairement à l'état du [PaymentBloc].
  final bool startedOnServer;

  const _OnboardingView({required this.state, required this.startedOnServer});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isLoading = state is PaymentLoading;
    final isPending = state is PaymentOnboardingPending || startedOnServer;
    final error = state is PaymentError
        ? ErrorPresenter.resolve(
            (state as PaymentError).error,
            l10n: context.l10n,
          ).message
        : null;
    // Compte inscrit par téléphone : Stripe exige un email de contact. Le
    // message seul laissait l'utilisateur chercher où l'ajouter (FLUTTER-3T).
    final needsEmail =
        state is PaymentError &&
        (state as PaymentError).error.code ==
            'contact-email-required'; // i18n-ignore
    // Email de contact transmis à Stripe, affiché dès qu'il est connu : après
    // l'avoir ajouté, l'utilisateur voit qu'il est bien pris en compte.
    final email = context.watch<AuthBloc>().state.currentUser?.email?.trim();
    final contactEmail = (email == null || email.isEmpty) ? null : email;

    return Scaffold(
      appBar: DonyAppBar(title: l.payoutTitle),
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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HeroSection(),
                          const SizedBox(height: DonySpacing.lg),
                          const _BenefitsSection(),
                          const SizedBox(height: DonySpacing.lg),
                          if (contactEmail != null) ...[
                            _ContactEmailRow(email: contactEmail),
                            const SizedBox(height: DonySpacing.md),
                          ],
                          if (isPending) ...[
                            // Ne plus dire « Stripe finalise votre compte » : dans
                            // le cas courant Stripe n'attend rien, il manque des
                            // informations que l'utilisateur seul peut fournir.
                            // Laisser croire à une attente le décourageait de
                            // reprendre.
                            DonyStatusBanner(
                              type: DonyStatusBannerType.warning,
                              iconAsset: 'clock',
                              message: l.payoutPendingBanner,
                            ),
                            const SizedBox(height: DonySpacing.md),
                            DonyButton(
                              label: l.payoutRefreshStatus,
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
                          if (needsEmail) ...[
                            DonyButton(
                              label: l.payoutAddEmailButton,
                              variant: DonyButtonVariant.secondary,
                              iconAsset: 'mail',
                              // Au retour avec un email vérifié, la demande
                              // est relancée : l'erreur périmée disparaît et
                              // l'inscription Stripe reprend (FLUTTER-BX).
                              onPressed: () async {
                                final added = await context.push<bool>(
                                  '/profile/edit/email',
                                );
                                if ((added ?? false) && context.mounted) {
                                  context.read<PaymentBloc>().add(
                                    const PaymentConnectAccountRequested(),
                                  );
                                }
                              },
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
                          ? l.payoutResumeSignup
                          : l.payoutConnectBankAccount,
                      onPressed: isLoading
                          ? null
                          : () => context.read<PaymentBloc>().add(
                              const PaymentConnectAccountRequested(),
                            ),
                      isLoading: isLoading,
                      iconAsset: 'landmark',
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

class _ContactEmailRow extends StatelessWidget {
  const _ContactEmailRow({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon('mail', size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            context.l10n.payoutContactEmailLabel(email),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        Text(l.payoutHeroTitle, style: tt.displayLarge?.copyWith(height: 1.2)),
        const SizedBox(height: DonySpacing.md),
        Text(
          l.payoutHeroSubtitle,
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
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final items = [
      ('lock', l.payoutBenefitSecureTitle, l.payoutBenefitSecureSubtitle),
      (
        'zap',
        l.payoutBenefitFastTransferTitle,
        l.payoutBenefitFastTransferSubtitle,
      ),
      (
        'shield-check',
        l.payoutBenefitStripeManagedTitle,
        l.payoutBenefitStripeManagedSubtitle,
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
  const _ActiveAccountView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      appBar: DonyAppBar(title: l.payoutTitle),
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
              Expanded(
                child: SingleChildScrollView(
                  child:
                      Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DonyIconContainer(
                                iconAsset: 'circle-check',
                                size: DonyIconContainerSize.xl,
                                borderRadius: DonyRadius.xl,
                                backgroundColor: cs.success.withValues(
                                  alpha: 0.1,
                                ),
                                iconColor: cs.success,
                              ),
                              const SizedBox(height: DonySpacing.md),
                              Text(
                                l.payoutActiveTitle,
                                style: tt.headlineMedium?.copyWith(height: 1.2),
                              ),
                              const SizedBox(height: DonySpacing.sm),
                              Text(
                                l.payoutActiveSubtitle,
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: DonySpacing.lg),
                              DonyCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    _InfoRow(
                                      iconAsset: 'lock',
                                      title: l.payoutBenefitSecureTitle,
                                      subtitle:
                                          l.payoutActiveInfoSecureSubtitle,
                                    ),
                                    const Divider(height: 1, indent: 70),
                                    _InfoRow(
                                      iconAsset: 'zap',
                                      title:
                                          l.payoutActiveInfoAutoTransferTitle,
                                      subtitle: l
                                          .payoutActiveInfoAutoTransferSubtitle,
                                    ),
                                    const Divider(height: 1, indent: 70),
                                    _InfoRow(
                                      iconAsset: 'landmark',
                                      title: l.payoutActiveInfoBankAccountTitle,
                                      subtitle:
                                          l.payoutActiveInfoBankAccountSubtitle,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: DonySpacing.lg),
                              // Changer d'IBAN se fait dans l'espace Stripe
                              // Express : sans ce bouton, aucun chemin dans
                              // l'app n'y menait.
                              SizedBox(
                                width: double.infinity,
                                child: ChangeBankAccountButton(
                                  source: BankAccountLinkSource.payoutsScreen,
                                  // Compte devenu incomplet entre-temps :
                                  // relire le statut ramène l'écran sur
                                  // l'inscription Stripe.
                                  onOnboardingRequired: () =>
                                      getIt<StripeAccountBloc>().add(
                                        const StripeAccountStatusRefreshed(),
                                      ),
                                ),
                              ),
                              const SizedBox(height: DonySpacing.sm),
                              Text(
                                l.bankAccountChangeHint,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),
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
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: DonyAppBar(title: l.payoutTitle),
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
                                      l.payoutSuccessTitle,
                                      style: tt.headlineMedium,
                                    ),
                                    const SizedBox(height: DonySpacing.sm),
                                    Text(
                                      l.payoutSuccessSubtitle,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
