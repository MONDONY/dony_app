import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/trip_arrival_events_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/announcement_payload.dart';
import 'package:dony/features/matching/data/models/announcement_search_page.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;
  final AnalyticsService _analytics;

  /// Prévient les écrans déjà ouverts qu'un trajet vient d'être marqué
  /// arrivé (FLUTTER-D6). Facultatif : absent dans les tests unitaires.
  final TripArrivalEventsService? _tripArrivalEvents;

  AnnouncementBloc(
    this._repository,
    this._analytics, {
    TripArrivalEventsService? tripArrivalEvents,
  }) : _tripArrivalEvents = tripArrivalEvents,
       super(AnnouncementInitial()) {
    on<AnnouncementCreateRequested>(_onCreateRequested);
    on<AnnouncementTripCreateRequested>(_onTripCreateRequested);
    on<AnnouncementPublishRequested>(_onPublishRequested);
    on<AnnouncementUnpublishRequested>(_onUnpublishRequested);
    on<AnnouncementListRequested>(_onListRequested);
    on<AnnouncementDetailRequested>(_onDetailRequested);
    on<AnnouncementUpdateRequested>(_onUpdateRequested);
    on<AnnouncementDeleteRequested>(_onDeleteRequested);
    on<AnnouncementSearchRequested>(_onSearchRequested);
    on<AnnouncementSearchMoreRequested>(_onSearchMoreRequested);
    on<AnnouncementSurplusOpenRequested>(_onSurplusOpenRequested);
    on<AnnouncementTripMarkArrivedRequested>(_onTripMarkArrivedRequested);
    on<AnnouncementRescheduleRequested>(_onRescheduleRequested);
    on<AnnouncementArrivalInstructionsUpdateRequested>(
      _onArrivalInstructionsUpdateRequested,
    );
  }

  Future<void> _onCreateRequested(
    AnnouncementCreateRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Anti double-soumission : on ignore les events empilés tant qu'une création
    // est déjà en cours. Sans cette garde, taper « Publier » plusieurs fois avant
    // que le bouton ne se désactive (le state Loading n'arrive qu'à la frame
    // suivante) envoyait 2-3 POST /announcements en rafale.
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.createAnnouncement(
        departureCity: event.departureCity,
        arrivalCity: event.arrivalCity,
        departureCountryCode: event.departureCountryCode,
        arrivalCountryCode: event.arrivalCountryCode,
        departureDate: event.departureDate,
        departureTime: event.departureTime,
        arrivalTime: event.arrivalTime,
        arrivalDate: event.arrivalDate,
        pickupAddress: event.pickupAddress,
        deliveryAddress: event.deliveryAddress,
        availableKg: event.availableKg,
        pricePerKg: event.pricePerKg,
        transportMode: event.transportMode,
        description: event.description,
        acceptedContentTypes: event.acceptedContentTypes,
        refusedTypes: event.refusedTypes,
        acceptedPaymentMethods: event.acceptedPaymentMethods,
        capacityUnit: event.capacityUnit,
        pricingMode: event.pricingMode,
        handoverDeadline: event.handoverDeadline,
        negotiable: event.negotiable,
        saveAsDraft: event.saveAsDraft,
        currency: event.currency,
      );
      emit(AnnouncementCreated(announcement));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.announcementCreated,
          properties: {
            'corridor': '${event.departureCity}→${event.arrivalCity}',
            'available_kg': event.availableKg,
            'price_per_kg': event.pricePerKg,
            'is_draft': event.saveAsDraft,
          },
        ),
      );
    } catch (e) {
      // Le datasource laisse remonter le DioException brut (dont `.error` porte la
      // ForbiddenException posée par l'interceptor). On déballe AVANT de router :
      // sinon `pro-limit-reached` tombait dans le cas générique et l'utilisateur
      // ne voyait qu'un vague « Action non autorisée » au lieu de l'invite PRO.
      final error = unwrapDioError(e);
      if (error is ForbiddenException && error.code == 'draft-limit-reached') {
        emit(AnnouncementDraftLimitReached(error));
      } else if (error is ForbiddenException &&
          error.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(error));
      } else {
        emit(AnnouncementError(error));
      }
    }
  }

  Future<void> _onPublishRequested(
    AnnouncementPublishRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Anti double-soumission (cf. _onCreateRequested).
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.publishAnnouncement(event.id);
      emit(AnnouncementPublished(announcement));
    } catch (e) {
      final error = unwrapDioError(e);
      if (error is ForbiddenException && error.code == 'kyc-not-verified') {
        emit(AnnouncementKycRequired(error));
      } else if (error is ForbiddenException &&
          error.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(error));
      } else if (error.code == 'departure-date-passed') {
        emit(AnnouncementDepartureDatePassed(error));
      } else {
        emit(AnnouncementError(error));
      }
    }
  }

  Future<void> _onUnpublishRequested(
    AnnouncementUnpublishRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.unpublishAnnouncement(event.id);
      emit(AnnouncementUpdated(announcement));
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }

  Future<void> _onListRequested(
    AnnouncementListRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Anti-course : cet event a plusieurs déclencheurs (retour au premier
    // plan, changement d'onglet, pull-to-refresh, bouton « Réessayer »...).
    // Sans cette garde, deux appels concurrents émettaient chacun leur
    // résultat — celui qui répondait en DERNIER l'emportait, pas forcément
    // le plus récent déclenché, ce qui pouvait afficher une erreur périmée
    // par-dessus des données fraîches (ou l'inverse) selon la latence
    // réseau du moment. Même principe que _onCreateRequested ci-dessus.
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final result = await _repository.getMyAnnouncements();
      emit(
        AnnouncementListLoaded(
          result.announcements,
          totalElements: result.totalElements,
        ),
      );
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }

  Future<void> _onDetailRequested(
    AnnouncementDetailRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.getAnnouncementDetail(event.id);
      emit(AnnouncementDetailLoaded(announcement));
    } catch (e) {
      final wrapped = unwrapDioError(e);
      if (wrapped is NotFoundException) {
        emit(AnnouncementNotFound());
      } else {
        emit(AnnouncementError(wrapped));
      }
    }
  }

  Future<void> _onSearchRequested(
    AnnouncementSearchRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    final current = state;
    if (current is AnnouncementSearchLoaded) {
      emit(AnnouncementSearchLoaded(current.results, isReloading: true));
    } else {
      emit(AnnouncementLoading());
    }
    try {
      _lastSearch = event;
      final result = await _fetchSearchPage(event, page: 0);
      emit(
        AnnouncementSearchLoaded(
          result.content,
          totalElements: result.totalElements,
        ),
      );
    } catch (e, stacktrace) {
      if (kDebugMode) debugPrint('=== SEARCH ERROR ===');
      if (kDebugMode) debugPrint(e.toString());
      if (kDebugMode) debugPrint(stacktrace.toString());
      emit(
        AnnouncementError(
          unwrapDioError(e),
          previousResults: current is AnnouncementSearchLoaded
              ? current.results
              : null,
        ),
      );
    }
  }

  /// Dernière recherche lancée : la page suivante reprend ses critères.
  AnnouncementSearchRequested? _lastSearch;

  Future<AnnouncementSearchPage> _fetchSearchPage(
    AnnouncementSearchRequested event, {
    required int page,
  }) {
    return _repository.searchAnnouncementsPage(
      departureCity: event.departureCity,
      arrivalCity: event.arrivalCity,
      departureDateFrom: event.departureDateFrom,
      departureDateTo: event.departureDateTo,
      minAvailableKg: event.minAvailableKg,
      maxAvailableKg: event.maxAvailableKg,
      maxPricePerKg: event.maxPricePerKg,
      kiloProOnly: event.kiloProOnly,
      minRating: event.minRating,
      weekendOnly: event.weekendOnly,
      transportMode: event.transportMode,
      kycVerifiedOnly: event.kycVerifiedOnly,
      contentType: event.contentType,
      userLat: event.userLat,
      userLng: event.userLng,
      radiusKm: event.radiusKm,
      sortBy: event.sortBy,
      sortDir: event.sortDir,
      urgent: event.urgent,
      page: page,
    );
  }

  Future<void> _onSearchMoreRequested(
    AnnouncementSearchMoreRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    final current = state;
    final search = _lastSearch;
    if (search == null ||
        current is! AnnouncementSearchLoaded ||
        current.isLoadingMore ||
        current.isReloading ||
        !current.hasMore) {
      return;
    }
    emit(
      AnnouncementSearchLoaded(
        current.results,
        totalElements: current.totalElements,
        page: current.page,
        isLoadingMore: true,
      ),
    );
    try {
      final next = await _fetchSearchPage(search, page: current.page + 1);
      // Une recherche relancée entre-temps a remplacé la liste : on jette.
      if (!identical(search, _lastSearch)) return;
      final known = {for (final a in current.results) a.id};
      emit(
        AnnouncementSearchLoaded(
          [
            ...current.results,
            ...next.content.where((a) => !known.contains(a.id)),
          ],
          totalElements: next.totalElements,
          page: next.page,
        ),
      );
    } catch (_) {
      // La liste déjà chargée reste ; le prochain défilement réessaiera.
      if (!identical(search, _lastSearch)) return;
      emit(
        AnnouncementSearchLoaded(
          current.results,
          totalElements: current.totalElements,
          page: current.page,
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    AnnouncementDeleteRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      await _repository.deleteAnnouncement(event.id);
      // Étapes suivantes du voyage (FLUTTER-4D) : au mieux, sans annuler
      // l'étape principale déjà supprimée si l'une d'elles est refusée.
      var followingFailed = 0;
      for (final id in event.followingLegIds) {
        try {
          await _repository.deleteAnnouncement(id);
        } catch (_) {
          followingFailed++;
        }
      }
      emit(AnnouncementDeleted(followingFailed: followingFailed));
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        emit(AnnouncementDeleteBlockedByAcceptedBid(event.id));
      } else {
        emit(AnnouncementError(unwrapDioError(e)));
      }
    }
  }

  Future<void> _onTripCreateRequested(
    AnnouncementTripCreateRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Même garde anti double-soumission que la création simple.
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final legs = await _repository.createTrip(
        buildTripPayloads(event.first, event.legs),
      );
      if (legs.isEmpty) {
        emit(AnnouncementTripUnsupported());
        return;
      }
      emit(AnnouncementTripCreated(legs));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripGroupCreated,
          properties: {
            'leg_count': legs.length,
            'corridor': [
              event.first.departureCity,
              ...legs.map((l) => l.arrivalCity),
            ].join('→'),
            'is_draft': event.first.saveAsDraft,
          },
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      // Backend antérieur à FLUTTER-4D : la route n'existe pas (404), ou
      // `/announcements/{id}` capte « trips » en identifiant (405).
      if (error is NotFoundException ||
          (error is NetworkException && error.code == '405')) {
        emit(AnnouncementTripUnsupported());
      } else if (error is ForbiddenException &&
          error.code == 'draft-limit-reached') {
        emit(AnnouncementDraftLimitReached(error));
      } else if (error is ForbiddenException &&
          error.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(error));
      } else {
        emit(AnnouncementError(error));
      }
    }
  }

  Future<void> _onSurplusOpenRequested(
    AnnouncementSurplusOpenRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Anti double-soumission : même garde que la création/màj (le bouton se
    // désactive à la frame suivante seulement).
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.openSurplus(
        announcementId: event.announcementId,
        surplusKg: event.surplusKg,
        pricePerKg: event.pricePerKg,
      );
      emit(AnnouncementSurplusOpened(announcement));
      // PII : aucun id utilisateur, aucune ville exacte — uniquement les
      // valeurs métier de l'ouverture.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.surplusOpened,
          properties: {
            'surplus_kg': event.surplusKg,
            'price_per_kg': event.pricePerKg,
          },
        ),
      );
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }

  Future<void> _onUpdateRequested(
    AnnouncementUpdateRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    // Anti double-soumission (cf. _onCreateRequested) : même bouton, même risque.
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.updateAnnouncement(
        id: event.id,
        departureCity: event.departureCity,
        arrivalCity: event.arrivalCity,
        departureCountryCode: event.departureCountryCode,
        arrivalCountryCode: event.arrivalCountryCode,
        departureDate: event.departureDate,
        departureTime: event.departureTime,
        arrivalTime: event.arrivalTime,
        arrivalDate: event.arrivalDate,
        pickupAddress: event.pickupAddress,
        deliveryAddress: event.deliveryAddress,
        availableKg: event.availableKg,
        pricePerKg: event.pricePerKg,
        transportMode: event.transportMode,
        description: event.description,
        acceptedContentTypes: event.acceptedContentTypes,
        refusedTypes: event.refusedTypes,
        acceptedPaymentMethods: event.acceptedPaymentMethods,
        capacityUnit: event.capacityUnit,
        pricingMode: event.pricingMode,
        handoverDeadline: event.handoverDeadline,
        negotiable: event.negotiable,
      );
      emit(AnnouncementUpdated(announcement));
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        emit(
          AnnouncementError(
            const ConflictException(
              // Message technique jamais affiché : ErrorCatalog.lookup résout
              // l'affichage sur le code announcement-update-blocked.
              'Modification impossible : des colis sont déjà acceptés pour ce trajet', // i18n-ignore
              code: 'announcement-update-blocked',
            ),
          ),
        );
      } else {
        emit(AnnouncementError(unwrapDioError(e)));
      }
    }
  }

  Future<void> _onTripMarkArrivedRequested(
    AnnouncementTripMarkArrivedRequested event,
    Emitter<AnnouncementState> emit,
  ) => _runArrivalAction(
    emit,
    action: () => _repository.markTripArrived(
      announcementId: event.announcementId,
      arrivalInstructions: event.arrivalInstructions,
    ),
    onSuccess: (announcement) {
      _tripArrivalEvents?.notifyArrived(event.announcementId);
      return AnnouncementTripArrived(announcement);
    },
    analyticsEvent: AnalyticsEvents.tripMarkedArrived,
  );

  Future<void> _onArrivalInstructionsUpdateRequested(
    AnnouncementArrivalInstructionsUpdateRequested event,
    Emitter<AnnouncementState> emit,
  ) => _runArrivalAction(
    emit,
    action: () => _repository.updateArrivalInstructions(
      announcementId: event.announcementId,
      arrivalInstructions: event.arrivalInstructions,
    ),
    onSuccess: AnnouncementArrivalInstructionsUpdated.new,
    analyticsEvent: AnalyticsEvents.arrivalInstructionsUpdated,
  );

  Future<void> _runArrivalAction(
    Emitter<AnnouncementState> emit, {
    required Future<AnnouncementModel> Function() action,
    required AnnouncementState Function(AnnouncementModel) onSuccess,
    required String analyticsEvent,
  }) async {
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final announcement = await action();
      emit(onSuccess(announcement));
      unawaited(_analytics.logEvent(analyticsEvent));
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }

  Future<void> _onRescheduleRequested(
    AnnouncementRescheduleRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state is AnnouncementLoading) return;
    emit(AnnouncementLoading());
    try {
      final result = await _repository.rescheduleTrip(
        announcementId: event.announcementId,
        departureDate: event.departureDate,
        departureTime: event.departureTime,
        arrivalDate: event.arrivalDate,
        arrivalTime: event.arrivalTime,
        handoverDeadline: event.handoverDeadline,
        reason: event.reason,
        note: event.note,
      );
      final announcement = await _repository.getAnnouncementDetail(
        event.announcementId,
      );
      emit(AnnouncementRescheduled(announcement, result));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripRescheduled,
          properties: {'reason': event.reason.wire},
        ),
      );
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }
}

