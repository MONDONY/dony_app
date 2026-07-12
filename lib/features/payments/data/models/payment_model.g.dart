// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentModel _$PaymentModelFromJson(Map<String, dynamic> json) => PaymentModel(
  id: json['id'] as String,
  bidId: json['bidId'] as String?,
  clientSecret: json['clientSecret'] as String?,
  amount: (json['amount'] as num).toDouble(),
  commissionAmount: (json['commissionAmount'] as num).toDouble(),
  status: $enumDecode(_$PaymentStatusEnumMap, json['status']),
  disputed: json['disputed'] as bool? ?? false,
  paymentMethodTypes:
      (json['paymentMethodTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$PaymentModelToJson(PaymentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bidId': instance.bidId,
      'clientSecret': instance.clientSecret,
      'amount': instance.amount,
      'commissionAmount': instance.commissionAmount,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'disputed': instance.disputed,
      'paymentMethodTypes': instance.paymentMethodTypes,
    };

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'PENDING',
  PaymentStatus.escrow: 'ESCROW',
  PaymentStatus.released: 'RELEASED',
  PaymentStatus.refunded: 'REFUNDED',
  PaymentStatus.failed: 'FAILED',
  PaymentStatus.cancelled: 'CANCELLED',
};
