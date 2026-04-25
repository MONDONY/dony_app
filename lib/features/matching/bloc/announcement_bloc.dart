import 'package:dio/dio.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;

  AnnouncementBloc(this._repository) : super(AnnouncementInitial()) {
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
        departureLocation: event.departureLocation,
        arrivalLocation: event.arrivalLocation,
        availableKg: event.availableKg,
        pricePerKg: event.pricePerKg,
      );
      emit(AnnouncementCreated(announcement));
    } catch (e) {
      emit(AnnouncementError(e.toString()));
    }
  }

  Future<void> _onListRequested(
    AnnouncementListRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final announcements = await _repository.getMyAnnouncements();
      emit(AnnouncementListLoaded(announcements));
    } catch (e) {
      emit(AnnouncementError(e.toString()));
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
      emit(AnnouncementError(e.toString()));
    }
  }

  Future<void> _onSearchRequested(
    AnnouncementSearchRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(AnnouncementLoading());
    try {
      final results = await _repository.searchAnnouncements(
        departureCity: event.departureCity,
        arrivalCity: event.arrivalCity,
        departureDateFrom: event.departureDateFrom,
        departureDateTo: event.departureDateTo,
        minAvailableKg: event.minAvailableKg,
        sortBy: event.sortBy,
        sortDir: event.sortDir,
      );
      emit(AnnouncementSearchLoaded(results));
    } catch (e, stacktrace) {
      print('=== SEARCH ERROR ===');
      print(e);
      print(stacktrace);
      emit(AnnouncementError(e.toString()));
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
      emit(AnnouncementError(e.toString()));
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
        departureLocation: event.departureLocation,
        arrivalLocation: event.arrivalLocation,
        availableKg: event.availableKg,
        pricePerKg: event.pricePerKg,
      );
      emit(AnnouncementUpdated(announcement));
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        emit(AnnouncementError(
          'Modification impossible : des colis sont déjà acceptés pour ce trajet',
        ));
      } else {
        emit(AnnouncementError(e.toString()));
      }
    }
  }
}
