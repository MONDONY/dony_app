import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayoutOnboardingScreen extends StatefulWidget {
  const PayoutOnboardingScreen({super.key});

  @override
  State<PayoutOnboardingScreen> createState() => _PayoutOnboardingScreenState();
}

class _PayoutOnboardingScreenState extends State<PayoutOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Resynchronise le statut Stripe à l'entrée : le bloc est un singleton
    // dont l'état peut être périmé (même pattern que
    // ConnectOnboardingIntroScreen). Sans ça, un état Ready(complete)
    // résiduel afficherait à tort la vue « Compte bancaire connecté ».
    context.read<StripeAccountBloc>().add(const StripeAccountStatusRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
      builder: (context, stripeState) {
        if (stripeState is StripeAccountReady &&
            stripeState.accountStatus.isComplete) {
          return const _ActiveAccountView();
        }

        return BlocConsumer<PaymentBloc, PaymentState>(
          listener: (context, state) async {
            if (state is PaymentOnboardingUrlReady) {
              await showGeneralDialog<void>(
                context: context,
                pageBuilder: (ctx, animation, secondaryAnimation) =>
                    _StripeOnboardingWebView(
                  url: state.url,
                  onReturn: () {
                    if (context.mounted) {
                      context
                          .read<PaymentBloc>()
                          .add(const PaymentOnboardingStatusChecked());
                    }
                  },
                ),
              );
            } else if (state is PaymentOnboardingComplete) {
              getIt<StripeAccountBloc>()
                  .add(const StripeAccountStatusRefreshed());
            }
          },
          builder: (context, state) {
            if (state is PaymentOnboardingComplete) {
              return const _SuccessView();
            }
            return _OnboardingView(state: state);
          },
        );
      },
    );
  }
}

// ── Vue principale d'onboarding ───────────────────────────────────────────────

class _OnboardingView extends StatelessWidget {
  final PaymentState state;
  const _OnboardingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final isLoading = state is PaymentLoading;
    final isPending = state is PaymentOnboardingPending;
    final error = state is PaymentError
        ? ErrorPresenter.resolve((state as PaymentError).error).message
        : null;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroSection(),
                const SizedBox(height: DonySpacing.xxl),
                const _BenefitsSection(),
                const SizedBox(height: DonySpacing.xxl),
                if (isPending) ...[
                  const DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    iconAsset: 'clock',
                    message:
                        'Vérification en cours : Stripe finalise votre compte. Si vous avez déjà terminé l\'inscription, rafraîchissez le statut.',
                  ),
                  const SizedBox(height: DonySpacing.md),
                  DonyButton(
                    label: 'Rafraîchir le statut',
                    variant: DonyButtonVariant.secondary,
                    onPressed: isLoading
                        ? null
                        : () => context
                            .read<PaymentBloc>()
                            .add(const PaymentOnboardingRefreshRequested()),
                    iconAsset: 'refresh-cw',
                  ),
                  const SizedBox(height: DonySpacing.xl),
                ],
                if (error != null) ...[
                  DonyStatusBanner(
                    type: DonyStatusBannerType.error,
                    message: error,
                  ),
                  const SizedBox(height: DonySpacing.xl),
                ],
                DonyButton(
                  label: 'Connecter mon compte bancaire',
                  onPressed: isLoading
                      ? null
                      : () => context
                          .read<PaymentBloc>()
                          .add(const PaymentConnectAccountRequested()),
                  isLoading: isLoading,
                  iconAsset: 'landmark',
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        );
      }),
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
      ('lock', 'Paiement sécurisé',
          'L\'argent est retenu en escrow jusqu\'à confirmation de livraison.'),
      ('zap', 'Virement rapide',
          'Reçu sur votre compte dans les 24h après confirmation.'),
      ('shield-check', 'Géré par Stripe',
          'La vérification d\'identité et la conformité sont gérées par Stripe.'),
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
                          Text(subtitle,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 70),
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.huge),
        child: DonyLayout.constrained(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIconContainer(
                iconAsset: 'circle-check',
                size: DonyIconContainerSize.xl,
                borderRadius: DonyRadius.xl,
                backgroundColor: cs.success.withValues(alpha: 0.1),
                iconColor: cs.success,
              ),
              const SizedBox(height: DonySpacing.lg),
              Text(
                'Compte bancaire connecté',
                style: tt.displayLarge?.copyWith(height: 1.2),
              ),
              const SizedBox(height: DonySpacing.md),
              Text(
                'Votre compte Stripe est actif. Après chaque livraison confirmée, '
                'le paiement est automatiquement viré sur votre compte bancaire '
                'sous 1 à 2 jours ouvrés.',
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DonySpacing.xxl),
              DonyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(
                      iconAsset: 'lock',
                      title: 'Paiement sécurisé en escrow',
                      subtitle:
                          "L'argent est retenu jusqu'à confirmation de livraison.",
                    ),
                    const Divider(height: 1, indent: 70),
                    _InfoRow(
                      iconAsset: 'zap',
                      title: 'Virement automatique',
                      subtitle:
                          'Aucune action requise, Stripe vire directement sur votre RIB.',
                    ),
                    const Divider(height: 1, indent: 70),
                    _InfoRow(
                      iconAsset: 'landmark',
                      title: 'Sur votre compte bancaire',
                      subtitle:
                          "Vous recevez l'argent sur le compte lié à votre RIB/IBAN, pas dans un wallet Stripe.",
                    ),
                  ],
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
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

  const _InfoRow({
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconAsset,
  });

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
    );
  }
}

