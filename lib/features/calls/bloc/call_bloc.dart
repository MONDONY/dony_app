import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/repositories/calls_repository.dart';
import 'package:dony/features/calls/data/ringback_tone.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Un appel audio, sortant (créé par le back puis rejoint) ou entrant
/// (décroché). Fermer le bloc pendant l'appel raccroche.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc(
    this._repository,
    this._gateway,
    this._analytics, {
    RingbackTone? ringback,
    this.ringTimeout = const Duration(seconds: 60),
  }) : _ringback = ringback,
       super(const CallIdle()) {
    on<CallStartRequested>(_onStart);
    on<CallIncomingAcceptRequested>(_onIncomingAccept);
    on<CallMuteToggleRequested>(_onMuteToggle);
    on<CallSpeakerToggleRequested>(_onSpeakerToggle);
    on<CallHangUpRequested>(_onHangUp);
    on<_CallSnapshotReceived>(_onSnapshot);
    on<_CallRingTimedOut>(_onRingTimedOut);
    _snapshots = _gateway.activeCall.listen(
      (s) => add(_CallSnapshotReceived(s)),
    );
  }

  final CallsRepository _repository;
  final CallGateway _gateway;
  final AnalyticsService _analytics;

  /// Tonalité de retour d'appel chez l'appelant (FLUTTER-9V), `null` en test.
  final RingbackTone? _ringback;
  late final StreamSubscription<ActiveCallSnapshot> _snapshots;

  /// Durée maximale de sonnerie d'un appel sortant. Le minuteur de Stream
  /// ne démarre qu'une fois l'appel rejoint : si la connexion traîne, rien
  /// ne bornait la sonnerie et l'écran restait sur « Ça sonne… ».
  final Duration ringTimeout;
  Timer? _ringGuard;

  /// Bascule de sortie audio en cours : les snapshots reçus entre-temps
  /// décrivent encore l'ancienne route et ne doivent pas remettre le bouton.
  bool _switchingSpeaker = false;

  /// La tonalité suit l'état : elle joue tant qu'un appel sortant sonne
  /// chez l'autre, et se tait à tout autre état (décroché, refus, sans
  /// réponse, raccroché, échec).
  @override
  void onChange(Change<CallState> change) {
    super.onChange(change);
    final ringback = _ringback;
    if (ringback == null) return;
    final next = change.nextState;
    final ringing = next is CallInProgress && next.phase == CallPhase.ringing;
    unawaited(ringing ? ringback.start() : ringback.stop());
  }

  bool get _live => state is CallStarting || state is CallInProgress;

  /// Appel en cours (création, sonnerie, connexion ou conversation) : la
  /// barre d'appel et l'écran réduit s'appuient dessus.
  bool get isLive => _live;

  /// Toujours en sonnerie après [ringTimeout] : sans réponse, on raccroche.
  void _armRingGuard() {
    _ringGuard?.cancel();
    _ringGuard = Timer(ringTimeout, () {
      final current = state;
      if (isClosed ||
          current is! CallInProgress ||
          current.phase == CallPhase.connected) {
        return;
      }
      add(const _CallRingTimedOut());
    });
  }

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
      // Écran fermé, ou raccroché, pendant la création : l'autre sonne déjà,
      // personne ne rejoindra l'appel de ce côté. Sans le second test, la
      // sonnerie réapparaissait après « Appel terminé ».
      if (isClosed || state is! CallStarting) {
        await _gateway.cancelOutgoing(call.callId);
        return;
      }
      unawaited(_analytics.logEvent(AnalyticsEvents.callStarted));
      emit(
        CallInProgress(phase: CallPhase.ringing, remoteName: event.remoteName),
      );
      _armRingGuard();
      joining = true;
      await _gateway.joinOutgoing(call.callId);
      // Raccroché pendant la connexion : l'appel rejoint après coup gardait
      // le micro ouvert, plus personne ne le quittait.
      if (isClosed || state is! CallInProgress) {
        await _gateway.hangUp();
        return;
      }
      // Rejoindre l'appel reconfigure la session audio (Stream/WebRTC), ce
      // qui peut couper la tonalité de retour déjà lancée : on la relance tant
      // que ça sonne encore (FLUTTER-9V).
      final ringback = _ringback;
      final current = state;
      if (ringback != null &&
          current is CallInProgress &&
          current.phase == CallPhase.ringing) {
        await ringback.stop();
        if (!isClosed && state == current) await ringback.start();
      }
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
    // Choix affiché tout de suite : pendant la sonnerie, Stream refuse de
    // changer de sortie (« Call not connected », Sentry FLUTTER-A5/A6) ; le
    // choix est alors appliqué au décroché (_applySpeakerOnConnect).
    emit(current.copyWith(speakerOn: on));
    if (current.phase != CallPhase.connected) return;
    _switchingSpeaker = true;
    try {
      await _gateway.setSpeakerOn(on);
    } catch (_) {
      // Sortie audio inchangée : le bouton revient à l'état réel.
      final latest = state;
      if (latest is CallInProgress) emit(latest.copyWith(speakerOn: !on));
    } finally {
      _switchingSpeaker = false;
    }
  }

  /// Haut-parleur choisi pendant la sonnerie : appliqué dès que l'autre
  /// décroche. Un échec laisse la sortie par défaut, et le bouton le dit.
  Future<void> _applySpeakerOnConnect(Emitter<CallState> emit) async {
    _switchingSpeaker = true;
    try {
      await _gateway.setSpeakerOn(true);
    } catch (_) {
      final latest = state;
      if (latest is CallInProgress) emit(latest.copyWith(speakerOn: false));
    } finally {
      _switchingSpeaker = false;
    }
  }

  /// État du bouton haut-parleur au snapshot connecté [snapshot] (FLUTTER-E1) :
  /// il suit la sortie réelle, sauf pendant une bascule demandée (la route
  /// observée est alors encore l'ancienne) ou quand le SDK ne la connaît pas.
  bool _speakerFor(CallInProgress current, ActiveCallSnapshot snapshot) {
    final output = snapshot.audioOutput;
    if (_switchingSpeaker || output == null) return current.speakerOn;
    return output.speaker;
  }

  Future<void> _onRingTimedOut(
    _CallRingTimedOut event,
    Emitter<CallState> emit,
  ) async {
    final current = state;
    if (current is! CallInProgress || current.phase == CallPhase.connected) {
      return;
    }
    await _gateway.hangUp();
    if (state is! CallInProgress) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.callEnded,
        properties: {'reason': 'missed'},
      ),
    );
    emit(const CallEnded(reason: 'missed'));
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

  Future<void> _onSnapshot(
    _CallSnapshotReceived event,
    Emitter<CallState> emit,
  ) async {
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
        final justConnected = current.phase != CallPhase.connected;
        if (justConnected) {
          unawaited(_analytics.logEvent(AnalyticsEvents.callConnected));
        }
        final output = snapshot.audioOutput;
        // Haut-parleur choisi pendant la sonnerie : appliqué au décroché, sauf
        // si un casque (filaire, Bluetooth, voiture) est la sortie courante —
        // le son doit rester dans le casque (FLUTTER-E1).
        final ringingChoice = justConnected && current.speakerOn;
        final skipRingingChoice = ringingChoice && (output?.external ?? false);
        emit(
          current.copyWith(
            phase: CallPhase.connected,
            connectedAt: snapshot.connectedAt,
            remoteName: snapshot.remoteName,
            speakerOn: ringingChoice
                ? !skipRingingChoice
                : _speakerFor(current, snapshot),
          ),
        );
        if (skipRingingChoice) {
          AppLog.info(
            'calls: ringing speaker choice skipped',
            data: {'output': output!.type},
          );
        } else if (ringingChoice) {
          await _applySpeakerOnConnect(emit);
        }
      case CallPhase.ringing:
      case CallPhase.connecting:
        emit(current.copyWith(phase: snapshot.phase));
    }
  }

  @override
  Future<void> close() async {
    _ringGuard?.cancel();
    await _snapshots.cancel();
    await _ringback?.dispose();
    if (_live) await _gateway.hangUp();
    return super.close();
  }
}
