import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/mock_analytics_backend.dart';

const _cachedJson = '''
{
  "schemaVersion": 1,
  "youtubeChannelUrl": "https://www.youtube.com/@yadony",
  "socialLinks": [],
  "tutorials": [
    {
      "id": "cached",
      "title": "Tutoriel en cache",
      "description": "Configuration activée.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"]
    }
  ]
}
''';

const _remoteJson = '''
{
  "schemaVersion": 1,
  "youtubeChannelUrl": "https://www.youtube.com/@yadony",
  "socialLinks": [],
  "tutorials": [
    {
      "id": "remote",
      "title": "Tutoriel distant",
      "description": "Configuration rafraîchie.",
      "youtubeVideoId": "M7lc1UVf-VE",
      "order": 1,
      "active": true,
      "contexts": ["tripPublish"]
    }
  ]
}
''';

const _invalidJson = '{"schemaVersion": 2}';

void main() {
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() async {
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
  });

  blocTest<HelpCenterBloc, HelpCenterState>(
    'publie le cache puis la configuration rafraîchie',
    build: () => HelpCenterBloc(
      _repository(source: _FakeSource(_cachedJson, fetchedJson: _remoteJson)),
      analytics,
    ),
    act: (bloc) => bloc.add(const HelpCenterLoadRequested()),
    expect: () => [
      const HelpCenterLoading(),
      isA<HelpCenterSuccess>()
          .having(
            (state) => state.config.tutorials.single.id,
            'cache',
            'cached',
          )
          .having((state) => state.isRefreshing, 'isRefreshing', isTrue),
      isA<HelpCenterSuccess>()
          .having(
            (state) => state.config.tutorials.single.id,
            'distant',
            'remote',
          )
          .having((state) => state.isRefreshing, 'isRefreshing', isFalse),
    ],
  );

  test(
    'trace l’ouverture réelle du centre sans la confondre avec son chargement',
    () async {
      final bloc = HelpCenterBloc(_repository(), analytics);

      bloc.add(const HelpCenterOpenRequested());
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.helpCenterOpened, null),
      ).called(1);
      await bloc.close();
    },
  );

  blocTest<HelpCenterBloc, HelpCenterState>(
    'conserve le cache et ferme la raison fetch si le rafraîchissement échoue',
    build: () => HelpCenterBloc(
      _repository(source: _FakeSource(_cachedJson)),
      analytics,
    ),
    act: (bloc) => bloc.add(const HelpCenterLoadRequested()),
    expect: () => [
      const HelpCenterLoading(),
      isA<HelpCenterSuccess>()
          .having(
            (state) => state.config.tutorials.single.id,
            'cache',
            'cached',
          )
          .having((state) => state.isRefreshing, 'isRefreshing', isTrue),
      isA<HelpCenterError>()
          .having((state) => state.reason, 'reason', 'fetch')
          .having(
            (state) => state.config.tutorials.single.id,
            'cache',
            'cached',
          ),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.helpConfigLoadFailed, {
          'reason': 'fetch',
        }),
      ).called(1);
    },
  );

  blocTest<HelpCenterBloc, HelpCenterState>(
    'conserve le cache et ferme la raison parse si le JSON distant est invalide',
    build: () => HelpCenterBloc(
      _repository(source: _FakeSource(_cachedJson, fetchedJson: _invalidJson)),
      analytics,
    ),
    act: (bloc) => bloc.add(const HelpCenterLoadRequested()),
    expect: () => [
      const HelpCenterLoading(),
      isA<HelpCenterSuccess>()
          .having(
            (state) => state.config.tutorials.single.id,
            'cache',
            'cached',
          )
          .having((state) => state.isRefreshing, 'isRefreshing', isTrue),
      isA<HelpCenterError>()
          .having((state) => state.reason, 'reason', 'parse')
          .having(
            (state) => state.config.tutorials.single.id,
            'cache',
            'cached',
          ),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.helpConfigLoadFailed, {
          'reason': 'parse',
        }),
      ).called(1);
    },
  );

  test(
    'trace l’ouverture d’un tutoriel avec son identifiant et sa source',
    () async {
      final bloc = HelpCenterBloc(_repository(), analytics);

      bloc.add(
        const HelpTutorialOpenRequested(
          tutorialId: 'publish-trip',
          source: TutorialContext.tripPublish,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
          'tutorial_id': 'publish-trip',
          'source': 'trip_publish',
        }),
      ).called(1);
      await bloc.close();
    },
  );

  test(
    'utilise help_center comme source d’ouverture quand le contexte est nul',
    () async {
      final bloc = HelpCenterBloc(_repository(), analytics);

      bloc.add(
        const HelpTutorialOpenRequested(
          tutorialId: 'search-intro',
          source: null,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
          'tutorial_id': 'search-intro',
          'source': 'help_center',
        }),
      ).called(1);
      await bloc.close();
    },
  );

  test('trace le démarrage et la fin explicitement demandés', () async {
    final bloc = HelpCenterBloc(_repository(), analytics);

    bloc
      ..add(
        const HelpTutorialPlaybackRequested(
          tutorialId: 'payment',
          action: HelpPlaybackAction.started,
        ),
      )
      ..add(
        const HelpTutorialPlaybackRequested(
          tutorialId: 'payment',
          action: HelpPlaybackAction.completed,
        ),
      );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialPlayStarted, {
        'tutorial_id': 'payment',
      }),
    ).called(1);
    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialCompleted, {
        'tutorial_id': 'payment',
      }),
    ).called(1);
    await bloc.close();
  });

  test(
    'transmet chaque intention playback répétée au tracking sans dédupliquer',
    () async {
      final bloc = HelpCenterBloc(_repository(), analytics);

      bloc
        ..add(
          const HelpTutorialPlaybackRequested(
            tutorialId: 'payment',
            action: HelpPlaybackAction.started,
          ),
        )
        ..add(
          const HelpTutorialPlaybackRequested(
            tutorialId: 'payment',
            action: HelpPlaybackAction.started,
          ),
        );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialPlayStarted, {
          'tutorial_id': 'payment',
        }),
      ).called(2);
      await bloc.close();
    },
  );

  test('ouvre et trace chacun des réseaux sociaux sans PII', () async {
    final launcher = _FakeLauncher();
    final bloc = HelpCenterBloc(_repository(launcher: launcher), analytics);

    for (final network in SocialNetwork.values) {
      bloc.add(
        HelpExternalOpenRequested.social(
          link: SocialLink(
            network: network,
            url: Uri.parse('https://community.yadony.com/${network.name}'),
            active: true,
          ),
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));

    for (final network in SocialNetwork.values) {
      verify(
        () => backend.capture(AnalyticsEvents.helpSocialLinkOpened, {
          'network': network.name,
        }),
      ).called(1);
    }
    expect(launcher.launchedUrls, hasLength(SocialNetwork.values.length));
    await bloc.close();
  });

  test('trace l’ouverture externe d’un tutoriel après lancement', () async {
    final bloc = HelpCenterBloc(
      _repository(launcher: _FakeLauncher()),
      analytics,
    );

    bloc.add(
      HelpExternalOpenRequested.tutorial(
        uri: Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        tutorialId: 'search-intro',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.helpTutorialExternalOpened, {
        'tutorial_id': 'search-intro',
      }),
    ).called(1);
    await bloc.close();
  });

  test('trace l’abonnement YouTube avec une source fermée', () async {
    final bloc = HelpCenterBloc(
      _repository(launcher: _FakeLauncher()),
      analytics,
    );

    bloc.add(
      HelpExternalOpenRequested.youtubeSubscription(
        uri: Uri.parse('https://www.youtube.com/@yadony'),
        source: TutorialContext.activities,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => backend.capture(AnalyticsEvents.helpYoutubeSubscribeTapped, {
        'source': 'activities',
      }),
    ).called(1);
    await bloc.close();
  });

  blocTest<HelpCenterBloc, HelpCenterState>(
    'émet une erreur non bloquante launch si l’ouverture externe échoue',
    build: () => HelpCenterBloc(
      _repository(launcher: _FakeLauncher(result: false)),
      analytics,
    ),
    act: (bloc) => bloc.add(
      HelpExternalOpenRequested.youtubeSubscription(
        uri: Uri.parse('https://www.youtube.com/@yadony'),
        source: null,
      ),
    ),
    expect: () => [
      const HelpCenterError('launch', config: HelpCenterConfig.empty),
    ],
    verify: (_) {
      verify(
        () => backend.capture(AnalyticsEvents.helpConfigLoadFailed, {
          'reason': 'launch',
        }),
      ).called(1);
      verifyNever(
        () =>
            backend.capture(AnalyticsEvents.helpYoutubeSubscribeTapped, any()),
      );
    },
  );

  test('séquentialise deux chargements concurrents', () async {
    final first = Completer<String?>();
    final second = Completer<String?>();
    final source = _ControlledSource(
      activatedJson: _cachedJson,
      fetchedResults: [first.future, second.future],
    );
    final bloc = HelpCenterBloc(_repository(source: source), analytics);

    try {
      bloc
        ..add(const HelpCenterLoadRequested())
        ..add(const HelpCenterLoadRequested());
      await source.firstFetchStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(source.secondFetchStarted.isCompleted, isFalse);
      expect(source.fetchCallCount, 1);

      first.complete(_remoteJson);
      await source.secondFetchStarted.future;
      expect(source.fetchCallCount, 2);

      second.complete(_remoteJson);
    } finally {
      if (!first.isCompleted) {
        first.complete(_remoteJson);
      }
      if (!second.isCompleted) {
        second.complete(_remoteJson);
      }
      await bloc.close();
    }
  });

  test(
    'conserve la configuration stable si launch échoue pendant un chargement',
    () async {
      final blockedFallback = Completer<String>();
      addTearDown(() {
        if (!blockedFallback.isCompleted) {
          blockedFallback.complete(_cachedJson);
        }
      });
      var fallbackCalls = 0;
      final source = _ControlledSource(
        activatedJson: '',
        fetchedResults: [
          Future.value(_remoteJson),
          Future.value(_remoteJson),
        ],
      );
      final bloc = HelpCenterBloc(
        _repository(
          source: source,
          launcher: _FakeLauncher(result: false),
          fallbackJsonLoader: () {
            fallbackCalls++;
            return fallbackCalls == 1
                ? Future.value(_cachedJson)
                : blockedFallback.future;
          },
        ),
        analytics,
      );

      final initialLoad = bloc.stream.firstWhere(
        (state) =>
            state is HelpCenterSuccess &&
            !state.isRefreshing &&
            state.config.tutorials.single.id == 'remote',
      );
      bloc.add(const HelpCenterLoadRequested());
      await initialLoad;

      final loading =
          bloc.stream.firstWhere((state) => state is HelpCenterLoading);
      bloc.add(const HelpCenterLoadRequested());
      await loading;

      final launchError = bloc.stream.firstWhere(
        (state) => state is HelpCenterError && state.reason == 'launch',
      );
      bloc.add(
        HelpExternalOpenRequested.youtubeSubscription(
          uri: Uri.parse('https://www.youtube.com/@yadony'),
          source: null,
        ),
      );

      final error = await launchError as HelpCenterError;
      expect(error.config.tutorials.single.id, 'remote');

      blockedFallback.complete(_cachedJson);
      await bloc.close();
    },
  );
}

HelpCenterRepository _repository({
  HelpCenterConfigSource? source,
  _FakeLauncher? launcher,
  Future<String> Function()? fallbackJsonLoader,
}) {
  return HelpCenterRepository(
    source ?? _FakeSource(_cachedJson, fetchedJson: _remoteJson),
    fallbackJsonLoader: fallbackJsonLoader ?? () async => _cachedJson,
    urlLauncher: launcher,
  );
}

final class _FakeSource implements HelpCenterConfigSource {
  _FakeSource(this.activatedJson, {this.fetchedJson});

  @override
  final String activatedJson;
  final String? fetchedJson;

  @override
  Future<String?> fetchAndActivate() async => fetchedJson;
}

final class _ControlledSource implements HelpCenterConfigSource {
  _ControlledSource({
    required this.activatedJson,
    required this.fetchedResults,
  });

  @override
  final String activatedJson;
  final List<Future<String?>> fetchedResults;
  int fetchCallCount = 0;
  final firstFetchStarted = Completer<void>();
  final secondFetchStarted = Completer<void>();

  @override
  Future<String?> fetchAndActivate() {
    final callIndex = fetchCallCount++;
    if (callIndex == 0) {
      firstFetchStarted.complete();
    } else if (callIndex == 1) {
      secondFetchStarted.complete();
    }
    return fetchedResults[callIndex];
  }
}

final class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({this.result = true});

  final bool result;
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return result;
  }
}