// ── Vue succès ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: Center(
        child: Builder(builder: (context) {
          return Padding(
            padding: EdgeInsets.all(DonyLayout.hPadding(context)),
            child: DonyLayout.constrained(
              context,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DonyMascotteAnimated(
                    type: DonyMascotteType.securise,
                    size: DonyMascotteSize.lg,
                    withGlow: true,
                  ),
                  const SizedBox(height: DonySpacing.xl),
                  Text(
                    'Paiements activés ✓',
                    style: tt.displayLarge,
                  ),
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    'Votre compte bancaire est connecté. Vous recevrez vos paiements automatiquement après chaque livraison.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
            ),
          );
        }),
      ),
    );
  }
}

// ── WebView Stripe onboarding ─────────────────────────────────────────────────

class _StripeOnboardingWebView extends StatefulWidget {
  final String url;
  final VoidCallback onReturn;

  const _StripeOnboardingWebView({
    required this.url,
    required this.onReturn,
  });

  @override
  State<_StripeOnboardingWebView> createState() =>
      _StripeOnboardingWebViewState();
}

bool _isStripeUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      (uri.host == 'connect.stripe.com' || uri.host.endsWith('.stripe.com'));
}

class _StripeOnboardingWebViewState extends State<_StripeOnboardingWebView> {
  late final WebViewController _controller;
  final _isLoading = ValueNotifier<bool>(true);
  bool _urlValid = true;

  @override
  void initState() {
    super.initState();
    _urlValid = _isStripeUrl(widget.url);
    if (!_urlValid) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _isLoading.value = true,
        onPageFinished: (_) => _isLoading.value = false,
        onNavigationRequest: (req) {
          if (req.url.startsWith('https://dony.app/payments/onboarding/return') ||
              req.url.startsWith('https://dony.app/payments/onboarding/refresh')) {
            Navigator.of(context).pop();
            widget.onReturn();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
    widget.onReturn();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!_urlValid) {
      return Scaffold(
        appBar: DonyAppBar(
          title: 'Configuration du compte',
          leadingIconAsset: 'x',
          onBack: _close,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyIcon('circle-alert', color: cs.error, size: 64),
                const SizedBox(height: DonySpacing.lg),
                Text(
                  'URL invalide',
                  style: tt.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.md),
                Text(
                  "L'URL de configuration n'est pas une URL Stripe valide.",
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Configuration du compte',
        leadingIconAsset: 'x',
        onBack: _close,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (_, loading, __) => loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
