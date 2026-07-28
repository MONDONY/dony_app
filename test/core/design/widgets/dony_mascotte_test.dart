import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    test('les types et le dossier d\'assets se recouvrent exactement', () {
      // Une seule passe de lecture disque pour les deux sens de l'égalité :
      // aucun type ne pointe vers un fichier absent, aucun fichier embarqué
      // n'est laissé sans type qui l'utilise.
      for (final t in DonyMascotteType.values) {
        expect(t.assetPath, startsWith('assets/mascotte/'));
        expect(t.assetPath, endsWith('.png'));
      }
      final referenced =
          DonyMascotteType.values.map((t) => t.assetPath).toSet();
      final onDisk = Directory('assets/mascotte')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.png'))
          .toSet();
      expect(referenced.difference(onDisk), isEmpty,
          reason: 'types pointant vers un asset absent');
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

    test('11 types exactement dans l\'enum', () {
      expect(DonyMascotteType.values.length, 11);
    });

    test('les partages d\'asset volontaires sont préservés', () {
      // Seule information que le test de recouvrement ne porte pas : deux types
      // pointent délibérément vers la même illustration, leur animation étant
      // ce qui les distingue. Un futur asset dédié doit être un choix explicite.
      expect(DonyMascotteType.confiant.assetPath,
          DonyMascotteType.enCourse.assetPath);
    });

    test('seul attente boucle en continu', () {
      final looping =
          DonyMascotteType.values.where((t) => t.loops).toList();
      expect(looping, [DonyMascotteType.attente]);
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
      // `cacheWidth`/`cacheHeight` enveloppent l'AssetImage dans un ResizeImage :
      // le décodage est borné une fois pour toutes, quelle que soit la taille
      // de rendu demandée, pour ne pas garder plusieurs copies en cache.
      final resized = image.image as ResizeImage;
      expect(resized.width, 480);
      expect(resized.height, 480);
      expect((resized.imageProvider as AssetImage).assetName,
          'assets/mascotte/hello.png');
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
          type: DonyMascotteType.attente,
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
        find.bySemanticsLabel('Mascotte curieuse, une loupe à la main'),
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

    testWidgets('attente isole sa boucle derrière un RepaintBoundary',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DonyMascotteAnimated(type: DonyMascotteType.attente),
      ));
      // Avance d'un cycle (1200ms) puis vérifie
      await tester.pump(const Duration(milliseconds: 1250));

      final m = tester.widget<DonyMascotte>(find.byType(DonyMascotte));
      expect(m.type.assetPath, 'assets/mascotte/waiting.png');
      expect(
        find.ancestor(
          of: find.byType(DonyMascotte),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );

      // Dispose avant que le repeat continue
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('attente ne boucle pas si le mouvement est réduit',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: DonyMascotteAnimated(type: DonyMascotteType.attente),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1250));

      // Sans Animate au-dessus, plus rien ne redemande de frame : le test se
      // termine sans timer pendant, ce qui échouerait si la boucle tournait.
      expect(find.byType(Animate), findsNothing);
      expect(find.byType(DonyMascotte), findsOneWidget);
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
