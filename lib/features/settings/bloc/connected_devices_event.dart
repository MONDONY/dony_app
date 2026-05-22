part of 'connected_devices_bloc.dart';

abstract class ConnectedDevicesEvent extends Equatable {
  const ConnectedDevicesEvent();
  @override
  List<Object?> get props => [];
}

class DevicesLoadRequested extends ConnectedDevicesEvent {
  const DevicesLoadRequested();
}

class DeviceRevokeRequested extends ConnectedDevicesEvent {
  final String deviceId;
  const DeviceRevokeRequested(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}

class AllOthersRevokeRequested extends ConnectedDevicesEvent {
  const AllOthersRevokeRequested();
}
