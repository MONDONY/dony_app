import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';

class PackageRequestPage {
  const PackageRequestPage({
    required this.content,
    required this.totalElements,
    required this.page,
    required this.size,
  });

  final List<PackageRequest> content;
  final int totalElements;
  final int page;
  final int size;

  factory PackageRequestPage.fromJson(Map<String, dynamic> json) =>
      PackageRequestPage(
        content: (json['content'] as List<dynamic>)
            .map((e) => PackageRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
        page: ((json['number'] as num?) ?? 0).toInt(),
        size: ((json['size'] as num?) ?? 20).toInt(),
      );
}

class PackageRequestSearchPage {
  const PackageRequestSearchPage({
    required this.content,
    required this.totalElements,
    required this.page,
    required this.size,
  });

  final List<PackageRequestSearchItem> content;
  final int totalElements;
  final int page;
  final int size;

  factory PackageRequestSearchPage.fromJson(Map<String, dynamic> json) =>
      PackageRequestSearchPage(
        content: (json['content'] as List<dynamic>)
            .map((e) => PackageRequestSearchItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
        page: ((json['number'] as num?) ?? 0).toInt(),
        size: ((json['size'] as num?) ?? 20).toInt(),
      );
}

class PackageRequestRepository {
  const PackageRequestRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PackageRequest> create({
    required String departureCity,
    required String arrivalCity,
    required DateTime desiredDate,
    required int dateToleranceDays,
    required double weightKg,
    required ParcelSize parcelSize,
    required TransportMode transportMode,
    required String contentCategory,
    String? description,
    double? targetPriceEur,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'desiredDate': desiredDate.toIso8601String().substring(0, 10),
        'dateToleranceDays': dateToleranceDays,
        'weightKg': weightKg,
        'parcelSize': parcelSize.wireName,
        'transportMode': transportModeToWire(transportMode),
        'contentCategory': contentCategory,
        if (description != null) 'description': description,
        if (targetPriceEur != null) 'targetPriceEur': targetPriceEur,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (pickupNeighborhood != null) 'pickupNeighborhood': pickupNeighborhood,
        if (deliveryNeighborhood != null) 'deliveryNeighborhood': deliveryNeighborhood,
      },
    );
    return PackageRequest.fromJson(response.data!);
  }

  Future<PackageRequestPage> findMine({int page = 0, int size = 20}) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/package-requests/me',
      queryParameters: {'page': page, 'size': size},
    );
    return PackageRequestPage.fromJson(response.data!);
  }

  Future<PackageRequest> getById(String id) async {
    final response = await _apiClient.dio
        .get<Map<String, dynamic>>('/package-requests/$id');
    return PackageRequest.fromJson(response.data!);
  }

  /// All negotiation threads attached to a request (sender inbox view).
  Future<List<NegotiationThread>> listThreadsForRequest(String requestId) async {
    final response = await _apiClient.dio
        .get<List<dynamic>>('/package-requests/$requestId/threads');
    return (response.data ?? <dynamic>[])
        .map((e) => NegotiationThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancel(String id) async {
    await _apiClient.dio.delete<void>('/package-requests/$id');
  }

  Future<PackageRequest> completeDetails(
    String id, {
    required String pickupAddressLabel,
    required double pickupLat,
    required double pickupLng,
    required String deliveryAddressLabel,
    required double deliveryLat,
    required double deliveryLng,
    required String recipientName,
    required String recipientPhone,
    required double declaredValueEur,
    required bool disclaimerSigned,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests/$id/complete-details',
      data: {
        'pickupAddressLabel': pickupAddressLabel,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'deliveryAddressLabel': deliveryAddressLabel,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'declaredValueEur': declaredValueEur,
        'disclaimerSigned': disclaimerSigned,
      },
    );
    return PackageRequest.fromJson(response.data!);
  }

  Future<PackageRequestSearchPage> search({
    String? departure,
    String? arrival,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? maxWeight,
    ParcelSize? parcelSize,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'size': size,
      if (departure != null) 'departure': departure,
      if (arrival != null) 'arrival': arrival,
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String().substring(0, 10),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String().substring(0, 10),
      if (maxWeight != null) 'maxWeight': maxWeight,
      if (parcelSize != null) 'parcelSize': parcelSize.wireName,
    };
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/package-requests',
      queryParameters: query,
    );
    return PackageRequestSearchPage.fromJson(response.data!);
  }
}
