part of 'call_bloc.dart';

abstract class CallState {
  const CallState();
}

class CallIdle extends CallState {
  const CallIdle();
}

/// Demande au back en cours (vérification des règles, création de l'appel).
class CallStarting extends CallState {
  const CallStarting();
}

class CallInProgress extends CallState {
  const CallInProgress({
    required this.phase,
    required this.remoteName,
    this.connectedAt,
    this.muted = false,
    this.speakerOn = false,
  });

  final CallPhase phase;
  final String remoteName;
  final DateTime? connectedAt;
  final bool muted;
  final bool speakerOn;

  CallInProgress copyWith({
    CallPhase? phase,
    String? remoteName,
    DateTime? connectedAt,
    bool? muted,
    bool? speakerOn,
  }) => CallInProgress(
    phase: phase ?? this.phase,
    remoteName: remoteName ?? this.remoteName,
    connectedAt: connectedAt ?? this.connectedAt,
    muted: muted ?? this.muted,
    speakerOn: speakerOn ?? this.speakerOn,
  );
}

/// [reason] : `hangup` | `rejected` | `missed` | `failed`.
class CallEnded extends CallState {
  const CallEnded({this.reason});

  final String? reason;
}

class CallFailure extends CallState {
  const CallFailure(this.error);

  final AppException error;
}
