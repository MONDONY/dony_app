import 'package:dony/features/rebooking/data/rebooking_repository.dart';

abstract class PastBookingsState {
  const PastBookingsState();
}

class PastBookingsInitial extends PastBookingsState {
  const PastBookingsInitial();
}

class PastBookingsLoading extends PastBookingsState {
  const PastBookingsLoading();
}

class PastBookingsLoaded extends PastBookingsState {
  final List<PastBookingItem> bookings;
  const PastBookingsLoaded({required this.bookings});
}

class PastBookingsError extends PastBookingsState {
  final String message;
  const PastBookingsError(this.message);
}

class RebookingInProgress extends PastBookingsState {
  final List<PastBookingItem> bookings;
  const RebookingInProgress({required this.bookings});
}

class RebookSuccess extends PastBookingsState {
  final String newBidId;
  final List<PastBookingItem> bookings;
  const RebookSuccess({required this.newBidId, required this.bookings});
}

class NoTripAvailable extends PastBookingsState {
  final String travelerId;
  final List<PastBookingItem> bookings;
  const NoTripAvailable({required this.travelerId, required this.bookings});
}

class TravelerSubscribed extends PastBookingsState {
  final String travelerId;
  final List<PastBookingItem> bookings;
  const TravelerSubscribed({required this.travelerId, required this.bookings});
}
