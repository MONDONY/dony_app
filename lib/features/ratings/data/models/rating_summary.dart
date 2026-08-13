class RatingItem {
  const RatingItem({
    required this.stars,
    this.comment,
    required this.createdAt,
    required this.excluded,
    this.authorName,
    this.authorAvatarUrl,
    this.departureCity,
    this.arrivalCity,
  });

  final int stars;
  final String? comment;
  final DateTime createdAt;
  final bool excluded;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? departureCity;
  final String? arrivalCity;

  factory RatingItem.fromJson(Map<String, dynamic> json) => RatingItem(
    stars: json['stars'] as int,
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    excluded: json['excluded'] as bool? ?? false,
    authorName: json['authorName'] as String?,
    authorAvatarUrl: json['authorAvatarUrl'] as String?,
    departureCity: json['departureCity'] as String?,
    arrivalCity: json['arrivalCity'] as String?,
  );
}

class RatingSummary {
  const RatingSummary({
    required this.averageRating,
    required this.ratingCount,
    required this.distribution,
    required this.ratings,
    required this.page,
    required this.totalPages,
  });

  final double averageRating;
  final int ratingCount;
  final Map<int, int> distribution;
  final List<RatingItem> ratings;
  final int page;
  final int totalPages;

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'] as Map<String, dynamic>? ?? {};
    final dist = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      dist[i] = (rawDist['$i'] as num?)?.toInt() ?? 0;
    }
    return RatingSummary(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      distribution: dist,
      ratings: (json['ratings'] as List<dynamic>? ?? [])
          .map((e) => RatingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
