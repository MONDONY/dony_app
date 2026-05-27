import 'package:dony/features/trip_templates/data/models/trip_template.dart';

enum TripTemplateStatus { initial, loading, success, error }

class TripTemplateState {
  const TripTemplateState({
    this.status = TripTemplateStatus.initial,
    this.templates = const [],
    this.error,
  });

  final TripTemplateStatus status;
  final List<TripTemplate> templates;
  final String? error;

  TripTemplateState copyWith({
    TripTemplateStatus? status,
    List<TripTemplate>? templates,
    String? error,
  }) =>
      TripTemplateState(
        status: status ?? this.status,
        templates: templates ?? this.templates,
        error: error,
      );
}
