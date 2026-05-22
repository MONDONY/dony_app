import 'package:dony/core/services/device_id_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('DeviceIdService', () {
    late MockSecureStorage storage;
    late DeviceIdService service;

    setUp(() {
      storage = MockSecureStorage();
      service = DeviceIdService(storage: storage);
    });

    test('retourne le deviceId existant sans en générer un nouveau', () async {
      when(() => storage.read(key: 'dony_device_id'))
          .thenAnswer((_) async => 'existing-uuid');

      final id = await service.getDeviceId();
      expect(id, 'existing-uuid');
      verifyNever(() => storage.write(key: any(named: 'key'), value: any(named: 'value')));
    });

    test('génère et stocke un nouveau deviceId si absent', () async {
      when(() => storage.read(key: 'dony_device_id')).thenAnswer((_) async => null);
      when(() => storage.write(key: 'dony_device_id', value: any(named: 'value')))
          .thenAnswer((_) async {});

      final id = await service.getDeviceId();
      expect(id, isNotEmpty);
      verify(() => storage.write(key: 'dony_device_id', value: id)).called(1);
    });

    test('met en cache le deviceId — un seul read sur deux appels', () async {
      when(() => storage.read(key: 'dony_device_id'))
          .thenAnswer((_) async => 'cached-uuid');

      final id1 = await service.getDeviceId();
      final id2 = await service.getDeviceId();
      expect(id1, id2);
      verify(() => storage.read(key: 'dony_device_id')).called(1);
    });
  });
}
