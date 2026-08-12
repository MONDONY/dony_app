import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address_data.g.dart';

@JsonSerializable()
class AddressData extends Equatable {
  const AddressData({
    required this.label,
    required this.lat,
    required this.lng,
    this.street,
    this.city,
    this.postalCode,
    this.country,
  });

  final String label;
  final double lat;
  final double lng;
  final String? street;
  final String? city;
  final String? postalCode;
  final String? country;

  factory AddressData.fromJson(Map<String, dynamic> json) =>
      _$AddressDataFromJson(json);

  Map<String, dynamic> toJson() => _$AddressDataToJson(this);

  @override
  List<Object?> get props => [label, lat, lng, street, city, postalCode, country];

  @override
  String toString() => 'AddressData($label, $lat, $lng, $city)';
}
