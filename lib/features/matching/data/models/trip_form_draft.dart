import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:equatable/equatable.dart';

/// Brouillon local du formulaire « Publier un trajet » (FormDraftStore).
///
/// Garde la saisie telle quelle, même incomplète, à l'étape où le voyageur
/// s'est arrêté. Les clés JSON sont figées : un brouillon enregistré par une
/// version de l'app doit rester lisible par la suivante.
class TripFormDraft extends Equatable {
  const TripFormDraft({
    this.step = 0,
    this.currency,
    this.departureCity,
    this.departureCountryCode,
    this.arrivalCity,
    this.arrivalCountryCode,
    this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.arrivalDayOffset = 0,
    this.handoverDeadline,
    this.handoverLeadDays,
    this.transportMode,
    this.stops,
    this.pickupAddress,
    this.deliveryAddress,
    this.availableKg,
    this.capacityUnit,
    this.pricingMode,
    this.kgPriceEnabled = true,
    this.priceOption = -1,
    this.customPrice,
    this.customPriceText = '',
    this.acceptedContent = const [],
    this.customAccepted = const [],
    this.refusedTypes = const [],
    this.description = '',
    this.cashEnabled = false,
    this.cardEnabled = true,
    this.mobileMoneyEnabled = false,
    this.negotiable = false,
    this.legs = const [],
  });

  /// Étape atteinte : 0 trajet, 1 lieux et capacité, 2 prix et conditions.
  final int step;

  /// Devise choisie (code ISO).
  final String? currency;
  final String? departureCity;
  final String? departureCountryCode;
  final String? arrivalCity;
  final String? arrivalCountryCode;

  /// Jour du départ, sans heure.
  final DateTime? departureDate;

  /// `HH:mm`.
  final String? departureTime;
  final String? arrivalTime;
  final int arrivalDayOffset;

  /// Date limite de dépôt, jour et heure choisis (FLUTTER-PK). Minuit = jour
  /// sans heure (modèle appliqué, heure annulée, brouillon d'avant l'heure) :
  /// l'écran en déduit l'heure de repli.
  final DateTime? handoverDeadline;

  /// Délai de remise d'un modèle appliqué, encore suivi par la date limite.
  final int? handoverLeadDays;

  /// Valeur fil (`PLANE`, `CAR`…).
  final String? transportMode;
  final TripStops? stops;
  final AddressData? pickupAddress;
  final AddressData? deliveryAddress;
  final double? availableKg;

  /// Valeur fil (`SUITCASE_23KG`, `KG_FREE`…).
  final String? capacityUnit;

  /// `KG` ou `MIXED`.
  final String? pricingMode;
  final bool kgPriceEnabled;

  /// Puce de prix choisie, dans la liste de la devise ([currency]) ; -1 :
  /// aucune ; le nombre de puces : « Autre prix ».
  final int priceOption;
  final double? customPrice;

  /// Texte du champ « Autre prix », même incomplet.
  final String customPriceText;
  final List<String> acceptedContent;
  final List<String> customAccepted;
  final List<String> refusedTypes;
  final String description;
  final bool cashEnabled;
  final bool cardEnabled;
  final bool mobileMoneyEnabled;
  final bool negotiable;

  /// Étapes ajoutées après le premier trajet (FLUTTER-4D).
  final List<TripLegDraft> legs;

  Map<String, dynamic> toJson() => {
    'step': step,
    'currency': currency,
    'departureCity': departureCity,
    'departureCountryCode': departureCountryCode,
    'arrivalCity': arrivalCity,
    'arrivalCountryCode': arrivalCountryCode,
    'departureDate': _encodeDate(departureDate),
    'departureTime': departureTime,
    'arrivalTime': arrivalTime,
    'arrivalDayOffset': arrivalDayOffset,
    'handoverDeadline': _encodeDateTime(handoverDeadline),
    'handoverLeadDays': handoverLeadDays,
    'transportMode': transportMode,
    'stops': tripStopsToWire(stops),
    'pickupAddress': pickupAddress?.toJson(),
    'deliveryAddress': deliveryAddress?.toJson(),
    'availableKg': availableKg,
    'capacityUnit': capacityUnit,
    'pricingMode': pricingMode,
    'kgPriceEnabled': kgPriceEnabled,
    'priceOption': priceOption,
    'customPrice': customPrice,
    'customPriceText': customPriceText,
    'acceptedContent': acceptedContent,
    'customAccepted': customAccepted,
    'refusedTypes': refusedTypes,
    'description': description,
    'cashEnabled': cashEnabled,
    'cardEnabled': cardEnabled,
    'mobileMoneyEnabled': mobileMoneyEnabled,
    'negotiable': negotiable,
    'legs': [for (final l in legs) _legToJson(l)],
  };

