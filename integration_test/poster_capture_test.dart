// Valide la rasterisation de l'affiche sur un appareil REEL.
//
// Ce test existe parce que le rendu d'un `RepaintBoundary` depend du GPU : sur
// l'emulateur `dony_test`, dont le GPU est logiciel, `toImage()` renvoie une
// image noire ou gele. Aucun test unitaire ne peut le detecter, la couche de
// rendu y etant simulee. Il faut donc verifier sur du materiel.
//
// Il verifie trois choses qu'un widget test ne voit pas :
//   1. la sortie fait bien 1080 x 1350 (pixelRatio 3 sur la taille logique) ;
//   2. l'image n'est ni noire ni uniforme, donc le GPU a reellement peint ;
//   3. les images d'asset (mot-logo, badges) sont presentes apres prechargement,
//      ce qui se mesure par la part de pixels sombres du bas de l'affiche.
//
// Lancer : flutter test integration_test/poster_capture_test.dart -d <device>
// Le PNG capture est reemis en base64 dans la sortie du test, entre les marqueurs
// POSTER_B64_START et POSTER_B64_END, pour pouvoir etre regarde a l'oeil.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/poster/trip_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement() => AnnouncementModel.fromJson({
  'id': '3f2a9c14-7b6e-4d18-9a52-c0e1f8b3d764',
  'travelerId': 't1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'departureDate': DateTime(2026, 8, 20).toIso8601String(),
  'availableKg': 12.0,
  'totalKg': 23.0,
  'pricePerKg': 7.14,
  'pricePerKgDisplay': 8.0,
  'handoverDeadline': DateTime(2026, 8, 19, 19).toIso8601String(),
  'currency': 'EUR',
  'pricingMode': 'KG',
  'priceGridItems': const [],
  'capacityUnit': 'SUITCASE_23KG',
  'pickupAddress': {
    'label': '12 rue de Tombouctou, 75018 Paris',
    'lat': 48.8920,
    'lng': 2.3550,
  },
  'deliveryAddress': {
    'label': 'Sacre-Coeur 3, villa 1245, Dakar',
    'lat': 14.6930,
    'lng': -17.4470,
  },
  'status': 'ACTIVE',
  'createdAt': DateTime(2026, 8).toIso8601String(),
  'updatedAt': DateTime(2026, 8).toIso8601String(),
});

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('l\'affiche se rasterise en 1080x1350 sur appareil reel', (
    tester,
  ) async {
    await initializeDateFormatting('fr');

    final posterKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: posterKey,
              child: TripPosterCard(announcement: _announcement()),
            ),
          ),
        ),
      ),
    );

    // Meme prechargement que TripPosterScreen : sans lui, la capture sortirait
    // amputee du mot-logo et des badges, silencieusement.
    final context = tester.element(find.byType(TripPosterCard));
    for (final asset in [
      DonyLogo.asset,
      TripPosterCard.appStoreBadgeAsset,
      TripPosterCard.googlePlayBadgeAsset,
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
    await tester.pumpAndSettle();

    final boundary =
        posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final width = image.width;
    final height = image.height;

    final rgba = await image.toByteData();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    expect(width, 1080, reason: 'largeur de sortie attendue 1080');
    expect(height, 1350, reason: 'hauteur de sortie attendue 1350');
    expect(png, isNotNull);

    // Le symptome de l'emulateur est une image noire ou uniforme : on echantillonne
    // pour verifier que le GPU a reellement peint quelque chose de contraste.
    final pixels = rgba!.buffer.asUint8List();
    var opaque = 0;
    var light = 0;
    var dark = 0;
    var blue = 0;
    for (var i = 0; i < pixels.length; i += 4 * 97) {
      final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2], a = pixels[i + 3];
      if (a > 200) {
        opaque++;
        if (r > 220 && g > 220 && b > 220) light++;
        if (r < 60 && g < 60 && b < 60) dark++;
        if (b > 150 && b - r > 80) blue++;
      }
    }

    expect(opaque, greaterThan(0), reason: 'image entierement transparente');
    // Le fond de l'affiche est blanc : sans lui, l'image est noire (bug GPU).
    expect(
      light / opaque,
      greaterThan(0.4),
      reason: 'fond blanc absent, capture probablement noire',
    );
    // Les badges des stores sont des rectangles noirs : leur absence signale un
    // asset non decode au moment de la capture.
    expect(
      dark / opaque,
      greaterThan(0.005),
      reason: 'aucun pixel sombre, badges des stores absents de la capture',
    );
    // Le bloc prix et le mot-logo sont bleus.
    expect(
      blue / opaque,
      greaterThan(0.02),
      reason: 'aucun pixel bleu, bloc prix ou mot-logo absent',
    );

    // Le PNG transite par la sortie du test, en base64 tronconne.
    //
    // Ni le dossier documents ni le stockage externe de l'application ne sont
    // recuperables : `run-as` est bride par certains constructeurs, et depuis
    // Android 11 `Android/data` est ferme meme a adb. La sortie standard, elle,
    // traverse toujours.
    final bytes = png!.buffer.asUint8List();
    final encoded = base64Encode(bytes);
    // `print` et non `debugPrint` : ce dernier bride le debit et *jette* les
    // lignes excedentaires, ce qui tronquait le PNG en silence.
    // ignore: avoid_print
    print('POSTER_B64_START ${encoded.length}');
    for (var i = 0; i < encoded.length; i += 720) {
      final end = i + 720 < encoded.length ? i + 720 : encoded.length;
      // ignore: avoid_print
      print('POSTER_B64 ${encoded.substring(i, end)}');
    }
    // ignore: avoid_print
    print('POSTER_B64_END');
    // ignore: avoid_print
    print('POSTER_STATS opaque=$opaque clair=$light sombre=$dark bleu=$blue');
  });
}
