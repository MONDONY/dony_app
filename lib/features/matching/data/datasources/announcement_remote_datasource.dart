import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
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
    required AddressData pickupAddress,
    required AddressData deliveryAddress,
    required double availableKg,
    required double pricePerKg,
    required TransportMode transportMode,
    String? description,
    List<String> acceptedContentTypes = const [],
    List<String> refusedTypes = const [],
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        'pickupAddress': pickupAddress.toJson(),
        'deliveryAddress': deliveryAddress.toJson(),
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
        'transportMode': transportModeToWire(transportMode),
        if (description != null && description.isNotEmpty) 'description': description,
        'acceptedContentTypes': acceptedContentTypes,
        'refusedTypes': refusedTypes,
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
    double? maxAvailableKg,
    double? maxPricePerKg,
    bool? kiloProOnly,
    double? minRating,
    bool? weekendOnly,
    double? userLat,
    double? userLng,
    double? radiusKm,
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
      if (maxAvailableKg != null) 'maxAvailableKg': maxAvailableKg,
      if (maxPricePerKg != null) 'maxPricePerKg': maxPricePerKg,
      if (kiloProOnly == true) 'kiloProOnly': true,
      if (minRating != null) 'minRating': minRating,
      if (weekendOnly == true) 'weekendOnly': true,
      if (userLat != null) 'userLat': userLat,
      if (userLng != null) 'userLng': userLng,
      if (radiusKm != null) 'radiusKm': radiusKm,
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
    required AddressData pickupAddress,
    required AddressData deliveryAddress,
    required double availableKg,
    required double pricePerKg,
    required TransportMode transportMode,
    String? description,
    List<String> acceptedContentTypes = const [],
    List<String> refusedTypes = const [],
  }) async {
    final response = await _apiClient.dio.put(
      '/announcements/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        'pickupAddress': pickupAddress.toJson(),
        'deliveryAddress': deliveryAddress.toJson(),
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
        'transportMode': transportModeToWire(transportMode),
        if (description != null && description.isNotEmpty) 'description': description,
        'acceptedContentTypes': acceptedContentTypes,
        'refusedTypes': refusedTypes,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }
}
