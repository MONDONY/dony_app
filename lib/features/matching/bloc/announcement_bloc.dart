import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;
  final HiveService _hive;
  final AnalyticsService _analytics;

  AnnouncementBloc(this._repository, this._hive, this._analytics)
    : super(AnnouncementInitial()) {
    on<AnnouncementCreateRequested>(_onCreateRequested);
    on<AnnouncementPublishRequested>(_onPublishRequested);
    on<AnnouncementUnpublishRequested>(_onUnpublishRequested);
    on<AnnouncementListRequested>(_onListRequested);
    on<AnnouncementDetailRequested>(_onDetailRequested);
    on<AnnouncementUpdateRequested>(_onUpdateRequested);
    on<AnnouncementDeleteRequested>(_onDeleteRequested);
    on<AnnouncementSearchRequested>(_onSearchRequested);
    on<AnnouncementSurplusOpenRequested>(_onSurplusOpenRequested);
    on<AnnouncementTripMarkArrivedRequested>(_onTripMarkArrivedRequested);
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
      );
      // Un brouillon n'est pas une publication : le flag "premier pas voyageur"
      // ne doit être posé que lorsque le trajet est réellement actif/visible.
      if (!event.saveAsDraft) {
        await _hive.userPrefs.put(HiveService.kHasPublishedAsTraveler, true);
      }
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
        emit(AnnouncementDraftLimitReached(error.message));
      } else if (error is ForbiddenException &&
          error.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(error.message));
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
      await _hive.userPrefs.put(HiveService.kHasPublishedAsTraveler, true);
      emit(AnnouncementPublished(announcement));
    } catch (e) {
      final error = unwrapDioError(e);
      if (error is ForbiddenException && error.code == 'kyc-not-verified') {
        emit(AnnouncementKycRequired(error.message));
      } else if (error is ForbiddenException &&
          error.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(error.message));
      } else if (error.code == 'departure-date-passed') {
        emit(AnnouncementDepartureDatePassed(error.message));
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
      final results = await _repository.searchAnnouncements(
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
      );
      emit(AnnouncementSearchLoaded(results));
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

  Future<void> _onDeleteRequested(
    AnnouncementDeleteRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      await _repository.deleteAnnouncement(event.id);
      emit(AnnouncementDeleted());
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        emit(AnnouncementDeleteBlockedByAcceptedBid(event.id));
      } else {
        emit(AnnouncementError(unwrapDioError(e)));
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
              'Modification impossible : des colis sont déjà acceptés pour ce trajet',
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
    onSuccess: AnnouncementTripArrived.new,
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
}
