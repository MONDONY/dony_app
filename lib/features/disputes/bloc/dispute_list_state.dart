import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

sealed class DisputeListState {
  const DisputeListState();
}

class DisputeListInitial extends DisputeListState {
  const DisputeListInitial();
}

class DisputeListLoading extends DisputeListState {
  const DisputeListLoading();
}

class DisputeListLoaded extends DisputeListState {
  final List<DisputeModel> disputes;
  const DisputeListLoaded(this.disputes);
}

class DisputeListError extends DisputeListState {
  final AppException error;
  const DisputeListError(this.error);
}
