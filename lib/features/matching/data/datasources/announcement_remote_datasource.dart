import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/announcement_search_page.dart';
import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
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
    final response = await _apiClient.dio.post(
      '/announcements',
      data: AnnouncementPayload(
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
      ).toJson(),
    );

    return AnnouncementModel.fromJson(response.data);
  }

  /// Voyage à plusieurs étapes (FLUTTER-4D) : toutes les étapes en une
  /// transaction côté serveur. Renvoie les étapes créées, dans l'ordre.
  Future<List<AnnouncementModel>> createTrip(
    List<AnnouncementPayload> legs,
  ) async {
    final response = await _apiClient.dio.post(
      '/announcements/trips',
      data: {'legs': legs.map((l) => l.toJson()).toList()},
    );
    final data = response.data as Map<String, dynamic>;
    return ((data['legs'] as List?) ?? const [])
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Étapes du voyage auquel appartient l'annonce [id] (FLUTTER-4D).
  Future<TripLegsInfo> getTripLegs(String id) async {
    final response = await _apiClient.dio.get('/announcements/$id/trip-legs');
    return TripLegsInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnnouncementModel> publishAnnouncement(String id) async {
    final response = await _apiClient.dio.post('/announcements/$id/publish');
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnnouncementModel> unpublishAnnouncement(String id) async {
    final response = await _apiClient.dio.post('/announcements/$id/unpublish');
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnnouncementModel> markTripArrived({
    required String announcementId,
    String? arrivalInstructions,
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements/$announcementId/mark-arrived',
      data: {'arrivalInstructions': arrivalInstructions},
    );
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnnouncementModel> updateArrivalInstructions({
    required String announcementId,
    required String arrivalInstructions,
  }) async {
    final response = await _apiClient.dio.patch(
      '/announcements/$announcementId/arrival-instructions',
      data: {'arrivalInstructions': arrivalInstructions},
    );
    return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<({List<AnnouncementModel> announcements, int totalElements})>
  getMyAnnouncements() async {
    const pageSize = 50;
    // On charge TOUTES les pages : la liste ET les compteurs de filtres
    // (Tous/Actifs/Terminés/Annulés, calculés côté client) doivent refléter
    // l'intégralité des trajets, pas seulement les 50 premiers. Cas courant
    // (≤ 50 trajets) = une seule requête.
    final first = await _fetchMyAnnouncementsPage(0, pageSize);
    final all = [...first.announcements];
    final total = first.totalElements;
    final totalPages = (total / pageSize).ceil();
    for (var page = 1; page < totalPages; page++) {
      final next = await _fetchMyAnnouncementsPage(page, pageSize);
      all.addAll(next.announcements);
    }
    return (announcements: all, totalElements: total);
  }

  Future<({List<AnnouncementModel> announcements, int totalElements})>
  _fetchMyAnnouncementsPage(int page, int size) async {
    final response = await _apiClient.dio.get(
      '/announcements/my',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data as Map<String, dynamic>;
    final announcements = (data['content'] as List)
        .map((json) => AnnouncementModel.fromJson(json as Map<String, dynamic>))
        .toList();
    final totalElements =
        (data['totalElements'] as num?)?.toInt() ?? announcements.length;
    return (announcements: announcements, totalElements: totalElements);
  }

  /// [period] : la valeur d'API d'un `StatsPeriod` (`7d`, `30d`, `12m`). Sans
  /// défaut ici : l'enum est la seule source de la période choisie. Un backend
  /// qui ne gère pas encore ce paramètre l'ignore et renvoie le mois courant.
  Future<TripsSummaryModel> getTripsSummary({required String period}) async {
    final response = await _apiClient.dio.get(
      '/travelers/me/trips-summary',
      queryParameters: {'period': period},
    );
    return TripsSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RevenueDetailsModel> getRevenueDetails({
    required String period,
  }) async {
    final response = await _apiClient.dio.get(
      '/travelers/me/trips-summary/revenues',
      queryParameters: {'period': period},
    );
    return RevenueDetailsModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<KgSoldModel> getKgSold({required String period}) async {
    final response = await _apiClient.dio.get(
      '/travelers/me/trips-summary/kg-sold',
      queryParameters: {'period': period},
    );
    return KgSoldModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnnouncementModel> getAnnouncementDetail(String id) async {
    final response = await _apiClient.dio.get('/announcements/$id');
    return AnnouncementModel.fromJson(response.data);
  }

  /// Première page seulement, sans le total : pour les appelants qui n'ont
  /// besoin que d'une liste (trajets proposés sur une demande, etc.).
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
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) async {
    final result = await searchAnnouncementsPage(
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
      page: page,
      urgent: urgent,
      maxStops: maxStops,
      paymentMethods: paymentMethods,
    );
    return result.content;
  }

  Future<AnnouncementSearchPage> searchAnnouncementsPage({
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
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': 20,
      'sortBy': sortBy,
      'sortDir': sortDir,
      ..._announcementFilterParams(
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
        urgent: urgent,
        maxStops: maxStops,
        paymentMethods: paymentMethods,
      ),
    };
    final response = await _apiClient.dio.get(
      '/announcements',
      queryParameters: params,
    );
    return AnnouncementSearchPage.fromJson(
      response.data as Map<String, dynamic>,
      page: page,
    );
  }

  /// Nombre de trajets correspondant aux critères, sans charger les résultats.
  /// Lit `totalElements` d'une page de taille 1. Alimente le compteur du
  /// segment inactif du sélecteur de mode.
  ///
  /// [searchAnnouncements] ne peut pas servir ici : elle ne renvoie que le
  /// `content` d'une page figée à 20 éléments et jette le `totalElements`.
  ///
  /// Porte exactement les mêmes filtres que [searchAnnouncements] (hors tri et
  /// pagination) : un compteur qui n'appliquerait qu'une partie des filtres
  /// annoncerait un nombre que la bascule de mode ne reproduirait pas.
  Future<int> countAnnouncements({
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
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/announcements',
      queryParameters: <String, dynamic>{
        'page': 0,
        'size': 1,
        ..._announcementFilterParams(
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
          urgent: urgent,
          maxStops: maxStops,
          paymentMethods: paymentMethods,
        ),
      },
    );
    return (response.data?['totalElements'] as num?)?.toInt() ?? 0;
  }

  /// Paramètres de filtre de `GET /announcements`, hors tri et pagination.
  ///
  /// Source unique de [searchAnnouncements] et [countAnnouncements] : le
  /// compteur du sélecteur de mode doit interroger exactement le même jeu de
  /// filtres que la recherche, sinon il annonce un nombre que la bascule ne
  /// reproduit pas. Deux listes jumelles auraient divergé au premier filtre
  /// ajouté d'un seul côté.
  Map<String, dynamic> _announcementFilterParams({
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
    bool? urgent,
    int? maxStops,
    List<String>? paymentMethods,
  }) => <String, dynamic>{
    'departureCity': ?departureCity,
    'arrivalCity': ?arrivalCity,
    if (departureDateFrom != null)
      'departureDateFrom': DateFormat('yyyy-MM-dd').format(departureDateFrom),
    if (departureDateTo != null)
      'departureDateTo': DateFormat('yyyy-MM-dd').format(departureDateTo),
    'minAvailableKg': ?minAvailableKg,
    'maxAvailableKg': ?maxAvailableKg,
    'maxPricePerKg': ?maxPricePerKg,
    if (kiloProOnly == true) 'kiloProOnly': true,
    'minRating': ?minRating,
    if (weekendOnly == true) 'weekendOnly': true,
    if (transportMode != null)
      'transportMode': transportModeToWire(transportMode),
    if (kycVerifiedOnly == true) 'kycVerifiedOnly': true,
    'contentType': ?contentType,
    'userLat': ?userLat,
    'userLng': ?userLng,
    'radiusKm': ?radiusKm,
    // Filtre serveur « annonces urgentes » — jamais envoyer urgent=false,
    // seulement présent quand le chip est actif (cf. PR back #112).
    if (urgent == true) 'urgent': true,
    // FLUTTER-GD : 0 = direct uniquement, 1 = au plus une escale ; absent =
    // peu importe. Un back antérieur ignore le paramètre (liste non filtrée).
    'maxStops': ?maxStops,
    // FLUTTER-G0 : moyens de paiement offerts (STRIPE, CASH, MOBILE_MONEY),
    // filtrés côté serveur. Jamais de liste vide.
    if (paymentMethods != null && paymentMethods.isNotEmpty)
      'paymentMethods': paymentMethods.join(','),
  };

  Future<void> deleteAnnouncement(String id) async {
    await _apiClient.dio.delete('/announcements/$id');
  }

  /// Signale qu'une personne a ouvert le trajet. 204 dans tous les cas où le
  /// back ne la compte pas (voyageur lui-même, trajet hors ligne, déjà vue).
  Future<void> recordView(String id) async {
    await _apiClient.dio.post('/announcements/$id/views');
  }

  Future<TripAudienceModel> getTripAudience(String id) async {
    final response = await _apiClient.dio.get('/announcements/$id/insights');
    return TripAudienceModel.fromJson(response.data as Map<String, dynamic>);
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
  }) async {
    final response = await _apiClient.dio.put(
      '/announcements/$id',
      data: {
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureCountryCode': ?departureCountryCode,
        'arrivalCountryCode': ?arrivalCountryCode,
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        'departureTime': ?departureTime,
        'arrivalTime': ?arrivalTime,
        'arrivalDate': ?arrivalDate,
        'pickupAddress': pickupAddress.toJson(),
        'deliveryAddress': deliveryAddress.toJson(),
        'availableKg': availableKg,
        'pricePerKg': pricePerKg,
        'transportMode': transportModeToWire(transportMode),
        if (stops != null && supportsStops(transportMode))
          'stopsCount': stops.wire,
        if (description != null && description.isNotEmpty)
          'description': description,
        'acceptedContentTypes': acceptedContentTypes,
        'refusedTypes': refusedTypes,
        'acceptedPaymentMethods': acceptedPaymentMethods,
        'capacityUnit': ?capacityUnit,
        'pricingMode': pricingMode,
        'handoverDeadline': handoverDeadline.toUtc().toIso8601String(),
        'negotiable': negotiable,
      },
    );

    return AnnouncementModel.fromJson(response.data);
  }

  /// Report d'un trajet publié (vol annulé, voyage repoussé), même avec des
  /// colis acceptés : les expéditeurs concernés choisissent ensuite de garder
  /// leur colis ou de se retirer sans frais.
  Future<TripRescheduleResult> rescheduleTrip({
    required String announcementId,
    required DateTime departureDate,
    required String departureTime,
    String? arrivalDate,
    String? arrivalTime,
    required DateTime handoverDeadline,
    required TripRescheduleReason reason,
    String? note,
  }) async {
    final response = await _apiClient.dio.post(
      '/announcements/$announcementId/reschedule',
      data: {
        'departureDate': DateFormat('yyyy-MM-dd').format(departureDate),
        'departureTime': departureTime,
        'arrivalDate': ?arrivalDate,
        'arrivalTime': ?arrivalTime,
        'handoverDeadline': handoverDeadline.toUtc().toIso8601String(),
        'reason': reason.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TripRescheduleResult.fromJson(response.data as Map<String, dynamic>);
  }
}
