import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeliveryAddressBloc extends Bloc<DeliveryAddressEvent, DeliveryAddressState> {
  DeliveryAddressBloc(this._repository) : super(const DeliveryAddressState()) {
    on<DeliveryAddressLoaded>(_onLoaded);
    on<DeliveryAddressCreated>(_onCreated);
    on<DeliveryAddressUpdated>(_onUpdated);
    on<DeliveryAddressSetDefault>(_onSetDefault);
    on<DeliveryAddressDeleted>(_onDeleted);
  }

  final DeliveryAddressRepository _repository;

  Future<void> _onLoaded(
      DeliveryAddressLoaded event, Emitter<DeliveryAddressState> emit) async {
    emit(state.copyWith(status: DeliveryAddressStatus.loading));
    try {
      final addresses = await _repository.getAll();
      emit(state.copyWith(status: DeliveryAddressStatus.success, addresses: addresses));
    } catch (e) {
      emit(state.copyWith(status: DeliveryAddressStatus.error, error: e.toString()));
    }
  }

  Future<void> _onCreated(
      DeliveryAddressCreated event, Emitter<DeliveryAddressState> emit) async {
    emit(state.copyWith(status: DeliveryAddressStatus.loading));
    try {
      final created = await _repository.create({
        'label': event.label,
        'street': event.street,
        'city': event.city,
        'country': event.country,
        'instructions': event.instructions,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'isDefault': event.isDefault,
      });
      final updated = event.isDefault
          ? [created, ...state.addresses.map((a) => a.copyWith(isDefault: false))]
          : [created, ...state.addresses];
      emit(state.copyWith(status: DeliveryAddressStatus.success, addresses: updated));
    } catch (e) {
      emit(state.copyWith(status: DeliveryAddressStatus.error, error: e.toString()));
    }
  }

  Future<void> _onUpdated(
      DeliveryAddressUpdated event, Emitter<DeliveryAddressState> emit) async {
    emit(state.copyWith(status: DeliveryAddressStatus.loading));
    try {
      final updated = await _repository.update(event.id, {
        'label': event.label,
        'street': event.street,
        'city': event.city,
        'country': event.country,
        'instructions': event.instructions,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'isDefault': event.isDefault,
      });
      final addresses = state.addresses.map((a) {
        if (a.id == event.id) {
          return updated;
        }
        return event.isDefault ? a.copyWith(isDefault: false) : a;
      }).toList();
      emit(state.copyWith(status: DeliveryAddressStatus.success, addresses: addresses));
    } catch (e) {
      emit(state.copyWith(status: DeliveryAddressStatus.error, error: e.toString()));
    }
  }

  Future<void> _onSetDefault(
      DeliveryAddressSetDefault event, Emitter<DeliveryAddressState> emit) async {
    try {
      final updated = await _repository.setDefault(event.id);
      final addresses = state.addresses.map((a) {
        if (a.id == event.id) {
          return updated;
        }
        return a.copyWith(isDefault: false);
      }).toList();
      emit(state.copyWith(status: DeliveryAddressStatus.success, addresses: addresses));
    } catch (e) {
      emit(state.copyWith(status: DeliveryAddressStatus.error, error: e.toString()));
    }
  }

  Future<void> _onDeleted(
      DeliveryAddressDeleted event, Emitter<DeliveryAddressState> emit) async {
    try {
      await _repository.delete(event.id);
      final addresses = state.addresses.where((a) => a.id != event.id).toList();
      emit(state.copyWith(status: DeliveryAddressStatus.success, addresses: addresses));
    } catch (e) {
      emit(state.copyWith(status: DeliveryAddressStatus.error, error: e.toString()));
    }
  }
}
