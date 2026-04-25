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
    String? departureTime,
    String? arrivalTime,
    String? departureLocation,
    String? arrivalLocation,
    required double availableKg,
    required double pricePerKg,
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (departureLocation != null && departureLocation.isNotEmpty)
          'departureLocation': departureLocation,
        if (arrivalLocation != null && arrivalLocation.isNotEmpty)
          'arrivalLocation': arrivalLocation,
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }

  Future<({List<AnnouncementModel> announcements, int totalElements})>
      getMyAnnouncements({int page = 0}) async {
    final response = await _apiClient.dio.get(
      '/announcements/my',
      queryParameters: {'page': page, 'size': 50},
    );
    final data = response.data as Map<String, dynamic>;
    final announcements = (data['content'] as List)
        .map((json) => AnnouncementModel.fromJson(json as Map<String, dynamic>))
        .toList();
    final totalElements = (data['totalElements'] as num?)?.toInt() ?? announcements.length;
    return (announcements: announcements, totalElements: totalElements);
  }

  Future<AnnouncementModel> getAnnouncementDetail(String id) async {
    final response = await _apiClient.dio.get('/announcements/$id');
    return AnnouncementModel.fromJson(response.data);
  }

  Future<List<AnnouncementModel>> searchAnnouncements({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateFrom,
    DateTime? departureDateTo,
    double? minAvailableKg,
    String sortBy = 'date',
    String sortDir = 'asc',
    int page = 0,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': 20,
      'sortBy': sortBy,
      'sortDir': sortDir,
      if (departureCity != null) 'departureCity': departureCity,
      if (arrivalCity != null) 'arrivalCity': arrivalCity,
      if (departureDateFrom != null)
        'departureDateFrom': DateFormat('yyyy-MM-dd').format(departureDateFrom),
      if (departureDateTo != null)
        'departureDateTo': DateFormat('yyyy-MM-dd').format(departureDateTo),
      if (minAvailableKg != null) 'minAvailableKg': minAvailableKg,
    };
    final response =
        await _apiClient.dio.get('/announcements', queryParameters: params);
    return (response.data['content'] as List)
        .map((json) => AnnouncementModel.fromJson(json))
        .toList();
  }

  Future<void> deleteAnnouncement(String id) async {
    await _apiClient.dio.delete('/announcements/$id');
  }

  Future<AnnouncementModel> updateAnnouncement({
    required String id,
    required String departureCity,
    required String arrivalCity,
    required DateTime departureDate,
    String? departureTime,
    String? arrivalTime,
    String? departureLocation,
    String? arrivalLocation,
    required double availableKg,
    required double pricePerKg,
  }) async {
    final response = await _apiClient.dio.put(
      '/announcements/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (departureLocation != null && departureLocation.isNotEmpty)
          'departureLocation': departureLocation,
        if (arrivalLocation != null && arrivalLocation.isNotEmpty)
          'arrivalLocation': arrivalLocation,
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }
}
