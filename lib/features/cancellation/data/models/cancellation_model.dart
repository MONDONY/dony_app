class CancellationModel {
  final String announcementId;
  final int affectedBidsCount;
  final String reason;
  final List<RematchSuggestionModel> rematchSuggestions;
  final DateTime cancelledAt;

  const CancellationModel({
    required this.announcementId,
    required this.affectedBidsCount,
    required this.reason,
    required this.rematchSuggestions,
    required this.cancelledAt,
  });

  factory CancellationModel.fromJson(Map<String, dynamic> json) {
    return CancellationModel(
      announcementId: json['announcementId'] as String,
      affectedBidsCount: json['affectedBidsCount'] as int,
      reason: json['reason'] as String,
      rematchSuggestions: (json['rematchSuggestions'] as List)
          .map((s) => RematchSuggestionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      cancelledAt: DateTime.parse(json['cancelledAt'] as String),
    );
  }
}

class RematchSuggestionModel {
  final String suggestionId;
  final String announcementId;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double availableKg;
  final double pricePerKg;

  const RematchSuggestionModel({
    required this.suggestionId,
    required this.announcementId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
  });

  factory RematchSuggestionModel.fromJson(Map<String, dynamic> json) {
    return RematchSuggestionModel(
      suggestionId: json['suggestionId'] as String,
      announcementId: json['announcementId'] as String,
      departureCity: json['departureCity'] as String,
      arrivalCity: json['arrivalCity'] as String,
      departureDate: DateTime.parse(json['departureDate'] as String),
      availableKg: (json['availableKg'] as num).toDouble(),
      pricePerKg: (json['pricePerKg'] as num).toDouble(),
    );
  }
}
