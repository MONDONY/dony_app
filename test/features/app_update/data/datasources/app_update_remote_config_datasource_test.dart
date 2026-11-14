import 'dart:async';

import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/datasources/remote_config_interval_store.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateRemoteConfigDatasource', () {
    test('configure puis renvoie la valeur activée', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 42);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: true,
      );

      await datasource.fetchAndActivate();

      expect(datasource.minSupportedBuild, 42);
      expect(client.settings.single.fetchTimeout, const Duration(seconds: 10));
      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 5),
      );
      expect(client.fetchCount, 1);
      // Jamais de setDefaults : setDefaults remplace la table entière de
      // l'instance FirebaseRemoteConfig.instance partagée, ce qui effacerait
      // celle posée par HelpCenterRemoteConfigDatasource.
    });

    test('utilise 60 minutes en production sans valeur mémorisée', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 0);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: false,
        intervalStore: _FakeStore(),
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 60),
      );
    });

    test('applique la valeur mémorisée en production', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 0);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: false,
        intervalStore: _FakeStore(stored: 15),
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 15),
      );
    });

    test('garde 5 minutes en debug malgré la valeur mémorisée', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 0);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: true,
        intervalStore: _FakeStore(stored: 15),
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 5),
      );
    });

    test('une lecture mémorisée en échec retombe sur 60 minutes', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 0);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: false,
        intervalStore: _FakeStore(readError: StateError('disk')),
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 60),
      );
    });

    group('syncRefreshInterval', () {
      AppUpdateRemoteConfigDatasource build(
        _FakeStore store,
        _FakeRemote? remote,
      ) => AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(minSupportedBuild: 0),
        isDevelopment: false,
        intervalStore: store,
        intervalRemote: remote,
      );

      test('mémorise une valeur valide du back', () async {
        final store = _FakeStore();
        await build(store, _FakeRemote(value: 120)).syncRefreshInterval();
        expect(store.stored, 120);
      });

      test('accepte les bornes 5 et 1440', () async {
        final store = _FakeStore();
        await build(store, _FakeRemote(value: 5)).syncRefreshInterval();
        expect(store.stored, 5);
        await build(store, _FakeRemote(value: 1440)).syncRefreshInterval();
        expect(store.stored, 1440);
      });

      for (final bad in <Object?>[4, 1441, 0, -10, 12.5, '60', null]) {
        test('ignore la valeur hors bornes ou invalide $bad', () async {
          final store = _FakeStore(stored: 30);
          await build(store, _FakeRemote(value: bad)).syncRefreshInterval();
          expect(store.stored, 30);
        });
      }

      test('une erreur (404, réseau) est sans effet', () async {
        final store = _FakeStore(stored: 30);
        await expectLater(
          build(
            store,
            _FakeRemote(error: StateError('404')),
          ).syncRefreshInterval(),
          completes,
        );
        expect(store.stored, 30);
      });

      test('une écriture en échec est avalée', () async {
        final store = _FakeStore(writeError: StateError('disk'));
        await expectLater(
          build(store, _FakeRemote(value: 60)).syncRefreshInterval(),
          completes,
        );
      });

      test('sans source distante, rien ne se passe', () async {
        final store = _FakeStore(stored: 30);
        await build(store, null).syncRefreshInterval();
        expect(store.stored, 30);
      });

      test('fetchAndActivate lance la synchro sans bloquer', () async {
        final store = _FakeStore();
        final remote = _FakeRemote(value: 90);
        final datasource = build(store, remote);

        await datasource.fetchAndActivate();
        await Future<void>.delayed(Duration.zero);

        expect(remote.calls, 1);
        expect(store.stored, 90);
      });
    });

    test('minSupportedBuild vaut 0 quand la clé n\'a jamais été publiée', () {
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(minSupportedBuild: 0),
      );

      expect(datasource.minSupportedBuild, 0);
    });

    test('minSupportedBuild renvoie 0 quand le client échoue', () {
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          minSupportedBuild: 42,
          getterError: StateError('unavailable'),
        ),
      );

      expect(datasource.minSupportedBuild, 0);
    });

    test('recommendedBuild lit la clé recommended_build', () {
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          minSupportedBuild: 42,
          recommendedBuild: 57,
        ),
      );

      expect(datasource.recommendedBuild, 57);
      expect(datasource.minSupportedBuild, 42);
    });

    test('recommendedBuild renvoie 0 quand le client échoue', () {
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          minSupportedBuild: 42,
          recommendedBuild: 57,
          getterError: StateError('unavailable'),
        ),
      );

      expect(datasource.recommendedBuild, 0);
    });

    test('fetchAndActivate avale les erreurs de configuration', () async {
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          minSupportedBuild: 0,
          settingsError: StateError('config unavailable'),
        ),
      );

      await expectLater(datasource.fetchAndActivate(), completes);
    });

    test('fetchAndActivate avale les erreurs réseau', () async {
      final client = _FakeRemoteConfigClient(
        minSupportedBuild: 0,
        fetchError: StateError('offline'),
      );
      final datasource = AppUpdateRemoteConfigDatasource(remoteConfig: client);

      await expectLater(datasource.fetchAndActivate(), completes);
      // La configuration réseau (timeout/intervalle) a bien été posée avant
      // l'échec du fetch : seule la partie réseau a raté.
      expect(client.settings, isNotEmpty);
    });

    group('temps réel', () {
      late _FakeRemoteConfigClient client;
      late AppUpdateRemoteConfigDatasource datasource;

      setUp(() {
        client = _FakeRemoteConfigClient(minSupportedBuild: 0);
        datasource = AppUpdateRemoteConfigDatasource(
          remoteConfig: client,
          isDevelopment: true,
        );
      });

      test('activate puis émet quand recommended_build change', () async {
        datasource.startRealtimeUpdates();
        final changes = expectLater(datasource.changes, emits(anything));

        client.updates.add({'recommended_build'});
        await changes;

        expect(client.activateCount, 1);
      });

      test('min_supported_build déclenche aussi', () async {
        datasource.startRealtimeUpdates();
        final changes = expectLater(datasource.changes, emits(anything));

        client.updates.add({'min_supported_build', 'autre'});
        await changes;

        expect(client.activateCount, 1);
      });

      test('une clé sans rapport est ignorée', () async {
        datasource.startRealtimeUpdates();
        var emitted = 0;
        final sub = datasource.changes.listen((_) => emitted++);
        addTearDown(sub.cancel);

        client.updates.add({'help_center_url'});
        await Future<void>.delayed(Duration.zero);

        expect(client.activateCount, 0);
        expect(emitted, 0);
      });

      test('une seule souscription même démarrée deux fois', () {
        datasource.startRealtimeUpdates();
        datasource.startRealtimeUpdates();

        expect(client.listenCount, 1);
      });

      test(
        'stopRealtimeUpdates annule l\'écoute et permet de repartir',
        () async {
          datasource.startRealtimeUpdates();
          await datasource.stopRealtimeUpdates();
          await datasource.stopRealtimeUpdates();
          var emitted = 0;
          final sub = datasource.changes.listen((_) => emitted++);
          addTearDown(sub.cancel);

          client.updates.add({'recommended_build'});
          await Future<void>.delayed(Duration.zero);

          expect(emitted, 0);
          datasource.startRealtimeUpdates();
          expect(client.listenCount, 2);
        },
      );

      test('plateforme sans prise en charge : avalé', () {
        client.listenError = UnsupportedError('pas de temps réel');

        expect(datasource.startRealtimeUpdates, returnsNormally);
        expect(datasource.startRealtimeUpdates, returnsNormally);
      });

      test('flux en erreur : avalé, l\'écoute continue', () async {
        datasource.startRealtimeUpdates();
        var emitted = 0;
        final sub = datasource.changes.listen((_) => emitted++);
        addTearDown(sub.cancel);

        client.updates.addError(StateError('flux cassé'));
        client.updates.addError(StateError('encore'));
        client.updates.add({'recommended_build'});
        await Future<void>.delayed(Duration.zero);

        expect(emitted, 1);
      });

      test('activate qui échoue : avalé, rien n\'est émis', () async {
        client.activateError = StateError('activate KO');
        datasource.startRealtimeUpdates();
        var emitted = 0;
        final sub = datasource.changes.listen((_) => emitted++);
        addTearDown(sub.cancel);

        client.updates.add({'recommended_build'});
        await Future<void>.delayed(Duration.zero);

        expect(emitted, 0);
      });
    });
  });
}

