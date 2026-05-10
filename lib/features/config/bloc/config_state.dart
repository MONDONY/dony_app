part of 'config_bloc.dart';

sealed class ConfigState {
  const ConfigState();
}

class ConfigInitial extends ConfigState {
  const ConfigInitial();
}

class ConfigLoading extends ConfigState {
  const ConfigLoading();
}

class ConfigLoaded extends ConfigState {
  final double commissionRate;
  const ConfigLoaded(this.commissionRate);
}

class ConfigError extends ConfigState {
  final AppException error;
  const ConfigError(this.error);
}
