import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  group('DonyPhotoCloseButton (FLUTTER-GR)', () {
    testWidgets('pastille sombre semi-opaque, zone de tap de 44', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        Center(child: DonyPhotoCloseButton(onPressed: () => taps++)),
      );

      final hit = find.byKey(const Key('dony-photo-close'));
      expect(tester.getSize(hit), const Size(44, 44));
      final pill = tester.widget<DecoratedBox>(
        find.descendant(of: hit, matching: find.byType(DecoratedBox)).first,
      );
      final color = (pill.decoration as BoxDecoration).color!;
      expect(color.a, greaterThan(0.4));
      expect(color.computeLuminance(), lessThan(0.05));
      expect(find.byTooltip('Fermer'), findsOneWidget);
      expect(find.bySemanticsLabel('Fermer'), findsOneWidget);

      await tester.tap(hit);
      expect(taps, 1);
    });

    testWidgets('anglais : Close', (tester) async {
      useEnglish();
      await pump(tester, DonyPhotoCloseButton(onPressed: () {}));
      expect(find.byTooltip('Close'), findsOneWidget);
    });
  });

  group('DonyPhotoDismiss', () {
    Widget viewer(VoidCallback onDismiss, Widget child) =>
        DonyPhotoDismiss(onDismiss: onDismiss, child: child);

    testWidgets('photo glissée vers le bas : fermeture', (tester) async {
      var dismissed = 0;
      await pump(
        tester,
        viewer(
          () => dismissed++,
          const DonyZoomablePhoto(child: SizedBox.expand(key: Key('photo'))),
        ),
      );
      await tester.drag(find.byKey(const Key('photo')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });

    testWidgets('petit glissement lent : la photo revient en place', (
      tester,
    ) async {
      var dismissed = 0;
      await pump(
        tester,
        viewer(
          () => dismissed++,
          const DonyZoomablePhoto(child: SizedBox.expand(key: Key('photo'))),
        ),
      );
      final start = tester.getTopLeft(find.byKey(const Key('photo')));
      final gesture = await tester.startGesture(const Offset(200, 200));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getTopLeft(find.byKey(const Key('photo'))).dy,
        greaterThan(start.dy),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(dismissed, 0);
      expect(tester.getTopLeft(find.byKey(const Key('photo'))), start);
    });

    testWidgets('vers le haut : rien ne bouge', (tester) async {
      var dismissed = 0;
      await pump(
        tester,
        viewer(
          () => dismissed++,
          const DonyZoomablePhoto(child: SizedBox.expand(key: Key('photo'))),
        ),
      );
      await tester.drag(find.byKey(const Key('photo')), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(dismissed, 0);
    });

    testWidgets('zone sans photo (chargement, erreur) : fermeture aussi', (
      tester,
    ) async {
      var dismissed = 0;
      await pump(
        tester,
        viewer(
          () => dismissed++,
          const DonyPhotoDragArea(child: SizedBox.expand(key: Key('area'))),
        ),
      );
      await tester.drag(find.byKey(const Key('area')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });

    testWidgets('fermeture appelée une seule fois', (tester) async {
      var dismissed = 0;
      await pump(
        tester,
        viewer(
          () => dismissed++,
          const DonyPhotoDragArea(child: SizedBox.expand(key: Key('area'))),
        ),
      );
      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const Key('area')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    });
  });
}