  /// Lecture tolérante : un champ absent ou illisible vaut le défaut du
  /// formulaire vierge. Un départ déjà passé est retiré et ramène à la
  /// première étape, où il se choisit ; la date limite et les étapes ajoutées
  /// suivent, elles en dépendent.
  factory TripFormDraft.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    var step = ((json['step'] as num?)?.toInt() ?? 0).clamp(0, 2);
    var date = _decodeDate(json['departureDate']);
    var deadline = _decodeDateTime(json['handoverDeadline']);
    var legs = [
      for (final raw in (json['legs'] as List?) ?? const [])
        if (raw is Map<String, dynamic>) ?_legFromJson(raw),
    ];
    if (date != null && date.isBefore(today)) {
      date = null;
      deadline = null;
      legs = const [];
      step = 0;
    }
    return TripFormDraft(
      step: step,
      currency: json['currency'] as String?,
      departureCity: json['departureCity'] as String?,
      departureCountryCode: json['departureCountryCode'] as String?,
      arrivalCity: json['arrivalCity'] as String?,
      arrivalCountryCode: json['arrivalCountryCode'] as String?,
      departureDate: date,
      departureTime: _hhmm(json['departureTime']),
      arrivalTime: _hhmm(json['arrivalTime']),
      arrivalDayOffset: ((json['arrivalDayOffset'] as num?)?.toInt() ?? 0)
          .clamp(0, 2),
      handoverDeadline: deadline,
      handoverLeadDays: (json['handoverLeadDays'] as num?)?.toInt(),
      transportMode: json['transportMode'] as String?,
      stops: tripStopsFromWire(json['stops']),
      pickupAddress: _address(json['pickupAddress']),
      deliveryAddress: _address(json['deliveryAddress']),
      availableKg: (json['availableKg'] as num?)?.toDouble(),
      capacityUnit: json['capacityUnit'] as String?,
      pricingMode: json['pricingMode'] as String?,
      kgPriceEnabled: json['kgPriceEnabled'] as bool? ?? true,
      priceOption: (json['priceOption'] as num?)?.toInt() ?? -1,
      customPrice: (json['customPrice'] as num?)?.toDouble(),
      customPriceText: json['customPriceText'] as String? ?? '',
      acceptedContent: _strings(json['acceptedContent']),
      customAccepted: _strings(json['customAccepted']),
      refusedTypes: _strings(json['refusedTypes']),
      description: json['description'] as String? ?? '',
      cashEnabled: json['cashEnabled'] as bool? ?? false,
      cardEnabled: json['cardEnabled'] as bool? ?? true,
      mobileMoneyEnabled: json['mobileMoneyEnabled'] as bool? ?? false,
      negotiable: json['negotiable'] as bool? ?? false,
      legs: legs,
    );
  }

  static Map<String, dynamic> _legToJson(TripLegDraft l) => {
    'arrivalCity': l.arrivalCity,
    'arrivalCountryCode': l.arrivalCountryCode,
    'departureDate': _encodeDate(l.departureDate),
    'departureTime': l.departureTime,
    'deliveryAddress': l.deliveryAddress.toJson(),
    'availableKg': l.availableKg,
    'pricePerKg': l.pricePerKg,
    'stops': tripStopsToWire(l.stops),
    'currency': l.currency,
    'acceptedPaymentMethods': l.acceptedPaymentMethods,
  };

  /// Étape illisible (champ obligatoire manquant) : écartée.
  static TripLegDraft? _legFromJson(Map<String, dynamic> j) {
    final city = j['arrivalCity'] as String?;
    final date = _decodeDate(j['departureDate']);
    final time = _hhmm(j['departureTime']);
    final address = _address(j['deliveryAddress']);
    final kg = (j['availableKg'] as num?)?.toDouble();
    if (city == null ||
        date == null ||
        time == null ||
        address == null ||
        kg == null) {
      return null;
    }
    final methods = j['acceptedPaymentMethods'];
    return TripLegDraft(
      arrivalCity: city,
      arrivalCountryCode: j['arrivalCountryCode'] as String?,
      departureDate: date,
      departureTime: time,
      deliveryAddress: address,
      availableKg: kg,
      pricePerKg: (j['pricePerKg'] as num?)?.toDouble(),
      stops: tripStopsFromWire(j['stops']),
      currency: j['currency'] as String?,
      acceptedPaymentMethods: methods is List ? _strings(methods) : null,
    );
  }

  static String? _encodeDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _decodeDate(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : _dateOnly(parsed);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Instant local au format ISO (`yyyy-MM-ddTHH:mm:00`), sans fuseau : il
  /// se relit tel quel sur le même appareil.
  static String? _encodeDateTime(DateTime? d) => d == null
      ? null
      : '${_encodeDate(d)}T'
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}:00';

  /// Relit un instant ISO, ou un ancien jour seul (`yyyy-MM-dd`, minuit).
  /// Secondes et fractions ignorées.
  static DateTime? _decodeDateTime(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  static String? _hhmm(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(raw)) {
      return null;
    }
    return raw;
  }

  static AddressData? _address(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return AddressData.fromJson(raw);
    } on Object {
      return null;
    }
  }

  static List<String> _strings(Object? raw) => [
    for (final e in (raw as List?) ?? const [])
      if (e is String) e,
  ];

  @override
  List<Object?> get props => [toJson().toString()];
}
