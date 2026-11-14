import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/transport_mode_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, TransportMode? mode) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransportModeIcon(mode: mode, size: 16, color: Colors.blue),
        ),
      ),
    );

Finder _icon(String name) => find.byWidgetPredicate(
  (w) => w is DonyIcon && w.name == name,
  description: 'DonyIcon $name',
);

void main() {
  group('TransportModeIcon', () {
    testWidgets('avion : icône plane tournée d\'un quart de tour', (
      tester,
    ) async {
      await _pump(tester, TransportMode.plane);
      expect(_icon('plane'), findsOneWidget);
      final rotated = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(rotated.quarterTurns, 1);
    });

    testWidgets('route, bus, bateau, train, autre : jamais tournée', (
      tester,
    ) async {
      const expected = {
        TransportMode.car: 'car',
        TransportMode.bus: 'car',
        TransportMode.boat: 'ship',
        TransportMode.train: 'route',
        TransportMode.other: 'route',
      };
      for (final entry in expected.entries) {
        await _pump(tester, entry.key);
        expect(_icon(entry.value), findsOneWidget, reason: '${entry.key}');
        expect(find.byType(RotatedBox), findsNothing, reason: '${entry.key}');
        expect(_icon('plane'), findsNothing, reason: '${entry.key}');
      }
    });

    testWidgets('mode absent (« peu importe ») : icône neutre, pas d\'avion', (
      tester,
    ) async {
      await _pump(tester, null);
      expect(_icon(kNeutralTripIconAsset), findsOneWidget);
      expect(find.byType(RotatedBox), findsNothing);
      expect(_icon('plane'), findsNothing);
    });

    testWidgets('taille et couleur transmises à l\'icône', (tester) async {
      await _pump(tester, TransportMode.car);
      final icon = tester.widget<DonyIcon>(_icon('car'));
      expect(icon.size, 16);
      expect(icon.color, Colors.blue);
    });
  });
}
