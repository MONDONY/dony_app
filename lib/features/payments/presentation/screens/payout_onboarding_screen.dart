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
              onReturn: () {
                Navigator.of(ctx).pop();
                context
                    .read<PaymentBloc>()
                    .add(const PaymentOnboardingStatusChecked());
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
    final cs = Theme.of(context).colorScheme;
    final isLoading = state is PaymentLoading;
    final isPending = state is PaymentOnboardingPending;
    final error = state is PaymentError ? (state as PaymentError).message : null;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Recevoir mes paiements'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroSection(),
            const SizedBox(height: DonySpacing.xxl),
            _BenefitsSection(),
            const SizedBox(height: DonySpacing.xxl),
            if (isPending) ...[
              _PendingBanner(),
              const SizedBox(height: DonySpacing.xl),
            ],
            if (error != null) ...[
              _ErrorBanner(message: error, cs: cs),
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
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.xl),
          ),
          child: Icon(Icons.account_balance_wallet_rounded,
              color: cs.primary, size: 32),
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
                    Container(
                      width: DonySpacing.icon,
                      height: DonySpacing.icon,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Icon(icon, color: cs.primary, size: 20),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: tt.titleMedium),
                          const SizedBox(height: 2),
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

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: DonyColors.amberLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: DonyColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              color: DonyColors.amberDark, size: 20),
          const SizedBox(width: DonySpacing.sm + 2),
          Expanded(
            child: Text(
              'Vérification en cours — Stripe finalise votre compte. Revenez dans quelques minutes.',
              style: tt.bodySmall?.copyWith(
                color: DonyColors.amberDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  const _ErrorBanner({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: DonySpacing.sm + 2),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w500,
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(DonySpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: cs.success, size: 44),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
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
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Configuration du compte',
          style: tt.headlineMedium,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onReturn();
          },
        ),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: cs.primary),
            ),
        ],
      ),
    );
  }
}
