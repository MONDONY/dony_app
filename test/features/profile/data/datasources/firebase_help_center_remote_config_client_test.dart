import 'dart:convert';

import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemoteConfig remoteConfig;

  setUpAll(() {
    registerFallbackValue(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
  });

  setUp(() {
    remoteConfig = _MockRemoteConfig();
    when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    when(() => remoteConfig.setConfigSettings(any())).thenAnswer((_) async {});
    when(() => remoteConfig.setDefaults(any())).thenAnswer((_) async {});
    when(
      () => remoteConfig.getString(HelpCenterRemoteConfigDatasource.configKey),
    ).thenReturn('{"schemaVersion": 2}');
  });

  test(
    'FirebaseHelpCenterRemoteConfigClient délègue à Remote Config',
    () async {
      final client = FirebaseHelpCenterRemoteConfigClient(remoteConfig);
      final settings = RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 3),
        minimumFetchInterval: const Duration(hours: 1),
      );

      expect(await client.fetchAndActivate(), isTrue);
      expect(
        client.getString(HelpCenterRemoteConfigDatasource.configKey),
        '{"schemaVersion": 2}',
      );
      await client.setConfigSettings(settings);
      await client.setDefaults({'k': 'v'});

      verify(() => remoteConfig.setConfigSettings(settings)).called(1);
      verify(() => remoteConfig.setDefaults({'k': 'v'})).called(1);
    },
  );

  test('sans chargeur fourni, le repli vient de l’asset embarqué', () async {
    final datasource = HelpCenterRemoteConfigDatasource(
      remoteConfig: FirebaseHelpCenterRemoteConfigClient(remoteConfig),
      isDevelopment: false,
    );

    expect(await datasource.fetchAndActivate(), '{"schemaVersion": 2}');

    final captured =
        verify(() => remoteConfig.setDefaults(captureAny())).captured.single
            as Map<String, dynamic>;
    final fallback =
        captured[HelpCenterRemoteConfigDatasource.configKey] as String;
    // L'asset est un JSON valide : il sert de configuration hors ligne.
    expect(jsonDecode(fallback), isA<Map<String, dynamic>>());
  });
}
