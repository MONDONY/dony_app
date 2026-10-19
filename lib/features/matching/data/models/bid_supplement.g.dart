// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_supplement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BidSupplement _$BidSupplementFromJson(Map<String, dynamic> json) =>
    BidSupplement(
      id: json['id'] as String,
      status: $enumDecode(
        _$BidSupplementStatusEnumMap,
        json['status'],
        unknownValue: BidSupplementStatus.unknown,
      ),
      rail: json['rail'] as String?,
      currency: json['currency'] as String? ?? 'EUR',
      netAmount: (json['netAmount'] as num?)?.toDouble(),
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble(),
      grossAmount: (json['grossAmount'] as num).toDouble(),
      reasonCode: json['reasonCode'] as String?,
      reasonText: json['reasonText'] as String?,
      gridItemLabel: json['gridItemLabel'] as String?,
      photoUrl: json['photoUrl'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.parse(json['paidAt'] as String),
      commissionStatus: json['commissionStatus'] as String?,
      blocksHandover: json['blocksHandover'] as bool? ?? false,
      commissionClientSecret: json['commissionClientSecret'] as String?,
    );

Map<String, dynamic> _$BidSupplementToJson(BidSupplement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': _$BidSupplementStatusEnumMap[instance.status]!,
      'rail': instance.rail,
      'currency': instance.currency,
      'netAmount': instance.netAmount,
      'commissionAmount': instance.commissionAmount,
      'grossAmount': instance.grossAmount,
      'reasonCode': instance.reasonCode,
      'reasonText': instance.reasonText,
      'gridItemLabel': instance.gridItemLabel,
      'photoUrl': instance.photoUrl,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'paidAt': instance.paidAt?.toIso8601String(),
      'commissionStatus': instance.commissionStatus,
      'blocksHandover': instance.blocksHandover,
    };

const _$BidSupplementStatusEnumMap = {
  BidSupplementStatus.commissionPending: 'COMMISSION_PENDING',
  BidSupplementStatus.proposed: 'PROPOSED',
  BidSupplementStatus.paymentPending: 'PAYMENT_PENDING',
  BidSupplementStatus.paid: 'PAID',
  BidSupplementStatus.payoutPending: 'PAYOUT_PENDING',
  BidSupplementStatus.paidOut: 'PAID_OUT',
  BidSupplementStatus.declined: 'DECLINED',
  BidSupplementStatus.expired: 'EXPIRED',
  BidSupplementStatus.withdrawn: 'WITHDRAWN',
  BidSupplementStatus.cancelled: 'CANCELLED',
  BidSupplementStatus.refundPending: 'REFUND_PENDING',
  BidSupplementStatus.refunded: 'REFUNDED',
  BidSupplementStatus.unknown: 'unknown',
};
