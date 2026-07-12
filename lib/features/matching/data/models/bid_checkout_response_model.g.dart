// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_checkout_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BidCheckoutResponseModel _$BidCheckoutResponseModelFromJson(
  Map<String, dynamic> json,
) => BidCheckoutResponseModel(
  bidId: json['bidId'] as String,
  clientSecret: json['clientSecret'] as String,
  publishableKey: json['publishableKey'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  paymentMethodTypes:
      (json['paymentMethodTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$BidCheckoutResponseModelToJson(
  BidCheckoutResponseModel instance,
) => <String, dynamic>{
  'bidId': instance.bidId,
  'clientSecret': instance.clientSecret,
  'publishableKey': instance.publishableKey,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'paymentMethodTypes': instance.paymentMethodTypes,
};
