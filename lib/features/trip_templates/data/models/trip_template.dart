import 'package:dony/features/matching/data/models/address_data.dart';

/// Modèle de trajet : tout le formulaire de création sauf la date.
///
/// Les champs ajoutés avec le formulaire complet (contrat back V257) sont
/// optionnels : un modèle enregistré avant reste lisible, et un champ absent
/// vaut le défaut du formulaire vierge.
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
    this.arrivalTime,
    this.currency,
    this.pricingMode = 'KG',
    List<String>? acceptedPaymentMethods,
    bool cashAccepted = false,
    this.negotiable = false,
    this.refusedTypes = const [],
    this.description,
    this.pickupAddress,
    this.deliveryAddress,
    this.departureTime,
    this.handoverLeadDays,
    this.departureCountryCode,
    this.arrivalCountryCode,
  }) : acceptedPaymentMethods =
           acceptedPaymentMethods ??
           (cashAccepted ? const ['STRIPE', 'CASH'] : const ['STRIPE']);

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

  /// Net voyageur au kilo. Nul en mode grille seule (`pricingMode == 'MIXED'`).
  final double? pricePerKg;
  final List<String> acceptedCategories;

  /// Heure d'arrivée optionnelle "HH:mm".
  final String? arrivalTime;

  /// Devise figée du modèle (ISO 4217). Nulle pour un modèle antérieur au
  /// formulaire complet : devise active du profil à l'application.
  final String? currency;

  /// "KG" ou "MIXED" (grille de profil + kilo optionnel).
  final String pricingMode;

  /// Codes wire parmi STRIPE, CASH, MOBILE_MONEY. Jamais vide.
  final List<String> acceptedPaymentMethods;

  final bool negotiable;
  final List<String> refusedTypes;
  final String? description;
  final AddressData? pickupAddress;
  final AddressData? deliveryAddress;

  /// Heure de départ optionnelle "HH:mm".
  final String? departureTime;

  /// Remise au plus tard N jours avant le départ (0 = le jour même). Nul :
  /// pas de délai mémorisé.
  final int? handoverLeadDays;
  final String? departureCountryCode;
  final String? arrivalCountryCode;

  /// Miroir historique : vrai si CASH fait partie des moyens acceptés.
  bool get cashAccepted => acceptedPaymentMethods.contains('CASH');

  bool get usesPriceGrid => pricingMode == 'MIXED';

  factory TripTemplate.fromJson(Map<String, dynamic> json) {
    final methods = (json['acceptedPaymentMethods'] as List?)
        ?.map((e) => e as String)
        .toList();
    return TripTemplate(
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
      pricePerKg: (json['pricePerKg'] as num?)?.toDouble(),
      acceptedCategories: _stringList(json['acceptedCategories']),
      arrivalTime: _hhmm(json['arrivalTime']),
      currency: json['currency'] as String?,
      pricingMode: json['pricingMode'] as String? ?? 'KG',
      acceptedPaymentMethods: methods,
      cashAccepted: json['cashAccepted'] as bool? ?? false,
      negotiable: json['negotiable'] as bool? ?? false,
      refusedTypes: _stringList(json['refusedTypes']),
      description: json['description'] as String?,
      pickupAddress: _address(json['pickupAddress']),
      deliveryAddress: _address(json['deliveryAddress']),
      departureTime: _hhmm(json['departureTime']),
      handoverLeadDays: (json['handoverLeadDays'] as num?)?.toInt(),
      departureCountryCode: json['departureCountryCode'] as String?,
      arrivalCountryCode: json['arrivalCountryCode'] as String?,
    );
  }

  /// Le back sérialise un `LocalTime` en "HH:mm:ss" ; l'app ne garde que "HH:mm".
  static String? _hhmm(Object? raw) {
    final value = raw as String?;
    if (value == null) return null;
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  static List<String> _stringList(Object? raw) =>
      (raw as List?)?.map((e) => e as String).toList() ?? const [];

  /// Une adresse mémorisée est complète (label + coordonnées) ; sinon nulle.
  static AddressData? _address(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label = raw['label'] as String?;
    final lat = raw['lat'] as num?;
    final lng = raw['lng'] as num?;
    if (label == null || lat == null || lng == null) return null;
    return AddressData(label: label, lat: lat.toDouble(), lng: lng.toDouble());
  }

  static Map<String, dynamic>? _addressJson(AddressData? address) =>
      address == null
      ? null
      : {'label': address.label, 'lat': address.lat, 'lng': address.lng};

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
    'cashAccepted': cashAccepted,
    'arrivalTime': arrivalTime,
    'currency': currency,
    'pricingMode': pricingMode,
    'acceptedPaymentMethods': acceptedPaymentMethods,
    'negotiable': negotiable,
    'refusedTypes': refusedTypes,
    'description': description,
    'pickupAddress': _addressJson(pickupAddress),
    'deliveryAddress': _addressJson(deliveryAddress),
    'departureTime': departureTime,
    'handoverLeadDays': handoverLeadDays,
    'departureCountryCode': departureCountryCode,
    'arrivalCountryCode': arrivalCountryCode,
  };
}
