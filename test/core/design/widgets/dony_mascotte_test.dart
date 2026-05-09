import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyMascotteType', () {
    test('chaque type expose un assetPath unique non vide', () {
      final paths = DonyMascotteType.values.map((t) => t.assetPath).toSet();
      expect(paths.length, DonyMascotteType.values.length,
          reason: 'paths must be unique');
      for (final p in paths) {
        expect(p, isNotEmpty);
        expect(p, startsWith('assets/mascottes/'));
        expect(p, endsWith('.png'));
      }
    });

    test('chaque type a un semanticLabel non vide', () {
      for (final t in DonyMascotteType.values) {
        expect(t.semanticLabel, isNotEmpty);
      }
    });

    test('mappings sémantiques attendus', () {
      expect(DonyMascotteType.salue.assetPath,
          'assets/mascottes/salue.png');
      expect(DonyMascotteType.pouceLeve.assetPath,
          'assets/mascottes/pouce_leve.png');
      expect(DonyMascotteType.colisLivre.assetPath,
          'assets/mascottes/colis_livre.png');
      expect(DonyMascotteType.noData.assetPath,
          'assets/mascottes/no_data.png');
    });
  });

  group('DonyMascotteSize', () {
    test('dimensions croissantes', () {
      expect(DonyMascotteSize.sm.dimension, 64);
      expect(DonyMascotteSize.md.dimension, 96);
      expect(DonyMascotteSize.lg.dimension, 160);
      expect(DonyMascotteSize.xl.dimension, 240);
    });
  });

  group('DonyMascotte widget', () {
    testWidgets('rend une Image au bon assetPath', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DonyMascotte(type: DonyMascotteType.salue),
        ),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/mascottes/salue.png');
    });

    testWidgets('utilise dimension par défaut (md = 96)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DonyMascotte(type: DonyMascotteType.salue)),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 96);
      expect(image.height, 96);
    });

    testWidgets('size lg force dimension 160', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DonyMascotte(
            type: DonyMascotteType.salue,
            size: DonyMascotteSize.lg,
          ),
        ),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 160);
    });

    testWidgets('customDimension override le size', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: DonyMascotte(
            type: DonyMascotteType.salue,
            size: DonyMascotteSize.lg,
            customDimension: 42,
          ),
        ),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 42);
      expect(image.height, 42);
    });

    testWidgets('borderRadius enveloppe dans ClipRRect', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DonyMascotte(
            type: DonyMascotteType.salue,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ));

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('sans borderRadius : pas de ClipRRect', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DonyMascotte(type: DonyMascotteType.salue)),
      ));

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('expose Semantics avec label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DonyMascotte(type: DonyMascotteType.salue)),
      ));

      expect(
        find.bySemanticsLabel('Mascotte qui salue'),
        findsOneWidget,
      );
    });
  });
}
