class DeliveryAddress {
  const DeliveryAddress({
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

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        id: json['id'] as String,
        label: json['label'] as String,
        street: json['street'] as String?,
        city: json['city'] as String,
        country: json['country'] as String,
        instructions: json['instructions'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isDefault: json['isDefault'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'street': street,
    'city': city,
    'country': country,
    'instructions': instructions,
    'latitude': latitude,
    'longitude': longitude,
    'isDefault': isDefault,
  };

  DeliveryAddress copyWith({
    String? id,
    String? label,
    String? street,
    String? city,
    String? country,
    String? instructions,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => DeliveryAddress(
    id: id ?? this.id,
    label: label ?? this.label,
    street: street ?? this.street,
    city: city ?? this.city,
    country: country ?? this.country,
    instructions: instructions ?? this.instructions,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isDefault: isDefault ?? this.isDefault,
  );
}
