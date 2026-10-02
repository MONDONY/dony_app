import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Un appel audio, sortant (créé par le back puis rejoint) ou entrant
/// (décroché). Fermer le bloc pendant l'appel raccroche.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc(this._repository, this._gateway, this._analytics)
    : super(const CallIdle()) {
    on<CallStartRequested>(_onStart);
    on<CallIncomingAcceptRequested>(_onIncomingAccept);
    on<CallMuteToggleRequested>(_onMuteToggle);
    on<CallSpeakerToggleRequested>(_onSpeakerToggle);
    on<CallHangUpRequested>(_onHangUp);
    on<_CallSnapshotReceived>(_onSnapshot);
    _snapshots = _gateway.activeCall.listen(
      (s) => add(_CallSnapshotReceived(s)),
    );
  }

  final CallsRepository _repository;
  final CallGateway _gateway;
  final AnalyticsService _analytics;
  late final StreamSubscription<ActiveCallSnapshot> _snapshots;

  bool get _live => state is CallStarting || state is CallInProgress;

  Future<void> _onStart(
    CallStartRequested event,
    Emitter<CallState> emit,
  ) async {
    if (_live) return;
    emit(const CallStarting());
    if (!await _gateway.ensureMicrophone()) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.callFailed,
          properties: {'code': 'microphone-denied'},
        ),
      );
      emit(const CallFailure(CallPermissionDeniedException()));
      return;
    }
    if (isClosed) return;
    var joining = false;
    try {
      final call = await _repository.startCall(event.conversationId);
      // Écran fermé pendant la création : l'autre sonne déjà, personne ne
      // rejoindra l'appel de ce côté.
      if (isClosed) {
        await _gateway.cancelOutgoing(call.callId);
        return;
      }
      unawaited(_analytics.logEvent(AnalyticsEvents.callStarted));
      emit(
        CallInProgress(phase: CallPhase.ringing, remoteName: event.remoteName),
      );
      joining = true;
      await _gateway.joinOutgoing(call.callId);
      if (isClosed) await _gateway.hangUp();
    } catch (e) {
      if (joining) await _gateway.hangUp();
      final error = unwrapDioError(e);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.callFailed,
          properties: {'code': error.code ?? 'unknown'},
        ),
      );
      emit(CallFailure(error));
    }
  }

  Future<void> _onIncomingAccept(
    CallIncomingAcceptRequested event,
    Emitter<CallState> emit,
  ) async {
    if (_live) return;
    if (!await _gateway.ensureMicrophone()) {
      await _gateway.rejectIncoming(event.callId);
      emit(const CallFailure(CallPermissionDeniedException()));
      return;
    }
    emit(
      CallInProgress(phase: CallPhase.connecting, remoteName: event.remoteName),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.callIncomingAccepted,
        properties: {'native': event.acceptedNatively},
      ),
    );
    // Même décroché depuis CallKit, il reste à rejoindre l'appel ;
    // l'adaptateur saute l'accept déjà fait.
    try {
      await _gateway.acceptIncoming(event.callId);
    } catch (e) {
      await _gateway.hangUp();
      emit(CallFailure(unwrapDioError(e)));
    }
  }

  Future<void> _onMuteToggle(
    CallMuteToggleRequested event,
    Emitter<CallState> emit,
  ) async {
    final current = state;
    if (current is! CallInProgress) return;
    final muted = !current.muted;
    await _gateway.setMicrophoneEnabled(!muted);
    emit(current.copyWith(muted: muted));
  }

  Future<void> _onSpeakerToggle(
    CallSpeakerToggleRequested event,
    Emitter<CallState> emit,
  ) async {
    final current = state;
    if (current is! CallInProgress) return;
    final on = !current.speakerOn;
    await _gateway.setSpeakerOn(on);
    emit(current.copyWith(speakerOn: on));
  }

  Future<void> _onHangUp(
    CallHangUpRequested event,
    Emitter<CallState> emit,
  ) async {
    if (!_live) return;
    await _gateway.hangUp();
    if (!_live) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.callEnded,
        properties: {'reason': 'hangup'},
      ),
    );
    emit(const CallEnded(reason: 'hangup'));
  }

  void _onSnapshot(_CallSnapshotReceived event, Emitter<CallState> emit) {
    final current = state;
    if (current is! CallInProgress) return;
    final snapshot = event.snapshot;
    switch (snapshot.phase) {
      case CallPhase.ended:
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.callEnded,
            properties: {'reason': snapshot.endReason ?? 'hangup'},
          ),
        );
        emit(CallEnded(reason: snapshot.endReason));
      case CallPhase.connected:
        if (current.phase != CallPhase.connected) {
          unawaited(_analytics.logEvent(AnalyticsEvents.callConnected));
        }
        emit(
          current.copyWith(
            phase: CallPhase.connected,
            connectedAt: snapshot.connectedAt,
            remoteName: snapshot.remoteName,
          ),
        );
      case CallPhase.ringing:
      case CallPhase.connecting:
        emit(current.copyWith(phase: snapshot.phase));
    }
  }

  @override
  Future<void> close() async {
    await _snapshots.cancel();
    if (_live) await _gateway.hangUp();
    return super.close();
  }
}
