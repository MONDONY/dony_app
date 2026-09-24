import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/connect_unavailable_view.dart';
import 'package:dony/features/stripe_account/presentation/widgets/identity_required_view.dart';
import 'package:dony/l10n/l10n.dart';
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
    extends State<ConnectOnboardingIntroScreen>
    with WidgetsBindingObserver {
  bool _hasLaunchedBrowser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final l = context.l10n;
    // Stripe n'ouvre pas de compte connecté dans tous les pays desservis par
    // yadony. Laisser l'utilisateur dérouler l'onboarding pour finir sur un
    // refus serveur n'apporte rien : on l'annonce ici.
    if (!context.watch<StripeAccountBloc>().state.connectAvailableInCountry) {
      return ConnectUnavailableView(title: l.connectOnboardingTitle);
    }

    // Stripe Connect exige une identité vérifiée : le serveur refuse sinon
    // (422 `kyc-required`). Sept points d'entrée de l'app mènent ici — écran
    // de publication, détail d'annonce, étape prix, feuilles de blocage,
    // compte désactivé, notification push, retour de lien Stripe. Les fermer
    // un par un serait vain : ils convergent tous sur cet écran, la garde y
    // vit donc une seule fois.
    final kycStatus = context.watch<AuthBloc>().state.currentUser?.kycStatus;
    final identityNotVerified = kycStatus != 'VERIFIED'; // i18n-ignore
    if (identityNotVerified) {
      return IdentityRequiredView(title: l.connectOnboardingTitle);
    }

    return BlocConsumer<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) async {
        if (state is ConnectOnboardingUrlReady) {
          await _openExternalBrowser(context, state.url);
        } else if (state is ConnectOnboardingComplete) {
          // Synchronise le singleton global pour que le reste de l'app
          // reflète immédiatement ONBOARDING_COMPLETE sans logout/login.
          getIt<StripeAccountBloc>().add(const StripeAccountStatusRefreshed());
          if (context.mounted) {
            context.go('/home');
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
        // Le message n'est jamais affiché tel quel : code 'launch-failed'
        // absent d'ErrorCatalog._byCode, résolu en générique réseau
        // (ErrorCatalog._byType, NetworkException -> _networkGeneric). Il
        // passe quand même par l10n pour rester traduit si ce comportement
        // change un jour.
        context.read<ConnectOnboardingBloc>().add(
          ConnectOnboardingLaunchFailed(
            context.l10n.connectOnboardingBrowserLaunchFailed,
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
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLoading = state is ConnectOnboardingLoading;
    final error = state is ConnectOnboardingError
        ? ErrorPresenter.resolve(
            (state as ConnectOnboardingError).error,
          ).message
        : null;

    return Scaffold(
      appBar: DonyAppBar(title: l.connectOnboardingTitle),
      body: Builder(
        builder: (context) {
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
                  // Hero mascotte
                  const DonyMascotteAnimated(
                    type: DonyMascotteType.securise,
                    size: DonyMascotteSize.lg,
                  ),
                  const SizedBox(height: DonySpacing.xl),

                  // Title
                  Text(
                    l.connectOnboardingHeroTitle,
                    style: tt.displayLarge?.copyWith(height: 1.2),
                  ).animate().fadeIn(delay: 60.ms),
                  const SizedBox(height: DonySpacing.md),

                  // Description
                  Text(
                    l.connectOnboardingHeroSubtitle,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // Benefits
                  _BenefitsList().animate().fadeIn(delay: 140.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // Info banner
                  DonyStatusBanner(
                    type: DonyStatusBannerType.info,
                    iconAsset: 'shield',
                    message: l.connectOnboardingSecurityNotice,
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
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.sm,
            DonySpacing.lg,
            DonySpacing.base,
          ),
          child: DonyButton(
            label: l.connectOnboardingCta,
            iconAsset: 'arrow-right',
            onPressed: isLoading
                ? null
                : () => context.read<ConnectOnboardingBloc>().add(
                    const ConnectOnboardingLinkRequested(),
                  ),
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final items = [
      (
        'timer',
        l.connectOnboardingBenefitTimeTitle,
        l.connectOnboardingBenefitTimeSubtitle,
      ),
      (
        'zap',
        l.connectOnboardingBenefitTransferTitle,
        l.connectOnboardingBenefitTransferSubtitle,
      ),
      (
        'shield-check',
        l.connectOnboardingBenefitSecureTitle,
        l.connectOnboardingBenefitSecureSubtitle,
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
