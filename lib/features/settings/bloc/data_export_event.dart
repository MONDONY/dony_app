part of 'data_export_bloc.dart';

abstract class DataExportEvent extends Equatable {
  const DataExportEvent();
  @override
  List<Object?> get props => [];
}

class DataExportRequested extends DataExportEvent {
  const DataExportRequested();
}
