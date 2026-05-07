import 'package:dony/core/network/api_client.dart';

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
}
