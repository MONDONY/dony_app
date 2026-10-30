import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/camera_permission_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// Permission caméra système au résultat choisi par le test.
class _FakeCameraPermission extends CameraPermissionService {
  _FakeCameraPermission(this.granted);
  final bool granted;

  @override
  Future<bool> request() async => granted;
}

class _FakeRequest extends PlatformWebViewPermissionRequest {
  _FakeRequest(Set<WebViewPermissionResourceType> types) : super(types: types);

  /// Décisions prises par l'écran, dans l'ordre (liste : la classe mère est
  /// immuable).
  final decisions = <String>[];

  String? get decision => decisions.isEmpty ? null : decisions.single;

  @override
  Future<void> grant() async => decisions.add('grant');

  @override
  Future<void> deny() async => decisions.add('deny');
}

/// Plateforme WebView qui garde les rappels posés par l'écran, pour que le
/// test joue la page : chargement, erreur, navigation, permission, retour.
class _CapturingPlatform extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onError;
  NavigationRequestCallback? onNavigation;
  void Function(PlatformWebViewPermissionRequest)? onPermission;
  final scripts = <String>[];
  bool canGoBack = false;
  int goBacks = 0;
  bool failScripts = false;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params, this);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Delegate(params, this);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
}

class _Controller extends PlatformWebViewController
    with MockPlatformInterfaceMixin {
  _Controller(super.params, this.platform) : super.implementation();
  final _CapturingPlatform platform;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) async => platform.onPermission = onPermissionRequest;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {
    if (platform.failScripts) throw StateError('page déchargée');
    platform.scripts.add(javaScript);
  }

  @override
  Future<bool> canGoBack() async => platform.canGoBack;

  @override
  Future<void> goBack() async => platform.goBacks++;
}

class _Delegate extends PlatformNavigationDelegate
    with MockPlatformInterfaceMixin {
  _Delegate(super.params, this.platform) : super.implementation();
  final _CapturingPlatform platform;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async =>
      platform.onPageStarted = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      platform.onPageFinished = onPageFinished;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async => platform.onError = onWebResourceError;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => platform.onNavigation = onNavigationRequest;
}

class _Widget extends PlatformWebViewWidget with MockPlatformInterfaceMixin {
  _Widget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  late _CapturingPlatform platform;
  late _MockAnalyticsService analytics;
  late _MockKycBloc kycBloc;
  late _MockAuthBloc authBloc;

