sealed class TripTemplateEvent {
  const TripTemplateEvent();
}

final class TripTemplateLoaded extends TripTemplateEvent {
  const TripTemplateLoaded();
}

final class TripTemplateCreated extends TripTemplateEvent {
  const TripTemplateCreated(this.data);
  final Map<String, dynamic> data;
}

final class TripTemplateUpdated extends TripTemplateEvent {
  const TripTemplateUpdated(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

final class TripTemplateDeleted extends TripTemplateEvent {
  const TripTemplateDeleted(this.id);
  final String id;
}
