import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../matching/presentation/widgets/trip_owner/trip_card_harness.dart'
    show loadAppFonts;
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

void main() {
  // Vraies polices : la police de repli des tests fausse la mesure à 360 dp.
  setUpAll(loadAppFonts);

  Future<VideoModalChoice?> Function() open(
    WidgetTester tester,
    VideoModalCampaign c, {
    Locale locale = AppL10n.fr,
  }) {
    VideoModalChoice? result;
    var done = false;
    return () async {
      await tester.pumpWidget(
        appWith(
          locale: locale,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await VideoModalSheet.show(context, campaign: c);
                  done = true;
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return done ? result : null;
    };
  }

  testWidgets('contenu de la maquette et boutons dans le pied collant', (
    tester,
  ) async {
    usePhone360(tester);
    await open(
      tester,
      campaign(
        highlights: [
          const VideoModalHighlight(icon: VideoModalIcon.parcel, text: 'Un'),
          const VideoModalHighlight(
            icon: VideoModalIcon.suitcase,
            text: 'Deux',
          ),
          const VideoModalHighlight(icon: VideoModalIcon.lock, text: 'Trois'),
        ],
      ),
    )();
    expect(find.text('Bienvenue sur Yadony'), findsOneWidget);
    expect(
      find.text("Envoyez ou voyagez, c'est vous qui choisissez."),
      findsOneWidget,
    );
    expect(find.text('3:24'), findsOneWidget);
    expect(find.text('Avec Yadony, vous pouvez'), findsOneWidget);
    expect(find.text('Un'), findsOneWidget);
    expect(find.text('Trois'), findsOneWidget);
    expect(find.byType(DonyButton), findsNWidgets(2));
    // Aucun bouton dans la partie qui défile.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(DonyButton),
      ),
      findsNothing,
    );
    // Empilés, le principal en haut, en pleine largeur.
    final primary = tester.getRect(
      find.byKey(const Key('video-modal-primary')),
    );
    final secondary = tester.getRect(
      find.byKey(const Key('video-modal-secondary')),
    );
    expect(primary.bottom, lessThanOrEqualTo(secondary.top));
    expect(primary.width, secondary.width);
    expect(primary.width, greaterThan(300));
    expectButtonLabelsFit(tester);
  });

  testWidgets('libellés anglais sur une ligne à 360 dp', (tester) async {
    usePhone360(tester);
    enableEnglish();
    await open(
      tester,
      campaign(
        primaryLabel: 'Watch the video (3 min)',
        secondaryLabel: 'Get started',
      ),
      locale: AppL10n.en,
    )();
    expect(find.text('With Yadony, you can'), findsOneWidget);
    expectButtonLabelsFit(tester);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('libellés de repli ($locale) sans liste ni sous-titre', (
      tester,
    ) async {
      usePhone360(tester);
      if (locale == AppL10n.en) enableEnglish();
      await open(
        tester,
        const VideoModalCampaign(
          id: 'c',
          version: 1,
          triggers: {VideoModalTrigger.searchTab},
          title: 'T',
          youtubeVideoId: 'dQw4w9WgXcQ',
        ),
        locale: locale,
      )();
      final l = lookupAppLocalizations(locale);
      expect(find.text(l.videoModalPrimaryFallback), findsOneWidget);
      expect(find.text(l.videoModalSecondaryFallback), findsOneWidget);
      expect(find.text(l.videoModalHighlightsTitle), findsNothing);
      expectButtonLabelsFit(tester);
    });
  }

  Future<VideoModalChoice?> tapAndRead(
    WidgetTester tester,
    Finder? target,
  ) async {
    VideoModalChoice? result;
    await tester.pumpWidget(
      appWith(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await VideoModalSheet.show(
                  context,
                  campaign: campaign(),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    if (target != null) {
      await tester.tap(target);
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('bouton principal = regarder', (tester) async {
    usePhone360(tester);
    expect(
      await tapAndRead(tester, find.byKey(const Key('video-modal-primary'))),
      VideoModalChoice.watch,
    );
  });

  testWidgets('miniature = regarder', (tester) async {
    usePhone360(tester);
    expect(
      await tapAndRead(tester, find.byKey(const Key('video-modal-thumbnail'))),
      VideoModalChoice.watch,
    );
  });

  testWidgets('bouton secondaire = ignorer', (tester) async {
    usePhone360(tester);
    expect(
      await tapAndRead(tester, find.byKey(const Key('video-modal-secondary'))),
      VideoModalChoice.dismiss,
    );
  });

  testWidgets('fermé d\'un geste : pas de réponse', (tester) async {
    usePhone360(tester);
    expect(await tapAndRead(tester, null), isNull);
  });

  test('icônes : jamais de camion', () {
    for (final i in VideoModalIcon.values) {
      expect(videoModalIconData(i), isNot(Icons.local_shipping_rounded));
    }
  });
}
