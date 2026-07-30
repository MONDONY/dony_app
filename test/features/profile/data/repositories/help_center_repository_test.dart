import 'dart:async';

import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _validConfigJson = '''
{
  "schemaVersion": 1,
  "youtubeChannelUrl": "https://www.youtube.com/@yadony",
  "socialLinks": [],
  "tutorials": [
    {
      "id": "payment-basics",
      "title": "Payer un envoi",
      "description": "Le paiement en toute simplicité.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["payment"]
    }
  ]
}
''';

const _invalidConfigJson = '{"schemaVersion": 2}';

void main() {
  group('HelpCenterRepository', () {
    test('load parse la configuration activée', () async {
      final repository = HelpCenterRepository(
        _FakeHelpCenterConfigSource(_validConfigJson),
        fallbackJsonLoader: () async => _invalidConfigJson,
      );

      final result = await repository.load();

      expect(result.config.tutorials.single.id, 'payment-basics');
      expect(result.failure, isNull);
    });

    test(
      'load utilise l’asset de secours quand la valeur activée est vide',
      () async {
        final repository = HelpCenterRepository(
          _FakeHelpCenterConfigSource(''),
          fallbackJsonLoader: () async => _validConfigJson,
        );

        final result = await repository.load();

        expect(result.config.tutorials.single.title, 'Payer un envoi');
        expect(result.failure, isNull);
      },
    );

    test(
      'load utilise l’asset de secours quand la lecture activée échoue',
      () async {
        final source = _FakeHelpCenterConfigSource(_invalidConfigJson)
          ..activatedError = StateError('remote config unavailable');
        final repository = HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _validConfigJson,
        );

        final result = await repository.load();

        expect(result.config.tutorials.single.id, 'payment-basics');
        expect(result.failure, isNull);
      },
    );

    test(
      'refresh retourne et mémorise une nouvelle configuration valide',
      () async {
        final source = _FakeHelpCenterConfigSource(
          '',
          fetchedJson: _validConfigJson,
        );
        final repository = HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _invalidConfigJson,
        );

        final refreshed = await repository.refresh();
        source.fetchError = StateError('offline');
        final retained = await repository.refresh();

        expect(refreshed.config.tutorials.single.id, 'payment-basics');
        expect(refreshed.failure, isNull);
        expect(retained.config, refreshed.config);
        expect(retained.failure, HelpCenterRepositoryFailure.fetch);
      },
    );

    test(
      'refresh conserve la dernière configuration valide après une erreur',
      () async {
        final source = _FakeHelpCenterConfigSource(_validConfigJson)
          ..fetchError = StateError('offline');
        final repository = HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _invalidConfigJson,
        );
        final loaded = await repository.load();

        final refreshed = await repository.refresh();

        expect(refreshed.config, loaded.config);
        expect(refreshed.failure, HelpCenterRepositoryFailure.fetch);
      },
    );

    test(
      'refresh conserve la dernière configuration valide après un JSON invalide',
      () async {
        final source = _FakeHelpCenterConfigSource(
          _validConfigJson,
          fetchedJson: _invalidConfigJson,
        );
        final repository = HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _invalidConfigJson,
        );
        final loaded = await repository.load();

        final refreshed = await repository.refresh();

        expect(refreshed.config, loaded.config);
        expect(refreshed.failure, HelpCenterRepositoryFailure.parse);
      },
    );

    test(
      'refresh séquentialise deux appels et associe chaque résultat à sa requête',
      () async {
        final first = Completer<String?>();
        final second = Completer<String?>();
        final source = _FakeHelpCenterConfigSource(
          _validConfigJson,
          fetchedResults: [first.future, second.future],
        );
        final repository = HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _invalidConfigJson,
        );

        final firstResult = repository.refresh();
        final secondResult = repository.refresh();
        try {
          await source.firstFetchStarted.future;
          await Future<void>.delayed(Duration.zero);

          expect(source.secondFetchStarted.isCompleted, isFalse);
          expect(source.fetchCallCount, 1);

          first.complete(_invalidConfigJson);
          await source.secondFetchStarted.future;
          expect(source.fetchCallCount, 2);

          second.complete(_validConfigJson);

          expect(
            (await firstResult).failure,
            HelpCenterRepositoryFailure.parse,
          );
          final successful = await secondResult;
          expect(successful.failure, isNull);
          expect(successful.config.tutorials.single.id, 'payment-basics');
        } finally {
          if (!first.isCompleted) {
            first.complete(_invalidConfigJson);
          }
          if (!second.isCompleted) {
            second.complete(_validConfigJson);
          }
          await Future.wait([firstResult, secondResult]);
        }
      },
    );

    test('openExternal refuse un schéma non HTTPS', () async {
      final launcher = _FakeUrlLauncherPlatform();
      final repository = HelpCenterRepository(
        _FakeHelpCenterConfigSource(_validConfigJson),
        fallbackJsonLoader: () async => _invalidConfigJson,
        urlLauncher: launcher,
      );

      final opened = await repository.openExternal(
        Uri.parse('http://yadony.com'),
      );

      expect(opened, isFalse);
      expect(launcher.launchedUrls, isEmpty);
    });

    test(
      'openExternal lance une URL HTTPS dans l’application externe',
      () async {
        final launcher = _FakeUrlLauncherPlatform();
        final repository = HelpCenterRepository(
          _FakeHelpCenterConfigSource(_validConfigJson),
          fallbackJsonLoader: () async => _invalidConfigJson,
          urlLauncher: launcher,
        );

        final opened = await repository.openExternal(
          Uri.parse('https://www.youtube.com/@yadony'),
        );

        expect(opened, isTrue);
        expect(launcher.launchedUrls, ['https://www.youtube.com/@yadony']);
        expect(
          launcher.lastOptions?.mode,
          PreferredLaunchMode.externalApplication,
        );
      },
    );
  });
}

final class _FakeHelpCenterConfigSource implements HelpCenterConfigSource {
  _FakeHelpCenterConfigSource(
    this._activatedJson, {
    this.fetchedJson,
    this.fetchedResults,
  });

  final String _activatedJson;
  String? fetchedJson;
  final List<Future<String?>>? fetchedResults;
  Object? activatedError;
  Object? fetchError;
  int fetchCallCount = 0;
  final firstFetchStarted = Completer<void>();
  final secondFetchStarted = Completer<void>();

  @override
  String get activatedJson {
    if (activatedError case final error?) {
      throw error;
    }
    return _activatedJson;
  }

  @override
  Future<String?> fetchAndActivate() async {
    if (fetchError case final error?) {
      throw error;
    }
    final callIndex = fetchCallCount++;
    if (callIndex == 0 && !firstFetchStarted.isCompleted) {
      firstFetchStarted.complete();
    } else if (callIndex == 1 && !secondFetchStarted.isCompleted) {
      secondFetchStarted.complete();
    }
    if (fetchedResults case final results?) {
      return results[callIndex];
    }
    return fetchedJson;
  }
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
