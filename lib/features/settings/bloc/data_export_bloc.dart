import 'package:dony/core/network/api_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'data_export_event.dart';
part 'data_export_state.dart';

class DataExportBloc extends Bloc<DataExportEvent, DataExportState> {
  final ApiClient _api;

  DataExportBloc(this._api) : super(const DataExportInitial()) {
    on<DataExportRequested>(_onExportRequested);
  }

  Future<void> _onExportRequested(
    DataExportRequested event,
    Emitter<DataExportState> emit,
  ) async {
    emit(const DataExportLoading());
    try {
      await _api.dio.get('/users/me/export');
      emit(const DataExportSuccess());
    } catch (_) {
      emit(const DataExportError('Impossible de lancer l\'export. Réessaie.'));
    }
  }
}
