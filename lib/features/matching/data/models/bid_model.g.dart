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
    );

Map<String, dynamic> _$BidModelToJson(BidModel instance) => <String, dynamic>{
      'id': instance.id,
      'announcementId': instance.announcementId,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
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
    };
