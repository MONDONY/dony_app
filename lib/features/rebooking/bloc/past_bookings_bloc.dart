import 'package:dony/features/rebooking/bloc/past_bookings_event.dart';
import 'package:dony/features/rebooking/bloc/past_bookings_state.dart';
import 'package:dony/features/rebooking/data/rebooking_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PastBookingsBloc extends Bloc<PastBookingsEvent, PastBookingsState> {
  final RebookingRepository _repository;

  PastBookingsBloc(this._repository) : super(const PastBookingsInitial()) {
    on<LoadPastBookings>(_onLoad);
    on<RebookTraveler>(_onRebook);
    on<SubscribeToTraveler>(_onSubscribe);
  }

  List<PastBookingItem> get _currentBookings {
    final s = state;
    return s is PastBookingsLoaded ? s.bookings : const [];
  }

  Future<void> _onLoad(
    LoadPastBookings event,
    Emitter<PastBookingsState> emit,
  ) async {
    emit(const PastBookingsLoading());
    try {
      final bookings = await _repository.getPastBookings();
      emit(PastBookingsLoaded(bookings: bookings));
    } catch (e) {
      emit(PastBookingsError(e.toString()));
    }
  }

  Future<void> _onRebook(
    RebookTraveler event,
    Emitter<PastBookingsState> emit,
  ) async {
    final bookings = _currentBookings;
    emit(const RebookingInProgress());
    try {
      final result = await _repository.rebook(event.pastBidId);
      if (result.status == 'NO_UPCOMING_TRIP' || result.newBidId == null) {
        final travelerId = bookings
            .firstWhere(
              (b) => b.bidId == event.pastBidId,
              orElse: () => bookings.first,
            )
            .travelerId;
        emit(NoTripAvailable(travelerId));
      } else {
        emit(RebookSuccess(result.newBidId!));
      }
    } catch (e) {
      emit(PastBookingsError(e.toString()));
    }
  }

  Future<void> _onSubscribe(
    SubscribeToTraveler event,
    Emitter<PastBookingsState> emit,
  ) async {
    try {
      await _repository.subscribeToTraveler(event.travelerId);
      emit(const TravelerSubscribed());
    } catch (e) {
      emit(PastBookingsError(e.toString()));
    }
  }
}
