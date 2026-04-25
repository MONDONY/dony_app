// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
      id: json['id'] as String,
      bidId: json['bidId'] as String,
      clientSecret: json['clientSecret'] as String?,
      amount: (json['amount'] as num).toDouble(),
      commissionAmount: (json['commissionAmount'] as num).toDouble(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$PaymentModelToJson(PaymentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bidId': instance.bidId,
      'clientSecret': instance.clientSecret,
      'amount': instance.amount,
      'commissionAmount': instance.commissionAmount,
      'status': instance.status,
    };
