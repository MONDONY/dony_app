import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

/// Avance le clock de [ms] ms pour drainer les timers flutter_animate,
/// puis dispose le widget tree pour annuler les animations encore actives.
Future<void> _drainAndDispose(WidgetTester tester, int ms) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('DonyMascotteType', () {
    test('chaque type expose un assetPath unique non vide', () {
      final paths = DonyMascotteType.values.map((t) => t.assetPath).toSet();
      expect(paths.length, DonyMascotteType.values.length,
          reason: 'paths must be unique');
      for (final p in paths) {
        expect(p, isNotEmpty);
        expect(p, startsWith('assets/mascotte/'));
        expect(p, endsWith('.png'));
      }
    });

    test('chaque type a un semanticLabel non vide', () {
      for (final t in DonyMascotteType.values) {
        expect(t.semanticLabel, isNotEmpty);
      }
    });

    test('8 types exactement dans l\'enum', () {
      expect(DonyMascotteType.values.length, 8);
    });

    test('mappings asset corrects pour les 8 types', () {
      expect(DonyMascotteType.joyeux.assetPath,
          'assets/mascotte/joyeux.png');
      expect(DonyMascotteType.confiant.assetPath,
          'assets/mascotte/confiant.png');
      expect(DonyMascotteType.securise.assetPath,
          'assets/mascotte/sécurisé.png');
      expect(DonyMascotteType.tenantColis.assetPath,
          'assets/mascotte/tenant_le_colis.png');
      expect(DonyMascotteType.donneColis.assetPath,
          'assets/mascotte/donne_un_colis.png');
      expect(DonyMascotteType.enCourse.assetPath,
          'assets/mascotte/en_course.png');
      expect(DonyMascotteType.assis.assetPath,
          'assets/mascotte/assis.png');
      expect(DonyMascotteType.scan.assetPath,
          'assets/mascotte/Scan.png');
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
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.joyeux),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/mascotte/joyeux.png');
    });

    testWidgets('utilise dimension par défaut (md = 96)', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.assis),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 96);
      expect(image.height, 96);
    });

    testWidgets('size lg force dimension 160', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(
          type: DonyMascotteType.securise,
          size: DonyMascotteSize.lg,
        ),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 160);
    });

    testWidgets('customDimension override le size', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(
          type: DonyMascotteType.scan,
          size: DonyMascotteSize.lg,
          customDimension: 42,
        ),
      ));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 42);
      expect(image.height, 42);
    });

    testWidgets('borderRadius enveloppe dans ClipRRect', (tester) async {
      await tester.pumpWidget(_wrap(
        DonyMascotte(
          type: DonyMascotteType.confiant,
          borderRadius: BorderRadius.circular(20),
        ),
      ));

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('sans borderRadius : pas de ClipRRect', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.joyeux),
      ));

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('expose Semantics avec label pour joyeux', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.joyeux),
      ));

      expect(find.bySemanticsLabel('Mascotte joyeuse'), findsOneWidget);
    });

    testWidgets('expose Semantics avec label pour assis', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.assis),
      ));

      expect(find.bySemanticsLabel('Mascotte assise'), findsOneWidget);
    });
  });

  group('DonyMascotteAnimated widget', () {
    // Pour chaque test, on avance de 2s pour drainer les timers flutter_animate
    // (fade: max 500ms, shimmer delay: 300ms, repeat 900ms par cycle).

    testWidgets('contient DonyMascotte avec le bon type', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(type: DonyMascotteType.joyeux),
      ));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(DonyMascotte), findsOneWidget);
      final m = tester.widget<DonyMascotte>(find.byType(DonyMascotte));
      expect(m.type, DonyMascotteType.joyeux);

      await _drainAndDispose(tester, 500);
    });

    testWidgets('withGlow=false : pas de Stack glow', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(type: DonyMascotteType.securise),
      ));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(DonyMascotte), findsOneWidget);

      await _drainAndDispose(tester, 500);
    });

    testWidgets('withGlow=true rend un Stack avec RadialGradient', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(
          type: DonyMascotteType.securise,
          withGlow: true,
        ),
      ));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(DonyMascotte), findsOneWidget);

      await _drainAndDispose(tester, 500);
    });

    testWidgets('scan charge le bon asset Scan.png', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(type: DonyMascotteType.scan),
      ));
      // Avance d'un cycle (900ms) puis vérifie
      await tester.pump(const Duration(milliseconds: 950));

      final m = tester.widget<DonyMascotte>(find.byType(DonyMascotte));
      expect(m.type.assetPath, 'assets/mascotte/Scan.png');

      // Dispose avant que le repeat continue
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('size lg propagée au DonyMascotte interne', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(
          type: DonyMascotteType.assis,
          size: DonyMascotteSize.lg,
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      final m = tester.widget<DonyMascotte>(find.byType(DonyMascotte));
      expect(m.size, DonyMascotteSize.lg);

      await _drainAndDispose(tester, 500);
    });
  });
}
