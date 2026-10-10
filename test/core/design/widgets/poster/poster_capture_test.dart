import 'dart:typed_data';

import 'package:dony/core/design/widgets/poster/poster_capture.dart';
import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sans affiche montée, ne capture rien', (tester) async {
    final capture = PosterCapture();
    await tester.pumpWidget(const SizedBox());

    final bytes = await tester.runAsync(capture.rasterize);

    expect(bytes, isNull);
  });

  testWidgets('rastérise en 1080 x 1350 et mémoïse le PNG', (tester) async {
    final capture = PosterCapture();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capture.warmUp(context);
            return Center(
              child: RepaintBoundary(
                key: capture.key,
                child: const SizedBox(
                  width: PosterLayout.width,
                  height: PosterLayout.height,
                  child: ColoredBox(color: PosterPalette.ink),
                ),
              ),
            );
          },
        ),
      ),
    );

    final first = await tester.runAsync(capture.rasterize);
    final second = await tester.runAsync(capture.rasterize);

    expect(first, isNotNull);
    // Signature PNG, puis largeur et hauteur de l'en-tête IHDR.
    expect(first!.sublist(1, 4), 'PNG'.codeUnits);
    final header = ByteData.sublistView(first, 16, 24);
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1350);
    expect(identical(first, second), isTrue);
  });
}
