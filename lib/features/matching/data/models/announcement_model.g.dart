// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TravelerProfile _$TravelerProfileFromJson(Map<String, dynamic> json) =>
    TravelerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalTrips: (json['totalTrips'] as num?)?.toInt(),
      kiloPro: json['kiloPro'] as bool? ?? false,
      isProAccount: json['isProAccount'] as bool? ?? false,
      kycVerified: json['kycVerified'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,
      acceptsUnverified: json['acceptsUnverified'] as bool? ?? false,
    );

Map<String, dynamic> _$TravelerProfileToJson(TravelerProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'phoneNumber': instance.phoneNumber,
      'averageRating': instance.averageRating,
      'totalTrips': instance.totalTrips,
      'kiloPro': instance.kiloPro,
      'isProAccount': instance.isProAccount,
      'kycVerified': instance.kycVerified,
      'avatarUrl': instance.avatarUrl,
      'acceptsUnverified': instance.acceptsUnverified,
    };

AnnouncementModel _$AnnouncementModelFromJson(
  Map<String, dynamic> json,
) => AnnouncementModel(
  id: json['id'] as String,
  travelerId: json['travelerId'] as String,
  departureCity: json['departureCity'] as String,
  arrivalCity: json['arrivalCity'] as String,
  departureCountryCode: json['departureCountryCode'] as String?,
  arrivalCountryCode: json['arrivalCountryCode'] as String?,
  departureFlag: json['departureFlag'] as String?,
  arrivalFlag: json['arrivalFlag'] as String?,
  departureDate: DateTime.parse(json['departureDate'] as String),
  departureTime: json['departureTime'] as String?,
  arrivalTime: json['arrivalTime'] as String?,
  pickupAddress: json['pickupAddress'] == null
      ? null
      : AddressData.fromJson(json['pickupAddress'] as Map<String, dynamic>),
  deliveryAddress: json['deliveryAddress'] == null
      ? null
      : AddressData.fromJson(json['deliveryAddress'] as Map<String, dynamic>),
  availableKg: (json['availableKg'] as num).toDouble(),
  totalKg: (json['totalKg'] as num).toDouble(),
  pricePerKg: (json['pricePerKg'] as num).toDouble(),
  pricePerKgDisplay: (json['pricePerKgDisplay'] as num?)?.toDouble(),
  transportMode: transportModeFromWire(json['transportMode'] as String?),
  status: json['status'] as String,
  bidsCount: (json['bidsCount'] as num?)?.toInt(),
  pendingBidCount: (json['pendingBidCount'] as num?)?.toInt() ?? 0,
  confirmedParcelCount: (json['confirmedParcelCount'] as num?)?.toInt() ?? 0,
  traveler: json['traveler'] == null
      ? null
      : TravelerProfile.fromJson(json['traveler'] as Map<String, dynamic>),
  description: json['description'] as String?,
  arrivalInstructions: json['arrivalInstructions'] as String?,
  acceptedContentTypes: (json['acceptedContentTypes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  refusedTypes: (json['refusedTypes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  acceptedPaymentMethods:
      (json['acceptedPaymentMethods'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$BidPaymentMethodEnumMap, e))
          .toSet() ??
      const {BidPaymentMethod.stripe},
  capacityUnit: json['capacityUnit'] as String?,
  pricingMode: json['pricingMode'] as String? ?? 'KG',
  priceGridItems: json['priceGridItems'] == null
      ? const []
      : _gridItemsFromJson(json['priceGridItems'] as List?),
  reservedKg: (json['reservedKg'] as num?)?.toDouble() ?? 0,
  surplusEligible: json['surplusEligible'] as bool? ?? false,
  surplusPublished: json['surplusPublished'] as bool? ?? false,
  handoverDeadline: json['handoverDeadline'] == null
      ? null
      : DateTime.parse(json['handoverDeadline'] as String),
  isFavorite: json['isFavorite'] as bool? ?? false,
  urgent: json['urgent'] as bool?,
  currency: json['currency'] as String? ?? 'EUR',
  negotiable: json['negotiable'] as bool? ?? false,
  convertedPricePerKg: (json['convertedPricePerKg'] as num?)?.toDouble(),
  convertedCurrency: json['convertedCurrency'] as String?,
);

Map<String, dynamic> _$AnnouncementModelToJson(AnnouncementModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'travelerId': instance.travelerId,
      'departureCity': instance.departureCity,
      'arrivalCity': instance.arrivalCity,
      'departureCountryCode': instance.departureCountryCode,
      'arrivalCountryCode': instance.arrivalCountryCode,
      'departureFlag': instance.departureFlag,
      'arrivalFlag': instance.arrivalFlag,
      'departureDate': instance.departureDate.toIso8601String(),
      'departureTime': instance.departureTime,
      'arrivalTime': instance.arrivalTime,
      'pickupAddress': instance.pickupAddress,
      'deliveryAddress': instance.deliveryAddress,
      'availableKg': instance.availableKg,
      'totalKg': instance.totalKg,
      'pricePerKg': instance.pricePerKg,
      'pricePerKgDisplay': instance.pricePerKgDisplay,
      'transportMode': _transportModeToWireOrNull(instance.transportMode),
      'status': instance.status,
      'bidsCount': instance.bidsCount,
      'pendingBidCount': instance.pendingBidCount,
      'confirmedParcelCount': instance.confirmedParcelCount,
      'traveler': instance.traveler,
      'description': instance.description,
      'arrivalInstructions': instance.arrivalInstructions,
      'acceptedContentTypes': instance.acceptedContentTypes,
      'refusedTypes': instance.refusedTypes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'acceptedPaymentMethods': instance.acceptedPaymentMethods
          .map((e) => _$BidPaymentMethodEnumMap[e]!)
          .toList(),
      'capacityUnit': instance.capacityUnit,
      'pricingMode': instance.pricingMode,
      'priceGridItems': _gridItemsToJson(instance.priceGridItems),
      'reservedKg': instance.reservedKg,
      'surplusEligible': instance.surplusEligible,
      'surplusPublished': instance.surplusPublished,
      'handoverDeadline': instance.handoverDeadline?.toIso8601String(),
      'isFavorite': instance.isFavorite,
      'urgent': instance.urgent,
      'currency': instance.currency,
      'negotiable': instance.negotiable,
      'convertedPricePerKg': instance.convertedPricePerKg,
      'convertedCurrency': instance.convertedCurrency,
    };

const _$BidPaymentMethodEnumMap = {
  BidPaymentMethod.stripe: 'STRIPE',
  BidPaymentMethod.cash: 'CASH',
  BidPaymentMethod.wave: 'WAVE',
  BidPaymentMethod.orangeMoney: 'ORANGE_MONEY',
};
