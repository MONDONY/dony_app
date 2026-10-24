// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_amendment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BidAmendmentItem _$BidAmendmentItemFromJson(Map<String, dynamic> json) =>
    BidAmendmentItem(
      label: json['label'] as String,
      quantity: (json['quantity'] as num).toInt(),
      grossAmount: (json['grossAmount'] as num).toDouble(),
      netAmount: (json['netAmount'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BidAmendmentItemToJson(BidAmendmentItem instance) =>
    <String, dynamic>{
      'label': instance.label,
      'quantity': instance.quantity,
      'grossAmount': instance.grossAmount,
      'netAmount': instance.netAmount,
    };

BidAmendment _$BidAmendmentFromJson(Map<String, dynamic> json) => BidAmendment(
  id: json['id'] as String,
  status: $enumDecode(
    _$BidAmendmentStatusEnumMap,
    json['status'],
    unknownValue: BidAmendmentStatus.unknown,
  ),
  rail: json['rail'] as String?,
  currency: json['currency'] as String? ?? 'EUR',
  addedWeightKg: (json['addedWeightKg'] as num?)?.toDouble() ?? 0,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => BidAmendmentItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  grossAmount: (json['grossAmount'] as num).toDouble(),
  netAmount: (json['netAmount'] as num?)?.toDouble(),
  commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  paymentExpiresAt: json['paymentExpiresAt'] == null
      ? null
      : DateTime.parse(json['paymentExpiresAt'] as String),
  closedReason: json['closedReason'] as String?,
  blocksHandover: json['blocksHandover'] as bool? ?? false,
  commissionStatus: json['commissionStatus'] as String?,
  commissionClientSecret: json['commissionClientSecret'] as String?,
);

Map<String, dynamic> _$BidAmendmentToJson(BidAmendment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$BidAmendmentStatusEnumMap[instance.status]!,
      'rail': instance.rail,
      'currency': instance.currency,
      'addedWeightKg': instance.addedWeightKg,
      'items': instance.items,
      'grossAmount': instance.grossAmount,
      'netAmount': instance.netAmount,
      'commissionAmount': instance.commissionAmount,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'paymentExpiresAt': instance.paymentExpiresAt?.toIso8601String(),
      'closedReason': instance.closedReason,
      'blocksHandover': instance.blocksHandover,
      'commissionStatus': instance.commissionStatus,
    };

const _$BidAmendmentStatusEnumMap = {
  BidAmendmentStatus.authorizationPending: 'AUTHORIZATION_PENDING',
  BidAmendmentStatus.proposed: 'PROPOSED',
  BidAmendmentStatus.commissionPending: 'COMMISSION_PENDING',
  BidAmendmentStatus.paymentPending: 'PAYMENT_PENDING',
  BidAmendmentStatus.accepted: 'ACCEPTED',
  BidAmendmentStatus.payoutPending: 'PAYOUT_PENDING',
  BidAmendmentStatus.paidOut: 'PAID_OUT',
  BidAmendmentStatus.declined: 'DECLINED',
  BidAmendmentStatus.expired: 'EXPIRED',
  BidAmendmentStatus.cancelled: 'CANCELLED',
  BidAmendmentStatus.refundPending: 'REFUND_PENDING',
  BidAmendmentStatus.refunded: 'REFUNDED',
  BidAmendmentStatus.unknown: 'unknown',
};
