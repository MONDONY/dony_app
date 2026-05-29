sealed class TripRecurrenceEvent {
  const TripRecurrenceEvent();
}

final class TripRecurrenceLoaded extends TripRecurrenceEvent {
  const TripRecurrenceLoaded();
}

final class TripRecurrenceCreated extends TripRecurrenceEvent {
  const TripRecurrenceCreated(this.data);
  final Map<String, dynamic> data;
}

final class TripRecurrenceUpdated extends TripRecurrenceEvent {
  const TripRecurrenceUpdated(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

final class TripRecurrenceDeleted extends TripRecurrenceEvent {
  const TripRecurrenceDeleted(this.id);
  final String id;
}