/// Corps des étapes d'un voyage (FLUTTER-4D), dans l'ordre du voyage.
///
/// Chaque étape ajoutée part de la ville et de l'adresse d'arrivée de la
/// précédente, et reprend du premier trajet ce qu'elle ne redéfinit pas. Sa
/// date limite de dépôt garde le même délai avant le départ que celle du
/// premier trajet.
@visibleForTesting
List<AnnouncementPayload> buildTripPayloads(
  AnnouncementCreateRequested first,
  List<TripLegDraft> legs,
) {
  final firstDeparture = _departureAt(first.departureDate, first.departureTime);
  var lead = firstDeparture.difference(first.handoverDeadline);
  if (lead.isNegative) lead = Duration.zero;

  final payloads = <AnnouncementPayload>[
    AnnouncementPayload(
      departureCity: first.departureCity,
      arrivalCity: first.arrivalCity,
      departureCountryCode: first.departureCountryCode,
      arrivalCountryCode: first.arrivalCountryCode,
      departureDate: first.departureDate,
      departureTime: first.departureTime,
      arrivalTime: first.arrivalTime,
      arrivalDate: first.arrivalDate,
      pickupAddress: first.pickupAddress,
      deliveryAddress: first.deliveryAddress,
      availableKg: first.availableKg,
      pricePerKg: first.pricePerKg,
      transportMode: first.transportMode,
      description: first.description,
      acceptedContentTypes: first.acceptedContentTypes,
      refusedTypes: first.refusedTypes,
      acceptedPaymentMethods: first.acceptedPaymentMethods,
      capacityUnit: first.capacityUnit,
      pricingMode: first.pricingMode,
      handoverDeadline: first.handoverDeadline,
      negotiable: first.negotiable,
      saveAsDraft: first.saveAsDraft,
      currency: first.currency,
    ),
  ];
  var fromCity = first.arrivalCity;
  var fromCountry = first.arrivalCountryCode;
  var fromAddress = first.deliveryAddress;
  for (final leg in legs) {
    payloads.add(
      AnnouncementPayload(
        departureCity: fromCity,
        arrivalCity: leg.arrivalCity,
        departureCountryCode: fromCountry,
        arrivalCountryCode: leg.arrivalCountryCode,
        departureDate: leg.departureDate,
        departureTime: leg.departureTime,
        pickupAddress: fromAddress,
        deliveryAddress: leg.deliveryAddress,
        availableKg: leg.availableKg,
        // Grille seule (MIXED) : l'étape garde le prix au kilo du premier trajet.
        pricePerKg: leg.pricePerKg ?? first.pricePerKg,
        transportMode: first.transportMode,
        description: first.description,
        acceptedContentTypes: first.acceptedContentTypes,
        refusedTypes: first.refusedTypes,
        acceptedPaymentMethods: first.acceptedPaymentMethods,
        capacityUnit: first.capacityUnit,
        pricingMode: first.pricingMode,
        handoverDeadline: leg.departureAt.subtract(lead),
        negotiable: first.negotiable,
        saveAsDraft: first.saveAsDraft,
        currency: first.currency,
      ),
    );
    fromCity = leg.arrivalCity;
    fromCountry = leg.arrivalCountryCode;
    fromAddress = leg.deliveryAddress;
  }
  return payloads;
}

DateTime _departureAt(DateTime date, String? time) {
  final parts = (time ?? '00:00').split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts[0]) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}
