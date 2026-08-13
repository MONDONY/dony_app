class RecurrenceAddress {
  const RecurrenceAddress({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;

  factory RecurrenceAddress.fromJson(Map<String, dynamic> json) =>
      RecurrenceAddress(
        label: json['label'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'lat': lat, 'lng': lng};
}

class TripRecurrence {
  const TripRecurrence({
    required this.id,
    this.sourceTemplateId,
    required this.departureCity,
    required this.arrivalCity,
    required this.transportMode,
    required this.capacityUnit,
    required this.availableKg,
    required this.pricePerKg,
    required this.acceptedCategories,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.departureTime,
    this.arrivalTime,
    this.cashAccepted = false,
    required this.weekdays,
    required this.horizonDays,
    required this.active,
    this.lastGeneratedDate,
  });

  final String id;
  final String? sourceTemplateId;
  final String departureCity;
  final String arrivalCity;
  final String transportMode;
  final String capacityUnit;
  final double availableKg;
  final double pricePerKg;
  final List<String> acceptedCategories;
  final RecurrenceAddress pickupAddress;
  final RecurrenceAddress deliveryAddress;

  /// Format "HH:mm" (l'API peut renvoyer "HH:mm:ss" — tronqué à la lecture).
  final String? departureTime;
  final String? arrivalTime;
  final bool cashAccepted;
  final String weekdays; // 7 caractères '0'/'1', Lundi..Dimanche
  final int horizonDays;
  final bool active;
  final String? lastGeneratedDate;

  factory TripRecurrence.fromJson(Map<String, dynamic> json) {
    String? time = json['departureTime'] as String?;
    if (time != null && time.length >= 5) {
      time = time.substring(0, 5); // "14:00:00" -> "14:00"
    }
    String? arrival = json['arrivalTime'] as String?;
    if (arrival != null && arrival.length >= 5) {
      arrival = arrival.substring(0, 5);
    }
    return TripRecurrence(
      id: json['id'] as String,
      sourceTemplateId: json['sourceTemplateId'] as String?,
      departureCity: json['departureCity'] as String,
      arrivalCity: json['arrivalCity'] as String,
      transportMode: json['transportMode'] as String,
      capacityUnit: json['capacityUnit'] as String,
      availableKg: (json['availableKg'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
      acceptedCategories:
          (json['acceptedCategories'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      pickupAddress: RecurrenceAddress.fromJson(
        json['pickupAddress'] as Map<String, dynamic>,
      ),
      deliveryAddress: RecurrenceAddress.fromJson(
        json['deliveryAddress'] as Map<String, dynamic>,
      ),
      departureTime: time,
      arrivalTime: arrival,
      cashAccepted: json['cashAccepted'] as bool? ?? false,
      weekdays: json['weekdays'] as String,
      horizonDays: (json['horizonDays'] as num).toInt(),
      active: json['active'] as bool,
      lastGeneratedDate: json['lastGeneratedDate'] as String?,
    );
  }
}
