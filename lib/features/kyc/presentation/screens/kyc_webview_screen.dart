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

  static const _kGreen = Color(0xFF1A6B3C);

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
            // Intercept Stripe's return_url (dony://kyc/complete)
            if (request.url.startsWith('dony://kyc/complete')) {
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Vérification d\'identité',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          onPressed: () => context.go('/kyc'),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: _kGreen),
            ),
        ],
      ),
    );
  }
}
