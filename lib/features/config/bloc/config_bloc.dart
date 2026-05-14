import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'config_event.dart';
part 'config_state.dart';

class ConfigBloc extends Bloc<ConfigEvent, ConfigState> {
  final IConfigRepository _repository;

  ConfigBloc(this._repository) : super(const ConfigInitial()) {
    on<ConfigCommissionRateRequested>(_onCommissionRateRequested);
  }

  Future<void> _onCommissionRateRequested(
    ConfigCommissionRateRequested event,
    Emitter<ConfigState> emit,
  ) async {
    emit(const ConfigLoading());
    try {
      final rate = await _repository.getCommissionRate();
      emit(ConfigLoaded(rate));
    } catch (e) {
      emit(ConfigError(unwrapDioError(e)));
    }
  }
}
