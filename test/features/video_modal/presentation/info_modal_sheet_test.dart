import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/info_modal_sheet.dart';
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
  setUpAll(loadAppFonts);

  Future<void> open(
    WidgetTester tester,
    VideoModalCampaign c, {
    Locale locale = AppL10n.fr,
    void Function(InfoModalChoice?)? onResult,
  }) async {
    await tester.pumpWidget(
      appWith(
        locale: locale,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final r = await InfoModalSheet.show(context, campaign: c);
                onResult?.call(r);
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

  testWidgets('contenu, icône et boutons dans le pied collant, empilés', (
    tester,
  ) async {
    usePhone360(tester);
    await open(tester, infoCampaign());
    expect(find.text('Mon argent'), findsOneWidget);
    expect(find.text('Tout au même endroit'), findsOneWidget);
    expect(find.text('Votre argent est à un seul endroit.'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byKey(const Key('info-modal-icon'))).icon,
      videoModalIconData(VideoModalIcon.wallet),
    );
    expect(find.byType(DonyButton), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(DonyButton),
      ),
      findsNothing,
    );
    final primary = tester.getRect(find.byKey(const Key('info-modal-primary')));
    final secondary = tester.getRect(
      find.byKey(const Key('info-modal-secondary')),
    );
    expect(primary.bottom, lessThanOrEqualTo(secondary.top));
    expect(primary.width, secondary.width);
    expect(primary.width, greaterThan(300));
    expectButtonLabelsFit(tester);
  });

  testWidgets('sans second bouton : un seul bouton', (tester) async {
    usePhone360(tester);
    await open(tester, infoCampaign(secondary: null, subtitle: null));
    expect(find.byType(DonyButton), findsOneWidget);
    expect(find.byKey(const Key('info-modal-secondary')), findsNothing);
    expect(find.text('Tout au même endroit'), findsNothing);
  });

  testWidgets('libellés anglais les plus longs : une ligne à 360 dp', (
    tester,
  ) async {
    usePhone360(tester);
    enableEnglish();
    await open(
      tester,
      infoCampaign(
        primaryLabel: 'Open my money screen now',
        secondaryLabel: 'Maybe later, thanks',
      ),
      locale: AppL10n.en,
    );
    expectButtonLabelsFit(tester);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('libellés de repli ($locale)', (tester) async {
      usePhone360(tester);
      if (locale == AppL10n.en) enableEnglish();
      await open(
        tester,
        infoCampaign(
          primaryLabel: null,
          secondaryLabel: null,
          primary: const VideoModalAction.openUrl('https://yadony.com'),
        ),
        locale: locale,
      );
      final l = lookupAppLocalizations(locale);
      expect(find.text(l.infoModalOpenFallback), findsOneWidget);
      expect(find.text(l.infoModalCloseFallback), findsOneWidget);
      expectButtonLabelsFit(tester);
    });
  }

  testWidgets('texte long : défile, boutons toujours visibles', (tester) async {
    usePhone360(tester);
    final long = List.filled(
      60,
      'Une phrase assez longue pour remplir.',
    ).join(' ');
    await open(tester, infoCampaign(body: long));
    expect(tester.takeException(), isNull);
    final primary = find.byKey(const Key('info-modal-primary'));
    expect(primary, findsOneWidget);
    final bottomBefore = tester.getRect(primary).bottom;
    await tester.drag(
      find.byKey(const Key('info-modal-body')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(primary).bottom, bottomBefore);
    expect(
      tester.getRect(primary).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height / 3),
    );
  });

  Future<InfoModalChoice?> tapAndRead(WidgetTester tester, Key? key) async {
    InfoModalChoice? result;
    var done = false;
    await open(
      tester,
      infoCampaign(),
      onResult: (r) {
        result = r;
        done = true;
      },
    );
    if (key != null) {
      await tester.tap(find.byKey(key));
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return result;
  }

  testWidgets('bouton principal', (tester) async {
    usePhone360(tester);
    expect(
      await tapAndRead(tester, const Key('info-modal-primary')),
      InfoModalChoice.primary,
    );
  });

  testWidgets('bouton secondaire', (tester) async {
    usePhone360(tester);
    expect(
      await tapAndRead(tester, const Key('info-modal-secondary')),
      InfoModalChoice.secondary,
    );
  });

  testWidgets('fermé d\'un geste : pas de réponse', (tester) async {
    usePhone360(tester);
    expect(await tapAndRead(tester, null), isNull);
  });
}
