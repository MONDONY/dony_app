import 'package:dony/core/network/api_client.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'diagnostics_event.dart';
part 'diagnostics_state.dart';

class DiagnosticsBloc extends Bloc<DiagnosticsEvent, DiagnosticsState> {
  final ApiClient _api;

  DiagnosticsBloc(this._api) : super(const DiagnosticsState()) {
    on<DiagnosticsLoadRequested>(_onLoadRequested);
    on<ApiPingRequested>(_onApiPing);
  }

  Future<void> _onLoadRequested(
    DiagnosticsLoadRequested e,
    Emitter<DiagnosticsState> emit,
  ) async {
    final info = await PackageInfo.fromPlatform();
    emit(
      state.copyWith(appVersion: info.version, buildNumber: info.buildNumber),
    );
  }

  Future<void> _onApiPing(
    ApiPingRequested e,
    Emitter<DiagnosticsState> emit,
  ) async {
    emit(state.copyWith(isPinging: true));
    try {
      await _api.dio.get('/actuator/health');
      emit(state.copyWith(isPinging: false, apiOk: true));
    } catch (_) {
      emit(state.copyWith(isPinging: false, apiOk: false));
    }
  }
}
