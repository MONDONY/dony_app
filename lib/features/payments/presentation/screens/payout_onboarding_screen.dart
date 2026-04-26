import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayoutOnboardingScreen extends StatelessWidget {
  const PayoutOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentBloc, PaymentState>(
      listener: (context, state) {
        if (state is PaymentOnboardingUrlReady) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _StripeOnboardingWebView(
              url: state.url,
              onReturn: () => context
                  .read<PaymentBloc>()
                  .add(const PaymentOnboardingStatusChecked()),
            ),
          ));
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
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Recevoir mes paiements',
          style: GoogleFonts.sora(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: DonyColors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroSection(),
            const SizedBox(height: 32),
            _BenefitsSection(),
            const SizedBox(height: 32),
            if (isPending) ...[
              _PendingBanner(),
              const SizedBox(height: 24),
            ],
            if (error != null) ...[
              _ErrorBanner(message: error),
              const SizedBox(height: 24),
            ],
            _ConnectButton(isLoading: isLoading),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: DonyColors.blue100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: DonyColors.blue400, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          'Connectez votre\ncompte bancaire',
          style: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: DonyColors.dark900,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Recevez automatiquement votre paiement dans les 24h après chaque livraison confirmée.',
          style: GoogleFonts.sora(
              fontSize: 15, color: DonyColors.grey400, height: 1.5),
        ),
      ],
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lock_rounded, 'Paiement sécurisé',
          'L\'argent est retenu en escrow jusqu\'à confirmation de livraison.'),
      (Icons.bolt_rounded, 'Virement rapide',
          'Reçu sur votre compte dans les 24h après confirmation.'),
      (Icons.verified_user_rounded, 'Géré par Stripe',
          'La vérification d\'identité et la conformité sont gérées par Stripe.'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: items.indexed.map((entry) {
          final (i, item) = entry;
          final (icon, title, subtitle) = item;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DonyColors.blue100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: DonyColors.blue400, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.sora(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: DonyColors.dark900)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: DonyColors.grey400,
                                  height: 1.4)),
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

class _ConnectButton extends StatelessWidget {
  final bool isLoading;
  const _ConnectButton({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () => context
                .read<PaymentBloc>()
                .add(const PaymentConnectAccountRequested()),
        style: ElevatedButton.styleFrom(
          backgroundColor: DonyColors.blue400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Connecter mon compte bancaire',
                style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vérification en cours — Stripe finalise votre compte. Revenez dans quelques minutes.',
              style: GoogleFonts.sora(
                  fontSize: 13,
                  color: const Color(0xFFB45309),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DonyColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: DonyColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.sora(
                  fontSize: 13, color: DonyColors.error, fontWeight: FontWeight.w500),
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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text('Recevoir mes paiements',
            style: GoogleFonts.sora(
                fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: DonyColors.white,
        elevation: 0,
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: DonyColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: DonyColors.success, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Paiements activés ✓',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.dark900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Votre compte bancaire est connecté. Vous recevrez vos paiements automatiquement après chaque livraison.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                    fontSize: 15, color: DonyColors.grey400, height: 1.5),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        title: Text(
          'Configuration du compte',
          style: GoogleFonts.sora(
              fontWeight: FontWeight.w600, fontSize: 17),
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
            const Center(
              child: CircularProgressIndicator(color: DonyColors.blue400),
            ),
        ],
      ),
    );
  }
}
