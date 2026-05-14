import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;
  final HiveService _hive;

  AnnouncementBloc(this._repository, this._hive) : super(AnnouncementInitial()) {
    on<AnnouncementCreateRequested>(_onCreateRequested);
    on<AnnouncementListRequested>(_onListRequested);
    on<AnnouncementDetailRequested>(_onDetailRequested);
    on<AnnouncementUpdateRequested>(_onUpdateRequested);
    on<AnnouncementDeleteRequested>(_onDeleteRequested);
    on<AnnouncementSearchRequested>(_onSearchRequested);
  }

  Future<void> _onCreateRequested(
    AnnouncementCreateRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.createAnnouncement(
        departureCity: event.departureCity,
        arrivalCity: event.arrivalCity,
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
      );
      await _hive.userPrefs
          .put(HiveService.kHasPublishedAsTraveler, true);
      emit(AnnouncementCreated(announcement));
    } on ForbiddenException catch (e) {
      if (e.code == 'pro-limit-reached') {
        emit(AnnouncementProLimitReached(e.message));
      } else {
        emit(AnnouncementError(e));
      }
    } catch (e) {
      emit(AnnouncementError(unwrapDioError(e)));
    }
  }

  Future<void> _onListRequested(
    AnnouncementListRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final result = await _repository.getMyAnnouncements();
      emit(AnnouncementListLoaded(
        result.announcements,
        totalElements: result.totalElements,
      ));
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
      );
      emit(AnnouncementSearchLoaded(results));
    } catch (e, stacktrace) {
      if (kDebugMode) debugPrint('=== SEARCH ERROR ===');
      if (kDebugMode) debugPrint(e.toString());
      if (kDebugMode) debugPrint(stacktrace.toString());
      emit(AnnouncementError(
        unwrapDioError(e),
        previousResults: current is AnnouncementSearchLoaded ? current.results : null,
      ));
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

  Future<void> _onUpdateRequested(
    AnnouncementUpdateRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final announcement = await _repository.updateAnnouncement(
        id: event.id,
        departureCity: event.departureCity,
        arrivalCity: event.arrivalCity,
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
      );
      emit(AnnouncementUpdated(announcement));
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        emit(AnnouncementError(
          const ConflictException(
            'Modification impossible : des colis sont déjà acceptés pour ce trajet',
            code: 'announcement-update-blocked',
          ),
        ));
      } else {
        emit(AnnouncementError(unwrapDioError(e)));
      }
    }
  }
}
