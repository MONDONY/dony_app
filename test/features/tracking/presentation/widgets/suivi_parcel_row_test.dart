import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(String status) => BidModel(
  id: 'bid-1',
  announcementId: 'trip-a',
  senderId: 's',
  status: status,
  recipientName: 'Awa',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Nombre de lignes réellement occupées par le libellé du bouton.
int _lineCount(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byKey(const Key('suivi-validate-label-bid-1')),
      matching: find.byType(RichText),
    ),
  );
  final length = paragraph.text.toPlainText().length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  return boxes.map((b) => b.top.round()).toSet().length;
}

/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et aucun libellé ne tient à 360 dp.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    required String status,
    required Locale locale,
    required double width,
    double textScale = 1,
    bool sending = false,
    void Function(BidModel, String)? onValidate,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(
            body: Padding(
              // Marges de l'onglet Suivi autour de la carte des colis.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SuiviParcelRow(
                    bid: _bid(status),
                    lastScan: null,
                    sending: sending,
                    onValidate: onValidate ?? (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Régression recette bateau (Redmi, 360 dp) : « Valider la récupération »
  // se coupait sur trois lignes à côté des informations du colis.
  for (final locale in AppLocalizations.supportedLocales) {
    for (final status in ['ACCEPTED', 'HANDED_OVER']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('libellé du bouton sur une ligne à 360 dp '
            '(${locale.languageCode}, $status, texte x$scale)', (tester) async {
          await pump(
            tester,
            status: status,
            locale: locale,
            width: 360,
            textScale: scale,
          );

          expect(_lineCount(tester), 1);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(const Key('suivi-validate-label-bid-1')),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final button = tester.getSize(
            find.byKey(const Key('suivi-validate-bid-1')),
          );
          expect(button.height, greaterThanOrEqualTo(44));
        });
      }
    }
  }

  testWidgets('sur écran large, le bouton reste à côté du colis', (
    tester,
  ) async {
    await pump(tester, status: 'ACCEPTED', locale: AppL10n.fr, width: 800);

    final button = tester.getCenter(
      find.byKey(const Key('suivi-validate-bid-1')),
    );
    final name = tester.getCenter(find.text('Awa'));
    expect(button.dy, closeTo(name.dy, 30));
    expect(button.dx, greaterThan(name.dx));
    expect(_lineCount(tester), 1);
  });

  testWidgets('sur écran étroit, le bouton passe sous le colis', (
    tester,
  ) async {
    await pump(tester, status: 'ACCEPTED', locale: AppL10n.fr, width: 360);

    final button = tester.getRect(
      find.byKey(const Key('suivi-validate-bid-1')),
    );
    final name = tester.getRect(find.text('Awa'));
    expect(button.top, greaterThan(name.bottom));
  });

  // Recette bateau : pendant l'envoi de la photo de dépôt, aucun indicateur,
  // et le bouton restait prêt à renvoyer.
  group('envoi en cours', () {
    testWidgets('le bouton tourne, dit « Envoi… » et ne renvoie rien', (
      tester,
    ) async {
      final calls = <String>[];
      await pump(
        tester,
        status: 'ACCEPTED',
        locale: AppL10n.fr,
        width: 360,
        sending: true,
        onValidate: (_, step) => calls.add(step),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('suivi-validate-progress-bid-1')),
        findsOneWidget,
      );
      expect(find.text('Envoi…'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('suivi-validate-bid-1')),
      );
      expect(button.onPressed, isNull);
      expect(calls, isEmpty);
    });

    testWidgets('au repos, le bouton valide l\'étape', (tester) async {
      final calls = <String>[];
      await pump(
        tester,
        status: 'ACCEPTED',
        locale: AppL10n.fr,
        width: 360,
        onValidate: (_, step) => calls.add(step),
      );

      expect(
        find.byKey(const Key('suivi-validate-progress-bid-1')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('suivi-validate-bid-1')));
      expect(calls, ['DEPART']);
    });
  });
}
