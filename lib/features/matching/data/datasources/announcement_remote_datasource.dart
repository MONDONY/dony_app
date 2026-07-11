import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:intl/intl.dart';
export 'package:dony/features/matching/data/models/transport_mode.dart';

class AnnouncementRemoteDatasource {
  final ApiClient _apiClient;

  AnnouncementRemoteDatasource(this._apiClient);

  Future<AnnouncementModel> createAnnouncement({
    required String departureCity,
    required String arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
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
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
    required DateTime handoverWindowStart,
    required DateTime handoverWindowEnd,
    bool saveAsDraft = false,
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        if (departureCountryCode != null)
          'departureCountryCode': departureCountryCode,
        if (arrivalCountryCode != null)
          'arrivalCountryCode': arrivalCountryCode,
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
        'acceptedPaymentMethods': acceptedPaymentMethods,
        if (capacityUnit != null) 'capacityUnit': capacityUnit,
        'pricingMode': pricingMode,
        'handoverWindowStart': handoverWindowStart.toUtc().toIso8601String(),
        'handoverWindowEnd': handoverWindowEnd.toUtc().toIso8601String(),
        if (saveAsDraft) 'saveAsDraft': true,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }

  Future<AnnouncementModel> publishAnnouncement(String id) async {
    final response = await _apiClient.dio.post('/announcements/$id/publish');
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
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

  Future<TripsSummaryModel> getTripsSummary() async {
    final response = await _apiClient.dio.get('/travelers/me/trips-summary');
    return TripsSummaryModel.fromJson(response.data as Map<String, dynamic>);
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
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
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
      if (transportMode != null) 'transportMode': transportModeToWire(transportMode),
      if (kycVerifiedOnly == true) 'kycVerifiedOnly': true,
      if (contentType != null) 'contentType': contentType,
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

  /// Ouvre au public la capacité excédentaire d'un trajet dédié.
  ///
  /// POST `/negotiations/trip/{announcementId}/open-surplus` renvoie 204 (sans
  /// corps) ; on recharge donc le détail pour récupérer l'annonce à jour
  /// (`availableKg`/`pricePerKg`/`surplusPublished` mis à jour côté back).
  Future<AnnouncementModel> openSurplus({
    required String announcementId,
    required double surplusKg,
    required double pricePerKg,
  }) async {
    await _apiClient.dio.post(
      '/negotiations/trip/$announcementId/open-surplus',
      data: {'surplusKg': surplusKg, 'pricePerKg': pricePerKg},
    );
    return getAnnouncementDetail(announcementId);
  }

  Future<AnnouncementModel> updateAnnouncement({
    required String id,
    required String departureCity,
    required String arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
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
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
    required DateTime handoverWindowStart,
    required DateTime handoverWindowEnd,
  }) async {
    final response = await _apiClient.dio.put(
      '/announcements/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        if (departureCountryCode != null)
          'departureCountryCode': departureCountryCode,
        if (arrivalCountryCode != null)
          'arrivalCountryCode': arrivalCountryCode,
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
        'acceptedPaymentMethods': acceptedPaymentMethods,
        if (capacityUnit != null) 'capacityUnit': capacityUnit,
        'pricingMode': pricingMode,
        'handoverWindowStart': handoverWindowStart.toUtc().toIso8601String(),
        'handoverWindowEnd': handoverWindowEnd.toUtc().toIso8601String(),
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }
}
