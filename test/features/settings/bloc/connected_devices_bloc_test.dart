import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/data/connected_devices_repository.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectedDevicesRepository extends Mock
    implements ConnectedDevicesRepository {}

DeviceModel _device({bool isCurrent = false}) => DeviceModel(
      deviceId: isCurrent ? 'dev-current' : 'dev-other',
      deviceName: isCurrent ? 'iPhone 14' : 'Galaxy S22',
      platform: isCurrent ? 'ios' : 'android',
      lastSeenAt: DateTime(2026, 5, 22),
      isCurrent: isCurrent,
    );

void main() {
  group('ConnectedDevicesBloc', () {
    late MockConnectedDevicesRepository repo;

    setUp(() => repo = MockConnectedDevicesRepository());

    blocTest<ConnectedDevicesBloc, ConnectedDevicesState>(
      'DevicesLoadRequested → Loading puis Loaded',
      build: () {
        when(() => repo.fetchDevices())
            .thenAnswer((_) async => [_device(isCurrent: true), _device()]);
        return ConnectedDevicesBloc(repo);
      },
      act: (bloc) => bloc.add(const DevicesLoadRequested()),
      expect: () => [
        isA<ConnectedDevicesLoading>(),
        isA<ConnectedDevicesLoaded>()
            .having((s) => s.devices.length, 'devices count', 2),
      ],
    );

    blocTest<ConnectedDevicesBloc, ConnectedDevicesState>(
      'DevicesLoadRequested → Error si repo échoue',
      build: () {
        when(() => repo.fetchDevices()).thenThrow(Exception('network'));
        return ConnectedDevicesBloc(repo);
      },
      act: (bloc) => bloc.add(const DevicesLoadRequested()),
      expect: () => [
        isA<ConnectedDevicesLoading>(),
        isA<ConnectedDevicesError>(),
      ],
    );

    blocTest<ConnectedDevicesBloc, ConnectedDevicesState>(
      'DeviceRevokeRequested → Revoking puis recharge la liste',
      build: () {
        when(() => repo.revokeDevice('dev-other')).thenAnswer((_) async {});
        when(() => repo.fetchDevices())
            .thenAnswer((_) async => [_device(isCurrent: true)]);
        return ConnectedDevicesBloc(repo);
      },
      seed: () => ConnectedDevicesLoaded(
          [_device(isCurrent: true), _device()]),
      act: (bloc) => bloc.add(const DeviceRevokeRequested('dev-other')),
      expect: () => [
        isA<DeviceRevoking>()
            .having((s) => s.deviceId, 'deviceId', 'dev-other'),
        isA<ConnectedDevicesLoaded>()
            .having((s) => s.devices.length, 'devices count', 1),
      ],
    );

    blocTest<ConnectedDevicesBloc, ConnectedDevicesState>(
      'AllOthersRevokeRequested → Revoking(others) puis recharge',
      build: () {
        when(() => repo.revokeOthers()).thenAnswer((_) async {});
        when(() => repo.fetchDevices())
            .thenAnswer((_) async => [_device(isCurrent: true)]);
        return ConnectedDevicesBloc(repo);
      },
      act: (bloc) => bloc.add(const AllOthersRevokeRequested()),
      expect: () => [
        isA<DeviceRevoking>()
            .having((s) => s.deviceId, 'deviceId', 'others'),
        isA<ConnectedDevicesLoaded>(),
      ],
    );
  });
}
