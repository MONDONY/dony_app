import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';

enum TripRecurrenceStatus { initial, loading, success, error }

class TripRecurrenceState {
  const TripRecurrenceState({
    this.status = TripRecurrenceStatus.initial,
    this.recurrences = const [],
    this.error,
  });

  final TripRecurrenceStatus status;
  final List<TripRecurrence> recurrences;
  final String? error;

  TripRecurrenceState copyWith({
    TripRecurrenceStatus? status,
    List<TripRecurrence>? recurrences,
    String? error,
  }) =>
      TripRecurrenceState(
        status: status ?? this.status,
        recurrences: recurrences ?? this.recurrences,
        error: error,
      );
}
