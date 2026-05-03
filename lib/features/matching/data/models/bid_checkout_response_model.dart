import 'package:json_annotation/json_annotation.dart';

part 'bid_checkout_response_model.g.dart';

@JsonSerializable()
class BidCheckoutResponseModel {
  final String bidId;
  final String clientSecret;
  final String publishableKey;
  final DateTime expiresAt;

  const BidCheckoutResponseModel({
    required this.bidId,
    required this.clientSecret,
    required this.publishableKey,
    required this.expiresAt,
  });

  factory BidCheckoutResponseModel.fromJson(Map<String, dynamic> json) =>
      _$BidCheckoutResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$BidCheckoutResponseModelToJson(this);
}
