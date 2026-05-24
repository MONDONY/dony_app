part of 'data_export_bloc.dart';

sealed class DataExportState extends Equatable {
  const DataExportState();
  @override
  List<Object?> get props => [];
}

class DataExportInitial extends DataExportState {
  const DataExportInitial();
}

class DataExportLoading extends DataExportState {
  const DataExportLoading();
}

class DataExportSuccess extends DataExportState {
  const DataExportSuccess();
}

class DataExportError extends DataExportState {
  final String message;
  const DataExportError(this.message);
  @override
  List<Object?> get props => [message];
}
