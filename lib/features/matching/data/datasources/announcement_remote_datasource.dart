import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:intl/intl.dart';

class AnnouncementRemoteDatasource {
  final ApiClient _apiClient;

  AnnouncementRemoteDatasource(this._apiClient);

  Future<AnnouncementModel> createAnnouncement({
    required String departureCity,
    required String arrivalCity,
    required DateTime departureDate,
    required double availableKg,
    required double pricePerKg,
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }

  Future<List<AnnouncementModel>> getMyAnnouncements({int page = 0}) async {
    final response = await _apiClient.dio.get(
      '/announcements/my',
      queryParameters: {'page': page, 'size': 20},
    );
    
    return (response.data['content'] as List)
        .map((json) => AnnouncementModel.fromJson(json))
        .toList();
  }

  Future<AnnouncementModel> getAnnouncementDetail(String id) async {
    final response = await _apiClient.dio.get('/announcements/$id');
    return AnnouncementModel.fromJson(response.data);
  }

  Future<AnnouncementModel> updateAnnouncement({
    required String id,
    required String departureCity,
    required String arrivalCity,
    required DateTime departureDate,
    required double availableKg,
    required double pricePerKg,
  }) async {
    final response = await _apiClient.dio.put(
      '/announcements/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }
}
