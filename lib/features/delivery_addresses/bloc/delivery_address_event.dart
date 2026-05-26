sealed class DeliveryAddressEvent {
  const DeliveryAddressEvent();
}

final class DeliveryAddressLoaded extends DeliveryAddressEvent {
  const DeliveryAddressLoaded();
}

final class DeliveryAddressCreated extends DeliveryAddressEvent {
  const DeliveryAddressCreated({
    required this.label,
    this.street,
    required this.city,
    required this.country,
    this.instructions,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });

  final String label;
  final String? street;
  final String city;
  final String country;
  final String? instructions;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
}

final class DeliveryAddressUpdated extends DeliveryAddressEvent {
  const DeliveryAddressUpdated({
    required this.id,
    required this.label,
    this.street,
    required this.city,
    required this.country,
    this.instructions,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String? street;
  final String city;
  final String country;
  final String? instructions;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
}

final class DeliveryAddressSetDefault extends DeliveryAddressEvent {
  const DeliveryAddressSetDefault(this.id);
  final String id;
}

final class DeliveryAddressDeleted extends DeliveryAddressEvent {
  const DeliveryAddressDeleted(this.id);
  final String id;
}
