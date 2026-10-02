part of 'call_bloc.dart';

abstract class CallEvent {
  const CallEvent();
}

/// Appel Yadony vers l'autre partie de la conversation [conversationId].
class CallStartRequested extends CallEvent {
  const CallStartRequested(this.conversationId, this.remoteName);

  final String conversationId;
  final String remoteName;
}

/// Décrocher l'appel entrant [callId] ; [acceptedNatively] s'il a déjà été
/// décroché depuis CallKit ou la notification Android.
class CallIncomingAcceptRequested extends CallEvent {
  const CallIncomingAcceptRequested(
    this.callId,
    this.remoteName, {
    this.acceptedNatively = false,
  });

  final String callId;
  final String remoteName;
  final bool acceptedNatively;
}

class CallMuteToggleRequested extends CallEvent {
  const CallMuteToggleRequested();
}

class CallSpeakerToggleRequested extends CallEvent {
  const CallSpeakerToggleRequested();
}

class CallHangUpRequested extends CallEvent {
  const CallHangUpRequested();
}

class _CallSnapshotReceived extends CallEvent {
  const _CallSnapshotReceived(this.snapshot);

  final ActiveCallSnapshot snapshot;
}
