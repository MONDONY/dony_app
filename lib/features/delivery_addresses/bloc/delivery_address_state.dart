import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';

enum DeliveryAddressStatus { initial, loading, success, error }

class DeliveryAddressState {
  const DeliveryAddressState({
    this.status = DeliveryAddressStatus.initial,
    this.addresses = const [],
    this.error,
  });

  final DeliveryAddressStatus status;
  final List<DeliveryAddress> addresses;
  final String? error;

  DeliveryAddressState copyWith({
    DeliveryAddressStatus? status,
    List<DeliveryAddress>? addresses,
    String? error,
  }) =>
      DeliveryAddressState(
        status: status ?? this.status,
        addresses: addresses ?? this.addresses,
        error: error,
      );
}
