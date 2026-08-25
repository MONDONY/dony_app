import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;
  final _isLoading = ValueNotifier<bool>(true);
  final _hasError = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _isLoading.value = true;
            _hasError.value = false;
          },
          onPageFinished: (_) => _isLoading.value = false,
          onWebResourceError: (_) {
            _isLoading.value = false;
            _hasError.value = true;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _hasError.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: DonyAppBar(
        title: widget.title,
        actions: [
          IconButton(
            icon: DonyIcon('external-link', color: cs.onSurfaceVariant),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        // Android 15 impose l'edge-to-edge : sans cette marge, la WebView
        // s'étend sous la barre de navigation. Le bouton d'action de la page
        // distante, ancré en bas, tombe alors entièrement dans la bande
        // système et devient invisible autant qu'intouchable.
        child: ValueListenableBuilder<bool>(
          valueListenable: _hasError,
          builder: (context, hasError, _) {
            if (hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(DonySpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DonyIcon(
                        'wifi-off',
                        size: 48,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: DonySpacing.base),
                      Text(
                        'Impossible de charger la page',
                        style: tt.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      Text(
                        'Vérifie ta connexion et réessaie.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DonySpacing.xl),
                      FilledButton.tonal(
                        onPressed: () {
                          _hasError.value = false;
                          _isLoading.value = true;
                          _controller.reload();
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                WebViewWidget(controller: _controller),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoading,
                  builder: (context, isLoading, _) {
                    if (!isLoading) return const SizedBox.shrink();
                    return Container(
                      color: cs.surface,
                      child: Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
