class PopularCorridorModel {
  const PopularCorridorModel({
    required this.departureCity,
    required this.departureCountry,
    required this.arrivalCity,
    required this.arrivalCountry,
  });

  final String departureCity;
  final String departureCountry;
  final String arrivalCity;
  final String arrivalCountry;

  factory PopularCorridorModel.fromJson(Map<String, dynamic> json) =>
      PopularCorridorModel(
        departureCity: json['departureCity'] as String,
        departureCountry: json['departureCountry'] as String,
        arrivalCity: json['arrivalCity'] as String,
        arrivalCountry: json['arrivalCountry'] as String,
      );

  String get displayLabel => '$departureCity → $arrivalCity';
}
