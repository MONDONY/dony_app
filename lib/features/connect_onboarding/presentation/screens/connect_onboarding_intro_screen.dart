import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ConnectOnboardingIntroScreen extends StatelessWidget {
  const ConnectOnboardingIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) async {
        if (state is ConnectOnboardingUrlReady) {
          await _openStripeOnboarding(context, state.url);
        } else if (state is ConnectOnboardingComplete) {
          context.go('/home');
        }
      },
      builder: (context, state) {
        return _IntroView(state: state);
      },
    );
  }

  Future<void> _openStripeOnboarding(BuildContext context, String url) async {
    await showGeneralDialog<void>(
      context: context,
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          _StripeOnboardingWebView(
        url: url,
        onReturn: () {
          if (context.mounted) {
            context.go('/connect/onboarding/pending');
          }
        },
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  final ConnectOnboardingState state;
  const _IntroView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isLoading = state is ConnectOnboardingLoading;
    final error = state is ConnectOnboardingError
        ? (state as ConnectOnboardingError).message
        : null;

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
                // Hero icon
                DonyIconContainer(
                  icon: Icons.account_balance_wallet_rounded,
                  size: DonyIconContainerSize.xl,
                  borderRadius: DonyRadius.xl,
                  backgroundColor: cs.primaryContainer,
                  iconColor: cs.primary,
                ).animate().fadeIn(duration: 260.ms).scale(
                      begin: const Offset(0.85, 0.85),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: DonySpacing.xl),

                // Title
                Text(
                  'Complète ton\ncompte Stripe',
                  style: tt.displayLarge?.copyWith(height: 1.2),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.md),

                // Description
                Text(
                  'Pour publier ton trajet et recevoir des paiements, complète ton compte Stripe — cela prend environ 5 minutes.',
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
                const DonyStatusBanner(
                  type: DonyStatusBannerType.info,
                  icon: Icons.shield_rounded,
                  message:
                      'Tes données sont chiffrées et gérées directement par Stripe — dony n\'a jamais accès à tes informations bancaires.',
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
            icon: Icons.arrow_forward_rounded,
            onPressed: isLoading
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

class _BenefitsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    const items = [
      (Icons.timer_outlined, '5 minutes', 'Rapide et guidé pas à pas'),
      (Icons.bolt_rounded, 'Virement automatique',
          'Reçu sur ton compte après chaque livraison confirmée'),
      (Icons.verified_user_rounded, 'Sécurisé par Stripe',
          'Leader mondial des paiements en ligne'),
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

// ── WebView Stripe (deep-link aware) ──────────────────────────────────────────

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
          if (req.url.startsWith('dony://') ||
              req.url.contains('/stripe/onboarding/complete') ||
              req.url.contains('/stripe/onboarding/refresh')) {
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
        title: 'Inscription Stripe',
        leadingIcon: Icons.close_rounded,
        onBack: _close,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (_, loading, __) => loading
                ? Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
