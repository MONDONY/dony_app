import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
export 'package:dony/features/matching/data/models/transport_mode.dart';

class AnnouncementRepository {
  final AnnouncementRemoteDatasource _remoteDatasource;

  AnnouncementRepository(this._remoteDatasource);

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
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
  }) async {
    return _remoteDatasource.createAnnouncement(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
      transportMode: transportMode,
      description: description,
      acceptedContentTypes: acceptedContentTypes,
      refusedTypes: refusedTypes,
      acceptedPaymentMethods: acceptedPaymentMethods,
      capacityUnit: capacityUnit,
      pricingMode: pricingMode,
    );
  }

  Future<({List<AnnouncementModel> announcements, int totalElements})>
      getMyAnnouncements({int page = 0}) async {
    return _remoteDatasource.getMyAnnouncements(page: page);
  }

  Future<AnnouncementModel> getAnnouncementDetail(String id) async {
    return _remoteDatasource.getAnnouncementDetail(id);
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
  }) {
    return _remoteDatasource.searchAnnouncements(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDateFrom: departureDateFrom,
      departureDateTo: departureDateTo,
      minAvailableKg: minAvailableKg,
      maxAvailableKg: maxAvailableKg,
      maxPricePerKg: maxPricePerKg,
      kiloProOnly: kiloProOnly,
      minRating: minRating,
      weekendOnly: weekendOnly,
      transportMode: transportMode,
      kycVerifiedOnly: kycVerifiedOnly,
      contentType: contentType,
      userLat: userLat,
      userLng: userLng,
      radiusKm: radiusKm,
      sortBy: sortBy,
      sortDir: sortDir,
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    return _remoteDatasource.deleteAnnouncement(id);
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
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
  }) async {
    return _remoteDatasource.updateAnnouncement(
      id: id,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
      transportMode: transportMode,
      description: description,
      acceptedContentTypes: acceptedContentTypes,
      refusedTypes: refusedTypes,
      acceptedPaymentMethods: acceptedPaymentMethods,
      capacityUnit: capacityUnit,
      pricingMode: pricingMode,
    );
  }
}
