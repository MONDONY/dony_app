import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
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

    test('utilise douze heures en production', () async {
      final client = _FakeRemoteConfigClient(minSupportedBuild: 0);
      final datasource = AppUpdateRemoteConfigDatasource(
        remoteConfig: client,
        isDevelopment: false,
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(hours: 12),
      );
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
  });
}

final class _FakeRemoteConfigClient implements AppUpdateRemoteConfigClient {
  _FakeRemoteConfigClient({
    required this.minSupportedBuild,
    this.getterError,
    this.fetchError,
    this.settingsError,
  });

  final int minSupportedBuild;
  final Object? getterError;
  final Object? fetchError;
  final Object? settingsError;
  final settings = <RemoteConfigSettings>[];
  var fetchCount = 0;

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
    return minSupportedBuild;
  }

  @override
  Future<void> setConfigSettings(RemoteConfigSettings value) async {
    if (settingsError case final error?) {
      throw error;
    }
    settings.add(value);
  }
}
