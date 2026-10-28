import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/announcement_search_page.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';

export 'package:dony/features/matching/data/models/transport_mode.dart';

class AnnouncementRepository {
  final AnnouncementRemoteDatasource _remoteDatasource;

  AnnouncementRepository(this._remoteDatasource);

  Future<AnnouncementModel> createAnnouncement({
    required String departureCity,
    required String arrivalCity,
    String? departureCountryCode,
    String? arrivalCountryCode,
    required DateTime departureDate,
    String? departureTime,
    String? arrivalTime,
    String? arrivalDate,
    required AddressData pickupAddress,
    required AddressData deliveryAddress,
    required double availableKg,
    required double pricePerKg,
    required TransportMode transportMode,
    TripStops? stops,
    String? description,
    List<String> acceptedContentTypes = const [],
    List<String> refusedTypes = const [],
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
    required DateTime handoverDeadline,
    bool negotiable = false,
    bool saveAsDraft = false,
    String? currency,
  }) async {
    return _remoteDatasource.createAnnouncement(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureCountryCode: departureCountryCode,
      arrivalCountryCode: arrivalCountryCode,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      arrivalDate: arrivalDate,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
      transportMode: transportMode,
      stops: stops,
      description: description,
      acceptedContentTypes: acceptedContentTypes,
      refusedTypes: refusedTypes,
      acceptedPaymentMethods: acceptedPaymentMethods,
      capacityUnit: capacityUnit,
      pricingMode: pricingMode,
      handoverDeadline: handoverDeadline,
      negotiable: negotiable,
      saveAsDraft: saveAsDraft,
      currency: currency,
    );
  }

  /// Voyage à plusieurs étapes (FLUTTER-4D).
  Future<List<AnnouncementModel>> createTrip(List<AnnouncementPayload> legs) =>
      _remoteDatasource.createTrip(legs);

  /// Trajet récurrent par dates précises (yadony-back #525).
  Future<TripSeriesResult> createSeries(
    String id, {
    required List<DateTime> dates,
    required bool saveAsDraft,
  }) => _remoteDatasource.createSeries(
    id,
    dates: dates,
    saveAsDraft: saveAsDraft,
  );

  /// Étapes du voyage de l'annonce [id] (FLUTTER-4D).
  Future<TripLegsInfo> getTripLegs(String id) =>
      _remoteDatasource.getTripLegs(id);

  Future<AnnouncementModel> publishAnnouncement(String id) =>
      _remoteDatasource.publishAnnouncement(id);

  Future<AnnouncementModel> unpublishAnnouncement(String id) =>
      _remoteDatasource.unpublishAnnouncement(id);

  Future<({List<AnnouncementModel> announcements, int totalElements})>
  getMyAnnouncements() async {
    return _remoteDatasource.getMyAnnouncements();
  }

  Future<TripsSummaryModel> getTripsSummary({required String period}) async {
    return _remoteDatasource.getTripsSummary(period: period);
  }

  Future<RevenueDetailsModel> getRevenueDetails({required String period}) =>
      _remoteDatasource.getRevenueDetails(period: period);

