import 'package:dony/features/settings/data/connected_devices_datasource.dart';
import 'package:dony/features/settings/data/connected_devices_repository.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectedDevicesDatasource extends Mock
    implements ConnectedDevicesDatasource {}

DeviceModel _device({required bool isCurrent}) => DeviceModel(
      deviceId: 'device-1',
      deviceName: 'Pixel 7',
      platform: 'android',
      lastSeenAt: DateTime(2026, 5, 22),
      isCurrent: isCurrent,
    );

void main() {
  late MockConnectedDevicesDatasource mockDatasource;
  late ConnectedDevicesRepository repo;

  setUp(() {
    mockDatasource = MockConnectedDevicesDatasource();
    repo = ConnectedDevicesRepository(mockDatasource);
  });

  group('fetchDevices', () {
    test('délègue au datasource et retourne la liste', () async {
      final devices = [_device(isCurrent: true)];
      when(() => mockDatasource.fetchDevices())
          .thenAnswer((_) async => devices);

      final result = await repo.fetchDevices();

      expect(result, devices);
      verify(() => mockDatasource.fetchDevices()).called(1);
    });
  });

  group('isCurrentDeviceRegistered', () {
    test(
        'retourne true quand au moins un appareil a isCurrent == true',
        () async {
      when(() => mockDatasource.fetchDevices()).thenAnswer(
        (_) async => [_device(isCurrent: false), _device(isCurrent: true)],
      );

      expect(await repo.isCurrentDeviceRegistered(), isTrue);
    });

    test(
        'retourne false quand aucun appareil n\'a isCurrent == true (appareil révoqué)',
        () async {
      when(() => mockDatasource.fetchDevices()).thenAnswer(
        (_) async => [_device(isCurrent: false), _device(isCurrent: false)],
      );

      expect(await repo.isCurrentDeviceRegistered(), isFalse);
    });

    test(
        'retourne false quand la liste est vide (appareil absent du serveur)',
        () async {
      when(() => mockDatasource.fetchDevices())
          .thenAnswer((_) async => []);

      expect(await repo.isCurrentDeviceRegistered(), isFalse);
    });

    test(
        'retourne true (fail-safe) quand le datasource lève une exception',
        () async {
      when(() => mockDatasource.fetchDevices())
          .thenThrow(Exception('Network error'));

      expect(await repo.isCurrentDeviceRegistered(), isTrue);
    });
  });

  group('revokeDevice', () {
    test('délègue au datasource', () async {
      when(() => mockDatasource.revokeDevice('device-1'))
          .thenAnswer((_) async {});

      await repo.revokeDevice('device-1');

      verify(() => mockDatasource.revokeDevice('device-1')).called(1);
    });
  });

  group('revokeOthers', () {
    test('délègue au datasource', () async {
      when(() => mockDatasource.revokeOthers()).thenAnswer((_) async {});

      await repo.revokeOthers();

      verify(() => mockDatasource.revokeOthers()).called(1);
    });
  });
}
