import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
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

// ---------------------------------------------------------------------------
// Minimal WebView platform stubs (do not test WebView internals)
// ---------------------------------------------------------------------------

class _FakeWebViewPlatform extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _FakePlatformWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _FakePlatformNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakePlatformWebViewWidget(params);
}

class _FakePlatformWebViewController extends PlatformWebViewController
    with MockPlatformInterfaceMixin {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request)
        onPermissionRequest,
  ) async {}
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate
    with MockPlatformInterfaceMixin {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {}

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockKycBloc mockKycBloc;
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
    registerFallbackValue(const KycSessionAbandoned());
    registerFallbackValue(const AuthCheckRequested());
  });

  setUp(() {
    getIt.reset();
    mockKycBloc = MockKycBloc();
    mockAuthBloc = MockAuthBloc();
    whenListen<KycState>(
      mockKycBloc,
      Stream.value(const KycInitial()),
      initialState: const KycInitial(),
    );
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(const AuthInitial()),
      initialState: const AuthInitial(),
    );
  });

  Widget wrap() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MultiBlocProvider(
              providers: [
                BlocProvider<KycBloc>.value(value: mockKycBloc),
                BlocProvider<AuthBloc>.value(value: mockAuthBloc),
              ],
              child: const KycWebViewScreen(
                stripeUrl: 'https://verify.stripe.com/start/vs_test',
              ),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
        ],
      ),
    );
  }

  group('KycWebViewScreen', () {
    testWidgets('système back button abandons session and returns home '
        '(regression: used to exit the whole app)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      // Simulates the Android hardware back button / iOS swipe-back gesture.
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      final bool handled = await navigator.maybePop();

      await tester.pumpAndSettle();

      expect(handled, isTrue);
      verify(() => mockKycBloc.add(const KycSessionAbandoned())).called(1);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('tap sur "✕" abandons session and returns home',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      verify(() => mockKycBloc.add(const KycSessionAbandoned())).called(1);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