final class _FakeRemoteConfigClient implements AppUpdateRemoteConfigClient {
  _FakeRemoteConfigClient({
    required this.minSupportedBuild,
    this.recommendedBuild = 0,
    this.getterError,
    this.fetchError,
    this.settingsError,
  });

  final int minSupportedBuild;
  final int recommendedBuild;
  final Object? getterError;
  final Object? fetchError;
  final Object? settingsError;
  final settings = <RemoteConfigSettings>[];
  var fetchCount = 0;
  var activateCount = 0;
  Object? activateError;
  Object? listenError;
  var listenCount = 0;
  // ignore: close_sinks
  final updates = StreamController<Set<String>>.broadcast();

  @override
  Future<bool> activate() async {
    if (activateError case final error?) throw error;
    activateCount++;
    return true;
  }

  @override
  Stream<Set<String>> get onConfigUpdated {
    listenCount++;
    if (listenError case final error?) throw error;
    return updates.stream;
  }

  @override
  Future<bool> fetchAndActivate() async {
    if (fetchError case final error?) {
      throw error;
    }
    fetchCount++;
    return true;
  }

  @override
  int getInt(String key) {
    if (getterError case final error?) {
      throw error;
    }
    return key == AppUpdateRemoteConfigDatasource.recommendedConfigKey
        ? recommendedBuild
        : minSupportedBuild;
  }

  @override
  Future<void> setConfigSettings(RemoteConfigSettings value) async {
    if (settingsError case final error?) {
      throw error;
    }
    settings.add(value);
  }
}

final class _FakeStore implements RemoteConfigIntervalStore {
  _FakeStore({this.stored, this.readError, this.writeError});

  int? stored;
  final Object? readError;
  final Object? writeError;

  @override
  Future<int?> read() async {
    if (readError case final error?) {
      throw error;
    }
    return stored;
  }

  @override
  Future<void> write(int minutes) async {
    if (writeError case final error?) {
      throw error;
    }
    stored = minutes;
  }
}

final class _FakeRemote implements RemoteConfigIntervalRemote {
  _FakeRemote({this.value, this.error});

  final Object? value;
  final Object? error;
  var calls = 0;

  @override
  Future<Object?> fetchMinutes() async {
    calls++;
    if (error case final e?) {
      throw e;
    }
    return value;
  }
}
