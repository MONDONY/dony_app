part of 'diagnostics_bloc.dart';

class DiagnosticsState extends Equatable {
  final String? appVersion;
  final String? buildNumber;
  final bool isPinging;
  final bool? apiOk;

  const DiagnosticsState({
    this.appVersion,
    this.buildNumber,
    this.isPinging = false,
    this.apiOk,
  });

  DiagnosticsState copyWith({
    String? appVersion,
    String? buildNumber,
    bool? isPinging,
    bool? apiOk,
  }) => DiagnosticsState(
    appVersion: appVersion ?? this.appVersion,
    buildNumber: buildNumber ?? this.buildNumber,
    isPinging: isPinging ?? this.isPinging,
    apiOk: apiOk,
  );

  @override
  List<Object?> get props => [appVersion, buildNumber, isPinging, apiOk];
}
