import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/ratings/data/models/pending_rating.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';

class RatingRepository {
  const RatingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> submitRating({
    required String bidId,
    required int stars,
    String? comment,
  }) async {
    await _apiClient.dio.post('/ratings', data: {
      'bidId': bidId,
      'stars': stars,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<void> submitTravelerRating({
    required String bidId,
    required int stars,
    String? comment,
  }) async {
    await _apiClient.dio.post('/ratings/traveler-to-sender', data: {
      'bidId': bidId,
      'stars': stars,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<RatingSummary> getUserRatings(String userId, {int page = 0}) async {
    final response = await _apiClient.dio.get(
      '/ratings/user/$userId',
      queryParameters: {'page': page, 'size': 20},
    );
    return RatingSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PendingRating?> getPendingRating() async {
    final response = await _apiClient.dio.get('/ratings/pending');
    if (response.statusCode == 204 || response.data == null) return null;
    return PendingRating.fromJson(response.data as Map<String, dynamic>);
  }
}
