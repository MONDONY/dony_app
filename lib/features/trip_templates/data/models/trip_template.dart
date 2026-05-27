class TripTemplate {
  const TripTemplate({
    required this.id,
    required this.label,
    this.emoji,
    required this.departureCity,
    this.departureLat,
    this.departureLng,
    required this.arrivalCity,
    this.arrivalLat,
    this.arrivalLng,
    required this.transportMode,
    required this.capacityUnit,
    required this.availableKg,
    required this.pricePerKg,
    required this.acceptedCategories,
  });

  final String id;
  final String label;
  final String? emoji;
  final String departureCity;
  final double? departureLat;
  final double? departureLng;
  final String arrivalCity;
  final double? arrivalLat;
  final double? arrivalLng;
  final String transportMode;
  final String capacityUnit;
  final int availableKg;
  final double pricePerKg;
  final List<String> acceptedCategories;

  factory TripTemplate.fromJson(Map<String, dynamic> json) => TripTemplate(
        id: json['id'] as String,
        label: json['label'] as String,
        emoji: json['emoji'] as String?,
        departureCity: json['departureCity'] as String,
        departureLat: (json['departureLat'] as num?)?.toDouble(),
        departureLng: (json['departureLng'] as num?)?.toDouble(),
        arrivalCity: json['arrivalCity'] as String,
        arrivalLat: (json['arrivalLat'] as num?)?.toDouble(),
        arrivalLng: (json['arrivalLng'] as num?)?.toDouble(),
        transportMode: json['transportMode'] as String,
        capacityUnit: json['capacityUnit'] as String,
        availableKg: (json['availableKg'] as num).toInt(),
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        acceptedCategories:
            (json['acceptedCategories'] as List?)?.map((e) => e as String).toList() ??
                const [],
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'emoji': emoji,
        'departureCity': departureCity,
        'departureLat': departureLat,
        'departureLng': departureLng,
        'arrivalCity': arrivalCity,
        'arrivalLat': arrivalLat,
        'arrivalLng': arrivalLng,
        'transportMode': transportMode,
        'capacityUnit': capacityUnit,
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
        'acceptedCategories': acceptedCategories,
      };
}
