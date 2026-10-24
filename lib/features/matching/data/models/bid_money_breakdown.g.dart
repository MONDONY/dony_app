// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_money_breakdown.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoneyLine _$MoneyLineFromJson(Map<String, dynamic> json) => MoneyLine(
  kind: $enumDecode(
    _$MoneyLineKindEnumMap,
    json['kind'],
    unknownValue: MoneyLineKind.unknown,
  ),
  refId: json['refId'] as String,
  method: json['method'] as String,
  amount: (json['amount'] as num?)?.toDouble() ?? 0,
  status: json['status'] as String,
);

Map<String, dynamic> _$MoneyLineToJson(MoneyLine instance) => <String, dynamic>{
  'kind': _$MoneyLineKindEnumMap[instance.kind]!,
  'refId': instance.refId,
  'method': instance.method,
  'amount': instance.amount,
  'status': instance.status,
};

const _$MoneyLineKindEnumMap = {
  MoneyLineKind.principal: 'PRINCIPAL',
  MoneyLineKind.amendment: 'AMENDMENT',
  MoneyLineKind.supplement: 'SUPPLEMENT',
  MoneyLineKind.unknown: 'unknown',
};

BidMoneyBreakdown _$BidMoneyBreakdownFromJson(Map<String, dynamic> json) =>
    BidMoneyBreakdown(
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => MoneyLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toDouble() ?? 0,
      onlineAmount: (json['onlineAmount'] as num?)?.toDouble() ?? 0,
      cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0,
      cashCommissionPaid: (json['cashCommissionPaid'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BidMoneyBreakdownToJson(BidMoneyBreakdown instance) =>
    <String, dynamic>{
      'lines': instance.lines,
      'total': instance.total,
      'onlineAmount': instance.onlineAmount,
      'cashAmount': instance.cashAmount,
      'cashCommissionPaid': instance.cashCommissionPaid,
    };
