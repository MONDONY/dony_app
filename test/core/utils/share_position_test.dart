import 'package:dony/core/utils/share_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sharePositionOriginFor', () {
    testWidgets('returns a non-zero Rect matching the widget bounds', (
      tester,
    ) async {
      Rect? origin;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => origin = sharePositionOriginFor(context),
                    child: const Text('share'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('share'));
      await tester.pump();

      expect(origin, isNotNull);
      expect(origin!.width, greaterThan(0));
      expect(origin!.height, greaterThan(0));
    });
  });
}
