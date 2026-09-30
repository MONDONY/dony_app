import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/camera_permission_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Hôtes autorisés dans la webview de vérification d'identité.
///
/// Liste fermée et vérifiée par égalité ou par suffixe de domaine : un simple
/// `contains` laisserait passer `verify.didit.me.attaquant.com`. C'est le seul
/// rempart entre l'utilisateur, qui va présenter sa pièce d'identité et son
/// visage, et une page qui se ferait passer pour le fournisseur.
///
/// Source unique : le routeur applique le MÊME filtre avant de construire cet
/// écran. Tant que la liste vivait en double, ajouter un fournisseur ici ne
/// suffisait pas — le routeur retombait sur l'écran de statut sans rien dire.
bool isVerificationProviderHost(String host) {
  const domaines = <String>['didit.me', 'stripe.com'];
  return domaines.any(
    (domaine) => host == domaine || host.endsWith('.$domaine'),
  );
}

class KycWebViewScreen extends StatefulWidget {
  const KycWebViewScreen({
    super.key,
    required this.stripeUrl,
    this.progress,
    this.returnTo,
    this.cameraPermission = const CameraPermissionService(),
    this.analytics,
  });
  final String stripeUrl;

  /// Écran où revenir une fois vérifié, transmis à l'écran de statut.
  final String? returnTo;

  /// Injectable pour les tests ; `null` lit le service du conteneur.
  final AnalyticsService? analytics;

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

/// Sans ces paramètres, WKWebView applique `allowsInlineMediaPlayback: false`
/// et éjecte le flux `getUserMedia` de Stripe Identity vers le lecteur vidéo
/// plein écran d'iOS : la zone de capture reste noire et le parcours plante.
/// `mediaTypesRequiringUserAction` vide laisse le flux démarrer seul, la page
/// Stripe n'ayant aucun bouton « lecture » à proposer.
PlatformWebViewControllerCreationParams _creationParams() {
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    return WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
  }
  if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    return AndroidWebViewControllerCreationParams();
  }
  return const PlatformWebViewControllerCreationParams();
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
    // La route `/kyc/verify` est partagée avec l'écran de statut, et
    // l'observer PostHog n'en voit que le chemin : ce second `$screen`
    // distingue le parcours du fournisseur.
    final host = Uri.tryParse(widget.stripeUrl)?.host ?? '';
    unawaited(
      (widget.analytics ?? getIt<AnalyticsService>()).logScreen(
        AnalyticsEvents.kycProviderWebviewScreen,
        properties: {
          'provider': host.endsWith('stripe.com') ? 'stripe' : 'didit',
        },
      ),
    );
    _controller =
        WebViewController.fromPlatformCreationParams(
            _creationParams(),
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
                // N'alerter que si c'est la PAGE qui échoue. Une sous-ressource
                // en échec est sans conséquence : la page Didit charge une vidéo
                // d'illustration (`/videos/face_scan_compressed.mp4`) qui tombe
                // en `net::ERR_FAILED`, et l'utilisateur voyait « Impossible de
                // charger la page de vérification » en plein parcours réussi —
                // un message alarmant, faux, et de nature à faire abandonner.
                //
                // `isForMainFrame` peut être nul selon la plateforme : dans le
                // doute on alerte, pour ne jamais taire une vraie panne.
                if (error.isForMainFrame == false) {
                  return;
                }
                if (mounted) {
                  _isLoading.value = false;
                  DonySnackbar.show(
                    context,
                    message: context.l10n.kycWebviewLoadError,
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
                      kycVerifyLocation(
                        fromOnboarding: widget.progress != null,
                        returnTo: widget.returnTo,
                      ),
                    );
                  }
                  return NavigationDecision.prevent;
                }
                // N'autoriser que les pages hébergées par un fournisseur de
                // vérification connu. Tout le reste est refusé (hameçonnage,
                // redirection ouverte, file://, intent://, ...).
                //
                // Didit remplace progressivement Stripe Identity : les deux
                // domaines cohabitent tant que des comptes vérifiés côté Stripe
                // peuvent rouvrir leur session. Retirer Stripe d'ici le jour où
                // l'implémentation serveur correspondante disparaît.
                final uri = Uri.tryParse(request.url);
                if (uri == null || uri.scheme != 'https') {
                  return NavigationDecision.prevent;
                }
                return isVerificationProviderHost(uri.host)
                    ? NavigationDecision.navigate
                    : NavigationDecision.prevent;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.stripeUrl));

    // Pendant Android de `mediaTypesRequiringUserAction` : sans cela le flux
    // caméra attend un geste utilisateur que la page Stripe ne déclenche pas.
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Croix de l'en-tête, et retour système une fois l'historique de la page
  /// de vérification épuisé.
  void _close() {
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
        getIt<AuthRepository>().markOnboardingSeen().catchError((_) {}),
      );
      // Fin du parcours : « Par quoi commencer ? » plutôt que
      // l'accueil.
      context.go(firstStepsRoute);
      return;
    }
    context.go(destination);
  }

  /// Retour Android : l'écran n'a pas de bouton retour, seulement la croix.
  /// Sans ce relais, le retour du téléphone fermait l'application en pleine
  /// vérification (route ouverte par `go()`, seule dans la pile). On recule
  /// d'abord dans la page du fournisseur, puis on fait comme la croix.
  Future<void> _onSystemBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onSystemBack,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: DonyAppBar(
          title: l.kycVerificationTitle,
          showBackButton: false,
          actions: [
            IconButton(
              tooltip: l.commonClose,
              icon: DonyIcon('x', color: cs.onSurface),
              onPressed: _close,
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
                    ? Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