  Future<KgSoldModel> getKgSold({required String period}) =>
      _remoteDatasource.getKgSold(period: period);

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
    bool? gpProOnly,
    double? minRating,
    bool? weekendOnly,
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
    double? userLat,
    double? userLng,
    double? radiusKm,
    String sortBy = 'score',
    String sortDir = 'asc',
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) {
    return _remoteDatasource.searchAnnouncements(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDateFrom: departureDateFrom,
      departureDateTo: departureDateTo,
      minAvailableKg: minAvailableKg,
      maxAvailableKg: maxAvailableKg,
      maxPricePerKg: maxPricePerKg,
      gpProOnly: gpProOnly,
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
      urgent: urgent,
      maxStops: maxStops,
      paymentMethods: paymentMethods,
    );
  }

  /// Page [page] de la recherche avec le total serveur (accueil paginé).
  Future<AnnouncementSearchPage> searchAnnouncementsPage({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateFrom,
    DateTime? departureDateTo,
    double? minAvailableKg,
    double? maxAvailableKg,
    double? maxPricePerKg,
    bool? gpProOnly,
    double? minRating,
    bool? weekendOnly,
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
    double? userLat,
    double? userLng,
    double? radiusKm,
    String sortBy = 'score',
    String sortDir = 'asc',
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
    int page = 0,
    bool includeFull = false,
  }) {
    return _remoteDatasource.searchAnnouncementsPage(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDateFrom: departureDateFrom,
      departureDateTo: departureDateTo,
      minAvailableKg: minAvailableKg,
      maxAvailableKg: maxAvailableKg,
      maxPricePerKg: maxPricePerKg,
      gpProOnly: gpProOnly,
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
      urgent: urgent,
      maxStops: maxStops,
      paymentMethods: paymentMethods,
      page: page,
      includeFull: includeFull,
    );
  }

  /// Nombre de trajets correspondant aux critères, sans charger les résultats.
  /// Alimente le compteur du segment inactif du sélecteur de mode.
  Future<int> countAnnouncements({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateFrom,
    DateTime? departureDateTo,
    double? minAvailableKg,
    double? maxAvailableKg,
    double? maxPricePerKg,
    bool? gpProOnly,
    double? minRating,
    bool? weekendOnly,
    TransportMode? transportMode,
    bool? kycVerifiedOnly,
    String? contentType,
    double? userLat,
    double? userLng,
    double? radiusKm,
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) {
    return _remoteDatasource.countAnnouncements(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDateFrom: departureDateFrom,
      departureDateTo: departureDateTo,
      minAvailableKg: minAvailableKg,
      maxAvailableKg: maxAvailableKg,
      maxPricePerKg: maxPricePerKg,
      gpProOnly: gpProOnly,
      minRating: minRating,
      weekendOnly: weekendOnly,
      transportMode: transportMode,
      kycVerifiedOnly: kycVerifiedOnly,
      contentType: contentType,
      userLat: userLat,
      userLng: userLng,
      radiusKm: radiusKm,
      urgent: urgent,
      maxStops: maxStops,
      paymentMethods: paymentMethods,
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    return _remoteDatasource.deleteAnnouncement(id);
  }

  Future<void> recordView(String id) => _remoteDatasource.recordView(id);

  Future<TripAudienceModel> getTripAudience(String id) =>
      _remoteDatasource.getTripAudience(id);

  /// Ouvre au public la capacité excédentaire d'un trajet dédié, puis renvoie
  /// l'annonce rechargée (le back répond 204 sans corps).
  Future<AnnouncementModel> openSurplus({
    required String announcementId,
    required double surplusKg,
    required double pricePerKg,
  }) async {
    return _remoteDatasource.openSurplus(
      announcementId: announcementId,
      surplusKg: surplusKg,
      pricePerKg: pricePerKg,
    );
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
    String? arrivalDate,
    required AddressData pickupAddress,
    required AddressData deliveryAddress,
    required double availableKg,
    required double pricePerKg,
    required TransportMode transportMode,
    TripStops? stops,
    String? description,
    List<String> acceptedContentTypes = const [],
    List<String> refusedTypes = const [],
    List<String> acceptedPaymentMethods = const ['STRIPE'],
    String? capacityUnit,
    String pricingMode = 'KG',
    required DateTime handoverDeadline,
    bool negotiable = false,
    String? currency,
  }) async {
    return _remoteDatasource.updateAnnouncement(
      id: id,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureCountryCode: departureCountryCode,
      arrivalCountryCode: arrivalCountryCode,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      arrivalDate: arrivalDate,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
      transportMode: transportMode,
      stops: stops,
      description: description,
      acceptedContentTypes: acceptedContentTypes,
      refusedTypes: refusedTypes,
      acceptedPaymentMethods: acceptedPaymentMethods,
      capacityUnit: capacityUnit,
      pricingMode: pricingMode,
      handoverDeadline: handoverDeadline,
      negotiable: negotiable,
      currency: currency,
    );
  }

  Future<AnnouncementModel> markTripArrived({
    required String announcementId,
    String? arrivalInstructions,
    ({double lat, double lon})? position,
  }) => _remoteDatasource.markTripArrived(
    announcementId: announcementId,
    arrivalInstructions: arrivalInstructions,
    position: position,
  );

  Future<AnnouncementModel> updateArrivalInstructions({
    required String announcementId,
    required String arrivalInstructions,
  }) => _remoteDatasource.updateArrivalInstructions(
    announcementId: announcementId,
    arrivalInstructions: arrivalInstructions,
  );

  Future<TripRescheduleResult> rescheduleTrip({
    required String announcementId,
    required DateTime departureDate,
    required String departureTime,
    String? arrivalDate,
    String? arrivalTime,
    required DateTime handoverDeadline,
    required TripRescheduleReason reason,
    String? note,
  }) => _remoteDatasource.rescheduleTrip(
    announcementId: announcementId,
    departureDate: departureDate,
    departureTime: departureTime,
    arrivalDate: arrivalDate,
    arrivalTime: arrivalTime,
    handoverDeadline: handoverDeadline,
    reason: reason,
    note: note,
  );
}
