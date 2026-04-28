import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            // Intercept Stripe's return_url (https://dony.app/kyc/complete)
            if (request.url.startsWith('https://dony.app/kyc/complete')) {
              if (mounted) {
                context.go('/kyc/status');
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.stripeUrl));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: DonyAppBar(
        title: 'Vérification d\'identité',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Fermer',
            icon: Icon(Icons.close, color: cs.onSurface),
            onPressed: () => context.go('/kyc'),
          ),
        ],
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
