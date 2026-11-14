import 'dart:async';

import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_image.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../video_modal_test_data.dart';
import 'video_modal_image_test.dart' show fakeModalImage;
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

final class _Launcher extends UrlLauncherPlatform {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

const _url = 'https://cdn.yadony.com/video-modals/i1/1.webp';

void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late List<String> events;
  late List<String> loaded;
  late _Launcher launcher;
  bool? proceed;
  var real = true;

  setUpAll(() {
    registerFallbackValue(infoCampaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    VideoModalPresenter.resetForTest();
    real = true;
    events = [];
    loaded = [];
    launcher = _Launcher();
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

  Future<void> pump(
    WidgetTester tester,
    VideoModalCampaign c, {
    required VideoModalImageLoader loader,
  }) async {
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
                  launcher: ExternalUrlLauncher(launcher: launcher),
                  hasRealSession: () => real,
                  imageLoader: (url) {
                    loaded.add(url);
                    return loader(url);
                  },
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
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

  VideoModalCampaign withImage(
    VideoModalImageMode mode, {
    VideoModalLayout layout = VideoModalLayout.bottomSheet,
    VideoModalAction? secondary = const VideoModalAction.close(),
  }) => infoCampaign(
    layout: layout,
    imageMode: mode,
    imageUrl: _url,
    secondary: secondary,
  );

  testWidgets('sans image : aucun préchargement', (tester) async {
    usePhone360(tester);
    await pump(tester, infoCampaign(), loader: (_) async => null);
    expect(loaded, isEmpty);
    expect(find.text('Mon argent'), findsOneWidget);
    expect(events, ['SHOWN']);
  });

  testWidgets('image préchargée AVANT l\'affichage, SHOWN après', (
    tester,
  ) async {
    usePhone360(tester);
    final gate = Completer<VideoModalImage?>();
    await pump(
      tester,
      withImage(VideoModalImageMode.top),
      loader: (_) => gate.future,
    );
    // Téléchargement en cours : rien d'affiché, rien de compté.
    expect(loaded, [_url]);
    expect(find.text('Mon argent'), findsNothing);
    expect(events, isEmpty);
    gate.complete(fakeModalImage());
    await tester.pumpAndSettle();
    expect(find.text('Mon argent'), findsOneWidget);
    expect(find.byKey(const Key('video-modal-banner')), findsOneWidget);
    expect(events, ['SHOWN']);
  });

  testWidgets('bannière en échec : modal affiché sans image, SHOWN compté', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      withImage(VideoModalImageMode.top),
      loader: (_) async => null,
    );
    expect(find.text('Mon argent'), findsOneWidget);
    expect(find.byKey(const Key('video-modal-banner')), findsNothing);
    expect(events, ['SHOWN']);
    expect(bloc.state.usedSlots, isNotEmpty);
  });

  for (final layout in VideoModalLayout.values) {
    testWidgets('affiche en échec (${layout.wire}) : pas de modal, pas de '
        'SHOWN, plafond et session intacts', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        withImage(VideoModalImageMode.poster, layout: layout),
        loader: (_) async => null,
      );
      expect(find.text('Mon argent'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(events, isEmpty);
      expect(bloc.state.usedSlots, isEmpty);
      // L'appelant poursuit : le formulaire n'est pas bloqué.
      expect(proceed, isTrue);
    });
  }

  testWidgets('affiche chargée : modal affiché, SHOWN', (tester) async {
    usePhone360(tester);
    await pump(
      tester,
      withImage(
        VideoModalImageMode.poster,
        layout: VideoModalLayout.fullscreen,
      ),
      loader: (_) async => fakeModalImage(),
    );
    expect(find.byKey(const Key('video-modal-poster')), findsOneWidget);
    expect(events, ['SHOWN']);
  });

  testWidgets('croix : DISMISSED (action_kind close), aucune action lancée', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      withImage(
        VideoModalImageMode.top,
        layout: VideoModalLayout.centered,
        secondary: const VideoModalAction.openUrl('https://yadony.com/promo'),
      ),
      loader: (_) async => fakeModalImage(),
    );
    await tester.tap(find.byKey(const Key('video-modal-close')));
    await tester.pumpAndSettle();
    expect(events, ['SHOWN', 'DISMISSED']);
    expect(launcher.launched, isEmpty);
    expect(proceed, isTrue);
  });

