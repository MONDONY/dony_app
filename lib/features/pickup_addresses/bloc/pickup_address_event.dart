part of 'pickup_address_bloc.dart';

abstract class PickupAddressEvent {
  const PickupAddressEvent();
}

class PickupAddressLoaded extends PickupAddressEvent {
  const PickupAddressLoaded();
}

class PickupAddressCreated extends PickupAddressEvent {
  const PickupAddressCreated({
    required this.label,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.country,
    this.floorApartment,
    this.instructions,
    this.isDefault = false,
  });

  final String label;
  final String street;
  final String postalCode;
  final String city;
  final String country;
  final String? floorApartment;
  final String? instructions;
  final bool isDefault;
}

class PickupAddressUpdated extends PickupAddressEvent {
  const PickupAddressUpdated({
    required this.id,
    required this.label,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.country,
    this.floorApartment,
    this.instructions,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String street;
  final String postalCode;
  final String city;
  final String country;
  final String? floorApartment;
  final String? instructions;
  final bool isDefault;
}

class PickupAddressSetDefault extends PickupAddressEvent {
  const PickupAddressSetDefault(this.id);
  final String id;
}

class PickupAddressDeleted extends PickupAddressEvent {
  const PickupAddressDeleted(this.id);
  final String id;
}
