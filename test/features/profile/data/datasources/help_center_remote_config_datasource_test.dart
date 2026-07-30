import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HelpCenterRemoteConfigDatasource', () {
    test('configure le fallback puis renvoie la valeur activée', () async {
      final client = _FakeRemoteConfigClient(
        activatedJson:
            '{"schemaVersion": 1, "socialLinks": [], "tutorials": []}',
      );
      final datasource = HelpCenterRemoteConfigDatasource(
        remoteConfig: client,
        fallbackJsonLoader: () async => '{"schemaVersion": 1}',
        isDevelopment: true,
      );

      final result = await datasource.fetchAndActivate();

      expect(result, client.activatedJson);
      expect(client.settings.single.fetchTimeout, const Duration(seconds: 10));
      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(minutes: 5),
      );
      expect(client.defaults.single, {
        HelpCenterRemoteConfigDatasource.configKey: '{"schemaVersion": 1}',
      });
      expect(client.fetchCount, 1);
    });

    test('utilise douze heures en production', () async {
      final client = _FakeRemoteConfigClient(activatedJson: '');
      final datasource = HelpCenterRemoteConfigDatasource(
        remoteConfig: client,
        fallbackJsonLoader: () async => '{}',
        isDevelopment: false,
      );

      await datasource.fetchAndActivate();

      expect(
        client.settings.single.minimumFetchInterval,
        const Duration(hours: 12),
      );
    });

    test('activatedJson renvoie vide quand le client échoue', () {
      final datasource = HelpCenterRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          activatedJson: '{}',
          getterError: StateError('unavailable'),
        ),
        fallbackJsonLoader: () async => '{}',
      );

      expect(datasource.activatedJson, isEmpty);
    });

    test(
      'fetchAndActivate renvoie null quand la configuration échoue',
      () async {
        final datasource = HelpCenterRemoteConfigDatasource(
          remoteConfig: _FakeRemoteConfigClient(
            activatedJson: '{}',
            fetchError: StateError('offline'),
          ),
          fallbackJsonLoader: () async => '{}',
        );

        expect(await datasource.fetchAndActivate(), isNull);
      },
    );

    test('fetchAndActivate renvoie null quand setDefaults échoue', () async {
      final datasource = HelpCenterRemoteConfigDatasource(
        remoteConfig: _FakeRemoteConfigClient(
          activatedJson: '{}',
          defaultsError: StateError('defaults unavailable'),
        ),
        fallbackJsonLoader: () async => '{}',
      );

      expect(await datasource.fetchAndActivate(), isNull);
    });
  });
}

final class _FakeRemoteConfigClient implements HelpCenterRemoteConfigClient {
  _FakeRemoteConfigClient({
    required this.activatedJson,
    this.getterError,
    this.fetchError,
    this.defaultsError,
  });

  final String activatedJson;
  final Object? getterError;
  final Object? fetchError;
  final Object? defaultsError;
  final settings = <RemoteConfigSettings>[];
  final defaults = <Map<String, dynamic>>[];
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
  String getString(String key) {
    if (getterError case final error?) {
      throw error;
    }
    return activatedJson;
  }

  @override
  Future<void> setConfigSettings(RemoteConfigSettings value) async {
    settings.add(value);
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> values) async {
    if (defaultsError case final error?) {
      throw error;
    }
    defaults.add(values);
  }
}
