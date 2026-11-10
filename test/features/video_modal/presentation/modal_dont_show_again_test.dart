import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/presentation/screens/video_modal_player_screen.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/features/video_modal/presentation/widgets/info_modal_sheet.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';
import '../../matching/presentation/widgets/trip_owner/trip_card_harness.dart'
    show loadAppFonts;
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

final _box = find.byKey(const Key('video-modal-dont-show-again'));

void main() {
  setUpAll(() {
    registerFallbackValue(campaign());
    registerFallbackValue(VideoModalEventType.shown);
  });
  setUpAll(loadAppFonts);

  group('case « Ne plus afficher » : habillages', () {
    late ValueNotifier<bool> checked;

    setUp(() {
      checked = ValueNotifier(false);
    });
    tearDown(() => checked.dispose());

    Future<void> open(
      WidgetTester tester,
      Future<Object?> Function(BuildContext) show, {
      Locale locale = AppL10n.fr,
    }) async {
      await tester.pumpWidget(
        appWith(
          locale: locale,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => show(context),
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
      Locale locale = AppL10n.fr,
    }) => open(
      tester,
      (ctx) => InfoModalSheet.show(ctx, campaign: c, dontShowAgain: checked),
      locale: locale,
    );

    Future<void> openVideo(
      WidgetTester tester,
      VideoModalCampaign c, {
      Locale locale = AppL10n.fr,
    }) => open(
      tester,
      (ctx) => VideoModalSheet.show(ctx, campaign: c, dontShowAgain: checked),
      locale: locale,
    );

    Finder footerOf(VideoModalLayout l) => l == VideoModalLayout.bottomSheet
        ? find.byKey(const Key('donyBottomSheetFooter'))
        : find.byKey(const Key('video-modal-footer'));

    for (final layout in VideoModalLayout.values) {
      group(layout.wire, () {
        testWidgets('information : sans autorisation, aucune case', (
          tester,
        ) async {
          usePhone360(tester);
          await openInfo(tester, infoCampaign(layout: layout));
          expect(_box, findsNothing);
        });

        testWidgets('vidéo : sans autorisation, aucune case', (tester) async {
          usePhone360(tester);
          await openVideo(tester, campaign(layout: layout));
          expect(_box, findsNothing);
        });

        testWidgets('information : case dans la zone fixe, avant les boutons', (
          tester,
        ) async {
          usePhone360(tester);
          await openInfo(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          expect(_box, findsOneWidget);
          expect(find.text('Ne plus afficher'), findsOneWidget);
          // Jamais dans le contenu qui défile.
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: _box,
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: footerOf(layout), matching: _box),
            findsOneWidget,
          );
          final box = tester.getRect(_box);
          final primary = tester.getRect(
            find.byKey(const Key('info-modal-primary')),
          );
          expect(box.bottom, lessThanOrEqualTo(primary.top));
          expectButtonLabelsFit(tester);
        });

        testWidgets('vidéo : case dans la zone fixe, avant les boutons', (
          tester,
        ) async {
          usePhone360(tester);
          await openVideo(
            tester,
            campaign(layout: layout, allowDontShowAgain: true),
          );
          expect(_box, findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: _box,
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: footerOf(layout), matching: _box),
            findsOneWidget,
          );
          final box = tester.getRect(_box);
          final primary = tester.getRect(
            find.byKey(const Key('video-modal-primary')),
          );
          expect(box.bottom, lessThanOrEqualTo(primary.top));
          expectButtonLabelsFit(tester);
        });

        testWidgets('cocher la case change l\'état, sans fermer', (
          tester,
        ) async {
          usePhone360(tester);
          await openInfo(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          expect(checked.value, isFalse);
          await tester.tap(_box);
          await tester.pump();
          expect(checked.value, isTrue);
          expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
          expect(find.text('Mon argent'), findsOneWidget);
          await tester.tap(_box);
          await tester.pump();
          expect(checked.value, isFalse);
        });

        testWidgets('texte long : la case et les boutons restent fixes', (
          tester,
        ) async {
          usePhone360(tester);
          final body = List.filled(80, 'Une phrase assez longue.').join(' ');
          await openInfo(
            tester,
            infoCampaign(layout: layout, body: body, allowDontShowAgain: true),
          );
          final before = tester.getRect(_box);
          await tester.drag(
            find.byKey(const Key('info-modal-body')),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(_box), before);
          expect(tester.takeException(), isNull);
        });

        testWidgets('anglais, 360 dp : libellé de la case et boutons sur une '
            'ligne', (tester) async {
          usePhone360(tester);
          enableEnglish();
          await openInfo(
            tester,
            infoCampaign(
              layout: layout,
              allowDontShowAgain: true,
              primaryLabel: 'Open my money screen now',
              secondaryLabel: 'Maybe later, thanks',
            ),
            locale: AppL10n.en,
          );
          expect(find.text("Don't show again"), findsOneWidget);
          final label = tester.getSize(find.text("Don't show again"));
          expect(label.height, lessThan(24), reason: 'une seule ligne');
          expectButtonLabelsFit(tester);
        });

        testWidgets('petit écran 320x480 : aucun dépassement', (tester) async {
          tester.view.physicalSize = const Size(320 * 3, 480 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await openInfo(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          expect(tester.takeException(), isNull);
          final screen = Offset.zero & const Size(320, 480);
          final r = tester.getRect(
            find.byKey(const Key('info-modal-secondary')),
          );
          expect(screen.contains(r.bottomRight), isTrue);
        });
      });
    }

    testWidgets('la hauteur des boutons ne change pas avec la case', (
      tester,
    ) async {
      usePhone360(tester);
      await openInfo(tester, infoCampaign());
      final without = tester.getSize(
        find.byKey(const Key('info-modal-primary')),
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await openInfo(tester, infoCampaign(allowDontShowAgain: true));
      final withBox = tester.getSize(
        find.byKey(const Key('info-modal-primary')),
      );
      expect(withBox, without);
      expect(find.byType(DonyButton), findsNWidgets(2));
    });

    testWidgets('sans notifier fourni, la case n\'est pas montrée', (
      tester,
    ) async {
      usePhone360(tester);
      await open(
        tester,
        (ctx) => InfoModalSheet.show(
          ctx,
          campaign: infoCampaign(allowDontShowAgain: true),
        ),
      );
      expect(_box, findsNothing);
      expect(find.byType(DonyButton), findsNWidgets(2));
    });
  });

  group('« Ne plus afficher » : événements envoyés', () {
    late _MockRepo repo;
    late VideoModalBloc bloc;
    late List<String> events;
    Object? proceed;

    setUp(() {
      VideoModalPresenter.resetForTest();
      events = [];
      repo = _MockRepo();
      when(
        () => repo.record(any(), any(), realSession: any(named: 'realSession')),
      ).thenAnswer((inv) async {
        events.add((inv.positionalArguments[1] as VideoModalEventType).wire);
      });
      bloc = VideoModalBloc(
        repo,
        makeEnabledAnalytics(MockAnalyticsBackend()),
        hasRealSession: () => true,
      );
    });

    tearDown(() => bloc.close());

    Future<void> pump(WidgetTester tester, VideoModalCampaign c) async {
      proceed = null;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  proceed = await VideoModalPresenter.present(
                    context,
                    bloc: bloc,
                    campaign: c,
                    trigger: VideoModalTrigger.publishTrip,
                    launcher: ExternalUrlLauncher(),
                    hasRealSession: () => true,
                  );
                },
                child: const Text('ouvrir'),
              ),
            ),
          ),
          GoRoute(
            path: '/money',
            builder: (_, _) => const Text('écran argent'),
          ),
          GoRoute(
            path: videoModalPlayerRoute,
            builder: (_, _) => const Text('lecteur'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: testTheme,
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    Future<void> check(WidgetTester tester) async {
      await tester.tap(_box);
      await tester.pump();
    }

    for (final layout in VideoModalLayout.values) {
      group(layout.wire, () {
        testWidgets('information, bouton secondaire : réponse puis '
            'DONT_SHOW_AGAIN', (tester) async {
          usePhone360(tester);
          await pump(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await tester.tap(find.byKey(const Key('info-modal-secondary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DISMISSED', 'DONT_SHOW_AGAIN']);
          expect(proceed, isTrue);
        });

        testWidgets('information, bouton principal : action exécutée puis '
            'DONT_SHOW_AGAIN', (tester) async {
          usePhone360(tester);
          await pump(
            tester,
            infoCampaign(
              layout: layout,
              allowDontShowAgain: true,
              primary: const VideoModalAction.close(),
            ),
          );
          await check(tester);
          await tester.tap(find.byKey(const Key('info-modal-primary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DISMISSED', 'DONT_SHOW_AGAIN']);
        });

        testWidgets('information, retour système : DONT_SHOW_AGAIN seul', (
          tester,
        ) async {
          usePhone360(tester);
          await pump(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DONT_SHOW_AGAIN']);
        });

        testWidgets('information, case décochée : aucun DONT_SHOW_AGAIN', (
          tester,
        ) async {
          usePhone360(tester);
          await pump(
            tester,
            infoCampaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await check(tester);
          await tester.tap(find.byKey(const Key('info-modal-secondary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DISMISSED']);
        });

        testWidgets('information, case cochée mais non autorisée : rien', (
          tester,
        ) async {
          usePhone360(tester);
          await pump(tester, infoCampaign(layout: layout));
          expect(_box, findsNothing);
          await tester.tap(find.byKey(const Key('info-modal-secondary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DISMISSED']);
        });

        testWidgets('vidéo, « Commencer » : DISMISSED puis DONT_SHOW_AGAIN', (
          tester,
        ) async {
          usePhone360(tester);
          await pump(
            tester,
            campaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await tester.tap(find.byKey(const Key('video-modal-secondary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DISMISSED', 'DONT_SHOW_AGAIN']);
        });

        testWidgets('vidéo, retour système : DONT_SHOW_AGAIN seul', (
          tester,
        ) async {
          usePhone360(tester);
          await pump(
            tester,
            campaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'DONT_SHOW_AGAIN']);
        });

        testWidgets('vidéo, lecture : OPENED puis DONT_SHOW_AGAIN, le '
            'lecteur s\'ouvre', (tester) async {
          usePhone360(tester);
          await pump(
            tester,
            campaign(layout: layout, allowDontShowAgain: true),
          );
          await check(tester);
          await tester.tap(find.byKey(const Key('video-modal-primary')));
          await tester.pumpAndSettle();
          expect(events, ['SHOWN', 'OPENED', 'DONT_SHOW_AGAIN']);
          expect(find.text('lecteur'), findsOneWidget);
        });
      });
    }

    testWidgets('croix (carte centrée) : DISMISSED puis DONT_SHOW_AGAIN', (
      tester,
    ) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          layout: VideoModalLayout.centered,
          allowDontShowAgain: true,
        ),
      );
      await check(tester);
      await tester.tap(find.byKey(const Key('video-modal-close')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN', 'DISMISSED', 'DONT_SHOW_AGAIN']);
    });

    testWidgets('croix (plein écran) : DISMISSED puis DONT_SHOW_AGAIN', (
      tester,
    ) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          layout: VideoModalLayout.fullscreen,
          allowDontShowAgain: true,
        ),
      );
      await check(tester);
      await tester.tap(find.byKey(const Key('video-modal-close')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN', 'DISMISSED', 'DONT_SHOW_AGAIN']);
    });

    testWidgets('bouton principal vers un écran : DONT_SHOW_AGAIN avant la '
        'navigation', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          allowDontShowAgain: true,
          primary: const VideoModalAction.openScreen(InfoScreen.settings),
        ),
      );
      await check(tester);
      await tester.tap(find.byKey(const Key('info-modal-primary')));
      await tester.pump();
      expect(events, ['SHOWN', 'OPENED', 'DONT_SHOW_AGAIN']);
    });

    testWidgets('modal existant sans nouveaux champs : comme avant', (
      tester,
    ) async {
      usePhone360(tester);
      await pump(tester, campaign());
      expect(_box, findsNothing);
      await tester.tap(find.byKey(const Key('video-modal-secondary')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN', 'DISMISSED']);
    });
  });
}
