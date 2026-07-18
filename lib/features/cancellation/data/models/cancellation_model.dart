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

/// Réponse des endpoints code de retour (D7) : `GET .../return-code` (expéditeur)
/// et `POST .../confirm-return` (voyageur). `returnCode` peut être null côté voyageur.
class ReturnCodeModel {
  final String? returnCode;
  final DateTime? returnDeadline;
  final DateTime? returnedAt;

  const ReturnCodeModel({
    this.returnCode,
    this.returnDeadline,
    this.returnedAt,
  });

  bool get isReturned => returnedAt != null;

  factory ReturnCodeModel.fromJson(Map<String, dynamic> json) {
    return ReturnCodeModel(
      returnCode: json['returnCode'] as String?,
      returnDeadline: json['returnDeadline'] != null
          ? DateTime.parse(json['returnDeadline'] as String)
          : null,
      returnedAt: json['returnedAt'] != null
          ? DateTime.parse(json['returnedAt'] as String)
          : null,
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
  final String? travelerFirstName;
  final double? travelerRating;
  final int? travelerRatingCount;
  final String? travelerAvatarUrl;

  const RematchSuggestionModel({
    required this.suggestionId,
    required this.announcementId,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.availableKg,
    required this.pricePerKg,
    this.travelerFirstName,
    this.travelerRating,
    this.travelerRatingCount,
    this.travelerAvatarUrl,
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
      travelerFirstName: json['travelerFirstName'] as String?,
      travelerRating: (json['travelerRating'] as num?)?.toDouble(),
      travelerRatingCount: json['travelerRatingCount'] as int?,
      travelerAvatarUrl: json['travelerAvatarUrl'] as String?,
    );
  }
}
