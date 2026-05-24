part of 'diagnostics_bloc.dart';

abstract class DiagnosticsEvent extends Equatable {
  const DiagnosticsEvent();
  @override
  List<Object?> get props => [];
}

class DiagnosticsLoadRequested extends DiagnosticsEvent {
  const DiagnosticsLoadRequested();
}

class ApiPingRequested extends DiagnosticsEvent {
  const ApiPingRequested();
}
