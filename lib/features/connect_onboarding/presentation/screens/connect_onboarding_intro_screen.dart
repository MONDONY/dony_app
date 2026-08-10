import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectOnboardingIntroScreen extends StatefulWidget {
  const ConnectOnboardingIntroScreen({super.key});

  @override
  State<ConnectOnboardingIntroScreen> createState() =>
      _ConnectOnboardingIntroScreenState();
}

class _ConnectOnboardingIntroScreenState
    extends State<ConnectOnboardingIntroScreen> with WidgetsBindingObserver {
  bool _hasLaunchedBrowser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // L'écran affichait le même CTA "Complète ton compte Stripe" même une
    // fois le compte déjà ONBOARDING_COMPLETE, faute de vérifier le statut
    // réel au chargement — seul un nouveau tap sur le bouton le détectait.
    context.read<ConnectOnboardingBloc>().add(
      const ConnectOnboardingStatusRequested(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final fromStripe =
            GoRouterState.of(context).uri.queryParameters['from'] == 'stripe';
        if (fromStripe) {
          ConnectPendingBottomSheet.show(context);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLaunchedBrowser && mounted) {
      context.read<ConnectOnboardingBloc>().add(
        const ConnectOnboardingPollingRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) async {
        if (state is ConnectOnboardingUrlReady) {
          await _openExternalBrowser(context, state.url);
        } else if (state is ConnectOnboardingComplete) {
          // Synchronise le singleton global pour que le reste de l'app
          // reflète immédiatement ONBOARDING_COMPLETE sans logout/login.
          // Ne redirige plus vers /home : l'utilisateur est venu consulter
          // cet écran spécifiquement, il doit y voir la confirmation plutôt
          // qu'être renvoyé ailleurs sans explication.
          getIt<StripeAccountBloc>().add(const StripeAccountStatusRefreshed());
          // AuthBloc.currentUser.stripeAccountStatus (chargé au login) ne
          // suit pas ce changement tout seul — sans ce refresh, le Profil
          // continue d'afficher la tuile « Recevoir mes paiements » même
          // une fois le compte connecté, car il lit ce champ-là.
          if (context.mounted) {
            context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          }
        }
      },
      builder: (context, state) {
        return _IntroView(state: state);
      },
    );
  }

  Future<void> _openExternalBrowser(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      _hasLaunchedBrowser = true;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // Si le deep link ne s'est pas déclenché, affiche le bottom sheet
      // pour que l'utilisateur puisse confirmer manuellement.
      if (context.mounted) {
        await ConnectPendingBottomSheet.show(context);
      }
    } else {
      if (context.mounted) {
        context.read<ConnectOnboardingBloc>().add(
          const ConnectOnboardingLaunchFailed(
            "Impossible d'ouvrir le navigateur. Vérifie ta connexion.",
          ),
        );
      }
    }
  }
}

class _IntroView extends StatelessWidget {
  final ConnectOnboardingState state;
  const _IntroView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is ConnectOnboardingComplete) {
      return const _ConnectedView();
    }

    // Le statut réel n'est pas encore connu au premier build (l'appel
    // ConnectOnboardingStatusRequested part dans initState mais n'a pas
    // encore répondu). Le Profil connaît déjà `user.stripeAccountStatus`
    // (chargé au login) — on s'en sert pour éviter un spinner arbitraire :
    // si le cache dit déjà "complet", on affiche directement la
    // confirmation, quitte à ce que le fetch en arrière-plan la corrige si
    // le cache était périmé. Sans ce garde, le CTA "Complète ton compte"
    // s'affichait brièvement même pour un compte déjà connecté.
    if (state is ConnectOnboardingInitial) {
      final cachedStatus =
          context.watch<AuthBloc>().state.currentUser?.stripeAccountStatus;
      if (cachedStatus == 'ONBOARDING_COMPLETE') {
        return const _ConnectedView();
      }
    }

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLoading = state is ConnectOnboardingLoading;
    final error = state is ConnectOnboardingError
        ? ErrorPresenter.resolve((state as ConnectOnboardingError).error).message
        : null;

    final kycVerified =
        context.watch<AuthBloc>().state.currentUser?.isKycVerified ?? false;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Compte Stripe Connect'),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            h,
            DonySpacing.xxl,
            h,
            MediaQuery.of(context).padding.bottom + 100,
          ),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Complète ton\ncompte Stripe',
                  style: tt.displayLarge?.copyWith(height: 1.2),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.md),

                // Description
                Text(
                  'Pour publier ton trajet et recevoir des paiements, complète ton compte Stripe. Cela prend environ 5 minutes.',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.55,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: DonySpacing.xxl),

                // Benefits
                _BenefitsList().animate().fadeIn(delay: 140.ms),
                const SizedBox(height: DonySpacing.xxl),

                // KYC requis avant Stripe
                if (!kycVerified) ...[
                  DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    title: 'Identité à vérifier',
                    message:
                        'Vérifie d\'abord ton identité avant de compléter ton compte Stripe.',
                    action: TextButton(
                      onPressed: () => context.push('/kyc/verify'),
                      child: const Text('Vérifier mon identité'),
                    ),
                  ).animate().fadeIn(delay: 160.ms),
                  const SizedBox(height: DonySpacing.lg),
                ],

                // Info banner
                const DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  iconAsset: 'shield',
                  message:
                      'Tes données sont chiffrées et gérées directement par Stripe : Yadony n\'a jamais accès à tes informations bancaires.',
                ).animate().fadeIn(delay: 180.ms),
                const SizedBox(height: DonySpacing.xl),

                // Error banner
                if (error != null) ...[
                  DonyStatusBanner(
                    type: DonyStatusBannerType.error,
                    message: error,
                  ),
                  const SizedBox(height: DonySpacing.lg),
                ],
              ],
            ).animate().slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.sm,
            DonySpacing.lg,
            DonySpacing.base,
          ),
          child: DonyButton(
            label: 'Compléter mon compte',
            iconAsset: 'arrow-right',
            onPressed: (isLoading || !kycVerified)
                ? null
                : () => context
                    .read<ConnectOnboardingBloc>()
                    .add(const ConnectOnboardingLinkRequested()),
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }
}

/// Affichée à la place du CTA d'onboarding quand le compte Stripe est déjà
/// ONBOARDING_COMPLETE — reste sur cet écran plutôt que de rediriger, pour
/// que l'utilisateur venu vérifier son statut voie la confirmation ici même.
class _ConnectedView extends StatelessWidget {
  const _ConnectedView();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Compte Stripe Connect'),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            h,
            DonySpacing.xxl,
            h,
            MediaQuery.of(context).padding.bottom + DonySpacing.huge,
          ),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compte Stripe\nconnecté',
                  style: tt.displayLarge?.copyWith(height: 1.2),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.md),
                Text(
                  'Ton compte Stripe est actif : tu peux publier tes trajets et recevoir tes paiements par carte directement sur ton compte bancaire.',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.55,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: DonySpacing.xxl),
                const DonyStatusBanner(
                  type: DonyStatusBannerType.success,
                  iconAsset: 'shield-check',
                  message: 'Virements automatiques activés après chaque livraison confirmée.',
                ).animate().fadeIn(delay: 140.ms),
              ],
            ).animate().slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        );
      }),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    const items = [
      ('timer', '5 minutes', 'Rapide et guidé pas à pas'),
      ('zap', 'Virement automatique',
          'Reçu sur ton compte après chaque livraison confirmée'),
      ('shield-check', 'Sécurisé par Stripe',
          'Leader mondial des paiements en ligne'),
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
                      size: DonyIconContainerSize.md,
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
