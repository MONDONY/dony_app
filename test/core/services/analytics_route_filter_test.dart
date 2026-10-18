import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/services/analytics_route_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Observe les routes poussées sur le navigateur racine.
class _RecordingObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

void main() {
  group('posthogRouteFilter', () {
    test('garde les pages', () {
      expect(
        posthogRouteFilter(
          MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
        isTrue,
      );
    });

    test('garde une feuille nommée /sheet/…', () {
      expect(
        posthogRouteFilter(
          ModalBottomSheetRoute<void>(
            builder: (_) => const SizedBox(),
            isScrollControlled: true,
            settings: const RouteSettings(name: '/sheet/payment'),
          ),
        ),
        isTrue,
      );
    });

    test('écarte une feuille ou un dialogue sans nom /sheet/', () {
      expect(
        posthogRouteFilter(
          ModalBottomSheetRoute<void>(
            builder: (_) => const SizedBox(),
            isScrollControlled: true,
          ),
        ),
        isFalse,
      );
      expect(
        posthogRouteFilter(
          RawDialogRoute<void>(
            pageBuilder: (_, _, _) => const SizedBox(),
            settings: const RouteSettings(name: '/dialog'),
          ),
        ),
        isFalse,
      );
      expect(posthogRouteFilter(null), isFalse);
    });
  });

  testWidgets('DonyBottomSheet.show(analyticsName:) nomme la route', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => DonyBottomSheet.show<void>(
              context,
              analyticsName: 'negotiation/accept-offer',
              child: const Text('contenu'),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final sheet = observer.pushed.last;
    expect(sheet.settings.name, '/sheet/negotiation/accept-offer');
    expect(posthogRouteFilter(sheet), isTrue);
  });

  testWidgets('sans analyticsName, la feuille reste hors du suivi', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => DonyBottomSheet.show<void>(
              context,
              child: const Text('contenu'),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(observer.pushed.last.settings.name, isNull);
    expect(posthogRouteFilter(observer.pushed.last), isFalse);
  });
}
