import 'package:equatable/equatable.dart';

/// Ville proposée par l'autocomplétion (`GET /flights/places`) : [code] est le
/// code IATA de la ville (PAR, ABJ…).
class FlightPlace extends Equatable {
  const FlightPlace({
    required this.code,
    required this.name,
    this.countryCode,
    this.countryName,
  });

  factory FlightPlace.fromJson(Map<String, dynamic> json) => FlightPlace(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? (json['code'] as String? ?? ''),
    countryCode: json['countryCode'] as String?,
    countryName: json['countryName'] as String?,
  );

  final String code;
  final String name;
  final String? countryCode;
  final String? countryName;

  @override
  List<Object?> get props => [code, name, countryCode, countryName];
}
