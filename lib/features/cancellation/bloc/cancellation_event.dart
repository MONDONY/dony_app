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

class TravelerNoShowReportRequested extends CancellationEvent {
  final String bidId;
  TravelerNoShowReportRequested(this.bidId);
}

class NoShowContestRequested extends CancellationEvent {
  final String bidId;
  NoShowContestRequested(this.bidId);
}

/// L'expéditeur confirme son absence signalée par le voyageur (le bid sera
/// annulé, pas de débit).
class NoShowConfirmRequested extends CancellationEvent {
  final String bidId;
  NoShowConfirmRequested(this.bidId);
}

/// Annulation après remise du colis (HANDED_OVER). `actor` = 'sender' | 'traveler'
/// (analytics uniquement, le backend déduit le rôle réel).
class CancelAfterHandoverRequested extends CancellationEvent {
  final String bidId;
  final String actor;
  CancelAfterHandoverRequested(this.bidId, {required this.actor});
}

/// Le voyageur saisit le code de retour détenu par l'expéditeur (D7).
class ReturnConfirmRequested extends CancellationEvent {
  final String bidId;
  final String code;
  ReturnConfirmRequested(this.bidId, this.code);
}

/// L'expéditeur consulte son code de retour + l'état de la restitution (D7).
class ReturnCodeRequested extends CancellationEvent {
  final String bidId;
  ReturnCodeRequested(this.bidId);
}
