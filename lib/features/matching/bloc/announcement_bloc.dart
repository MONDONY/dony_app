import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'announcement_event.dart';
import 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;

  AnnouncementBloc(this._repository) : super(AnnouncementInitial()) {
    on<AnnouncementCreateRequested>(_onCreateRequested);
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
        availableKg: event.availableKg,
        pricePerKg: event.pricePerKg,
      );
      emit(AnnouncementCreated(announcement));
    } catch (e) {
      emit(AnnouncementError(e.toString()));
    }
  }
}
