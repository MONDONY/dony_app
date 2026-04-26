abstract class TrackingEvent {}

class TrackingQrCodeRequested extends TrackingEvent {
  final String bidId;
  TrackingQrCodeRequested(this.bidId);
}

class TrackingSearchRequested extends TrackingEvent {
  final String number;
  TrackingSearchRequested(this.number);
}
