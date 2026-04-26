import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';

class TrackingRepository {
  final ApiClient _apiClient;

  TrackingRepository(this._apiClient);

  Future<QrCodeModel> getQrCode(String bidId) async {
    final response = await _apiClient.dio.get('/tracking/$bidId/qr-code');
    return QrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TrackingSearchModel> searchByTrackingNumber(String number) async {
    final response = await _apiClient.dio
        .get('/tracking/search', queryParameters: {'number': number});
    return TrackingSearchModel.fromJson(response.data as Map<String, dynamic>);
  }
}
