abstract class CancellationEvent {}

class CancellationTripRequested extends CancellationEvent {
  final String announcementId;
  final String reason;

  CancellationTripRequested({required this.announcementId, required this.reason});
}

class RematchSuggestionsRequested extends CancellationEvent {
  final String cancellationId;
  RematchSuggestionsRequested(this.cancellationId);
}

class NoShowReportRequested extends CancellationEvent {
  final String bidId;
  NoShowReportRequested(this.bidId);
}

class NoShowContestRequested extends CancellationEvent {
  final String bidId;
  NoShowContestRequested(this.bidId);
}
