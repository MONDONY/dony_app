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

  testWidgets(
    'anglais : infobulle Close',
    (tester) async {
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
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
