import 'package:dony/core/design/widgets/dony_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('déclenche onTap au tap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        DonyPressable(
          onTap: () => tapped++,
          child: const SizedBox(width: 100, height: 100, child: Text('x')),
        ),
      ),
    );
    await tester.tap(find.text('x'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('réduit l\'échelle pendant la pression puis revient à 1', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        DonyPressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 100, child: Text('x')),
        ),
      ),
    );

    AnimatedScale scaleOf() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));

    expect(scaleOf().scale, 1.0);

    // Appui maintenu → scale cible = 0.96
    final gesture = await tester.startGesture(tester.getCenter(find.text('x')));
    await tester.pump();
    expect(scaleOf().scale, 0.96);

    // Relâché → retour à 1.0
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf().scale, 1.0);
  });

  testWidgets('scale personnalisable', (tester) async {
    await tester.pumpWidget(
      wrap(
        DonyPressable(
          onTap: () {},
          scale: 0.90,
          child: const SizedBox(width: 100, height: 100, child: Text('x')),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('x')));
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.90,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('enableHaptic=false ne déclenche pas de retour haptique', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      wrap(
        DonyPressable(
          onTap: () {},
          enableHaptic: false,
          child: const SizedBox(width: 100, height: 100, child: Text('x')),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('x')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
  });
}
