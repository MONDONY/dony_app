import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  PackageInfo infoWithBuild(String buildNumber) => PackageInfo(
    appName: 'Yadony',
    packageName: 'com.yadony.yadony',
    version: '1.0.0',
    buildNumber: buildNumber,
  );

  group('AppUpdateService.isUpdateRequired', () {
    test('ne bloque pas quand le build installé est égal au minimum', () async {
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30),
        packageInfoLoader: () async => infoWithBuild('30'),
      );

      expect(await service.isUpdateRequired(), isFalse);
    });

    test(
      'ne bloque pas quand le build installé est supérieur au minimum',
      () async {
        final service = AppUpdateService(
          _FakeConfigSource(minSupportedBuild: 30),
          packageInfoLoader: () async => infoWithBuild('45'),
        );

        expect(await service.isUpdateRequired(), isFalse);
      },
    );

    test('bloque quand le build installé est inférieur au minimum', () async {
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30),
        packageInfoLoader: () async => infoWithBuild('12'),
      );

      expect(await service.isUpdateRequired(), isTrue);
    });

    test('ne bloque pas quand Remote Config est en erreur', () async {
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30, throwsOnRead: true),
        packageInfoLoader: () async => infoWithBuild('1'),
      );

      expect(await service.isUpdateRequired(), isFalse);
    });

    test(
      'ne bloque pas quand aucune valeur n\'a jamais été publiée (0)',
      () async {
        final service = AppUpdateService(
          _FakeConfigSource(minSupportedBuild: 0),
          packageInfoLoader: () async => infoWithBuild('1'),
        );

        expect(await service.isUpdateRequired(), isFalse);
      },
    );

    test('ne bloque pas quand le buildNumber installé est illisible', () async {
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30),
        packageInfoLoader: () async => infoWithBuild('not-a-number'),
      );

      expect(await service.isUpdateRequired(), isFalse);
    });

    test('ne bloque pas quand PackageInfo échoue', () async {
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30),
        packageInfoLoader: () async => throw StateError('platform error'),
      );

      expect(await service.isUpdateRequired(), isFalse);
    });

    test('ne relit PackageInfo qu\'une seule fois (mise en cache)', () async {
      var loadCount = 0;
      final service = AppUpdateService(
        _FakeConfigSource(minSupportedBuild: 30),
        packageInfoLoader: () async {
          loadCount++;
          return infoWithBuild('45');
        },
      );

      await service.isUpdateRequired();
      await service.isUpdateRequired();

      expect(loadCount, 1);
    });
  });

  group('AppUpdateService.refresh', () {
    test('délègue au config source', () async {
      final configSource = _FakeConfigSource(minSupportedBuild: 0);
      final service = AppUpdateService(configSource);

      await service.refresh();

      expect(configSource.fetchAndActivateCount, 1);
    });
  });
}

final class _FakeConfigSource implements AppUpdateConfigSource {
  _FakeConfigSource({required int minSupportedBuild, this.throwsOnRead = false})
    : _minSupportedBuild = minSupportedBuild;

  final int _minSupportedBuild;
  final bool throwsOnRead;
  var fetchAndActivateCount = 0;

  @override
  int get minSupportedBuild {
    if (throwsOnRead) {
      throw StateError('remote config unavailable');
    }
    return _minSupportedBuild;
  }

  @override
  Future<void> fetchAndActivate() async {
    fetchAndActivateCount++;
  }
}
