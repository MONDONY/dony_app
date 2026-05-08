part of 'config_bloc.dart';

sealed class ConfigEvent {
  const ConfigEvent();
}

class ConfigCommissionRateRequested extends ConfigEvent {
  const ConfigCommissionRateRequested();
}
