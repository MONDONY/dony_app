import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/camera_permission_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KycWebViewScreen extends StatefulWidget {
  const KycWebViewScreen({
    super.key,
    required this.stripeUrl,
    this.progress,
    this.cameraPermission = const CameraPermissionService(),
  });
  final String stripeUrl;

  /// Injectable pour les tests : la vraie implémentation passe par un
  /// canal natif absent du binaire de test.
  final CameraPermissionService cameraPermission;

  /// Non `null` seulement quand cette webview a été ouverte depuis
  /// l'onboarding — voir `KycStatusScreen`, seul point d'entrée qui la
  /// construit avec cette valeur (`readOnboardingProgress` reste un point
  /// impur du routeur, jamais lu ici directement).
  final OnboardingProgress? progress;

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
    _controller =
        WebViewController(
            onPermissionRequest: (request) async {
              // Only grant camera access — Stripe Identity needs it for the
              // selfie step. Blanket grant() would also allow
              // microphone/other sensors unnecessarily.
              if (!request.types.contains(
                WebViewPermissionResourceType.camera,
              )) {
                return;
              }
              // La permission web ne vaut rien sans la permission système :
              // le plugin Android relaie `grant()` sans jamais demander
              // `android.permission.CAMERA`, si bien que la page se croit
              // autorisée pendant que le système lui refuse l'objectif.
              if (await widget.cameraPermission.request()) {
                await request.grant();
              } else {
                await request.deny();
              }
            },
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
                // Intercept Stripe's return_url (https://yadony.com/kyc/complete —
                // dony.store/dony.app kept as legacy fallback for older backend configs).
                if (request.url.startsWith('https://yadony.com/kyc/complete') ||
                    request.url.startsWith('https://dony.store/kyc/complete') ||
                    request.url.startsWith('https://dony.app/kyc/complete')) {
                  if (mounted) {
                    // Depuis l'onboarding, `/kyc/status` ferait perdre
                    // `widget.progress` (route distincte, sans query param) :
                    // `/kyc/verify` avec le même marqueur reconstruit la même
                    // progression et permet à l'écran de statut d'enchaîner
                    // sur l'étape suivante une fois vérifié.
                    context.go(
                      '/kyc/verify'
                      '${onboardingEntrySuffix(fromOnboarding: widget.progress != null)}',
                    );
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
                final isStripe =
                    host == 'verify.stripe.com' ||
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
            icon: DonyIcon('x', color: cs.onSurface),
            onPressed: () {
              context.read<KycBloc>().add(const KycSessionAbandoned());
              context.read<AuthBloc>().add(const AuthCheckRequested());
              // Abandonner l'identité ne la termine pas : positionnel, pas
              // `progress.next`, pour ne jamais reboucler sur cette même
              // étape (voir `OnboardingProgress.routeAfter`).
              final progress = widget.progress;
              final destination =
                  progress?.routeAfter(OnboardingStep.identity) ?? '/home';
              if (progress != null && destination == '/home') {
                unawaited(
                  getIt<AuthRepository>().markOnboardingSeen().catchError(
                    (_) {},
                  ),
                );
              }
              context.go(destination);
            },
          ),
        ],
      ),
      body: SafeArea(
        // Android 15 impose l'edge-to-edge : sans cette marge, la WebView
        // s'étend sous la barre de navigation. Le bouton d'action de la page
        // distante, ancré en bas, tombe alors entièrement dans la bande
        // système et devient invisible autant qu'intouchable.
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (_, loading, _) => loading
                  ? Center(child: CircularProgressIndicator(color: cs.primary))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
