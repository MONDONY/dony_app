class PickupAddress {
  final String id;
  final String label;
  final String street;
  final String postalCode;
  final String city;
  final String country;
  final String? floorApartment;
  final String? instructions;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const PickupAddress({
    required this.id,
    required this.label,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.country,
    this.floorApartment,
    this.instructions,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });

  factory PickupAddress.fromJson(Map<String, dynamic> json) => PickupAddress(
    id: json['id'] as String,
    label: json['label'] as String,
    street: json['street'] as String,
    postalCode: json['postalCode'] as String,
    city: json['city'] as String,
    country: json['country'] as String,
    floorApartment: json['floorApartment'] as String?,
    instructions: json['instructions'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    isDefault: json['isDefault'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'street': street,
    'postalCode': postalCode,
    'city': city,
    'country': country,
    if (floorApartment != null) 'floorApartment': floorApartment,
    if (instructions != null) 'instructions': instructions,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'isDefault': isDefault,
  };

  PickupAddress copyWith({
    String? id,
    String? label,
    String? street,
    String? postalCode,
    String? city,
    String? country,
    String? floorApartment,
    String? instructions,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => PickupAddress(
    id: id ?? this.id,
    label: label ?? this.label,
    street: street ?? this.street,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    country: country ?? this.country,
    floorApartment: floorApartment ?? this.floorApartment,
    instructions: instructions ?? this.instructions,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isDefault: isDefault ?? this.isDefault,
  );
}
