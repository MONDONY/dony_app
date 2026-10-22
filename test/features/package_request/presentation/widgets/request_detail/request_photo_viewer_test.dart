import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  // Le harnais `flutter test` renvoie systématiquement 400 sur tout
  // HttpClient sans jamais faire de vraie requête (avertissement du binding)
  // et flutter_cache_manager reste alors indéfiniment en `placeholder`
  // (constaté : le CircularProgressIndicator ne se résout jamais vers
  // `errorWidget` en pumps bornés). Non testable ici sans mocker le client
  // HTTP de cached_network_image — voir task-5-fix1-report.md. Ce test
  // couvre donc l'exigence vérifiable : ouvrir le visionneur avec une URL
  // invalide ne lève aucune exception (le contrat `errorWidget` existe et
  // est vérifié par lecture de code + `flutter analyze`).
  testWidgets(
    'URL invalide : ouverture du visionneur sans exception',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RequestPhotoViewer.show(
                  context,
                  urls: const ['https://host.invalid/introuvable.jpg'],
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        find.text('Fermer'),
        findsNothing,
      ); // tooltip, pas un texte affiché
      expect(find.byTooltip('Fermer'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('anglais : infobulle Close', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RequestPhotoViewer.show(
                context,
                urls: const ['https://host.invalid/introuvable.jpg'],
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets(
    'FLUTTER-GR : croix sur pastille, glisser vers le bas referme',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RequestPhotoViewer.show(
                  context,
                  urls: const ['https://host.invalid/introuvable.jpg'],
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DonyPhotoCloseButton), findsOneWidget);
      expect(find.byType(DonyPhotoDismiss), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DonyPhotoDismiss), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  group('compteur « n / total »', () {
    const urls = [
      'https://host.invalid/a.jpg',
      'https://host.invalid/b.jpg',
      'https://host.invalid/c.jpg',
    ];
    final counter = find.byKey(const Key('request-photo-viewer-counter'));

    Future<void> open(
      WidgetTester tester,
      List<String> list, {
      int initialIndex = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RequestPhotoViewer.show(
                  context,
                  urls: list,
                  initialIndex: initialIndex,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('plusieurs photos : « 1 / 3 » à l\'ouverture', (tester) async {
      await open(tester, urls);

      expect(counter, findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('ouvre sur la photo demandée', (tester) async {
      await open(tester, urls, initialIndex: 2);

      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('balayer passe à la photo suivante, puis revient', (
      tester,
    ) async {
      await open(tester, urls);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('une seule photo : pas de compteur', (tester) async {
      await open(tester, const ['https://host.invalid/a.jpg']);

      expect(counter, findsNothing);
      expect(find.byType(DonyPhotoCloseButton), findsOneWidget);
    });

    testWidgets('rang hors liste : ramené sur la dernière photo, sans erreur', (
      tester,
    ) async {
      await open(tester, urls, initialIndex: 9);

      expect(tester.takeException(), isNull);
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('rang négatif : ramené sur la première photo', (tester) async {
      await open(tester, urls, initialIndex: -4);

      expect(tester.takeException(), isNull);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('liste vide : s\'ouvre sans erreur ni compteur', (
      tester,
    ) async {
      await open(tester, const []);

      expect(tester.takeException(), isNull);
      expect(counter, findsNothing);
    });

    testWidgets('la croix referme la galerie', (tester) async {
      await open(tester, urls);

      await tester.tap(find.byType(DonyPhotoCloseButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DonyPhotoDismiss), findsNothing);
    });
  });
}