  setUp(() {
    useEnglish();
    DonySnackbar.clearDedup();
    platform = _CapturingPlatform();
    WebViewPlatform.instance = platform;
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    kycBloc = _MockKycBloc();
    whenListen(
      kycBloc,
      const Stream<KycState>.empty(),
      initialState: const KycInitial(),
    );
    authBloc = _MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthInitial(),
    );
  });

  tearDown(() => getIt.reset());

  /// Monte l'écran sur `/kyc/verify` ; chaque autre route affiche son chemin.
  Future<void> pump(
    WidgetTester tester, {
    bool cameraGranted = true,
    String? returnTo,
    bool pushed = false,
  }) async {
    Widget echo(GoRouterState s) => Scaffold(body: Text('page ${s.uri}'));
    final router = GoRouter(
      initialLocation: pushed ? '/profile' : '/kyc/session',
      routes: [
        GoRoute(
          path: '/kyc/session',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<KycBloc>.value(value: kycBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: KycWebViewScreen(
              stripeUrl: 'https://verify.didit.me/session/x',
              analytics: analytics,
              cameraPermission: _FakeCameraPermission(cameraGranted),
              openAppSettings: () async {},
              returnTo: returnTo,
            ),
          ),
        ),
        GoRoute(path: '/kyc/verify', builder: (_, s) => echo(s)),
        GoRoute(path: '/home', builder: (_, s) => echo(s)),
        GoRoute(path: '/profile', builder: (_, s) => echo(s)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    if (pushed) {
      unawaited(router.push('/kyc/session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump();
  }

  NavigationDecision navigate(String url) =>
      platform.onNavigation!(NavigationRequest(url: url, isMainFrame: true))
          as NavigationDecision;

  group('chargement de la page', () {
    testWidgets('indicateur jusqu\'à la fin, puis relais caméra injecté', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      platform.onPageFinished!('https://verify.didit.me/session/x');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(platform.scripts, [kycCameraHookScript]);

      platform.onPageStarted!('https://verify.didit.me/next');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('script refusé par la page : sans conséquence', (tester) async {
      await pump(tester);
      platform.failScripts = true;
      platform.onPageFinished!('https://verify.didit.me/session/x');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('erreur de la page principale : avis d\'erreur', (
      tester,
    ) async {
      await pump(tester);
      platform.onError!(
        const WebResourceError(
          errorCode: -2,
          description: 'net::ERR_INTERNET_DISCONNECTED',
          isForMainFrame: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Unable to load the verification page'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('erreur d\'une sous-ressource : silence', (tester) async {
      await pump(tester);
      platform.onError!(
        const WebResourceError(
          errorCode: -1,
          description: 'net::ERR_FAILED',
          isForMainFrame: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Unable to load the verification page'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('navigation dans la webview', () {
    testWidgets('pages du fournisseur autorisées, le reste bloqué', (
      tester,
    ) async {
      await pump(tester);
      expect(
        navigate('https://verify.didit.me/step/2'),
        NavigationDecision.navigate,
      );
      expect(
        navigate('https://connect.stripe.com/x'),
        NavigationDecision.navigate,
      );
      expect(
        navigate('https://verify.didit.me.attaquant.com/'),
        NavigationDecision.prevent,
      );
      expect(navigate('http://verify.didit.me/'), NavigationDecision.prevent);
      expect(navigate('intent://scan'), NavigationDecision.prevent);
      expect(navigate('http://[::1'), NavigationDecision.prevent);
    });

    for (final host in ['yadony.com', 'dony.store', 'dony.app']) {
      testWidgets('retour $host/kyc/complete : écran de statut', (
        tester,
      ) async {
        await pump(tester);
        expect(
          navigate('https://$host/kyc/complete?session=x'),
          NavigationDecision.prevent,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('page /kyc/verify'), findsOneWidget);
      });
    }

    testWidgets('retour du fournisseur : l\'écran où revenir est conservé', (
      tester,
    ) async {
      await pump(tester, returnTo: '/parcels/send-intro');
      navigate('https://yadony.com/kyc/complete');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('page /kyc/verify?next=%2Fparcels%2Fsend-intro'),
        findsOneWidget,
      );
    });
  });

  group('permission caméra', () {
    testWidgets('caméra accordée par le système : la page l\'obtient', (
      tester,
    ) async {
      await pump(tester);
      final request = _FakeRequest(const {
        WebViewPermissionResourceType.camera,
      });
      platform.onPermission!(request);
      await tester.pump();
      expect(request.decision, 'grant');
    });

    testWidgets('caméra refusée : refus et feuille d\'explication', (
      tester,
    ) async {
      await pump(tester, cameraGranted: false);
      final request = _FakeRequest(const {
        WebViewPermissionResourceType.camera,
      });
      platform.onPermission!(request);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(request.decision, 'deny');
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('micro seul : aucune décision', (tester) async {
      await pump(tester);
      final request = _FakeRequest(const {
        WebViewPermissionResourceType.microphone,
      });
      platform.onPermission!(request);
      await tester.pump();
      expect(request.decision, isNull);
    });
  });

  group('sortie', () {
    testWidgets('la croix abandonne la session et mène à l\'accueil', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => kycBloc.add(const KycSessionAbandoned())).called(1);
      verify(() => authBloc.add(const AuthCheckRequested())).called(1);
      expect(find.text('page /home'), findsOneWidget);
    });

    testWidgets('ouverte par-dessus un écran : la croix y revient', (
      tester,
    ) async {
      await pump(tester, pushed: true);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      verify(() => kycBloc.add(const KycSessionAbandoned())).called(1);
      expect(find.text('page /profile'), findsOneWidget);
      expect(find.byType(KycWebViewScreen), findsNothing);
    });

    testWidgets('retour système : recule d\'abord dans la page', (
      tester,
    ) async {
      await pump(tester);
      platform.canGoBack = true;
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(platform.goBacks, 1);
      verifyNever(() => kycBloc.add(const KycSessionAbandoned()));

      // Historique épuisé : comme la croix.
      platform.canGoBack = false;
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => kycBloc.add(const KycSessionAbandoned())).called(1);
      expect(find.text('page /home'), findsOneWidget);
    });
  });
}
