import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KycWebViewScreen extends StatefulWidget {
  const KycWebViewScreen({super.key, required this.stripeUrl});
  final String stripeUrl;

  @override
  State<KycWebViewScreen> createState() => _KycWebViewScreenState();
}

class _KycWebViewScreenState extends State<KycWebViewScreen> {
  late final WebViewController _controller;
  final _isLoading = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // onPermissionRequest is passed at construction so the selfie camera
    // step on Stripe's hosted page works without a prompt.
    _controller = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _isLoading.value = true,
          onPageFinished: (_) => _isLoading.value = false,
          onWebResourceError: (error) {
            if (mounted) {
              _isLoading.value = false;
              DonySnackbar.show(
                context,
                message: 'Impossible de charger la page de vérification',
                type: DonySnackbarType.error,
              );
            }
          },
          onNavigationRequest: (request) {
            // Intercept Stripe's return_url (https://dony.app/kyc/complete)
            if (request.url.startsWith('https://dony.app/kyc/complete')) {
              if (mounted) {
                context.go('/kyc/status');
              }
              return NavigationDecision.prevent;
            }
            // Allow only Stripe-hosted pages. Reject any other navigation
            // (phishing, open redirect, file://, intent://, ...).
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            final host = uri.host;
            final isStripe = host == 'verify.stripe.com' ||
                host == 'stripe.com' ||
                host.endsWith('.stripe.com');
            return isStripe
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.stripeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: DonyAppBar(
        title: 'Vérification d\'identité',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Fermer',
            icon: Icon(Icons.close, color: cs.onSurface),
            onPressed: () {
              context.read<KycBloc>().add(const KycSessionAbandoned());
              context.read<AuthBloc>().add(const AuthCheckRequested());
              context.go('/home');
            },
          ),
        ],
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
