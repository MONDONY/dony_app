class FavoriteTraveler {
  final String id;
  final String travelerId;
  final String travelerName;
  final String? travelerAvatarUrl;
  final double? travelerAverageRating;
  final String? notes;

  const FavoriteTraveler({
    required this.id,
    required this.travelerId,
    required this.travelerName,
    this.travelerAvatarUrl,
    this.travelerAverageRating,
    this.notes,
  });

  factory FavoriteTraveler.fromJson(Map<String, dynamic> json) =>
      FavoriteTraveler(
        id: json['id'] as String,
        travelerId: json['travelerId'] as String,
        travelerName: json['travelerName'] as String,
        travelerAvatarUrl: json['travelerAvatarUrl'] as String?,
        travelerAverageRating:
            (json['travelerAverageRating'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'travelerId': travelerId,
        'travelerName': travelerName,
        if (travelerAvatarUrl != null) 'travelerAvatarUrl': travelerAvatarUrl,
        if (travelerAverageRating != null)
          'travelerAverageRating': travelerAverageRating,
        if (notes != null) 'notes': notes,
      };
}
