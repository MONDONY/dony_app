import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/video_modal/bloc/video_modal_bloc.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:dony/features/video_modal/presentation/video_modal_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/mock_analytics_backend.dart';
import '../video_modal_test_data.dart';
import 'video_modal_widget_harness.dart';

class _MockRepo extends Mock implements VideoModalRepository {}

final class _Launcher extends UrlLauncherPlatform {
  _Launcher({this.result = true, this.throws = false});

  final bool result;
  final bool throws;
  final launched = <String>[];
  LaunchOptions? options;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (throws) throw Exception('pas de navigateur');
    launched.add(url);
    this.options = options;
    return result;
  }
}

void main() {
  late _MockRepo repo;
  late VideoModalBloc bloc;
  late List<String> events;
  var real = true;

  setUpAll(() {
    registerFallbackValue(infoCampaign());
    registerFallbackValue(VideoModalEventType.shown);
  });

  setUp(() {
    VideoModalPresenter.resetForTest();
    real = true;
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
      hasRealSession: () => real,
    );
  });

  tearDown(() => bloc.close());

  late bool? proceed;

  Future<void> pump(
    WidgetTester tester,
    VideoModalCampaign c, {
    required _Launcher launcher,
    VideoModalTrigger trigger = VideoModalTrigger.publishTrip,
  }) async {
    proceed = null;
    GoRoute stub(String path) => GoRoute(
      path: path,
      builder: (_, _) => Scaffold(body: Text('page $path')),
    );
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
                  trigger: trigger,
                  launcher: ExternalUrlLauncher(launcher: launcher),
                  hasRealSession: () => real,
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
        for (final s in InfoScreen.values) stub(s.route),
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

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('SCREEN : ferme la feuille puis ouvre la route, OPENED', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(tester, infoCampaign(), launcher: _Launcher());
    await tapAndSettle(tester, 'info-modal-primary');
    expect(find.text('page /payments/money'), findsOneWidget);
    expect(find.byKey(const Key('info-modal-primary')), findsNothing);
    expect(events, ['SHOWN', 'OPENED']);
    // Un écran d'accueil du formulaire a été ouvert : pas de formulaire en plus.
    expect(proceed, isFalse);
  });

  for (final s in InfoScreen.values) {
    testWidgets('SCREEN ${s.wire} -> ${s.route}', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(primary: VideoModalAction.openScreen(s)),
        launcher: _Launcher(),
      );
      await tapAndSettle(tester, 'info-modal-primary');
      expect(find.text('page ${s.route}'), findsOneWidget);
    });
  }

  testWidgets('visiteur devant un écran protégé : feuille de connexion', (
    tester,
  ) async {
    usePhone360(tester);
    real = false;
    await pump(tester, infoCampaign(), launcher: _Launcher());
    await tapAndSettle(tester, 'info-modal-primary');
    expect(find.text('page /payments/money'), findsNothing);
    expect(
      find.text(lookupAppLocalizations(AppL10n.fr).authRequiredTitle),
      findsOneWidget,
    );
    expect(events, ['SHOWN', 'OPENED']);
  });

  testWidgets('visiteur devant un écran public : navigue', (tester) async {
    usePhone360(tester);
    real = false;
    await pump(
      tester,
      infoCampaign(
        primary: const VideoModalAction.openScreen(InfoScreen.search),
      ),
      launcher: _Launcher(),
    );
    await tapAndSettle(tester, 'info-modal-primary');
    expect(find.text('page /home'), findsOneWidget);
  });

  testWidgets('URL : navigateur externe, OPENED', (tester) async {
    usePhone360(tester);
    final launcher = _Launcher();
    await pump(
      tester,
      infoCampaign(
        primary: const VideoModalAction.openUrl('https://yadony.com/aide'),
      ),
      launcher: launcher,
    );
    await tapAndSettle(tester, 'info-modal-primary');
    expect(launcher.launched, ['https://yadony.com/aide']);
    expect(launcher.options!.mode, PreferredLaunchMode.externalApplication);
    expect(events, ['SHOWN', 'OPENED']);
    expect(proceed, isFalse);
  });

  for (final (name, launcher) in [
    ('refusé', _Launcher(result: false)),
    ('exception', _Launcher(throws: true)),
  ]) {
    testWidgets('URL, ouverture $name : rien ne casse', (tester) async {
      usePhone360(tester);
      await pump(
        tester,
        infoCampaign(
          primary: const VideoModalAction.openUrl('https://yadony.com'),
        ),
        launcher: launcher,
      );
      await tapAndSettle(tester, 'info-modal-primary');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('info-modal-primary')), findsNothing);
      expect(events, ['SHOWN', 'OPENED']);
    });
  }

  testWidgets('CLOSE en bouton principal : DISMISSED, on poursuit', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      infoCampaign(primary: const VideoModalAction.close(), secondary: null),
      launcher: _Launcher(),
    );
    await tapAndSettle(tester, 'info-modal-primary');
    expect(events, ['SHOWN', 'DISMISSED']);
    expect(proceed, isTrue);
    expect(find.text('ouvrir'), findsOneWidget);
  });

  testWidgets('bouton secondaire : DISMISSED, son action est exécutée', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(
      tester,
      infoCampaign(
        secondary: const VideoModalAction.openScreen(InfoScreen.help),
      ),
      launcher: _Launcher(),
    );
    await tapAndSettle(tester, 'info-modal-secondary');
    expect(find.text('page /profile/help/faq'), findsOneWidget);
    expect(events, ['SHOWN', 'DISMISSED']);
  });

  testWidgets('secondaire CLOSE : DISMISSED, on poursuit vers le formulaire', (
    tester,
  ) async {
    usePhone360(tester);
    await pump(tester, infoCampaign(), launcher: _Launcher());
    await tapAndSettle(tester, 'info-modal-secondary');
    expect(events, ['SHOWN', 'DISMISSED']);
    expect(proceed, isTrue);
  });

  testWidgets('fermé d\'un geste : seul SHOWN, on poursuit', (tester) async {
    usePhone360(tester);
    await pump(tester, infoCampaign(), launcher: _Launcher());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(events, ['SHOWN']);
    expect(proceed, isTrue);
  });

  testWidgets('une présentation à la fois', (tester) async {
    usePhone360(tester);
    await pump(tester, infoCampaign(), launcher: _Launcher());
    final context = tester.element(find.byType(Scaffold).first);
    expect(
      await VideoModalPresenter.present(
        context,
        bloc: bloc,
        campaign: infoCampaign(),
        trigger: VideoModalTrigger.searchTab,
      ),
      isTrue,
    );
    expect(events, ['SHOWN']);
  });
}
