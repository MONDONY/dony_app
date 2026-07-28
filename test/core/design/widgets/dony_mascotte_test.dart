import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
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
    test('chaque type pointe vers un fichier existant', () {
      // Plusieurs types peuvent partager une illustration (ex. les états liés au
      // voyage), mais aucun ne doit pointer vers un asset absent.
      for (final t in DonyMascotteType.values) {
        expect(t.assetPath, isNotEmpty);
        expect(t.assetPath, startsWith('assets/mascotte/'));
        expect(t.assetPath, endsWith('.png'));
        expect(File(t.assetPath).existsSync(), isTrue,
            reason: 'asset manquant pour $t : ${t.assetPath}');
      }
    });

    test('aucun asset mascotte orphelin dans le dossier', () {
      final referenced =
          DonyMascotteType.values.map((t) => t.assetPath).toSet();
      final onDisk = Directory('assets/mascotte')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.png'))
          .toSet();
      expect(onDisk.difference(referenced), isEmpty,
          reason: 'assets embarqués mais jamais référencés par l\'enum');
    });

    test('chaque type a un semanticLabel non vide et distinct', () {
      final labels = <String>{};
      for (final t in DonyMascotteType.values) {
        expect(t.semanticLabel, isNotEmpty);
        expect(labels.add(t.semanticLabel), isTrue,
            reason: 'semanticLabel dupliqué : ${t.semanticLabel}');
      }
    });

    test('14 types exactement dans l\'enum', () {
      expect(DonyMascotteType.values.length, 14);
    });

    test('mappings asset corrects', () {
      expect(DonyMascotteType.joyeux.assetPath,
          'assets/mascotte/hello.png');
      expect(DonyMascotteType.bienvenue.assetPath,
          'assets/mascotte/welcome.png');
      expect(DonyMascotteType.confiant.assetPath,
          'assets/mascotte/travel.png');
      expect(DonyMascotteType.securise.assetPath,
          'assets/mascotte/success.png');
      expect(DonyMascotteType.succes.assetPath,
          'assets/mascotte/success_celebration.png');
      expect(DonyMascotteType.tenantColis.assetPath,
          'assets/mascotte/welcome.png');
      expect(DonyMascotteType.donneColis.assetPath,
          'assets/mascotte/travel.png');
      expect(DonyMascotteType.enCourse.assetPath,
          'assets/mascotte/travel.png');
      expect(DonyMascotteType.assis.assetPath,
          'assets/mascotte/empty_search.png');
      expect(DonyMascotteType.aucunResultat.assetPath,
          'assets/mascotte/no_result.png');
      expect(DonyMascotteType.attente.assetPath,
          'assets/mascotte/waiting.png');
      expect(DonyMascotteType.erreur.assetPath,
          'assets/mascotte/error.png');
      expect(DonyMascotteType.erreurLegere.assetPath,
          'assets/mascotte/error_light.png');
      expect(DonyMascotteType.scan.assetPath,
          'assets/mascotte/search.png');
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
      expect(assetImage.assetName, 'assets/mascotte/hello.png');
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

      expect(find.bySemanticsLabel('Mascotte qui salue'), findsOneWidget);
    });

    testWidgets('expose Semantics avec label pour assis', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotte(type: DonyMascotteType.assis),
      ));

      expect(
        find.bySemanticsLabel('Mascotte cherchant à la loupe, rien trouvé'),
        findsOneWidget,
      );
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

    testWidgets('scan charge le bon asset search.png', (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(type: DonyMascotteType.scan),
      ));
      // Avance d'un cycle (900ms) puis vérifie
      await tester.pump(const Duration(milliseconds: 950));

      final m = tester.widget<DonyMascotte>(find.byType(DonyMascotte));
      expect(m.type.assetPath, 'assets/mascotte/search.png');

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
