part of 'pickup_address_bloc.dart';

enum PickupAddressStatus { initial, loading, success, error }

class PickupAddressState {
  const PickupAddressState({
    this.status = PickupAddressStatus.initial,
    this.addresses = const [],
    this.error,
  });

  final PickupAddressStatus status;
  final List<PickupAddress> addresses;
  final String? error;

  PickupAddressState copyWith({
    PickupAddressStatus? status,
    List<PickupAddress>? addresses,
    String? error,
  }) => PickupAddressState(
    status: status ?? this.status,
    addresses: addresses ?? this.addresses,
    error: error,
  );
}
