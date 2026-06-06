import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';

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

  Future<String> uploadPhoto(File photo) async {
    final bytes = await photo.readAsBytes();
    final filename = '${DateTime.now().millisecondsSinceEpoch}_photo.jpg';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/storage/upload/package-request',
      data: formData,
    );
    return response.data!['url'] as String;
  }

  Future<PackageRequest> create({
    required String departureCity,
    required String arrivalCity,
    required DateTime desiredDate,
    required int dateToleranceDays,
    required double weightKg,
    required ContentCategory contentCategory,
    required bool negotiable,
    required Set<PaymentMethod> acceptedPaymentMethods,
    double? totalBudgetEur,
    String? description,
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
        'contentCategory': contentCategory.wireName,
        'negotiable': negotiable,
        'acceptedPaymentMethods':
            acceptedPaymentMethods.map((m) => m.wireName).toList(),
        if (totalBudgetEur != null) 'totalBudgetEur': totalBudgetEur,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (pickupNeighborhood != null) 'pickupNeighborhood': pickupNeighborhood,
        if (deliveryNeighborhood != null) 'deliveryNeighborhood': deliveryNeighborhood,
      },
    );
    return PackageRequest.fromJson(response.data!);
  }

  /// Modifie une demande existante (PUT). Autorisé tant qu'aucun accord n'a été
  /// conclu (OPEN/NEGOTIATING côté backend) ; sinon 409 `request/not-editable`.
  Future<PackageRequest> update(
    String id, {
    required String departureCity,
    required String arrivalCity,
    required DateTime desiredDate,
    required int dateToleranceDays,
    required double weightKg,
    required ContentCategory contentCategory,
    required bool negotiable,
    required Set<PaymentMethod> acceptedPaymentMethods,
    double? totalBudgetEur,
    String? description,
    String? photoUrl,
    String? pickupNeighborhood,
    String? deliveryNeighborhood,
  }) async {
    final response = await _apiClient.dio.put<Map<String, dynamic>>(
      '/package-requests/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'desiredDate': desiredDate.toIso8601String().substring(0, 10),
        'dateToleranceDays': dateToleranceDays,
        'weightKg': weightKg,
        'contentCategory': contentCategory.wireName,
        'negotiable': negotiable,
        'acceptedPaymentMethods':
            acceptedPaymentMethods.map((m) => m.wireName).toList(),
        if (totalBudgetEur != null) 'totalBudgetEur': totalBudgetEur,
        if (description != null) 'description': description,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (pickupNeighborhood != null) 'pickupNeighborhood': pickupNeighborhood,
        if (deliveryNeighborhood != null)
          'deliveryNeighborhood': deliveryNeighborhood,
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
    required String recipientName,
    required String recipientPhone,
    String? recipientCity,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/package-requests/$id/complete-details',
      data: {
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        if (recipientCity != null && recipientCity.isNotEmpty)
          'recipientCity': recipientCity,
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
    double? lat,
    double? lng,
    double? radiusKm,
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
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radiusKm != null) 'radiusKm': radiusKm,
    };
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/package-requests',
      queryParameters: query,
    );
    return PackageRequestSearchPage.fromJson(response.data!);
  }
}
