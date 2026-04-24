import 'package:dony/features/cancellation/data/models/cancellation_model.dart';

abstract class CancellationState {}

class CancellationInitial extends CancellationState {}

class CancellationLoading extends CancellationState {}

class CancellationSuccess extends CancellationState {
  final CancellationModel cancellation;
  CancellationSuccess(this.cancellation);
}

class RematchSuggestionsLoaded extends CancellationState {
  final List<RematchSuggestionModel> suggestions;
  RematchSuggestionsLoaded(this.suggestions);
}

class CancellationError extends CancellationState {
  final String message;
  CancellationError(this.message);
}
