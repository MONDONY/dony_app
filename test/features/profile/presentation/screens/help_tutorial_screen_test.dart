import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _tutorialConfigJson = '''
{
  "schemaVersion": 1,
  "youtubeChannelUrl": "https://www.youtube.com/@yadony",
  "socialLinks": [],
  "tutorials": [
    {
      "id": "search_intro",
      "title": "Découvrir Yadony",
      "description": "Comprendre la recherche en quelques minutes.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"],
      "durationLabel": "2:30"
    }
  ]
}
''';

void main() {
  testWidgets(
    'configure un lecteur intégré 16:9 sans autoplay et affiche le tutoriel',
    (tester) async {
      final harness = _TutorialHarness();

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      expect(find.text('Découvrir Yadony'), findsOneWidget);
      expect(
        find.text('Comprendre la recherche en quelques minutes.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('fake-player-1')), findsOneWidget);

      final ratio = tester.widget<AspectRatio>(
        find.byKey(const Key('help-tutorial-player-aspect-ratio')),
      );
      expect(ratio.aspectRatio, 16 / 9);

      final configuration = harness.configurations.single;
      expect(configuration.videoId, 'dQw4w9WgXcQ');
      expect(configuration.autoPlay, isFalse);
      expect(configuration.showControls, isTrue);
      expect(configuration.showFullscreenButton, isTrue);
      expect(configuration.enableCaption, isTrue);
      expect(configuration.strictRelatedVideos, isTrue);
      expect(configuration.privacyEnhanced, isTrue);
    },
  );

  testWidgets('affiche un état dédié pour un tutoriel inconnu', (tester) async {
    final harness = _TutorialHarness(tutorialId: 'unknown');

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(find.text('Tutoriel introuvable'), findsOneWidget);
    expect(find.text('Ce tutoriel n’est plus disponible.'), findsOneWidget);
    expect(harness.sessions, isEmpty);
  });

  testWidgets('affiche les actions de secours quand le lecteur échoue', (
    tester,
  ) async {
    final harness = _TutorialHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    harness.sessions.single.emit(HelpTutorialPlayerEvent.error);
    await tester.pump();

    expect(find.text('Lecture impossible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Ouvrir dans YouTube'), findsOneWidget);
  });

  testWidgets('réessaie avec une nouvelle session et ferme l’ancienne', (
    tester,
  ) async {
    final harness = _TutorialHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final firstSession = harness.sessions.single;

    firstSession.emit(HelpTutorialPlayerEvent.error);
    await tester.pump();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(firstSession.closed, isTrue);
    expect(harness.sessions, hasLength(2));
    expect(find.byKey(const Key('fake-player-2')), findsOneWidget);
  });

  testWidgets('ouvre la vidéo exacte dans YouTube depuis le fallback', (
    tester,
  ) async {
    final harness = _TutorialHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    harness.sessions.single.emit(HelpTutorialPlayerEvent.error);
    await tester.pump();
    await tester.tap(find.text('Ouvrir dans YouTube'));
    await tester.pumpAndSettle();

    expect(harness.launcher.launchedUrls, [
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    ]);
    expect(
      harness.launcher.lastOptions?.mode,
      PreferredLaunchMode.externalApplication,
    );
  });

  testWidgets('ouvre la chaîne distante depuis S’abonner à la chaîne', (
    tester,
  ) async {
    final harness = _TutorialHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    final subscribe = find.text('S’abonner à la chaîne');
    await tester.ensureVisible(subscribe);
    await tester.tap(subscribe);
    await tester.pumpAndSettle();

    expect(harness.launcher.launchedUrls, ['https://www.youtube.com/@yadony']);
  });

  testWidgets(
    'trace started et completed une seule fois malgré les callbacks répétés',
    (tester) async {
      final backend = MockAnalyticsBackend();
      final analytics = makeEnabledAnalytics(backend);
      await analytics.onConfigured();
      final harness = _TutorialHarness(
        analytics: analytics,
        analyticsBackend: backend,
      );

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      final session = harness.sessions.single;
      session
        ..emit(HelpTutorialPlayerEvent.playing)
        ..emit(HelpTutorialPlayerEvent.playing)
        ..emit(HelpTutorialPlayerEvent.ended)
        ..emit(HelpTutorialPlayerEvent.ended);
      await tester.pump();

      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialPlayStarted, {
          'tutorial_id': 'search_intro',
        }),
      ).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialCompleted, {
          'tutorial_id': 'search_intro',
        }),
      ).called(1);
    },
  );

  testWidgets('ferme la session du lecteur à la destruction de l’écran', (
    tester,
  ) async {
    final harness = _TutorialHarness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final session = harness.sessions.single;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(session.closed, isTrue);
  });

  testWidgets('reste sans overflow avec un facteur de texte 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = _TutorialHarness(textScaler: const TextScaler.linear(2));

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    harness.sessions.single.emit(HelpTutorialPlayerEvent.error);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

final class _TutorialHarness {
  _TutorialHarness({
    this.tutorialId = 'search_intro',
    AnalyticsService? analytics,
    MockAnalyticsBackend? analyticsBackend,
    this.textScaler = TextScaler.noScaling,
  }) : analytics =
           analytics ??
           makeDisabledAnalytics(analyticsBackend ?? MockAnalyticsBackend());

  final String tutorialId;
  final AnalyticsService analytics;
  final TextScaler textScaler;
  final launcher = _FakeUrlLauncherPlatform();
  final configurations = <HelpTutorialPlayerConfiguration>[];
  final sessions = <_FakePlayerSession>[];

  Widget build() {
    final repository = HelpCenterRepository(
      const _StaticHelpCenterSource(_tutorialConfigJson),
      fallbackJsonLoader: () async => _tutorialConfigJson,
      urlLauncher: launcher,
    );

    return BlocProvider(
      create: (_) =>
          HelpCenterBloc(repository, analytics)
            ..add(const HelpCenterLoadRequested()),
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: HelpTutorialScreen(
          tutorialId: tutorialId,
          playerSessionFactory: (configuration) {
            configurations.add(configuration);
            final session = _FakePlayerSession(sessions.length + 1);
            sessions.add(session);
            return session;
          },
        ),
      ),
    );
  }
}

final class _FakePlayerSession implements HelpTutorialPlayerSession {
  _FakePlayerSession(this.id);

  final int id;
  final _events = StreamController<HelpTutorialPlayerEvent>.broadcast(
    sync: true,
  );
  bool closed = false;

  @override
  Stream<HelpTutorialPlayerEvent> get events => _events.stream;

  void emit(HelpTutorialPlayerEvent event) => _events.add(event);

  @override
  Widget buildInline({required Widget Function(Widget player) frameBuilder}) {
    return frameBuilder(
      ColoredBox(key: Key('fake-player-$id'), color: Colors.black),
    );
  }

  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
  }
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

final class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final launchedUrls = <String>[];
  LaunchOptions? lastOptions;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    lastOptions = options;
    return true;
  }
}
