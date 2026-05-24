part of 'connected_devices_bloc.dart';

sealed class ConnectedDevicesState extends Equatable {
  const ConnectedDevicesState();
  @override
  List<Object?> get props => [];
}

class ConnectedDevicesInitial extends ConnectedDevicesState {
  const ConnectedDevicesInitial();
}

class ConnectedDevicesLoading extends ConnectedDevicesState {
  const ConnectedDevicesLoading();
}

class ConnectedDevicesLoaded extends ConnectedDevicesState {
  final List<DeviceModel> devices;
  const ConnectedDevicesLoaded(this.devices);
  @override
  List<Object?> get props => [devices];
}

class ConnectedDevicesError extends ConnectedDevicesState {
  final String message;
  const ConnectedDevicesError(this.message);
  @override
  List<Object?> get props => [message];
}

class DeviceRevoking extends ConnectedDevicesState {
  final String deviceId;
  const DeviceRevoking(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}
