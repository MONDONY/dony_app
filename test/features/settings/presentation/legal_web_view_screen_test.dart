import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/presentation/screens/legal_web_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  _FakePlatformWebViewController(super.params)
      : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> reload() async {}
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate
    with MockPlatformInterfaceMixin {
  _FakePlatformNavigationDelegate(super.params)
      : super.implementation();

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget
    with MockPlatformInterfaceMixin {
  _FakePlatformWebViewWidget(super.params)
      : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  Widget wrap({String title = 'CGU', String url = 'https://dony.app/legal/terms'}) {
    return MaterialApp(
      home: LegalWebViewScreen(title: title, url: url),
    );
  }

  group('LegalWebViewScreen', () {
    testWidgets('affiche le titre fourni dans l\'AppBar', (tester) async {
      await tester.pumpWidget(wrap(title: 'CGU'));
      expect(find.text('CGU'), findsOneWidget);
    });

    testWidgets('affiche le titre "Politique de confidentialité"', (tester) async {
      await tester.pumpWidget(wrap(title: 'Politique de confidentialité'));
      expect(find.text('Politique de confidentialité'), findsOneWidget);
    });

    testWidgets('affiche l\'icône d\'ouverture externe dans l\'AppBar', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // une frame pour construire l'appbar
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'external-link'),
        findsOneWidget,
      );
    });

    testWidgets('dispose sans erreur', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      // Naviguer hors du widget pour déclencher dispose()
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      // Aucune exception n'est levée
    });
  });
}
