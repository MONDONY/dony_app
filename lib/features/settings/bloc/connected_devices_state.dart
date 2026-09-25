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

/// Catégorie d'échec du bloc : l'écran choisit le texte via `AppLocalizations`
/// (le bloc ne porte aucun texte traduit dans son état).
enum DevicesFailure { load, revoke, revokeAll }

class ConnectedDevicesError extends ConnectedDevicesState {
  final DevicesFailure failure;
  const ConnectedDevicesError(this.failure);
  @override
  List<Object?> get props => [failure];
}

class DeviceRevoking extends ConnectedDevicesState {
  final String deviceId;
  const DeviceRevoking(this.deviceId);
  @override
  List<Object?> get props => [deviceId];
}
