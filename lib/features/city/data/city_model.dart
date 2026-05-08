class CityModel {
  const CityModel({
    required this.name,
    required this.countryCode,
    required this.countryName,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String countryCode;
  final String countryName;
  final double lat;
  final double lng;

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        name: json['name'] as String,
        countryCode: json['countryCode'] as String,
        countryName: json['countryName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  String get displayLabel => '$name, $countryName';
}
