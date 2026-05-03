import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayoutOnboardingScreen extends StatelessWidget {
  const PayoutOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentBloc, PaymentState>(
      listener: (context, state) async {
        if (state is PaymentOnboardingUrlReady) {
          await showGeneralDialog<void>(
            context: context,
            pageBuilder: (ctx, animation, secondaryAnimation) =>
                _StripeOnboardingWebView(
              url: state.url,
              // Bug #1 fix: le dialog est déjà fermé par _StripeOnboardingWebView
              // avant d'appeler onReturn — ne pas re-popper ici.
              onReturn: () {
                if (context.mounted) {
                  context
                      .read<PaymentBloc>()
                      .add(const PaymentOnboardingStatusChecked());
                }
              },
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is PaymentOnboardingComplete) {
          return const _SuccessView();
        }
        return _OnboardingView(state: state);
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
    final error = state is PaymentError ? (state as PaymentError).message : null;

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
                    icon: Icons.schedule_rounded,
                    message:
                        'Vérification en cours — Stripe finalise votre compte. Si vous avez déjà terminé l\'inscription, rafraîchissez le statut.',
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
                    icon: Icons.refresh_rounded,
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
                  icon: Icons.account_balance_rounded,
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
          icon: Icons.account_balance_wallet_rounded,
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
      (Icons.lock_rounded, 'Paiement sécurisé',
          'L\'argent est retenu en escrow jusqu\'à confirmation de livraison.'),
      (Icons.bolt_rounded, 'Virement rapide',
          'Reçu sur votre compte dans les 24h après confirmation.'),
      (Icons.verified_user_rounded, 'Géré par Stripe',
          'La vérification d\'identité et la conformité sont gérées par Stripe.'),
    ];

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.indexed.map((entry) {
          final (i, item) = entry;
          final (icon, title, subtitle) = item;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Row(
                  children: [
                    DonyIconContainer(
                      icon: icon,
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
                  DonyIconContainer(
                    icon: Icons.check_circle_rounded,
                    size: DonyIconContainerSize.xxl,
                    backgroundColor: cs.success.withValues(alpha: 0.1),
                    iconColor: cs.success,
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

class _StripeOnboardingWebViewState extends State<_StripeOnboardingWebView> {
  late final WebViewController _controller;
  final _isLoading = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
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

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Configuration du compte',
        leadingIcon: Icons.close_rounded,
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
