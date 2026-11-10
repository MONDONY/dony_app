import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/info_modal_sheet.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_frame.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_image.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../matching/presentation/widgets/trip_owner/trip_card_harness.dart'
    show loadAppFonts;
import '../video_modal_test_data.dart';
import 'video_modal_image_test.dart' show fakeModalImage;
import 'video_modal_widget_harness.dart';

const _url = 'https://cdn.yadony.com/video-modals/i1/1.webp';

void setScreen(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(loadAppFonts);

  Object? result;
  var closed = false;

  Future<void> pumpHost(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) show, {
    Locale locale = AppL10n.fr,
  }) async {
    result = 'rien';
    closed = false;
    await tester.pumpWidget(
      appWith(
        locale: locale,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await show(context);
                closed = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> openInfo(
    WidgetTester tester,
    VideoModalCampaign c, {
    VideoModalImage? image,
    Locale locale = AppL10n.fr,
  }) => pumpHost(
    tester,
    (ctx) => InfoModalSheet.show(ctx, campaign: c, image: image),
    locale: locale,
  );

  Future<void> openVideo(
    WidgetTester tester,
    VideoModalCampaign c, {
    Locale locale = AppL10n.fr,
  }) => pumpHost(
    tester,
    (ctx) => VideoModalSheet.show(ctx, campaign: c),
    locale: locale,
  );

  final cross = find.byKey(const Key('video-modal-close'));
  final footer = find.byKey(const Key('video-modal-footer'));

  Finder frameOf(VideoModalLayout l) => switch (l) {
    VideoModalLayout.bottomSheet => find.byKey(
      const Key('donyBottomSheetFooter'),
    ),
    VideoModalLayout.centered => find.byKey(const Key('video-modal-card')),
    VideoModalLayout.fullscreen => find.byKey(
      const Key('video-modal-fullscreen'),
    ),
  };

  final longBody = List.filled(
    80,
    'Une phrase assez longue pour remplir le modal.',
  ).join(' ');

  group('chaque habillage, information', () {
    for (final layout in VideoModalLayout.values) {
      group(layout.wire, () {
        testWidgets('contenu, boutons empilés fixes hors du défilement', (
          tester,
        ) async {
          usePhone360(tester);
          await openInfo(tester, infoCampaign(layout: layout));
          expect(frameOf(layout), findsOneWidget);
          expect(find.text('Mon argent'), findsOneWidget);
          expect(find.byType(DonyButton), findsNWidgets(2));
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(DonyButton),
            ),
            findsNothing,
          );
          final p = tester.getRect(find.byKey(const Key('info-modal-primary')));
          final s = tester.getRect(
            find.byKey(const Key('info-modal-secondary')),
          );
          expect(p.bottom, lessThanOrEqualTo(s.top));
          expect(p.width, s.width);
          expect(p.width, greaterThan(250));
          expectButtonLabelsFit(tester);
        });

        testWidgets('libellés anglais les plus longs : une ligne à 360 dp', (
          tester,
        ) async {
          usePhone360(tester);
          enableEnglish();
          await openInfo(
            tester,
            infoCampaign(
              layout: layout,
              primaryLabel: 'Open my money screen now',
              secondaryLabel: 'Maybe later, thanks',
            ),
            locale: AppL10n.en,
          );
          expectButtonLabelsFit(tester);
        });

        testWidgets('texte long : défile, boutons fixes', (tester) async {
          usePhone360(tester);
          await openInfo(tester, infoCampaign(layout: layout, body: longBody));
          final primary = find.byKey(const Key('info-modal-primary'));
          final before = tester.getRect(primary);
          await tester.drag(
            find.byKey(const Key('info-modal-body')),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(primary), before);
          expect(
            before.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height / 3),
          );
          expect(tester.takeException(), isNull);
        });

        for (final (name, w, h) in [
          ('petit écran 320x480', 320.0, 480.0),
          ('paysage 740x360', 740.0, 360.0),
          ('très grand écran 900x1400', 900.0, 1400.0),
        ]) {
          testWidgets('$name : aucun dépassement, boutons entiers', (
            tester,
          ) async {
            setScreen(tester, w, h);
            await openInfo(
              tester,
              infoCampaign(layout: layout, body: longBody),
            );
            expect(tester.takeException(), isNull);
            final screen = Offset.zero & Size(w, h);
            for (final k in ['info-modal-primary', 'info-modal-secondary']) {
              final r = tester.getRect(find.byKey(Key(k)));
              expect(screen.contains(r.topLeft), isTrue, reason: k);
              expect(screen.contains(r.bottomRight), isTrue, reason: k);
            }
          });
        }

        testWidgets('toucher le bouton principal rend primary', (tester) async {
          usePhone360(tester);
          await openInfo(tester, infoCampaign(layout: layout));
          await tester.tap(find.byKey(const Key('info-modal-primary')));
          await tester.pumpAndSettle();
          expect(result, InfoModalChoice.primary);
        });

        testWidgets('retour système : pas une réponse (null)', (tester) async {
          usePhone360(tester);
          await openInfo(tester, infoCampaign(layout: layout));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(closed, isTrue);
          expect(result, isNull);
        });
      });
    }

    testWidgets('feuille du bas : pas de croix', (tester) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign());
      expect(cross, findsNothing);
    });

    for (final layout in [
      VideoModalLayout.centered,
      VideoModalLayout.fullscreen,
    ]) {
      testWidgets('${layout.wire} : la croix ferme explicitement (closed)', (
        tester,
      ) async {
        usePhone360(tester);
        await openInfo(tester, infoCampaign(layout: layout, secondary: null));
        expect(cross, findsOneWidget);
        // Toujours visible, même contenu long.
        await tester.tap(cross);
        await tester.pumpAndSettle();
        expect(result, InfoModalChoice.closed);
      });
    }

    testWidgets('carte centrée : toucher à côté n\'est pas une réponse', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign(layout: VideoModalLayout.centered));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('plein écran : ne se ferme pas en touchant à côté', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign(layout: VideoModalLayout.fullscreen));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
    });
  });

  group('taille', () {
    testWidgets('feuille du bas : hauteur max = % de l\'écran', (tester) async {
      usePhone360(tester); // 360 x 780
      await openInfo(tester, infoCampaign(sizePercent: 40, body: longBody));
      final sheet = find.ancestor(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.byType(Container),
      );
      final top = tester.getTopLeft(sheet.last).dy;
      expect(780 - top, lessThanOrEqualTo(780 * 0.4 + 1));
      expect(780 - top, greaterThan(780 * 0.3));
    });

    testWidgets('feuille du bas : contenu court garde sa taille naturelle', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign(sizePercent: 90));
      final footerTop = tester.getTopLeft(
        find.byKey(const Key('donyBottomSheetFooter')),
      );
      expect(footerTop.dy, greaterThan(780 * 0.4));
    });

    testWidgets('feuille du bas à 100 % : sous la barre d\'état', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign(sizePercent: 100, body: longBody));
      expect(tester.takeException(), isNull);
    });

    testWidgets('carte centrée : hauteur max = % de l\'écran', (tester) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(
          layout: VideoModalLayout.centered,
          sizePercent: 50,
          body: longBody,
        ),
      );
      final h = tester
          .getSize(find.byKey(const Key('video-modal-card')))
          .height;
      expect(h, lessThanOrEqualTo(780 * 0.5 + 1));
      expect(h, greaterThan(780 * 0.4));
    });

    testWidgets('carte centrée à 100 % : reste dans l\'écran avec ses marges', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(
          layout: VideoModalLayout.centered,
          sizePercent: 100,
          body: longBody,
        ),
      );
      final r = tester.getRect(find.byKey(const Key('video-modal-card')));
      expect(r.top, greaterThanOrEqualTo(VideoModalFrame.dialogInset - 0.5));
      expect(
        r.bottom,
        lessThanOrEqualTo(780 - VideoModalFrame.dialogInset + 0.5),
      );
    });

    testWidgets('carte centrée sans taille : épouse un contenu court', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign(layout: VideoModalLayout.centered));
      final h = tester
          .getSize(find.byKey(const Key('video-modal-card')))
          .height;
      expect(h, lessThan(780 * 0.7));
    });

    testWidgets('plein écran : occupe tout l\'écran, taille ignorée', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(layout: VideoModalLayout.fullscreen, sizePercent: 30),
      );
      expect(
        tester.getSize(find.byKey(const Key('video-modal-fullscreen'))),
        const Size(360, 780),
      );
    });
  });

  group('vidéo', () {
    for (final layout in VideoModalLayout.values) {
      testWidgets('${layout.wire} : boutons fixes, libellés sur une ligne', (
        tester,
      ) async {
        usePhone360(tester);
        await openVideo(tester, campaign(layout: layout, sizePercent: 70));
        expect(find.byKey(const Key('video-modal-thumbnail')), findsOneWidget);
        expect(find.byType(DonyButton), findsNWidgets(2));
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(DonyButton),
          ),
          findsNothing,
        );
        expectButtonLabelsFit(tester);
      });

      testWidgets('${layout.wire} EN : libellés sur une ligne', (tester) async {
        usePhone360(tester);
        enableEnglish();
        await openVideo(
          tester,
          campaign(
            layout: layout,
            primaryLabel: 'Watch the video (3 min)',
            secondaryLabel: 'Get started',
          ),
          locale: AppL10n.en,
        );
        expectButtonLabelsFit(tester);
      });

      testWidgets('${layout.wire} paysage : aucun dépassement', (tester) async {
        setScreen(tester, 740, 360);
        await openVideo(tester, campaign(layout: layout));
        expect(tester.takeException(), isNull);
        final r = tester.getRect(
          find.byKey(const Key('video-modal-secondary')),
        );
        expect(r.bottom, lessThanOrEqualTo(360));
      });
    }

    for (final layout in [
      VideoModalLayout.centered,
      VideoModalLayout.fullscreen,
    ]) {
      testWidgets('${layout.wire} : la croix rend dismiss', (tester) async {
        usePhone360(tester);
        await openVideo(tester, campaign(layout: layout));
        await tester.tap(cross);
        await tester.pumpAndSettle();
        expect(result, VideoModalChoice.dismiss);
      });
    }

    testWidgets('carte centrée : bouton Voir la vidéo rend watch', (
      tester,
    ) async {
      usePhone360(tester);
      await openVideo(tester, campaign(layout: VideoModalLayout.centered));
      await tester.tap(find.byKey(const Key('video-modal-primary')));
      await tester.pumpAndSettle();
      expect(result, VideoModalChoice.watch);
    });

    testWidgets('sans champ de format : feuille du bas, comme avant', (
      tester,
    ) async {
      usePhone360(tester);
      await openVideo(tester, campaign());
      expect(cross, findsNothing);
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsOneWidget);
      expect(find.byKey(const Key('video-modal-card')), findsNothing);
    });
  });

  group('image', () {
    for (final layout in VideoModalLayout.values) {
      testWidgets('${layout.wire} : bannière au-dessus du titre, sans icône', (
        tester,
      ) async {
        usePhone360(tester);
        await openInfo(
          tester,
          infoCampaign(
            layout: layout,
            imageMode: VideoModalImageMode.top,
            imageUrl: _url,
          ),
          image: fakeModalImage(),
        );
        final banner = find.byKey(const Key('video-modal-banner'));
        expect(banner, findsOneWidget);
        expect(find.byKey(const Key('info-modal-icon')), findsNothing);
        expect(find.text('Mon argent'), findsOneWidget);
        expect(
          find.text('Votre argent est à un seul endroit.'),
          findsOneWidget,
        );
        expect(
          tester.getRect(banner).bottom,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Mon argent')).dy),
        );
        expectButtonLabelsFit(tester);
      });

      testWidgets('${layout.wire} : affiche sans titre ni texte, avec alt', (
        tester,
      ) async {
        usePhone360(tester);
        final handle = tester.ensureSemantics();
        await openInfo(
          tester,
          infoCampaign(
            layout: layout,
            sizePercent: 80,
            imageMode: VideoModalImageMode.poster,
            imageUrl: _url,
            imageAlt: 'Grand concours Yadony',
          ),
          image: fakeModalImage(aspectRatio: 0.75),
        );
        expect(find.byKey(const Key('video-modal-poster')), findsOneWidget);
        expect(find.text('Mon argent'), findsNothing);
        expect(find.text('Tout au même endroit'), findsNothing);
        expect(find.byKey(const Key('info-modal-body')), findsNothing);
        expect(find.bySemanticsLabel('Grand concours Yadony'), findsOneWidget);
        expect(find.byType(DonyButton), findsNWidgets(2));
        // Aucun texte ni dégradé superposé à l'image.
        final overlay = find.descendant(
          of: find.byKey(const Key('video-modal-poster')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text ||
                (w is DecoratedBox &&
                    (w.decoration as BoxDecoration).gradient != null),
          ),
        );
        expect(overlay, findsNothing);
        expectButtonLabelsFit(tester);
        handle.dispose();
      });
    }

    testWidgets('affiche : repli sur le titre sans texte alternatif', (
      tester,
    ) async {
      usePhone360(tester);
      final handle = tester.ensureSemantics();
      await openInfo(
        tester,
        infoCampaign(
          layout: VideoModalLayout.fullscreen,
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
        ),
        image: fakeModalImage(),
      );
      expect(find.bySemanticsLabel('Mon argent'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('affiche plein écran : remplit la zone au-dessus des boutons', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(
          layout: VideoModalLayout.fullscreen,
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
        ),
        image: fakeModalImage(),
      );
      final poster = tester.getRect(
        find.byKey(const Key('video-modal-poster')),
      );
      final buttons = tester.getRect(footer);
      expect(poster.bottom, lessThanOrEqualTo(buttons.top));
      expect(poster.height, greaterThan(780 * 0.5));
    });

    testWidgets('cadrage CONTAIN transmis à l\'image', (tester) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(
          imageMode: VideoModalImageMode.top,
          imageFit: VideoModalImageFit.contain,
          imageUrl: _url,
        ),
        image: fakeModalImage(),
      );
      expect(
        tester.widget<Image>(find.byKey(const Key('video-modal-image'))).fit,
        BoxFit.contain,
      );
    });

    testWidgets('bannière sans image chargée : modal sans image, icône', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(
        tester,
        infoCampaign(imageMode: VideoModalImageMode.top, imageUrl: _url),
      );
      expect(find.byKey(const Key('video-modal-banner')), findsNothing);
      expect(find.byKey(const Key('info-modal-icon')), findsOneWidget);
      expect(find.text('Mon argent'), findsOneWidget);
    });

    testWidgets('modal sans image : rendu inchangé (icône, pas de bannière)', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign());
      expect(find.byKey(const Key('info-modal-icon')), findsOneWidget);
      expect(find.byKey(const Key('video-modal-banner')), findsNothing);
      expect(find.byKey(const Key('video-modal-image')), findsNothing);
    });
  });
}
