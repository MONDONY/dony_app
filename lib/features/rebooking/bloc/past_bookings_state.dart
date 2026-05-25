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
  const RebookingInProgress();
}

class RebookSuccess extends PastBookingsState {
  final String newBidId;
  const RebookSuccess(this.newBidId);
}

class NoTripAvailable extends PastBookingsState {
  final String travelerId;
  const NoTripAvailable(this.travelerId);
}

class TravelerSubscribed extends PastBookingsState {
  const TravelerSubscribed();
}