  testWidgets('toucher à côté : seulement SHOWN, pas une réponse', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      infoCampaign(layout: VideoModalLayout.centered),
      loader: (_) async => null,
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(events, ['SHOWN']);
  });

  testWidgets('carte centrée : le bouton principal garde son action', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      infoCampaign(
        layout: VideoModalLayout.centered,
        primary: const VideoModalAction.openUrl('https://yadony.com/promo'),
      ),
      loader: (_) async => null,
    );
    await tester.tap(find.byKey(const Key('info-modal-primary')));
    await tester.pumpAndSettle();
    expect(events, ['SHOWN', 'OPENED']);
    expect(launcher.launched, ['https://yadony.com/promo']);
  });

  testWidgets('vidéo en plein écran : la croix compte comme DISMISSED', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      campaign(layout: VideoModalLayout.fullscreen),
      loader: (_) async => null,
    );
    await tester.tap(find.byKey(const Key('video-modal-close')));
    await tester.pumpAndSettle();
    expect(events, ['SHOWN', 'DISMISSED']);
  });

  group('toucher l\'affiche = bouton principal', () {
    for (final layout in VideoModalLayout.values) {
      testWidgets('${layout.wire} : URL externe, OPENED', (tester) async {
        usePhone360(tester);
        await pump(
          tester,
          infoCampaign(
            layout: layout,
            imageMode: VideoModalImageMode.poster,
            imageUrl: _url,
            primary: const VideoModalAction.openUrl('https://yadony.com/promo'),
          ),
          loader: (_) async => fakeModalImage(),
        );
        await tester.tap(find.byKey(const Key('video-modal-poster-tap')));
        await tester.pumpAndSettle();
        expect(events, ['SHOWN', 'OPENED']);
        expect(launcher.launched, ['https://yadony.com/promo']);
        expect(find.byKey(const Key('video-modal-poster')), findsNothing);
      });
    }

    testWidgets('SCREEN : ouvre l\'écran (session réelle)', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
          layout: VideoModalLayout.fullscreen,
        ),
        loader: (_) async => fakeModalImage(),
      );
      await tester.tap(find.byKey(const Key('video-modal-poster-tap')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN', 'OPENED']);
      expect(proceed, isFalse);
    });

    testWidgets('SCREEN protégé, visiteur : feuille de connexion', (
      tester,
    ) async {
      usePhone360(tester);
      real = false;
      await pump(
        tester,
        infoCampaign(
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
          layout: VideoModalLayout.centered,
        ),
        loader: (_) async => fakeModalImage(),
      );
      await tester.tap(find.byKey(const Key('video-modal-poster-tap')));
      await tester.pumpAndSettle();
      expect(
        find.text(lookupAppLocalizations(AppL10n.fr).authRequiredTitle),
        findsOneWidget,
      );
      expect(events, ['SHOWN', 'OPENED']);
    });

    testWidgets('CLOSE : DISMISSED, ferme', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
          layout: VideoModalLayout.centered,
          primary: const VideoModalAction.close(),
        ),
        loader: (_) async => fakeModalImage(),
      );
      await tester.tap(find.byKey(const Key('video-modal-poster-tap')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN', 'DISMISSED']);
      expect(find.byKey(const Key('video-modal-poster')), findsNothing);
    });

    testWidgets('accessibilité : rôle bouton, texte alternatif', (
      tester,
    ) async {
      usePhone360(tester);
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        infoCampaign(
          imageMode: VideoModalImageMode.poster,
          imageUrl: _url,
          imageAlt: 'Concours Yadony',
        ),
        loader: (_) async => fakeModalImage(),
      );
      final node = tester.getSemantics(
        find.byKey(const Key('video-modal-poster-tap')),
      );
      expect(node.label, 'Concours Yadony');
      // ignore: deprecated_member_use
      expect(node.getSemanticsData().hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('bannière TOP : l\'image n\'est pas cliquable', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        withImage(VideoModalImageMode.top),
        loader: (_) async => fakeModalImage(),
      );
      expect(find.byKey(const Key('video-modal-poster-tap')), findsNothing);
      await tester.tap(find.byKey(const Key('video-modal-banner')));
      await tester.pumpAndSettle();
      expect(events, ['SHOWN']);
      expect(find.text('Mon argent'), findsOneWidget);
    });
  });
}
