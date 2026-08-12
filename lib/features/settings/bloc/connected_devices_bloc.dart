import 'package:dony/features/settings/data/connected_devices_repository.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'connected_devices_event.dart';
part 'connected_devices_state.dart';

class ConnectedDevicesBloc
    extends Bloc<ConnectedDevicesEvent, ConnectedDevicesState> {
  final ConnectedDevicesRepository _repository;

  ConnectedDevicesBloc(this._repository) : super(const ConnectedDevicesInitial()) {
    on<DevicesLoadRequested>(_onLoad);
    on<DeviceRevokeRequested>(_onRevoke);
    on<AllOthersRevokeRequested>(_onRevokeOthers);
  }

  Future<void> _onLoad(
    DevicesLoadRequested event,
    Emitter<ConnectedDevicesState> emit,
  ) async {
    emit(const ConnectedDevicesLoading());
    try {
      final devices = await _repository.fetchDevices();
      emit(ConnectedDevicesLoaded(devices));
    } catch (_) {
      emit(const ConnectedDevicesError('Impossible de charger les appareils'));
    }
  }

  Future<void> _onRevoke(
    DeviceRevokeRequested event,
    Emitter<ConnectedDevicesState> emit,
  ) async {
    final current = state;
    emit(DeviceRevoking(event.deviceId));
    try {
      await _repository.revokeDevice(event.deviceId);
      final devices = await _repository.fetchDevices();
      emit(ConnectedDevicesLoaded(devices));
    } catch (_) {
      emit(current is ConnectedDevicesLoaded
          ? current
          : const ConnectedDevicesError('Erreur lors de la révocation'));
    }
  }

  Future<void> _onRevokeOthers(
    AllOthersRevokeRequested event,
    Emitter<ConnectedDevicesState> emit,
  ) async {
    final current = state;
    emit(const DeviceRevoking('others'));
    try {
      await _repository.revokeOthers();
      final devices = await _repository.fetchDevices();
      emit(ConnectedDevicesLoaded(devices));
    } catch (_) {
      emit(current is ConnectedDevicesLoaded
          ? current
          : const ConnectedDevicesError('Erreur lors de la déconnexion'));
    }
  }
}
