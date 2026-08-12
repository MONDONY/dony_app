import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'pickup_address_event.dart';
part 'pickup_address_state.dart';

class PickupAddressBloc
    extends Bloc<PickupAddressEvent, PickupAddressState> {
  final PickupAddressRepository _repository;

  PickupAddressBloc(this._repository) : super(const PickupAddressState()) {
    on<PickupAddressLoaded>(_onLoaded);
    on<PickupAddressCreated>(_onCreated);
    on<PickupAddressUpdated>(_onUpdated);
    on<PickupAddressSetDefault>(_onSetDefault);
    on<PickupAddressDeleted>(_onDeleted);
  }

  Future<void> _onLoaded(
    PickupAddressLoaded event,
    Emitter<PickupAddressState> emit,
  ) async {
    emit(state.copyWith(status: PickupAddressStatus.loading));
    try {
      final addresses = await _repository.getAll();
      emit(state.copyWith(
        status: PickupAddressStatus.success,
        addresses: addresses,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PickupAddressStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreated(
    PickupAddressCreated event,
    Emitter<PickupAddressState> emit,
  ) async {
    emit(state.copyWith(status: PickupAddressStatus.loading));
    try {
      final created = await _repository.create({
        'label': event.label,
        'street': event.street,
        'postalCode': event.postalCode,
        'city': event.city,
        'country': event.country,
        if (event.floorApartment != null)
          'floorApartment': event.floorApartment,
        if (event.instructions != null) 'instructions': event.instructions,
        if (event.latitude != null) 'latitude': event.latitude,
        if (event.longitude != null) 'longitude': event.longitude,
        'isDefault': event.isDefault,
      });
      var updatedList = List.of(state.addresses);
      if (event.isDefault) {
        updatedList =
            updatedList.map((a) => a.copyWith(isDefault: false)).toList();
      }
      updatedList.add(created);
      emit(state.copyWith(
        status: PickupAddressStatus.success,
        addresses: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PickupAddressStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdated(
    PickupAddressUpdated event,
    Emitter<PickupAddressState> emit,
  ) async {
    emit(state.copyWith(status: PickupAddressStatus.loading));
    try {
      final updated = await _repository.update(event.id, {
        'label': event.label,
        'street': event.street,
        'postalCode': event.postalCode,
        'city': event.city,
        'country': event.country,
        if (event.floorApartment != null)
          'floorApartment': event.floorApartment,
        if (event.instructions != null) 'instructions': event.instructions,
        if (event.latitude != null) 'latitude': event.latitude,
        if (event.longitude != null) 'longitude': event.longitude,
        'isDefault': event.isDefault,
      });
      var updatedList = List.of(state.addresses);
      if (event.isDefault) {
        updatedList =
            updatedList.map((a) => a.copyWith(isDefault: false)).toList();
      }
      final idx = updatedList.indexWhere((a) => a.id == event.id);
      if (idx != -1) {
        updatedList[idx] = updated;
      }
      emit(state.copyWith(
        status: PickupAddressStatus.success,
        addresses: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PickupAddressStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSetDefault(
    PickupAddressSetDefault event,
    Emitter<PickupAddressState> emit,
  ) async {
    try {
      final updated = await _repository.setDefault(event.id);
      final updatedList = state.addresses
          .map((a) => a.id == event.id
              ? updated
              : a.copyWith(isDefault: false))
          .toList();
      emit(state.copyWith(
        status: PickupAddressStatus.success,
        addresses: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PickupAddressStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onDeleted(
    PickupAddressDeleted event,
    Emitter<PickupAddressState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      final updatedList =
          state.addresses.where((a) => a.id != event.id).toList();
      emit(state.copyWith(
        status: PickupAddressStatus.success,
        addresses: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PickupAddressStatus.error,
        error: e.toString(),
      ));
    }
  }
}
