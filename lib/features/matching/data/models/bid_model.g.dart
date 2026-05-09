// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BidModel _$BidModelFromJson(Map<String, dynamic> json) => BidModel(
  id: json['id'] as String,
  announcementId: json['announcementId'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String?,
  senderPhone: json['senderPhone'] as String?,
  senderTotalShipments: (json['senderTotalShipments'] as num?)?.toInt(),
  senderKycVerified: json['senderKycVerified'] as bool? ?? false,
  senderIsProAccount: json['senderIsProAccount'] as bool? ?? false,
  senderKiloPro: json['senderKiloPro'] as bool? ?? false,
  weightKg: (json['weightKg'] as num).toDouble(),
  declaredValueEur: (json['declaredValueEur'] as num).toDouble(),
  description: json['description'] as String,
  contentCategory: json['contentCategory'] as String?,
  recipientName: json['recipientName'] as String?,
  recipientPhone: json['recipientPhone'] as String?,
  status: json['status'] as String,
  rejectionReason: json['rejectionReason'] as String?,
  handoverLocation: json['handoverLocation'] as String?,
  handoverWindowStart: json['handoverWindowStart'] == null
      ? null
      : DateTime.parse(json['handoverWindowStart'] as String),
  handoverWindowEnd: json['handoverWindowEnd'] == null
      ? null
      : DateTime.parse(json['handoverWindowEnd'] as String),
  voyageurConfirmed: json['voyageurConfirmed'] as bool? ?? false,
  disclaimerSignedAt: json['disclaimerSignedAt'] == null
      ? null
      : DateTime.parse(json['disclaimerSignedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  departureCity: json['departureCity'] as String?,
  arrivalCity: json['arrivalCity'] as String?,
  departureDate: json['departureDate'] == null
      ? null
      : DateTime.parse(json['departureDate'] as String),
  departureTime: json['departureTime'] as String?,
  arrivalTime: json['arrivalTime'] as String?,
  pricePerKg: (json['pricePerKg'] as num?)?.toDouble(),
  trackingNumber: json['trackingNumber'] as String?,
  trackingToken: json['trackingToken'] as String?,
  confirmationCode: json['confirmationCode'] as String?,
  travelerId: json['travelerId'] as String?,
  travelerName: json['travelerName'] as String?,
  travelerPhone: json['travelerPhone'] as String?,
  travelerKycVerified: json['travelerKycVerified'] as bool? ?? false,
  travelerIsProAccount: json['travelerIsProAccount'] as bool? ?? false,
  travelerKiloPro: json['travelerKiloPro'] as bool? ?? false,
  travelerTotalTrips: (json['travelerTotalTrips'] as num?)?.toInt(),
  travelerAverageRating: (json['travelerAverageRating'] as num?)?.toDouble(),
  senderHasRated: json['senderHasRated'] as bool? ?? false,
  travelerHasRated: json['travelerHasRated'] as bool? ?? false,
  confirmationCodeRefreshCount:
      (json['confirmationCodeRefreshCount'] as num?)?.toInt() ?? 0,
  confirmationCodeRefreshWindowStart:
      json['confirmationCodeRefreshWindowStart'] == null
          ? null
          : DateTime.parse(json['confirmationCodeRefreshWindowStart'] as String),
);

Map<String, dynamic> _$BidModelToJson(BidModel instance) => <String, dynamic>{
  'id': instance.id,
  'announcementId': instance.announcementId,
  'senderId': instance.senderId,
  'senderName': instance.senderName,
  'senderPhone': instance.senderPhone,
  'senderTotalShipments': instance.senderTotalShipments,
  'senderKycVerified': instance.senderKycVerified,
  'senderIsProAccount': instance.senderIsProAccount,
  'senderKiloPro': instance.senderKiloPro,
  'weightKg': instance.weightKg,
  'declaredValueEur': instance.declaredValueEur,
  'description': instance.description,
  'contentCategory': instance.contentCategory,
  'recipientName': instance.recipientName,
  'recipientPhone': instance.recipientPhone,
  'status': instance.status,
  'rejectionReason': instance.rejectionReason,
  'handoverLocation': instance.handoverLocation,
  'handoverWindowStart': instance.handoverWindowStart?.toIso8601String(),
  'handoverWindowEnd': instance.handoverWindowEnd?.toIso8601String(),
  'voyageurConfirmed': instance.voyageurConfirmed,
  'disclaimerSignedAt': instance.disclaimerSignedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'departureCity': instance.departureCity,
  'arrivalCity': instance.arrivalCity,
  'departureDate': instance.departureDate?.toIso8601String(),
  'departureTime': instance.departureTime,
  'arrivalTime': instance.arrivalTime,
  'pricePerKg': instance.pricePerKg,
  'trackingNumber': instance.trackingNumber,
  'trackingToken': instance.trackingToken,
  'confirmationCode': instance.confirmationCode,
  'travelerId': instance.travelerId,
  'travelerName': instance.travelerName,
  'travelerPhone': instance.travelerPhone,
  'travelerKycVerified': instance.travelerKycVerified,
  'travelerIsProAccount': instance.travelerIsProAccount,
  'travelerKiloPro': instance.travelerKiloPro,
  'travelerTotalTrips': instance.travelerTotalTrips,
  'travelerAverageRating': instance.travelerAverageRating,
  'senderHasRated': instance.senderHasRated,
  'travelerHasRated': instance.travelerHasRated,
  'confirmationCodeRefreshCount': instance.confirmationCodeRefreshCount,
  'confirmationCodeRefreshWindowStart':
      instance.confirmationCodeRefreshWindowStart?.toIso8601String(),
};
