abstract class PastBookingsEvent {
  const PastBookingsEvent();
}

class LoadPastBookings extends PastBookingsEvent {
  const LoadPastBookings();
}

class RebookTraveler extends PastBookingsEvent {
  final String pastBidId;
  const RebookTraveler(this.pastBidId);
}

class SubscribeToTraveler extends PastBookingsEvent {
  final String travelerId;
  const SubscribeToTraveler(this.travelerId);
}
