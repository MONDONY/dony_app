// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid_quote_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BidQuoteResponse _$BidQuoteResponseFromJson(Map<String, dynamic> json) =>
    BidQuoteResponse(
      netEur: (json['netEur'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      commissionEur: (json['commissionEur'] as num).toDouble(),
      totalEur: (json['totalEur'] as num).toDouble(),
      promoApplied: json['promoApplied'] as bool,
      promoLabel: json['promoLabel'] as String?,
    );

Map<String, dynamic> _$BidQuoteResponseToJson(BidQuoteResponse instance) =>
    <String, dynamic>{
      'netEur': instance.netEur,
      'rate': instance.rate,
      'commissionEur': instance.commissionEur,
      'totalEur': instance.totalEur,
      'promoApplied': instance.promoApplied,
      'promoLabel': instance.promoLabel,
    };
