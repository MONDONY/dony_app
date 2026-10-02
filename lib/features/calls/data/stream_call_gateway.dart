import 'dart:async';

import 'package:dony/core/config/stream_push_providers.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:rxdart/rxdart.dart' show CompositeSubscription;
import 'package:stream_video_flutter/stream_video_flutter.dart' hide CallUser;
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

/// Seul point de l'app qui parle au SDK Stream Video. Type d'appel `audio_call`
/// (vidéo coupée côté Stream) ; les appels sont créés par le back, l'app ne
/// fait que les rejoindre, les décrocher ou les refuser.
///
/// Non couvert par les tests unitaires (le SDK exige les plugins natifs WebRTC
/// et CallKit) : vérifié en recette sur appareil.
class StreamCallGateway implements CallGateway {
  static const _callType = 'audio_call';

  StreamVideo? _client;
  Call? _call;
  bool _outgoing = false;
  DateTime? _connectedAt;
  CompositeSubscription? _ringing;
  StreamSubscription<Call?>? _incomingSub;
  StreamSubscription<CallState>? _stateSub;
  final _active = StreamController<ActiveCallSnapshot>.broadcast();
  final _incoming = StreamController<IncomingCall>.broadcast();

  @override
  bool get isConnected => _client != null;

  @override
  Stream<ActiveCallSnapshot> get activeCall => _active.stream;

  @override
  Stream<IncomingCall> get incomingCalls => _incoming.stream;

  @override
  Future<void> connect({
    required String apiKey,
    required CallUser user,
    required Future<String> Function() tokenLoader,
  }) async {
    if (_client != null) {
      await disconnect();
    }
    final client = StreamVideo(
      apiKey,
      user: User.regular(
        userId: user.id,
        name: user.name,
        image: user.imageUrl,
      ),
      userToken: await tokenLoader(),
      tokenLoader: (_) => tokenLoader(),
      failIfSingletonExists: false,
      options: StreamVideoOptions(keepConnectionsAliveWhenInBackground: true),
      pushNotificationManagerProvider:
          StreamVideoPushNotificationManager.create(
            iosPushProvider: StreamVideoPushProvider.apn(
              name: streamIosPushProvider,
            ),
            androidPushProvider: StreamVideoPushProvider.firebase(
              name: streamAndroidPushProvider,
            ),
            pushConfiguration: const StreamVideoPushConfiguration(
              android: AndroidPushConfiguration(
                telecom: TelecomPushConfiguration(enabled: true),
              ),
            ),
          ),
    );
    final result = await client.connect();
    if (result.isFailure) {
      await StreamVideo.reset(disconnect: true);
      throw StateError('Connexion Stream Video impossible');
    }
    _client = client;

    // Décroché depuis CallKit ou la notification Android.
    _ringing = client.observeCoreRingingEvents(onCallAccepted: _onNativeAccept);
    // App ouverte : l'appel entrant s'affiche dans l'app.
    _incomingSub = client.state.incomingCall.listen((call) {
      if (call == null) return;
      _incoming.add(
        IncomingCall(
          callId: call.id,
          callerName: call.state.value.createdByUser.name,
          callerImageUrl: call.state.value.createdByUser.image,
        ),
      );
    });
    // Android : appel décroché pendant que l'app était tuée.
    unawaited(
      client.consumeAndAcceptActiveCall(onCallAccepted: _onNativeAccept),
    );
  }

  void _onNativeAccept(Call call) {
    _bind(call, outgoing: false);
    _incoming.add(
      IncomingCall(
        callId: call.id,
        callerName: call.state.value.createdByUser.name,
        callerImageUrl: call.state.value.createdByUser.image,
        acceptedNatively: true,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _stateSub?.cancel();
    await _incomingSub?.cancel();
    unawaited(_ringing?.cancel());
    _stateSub = null;
    _incomingSub = null;
    _ringing = null;
    _call = null;
    if (_client != null) {
      _client = null;
      await StreamVideo.reset(disconnect: true);
    }
  }

  @override
  Future<void> joinOutgoing(String callId) async {
    final call = _requireClient().makeCall(
      callType: StreamCallType.custom(_callType),
      id: callId,
    );
    _bind(call, outgoing: true);
    _check(await call.join());
  }

  @override
  Future<void> acceptIncoming(String callId) async {
    final call = _call?.id == callId
        ? _call!
        : _requireClient().makeCall(
            callType: StreamCallType.custom(_callType),
            id: callId,
          );
    _bind(call, outgoing: false);
    if (call.state.value.status is CallStatusIncoming) {
      _check(await call.accept());
    }
    _check(await call.join());
  }

  @override
  Future<void> rejectIncoming(String callId) async {
    final call = _requireClient().makeCall(
      callType: StreamCallType.custom(_callType),
      id: callId,
    );
    await call.reject(reason: CallRejectReason.decline());
  }

  @override
  Future<void> hangUp() async {
    final call = _call;
    if (call == null) return;
    // Raccrocher avant que l'autre décroche annule la sonnerie (le back
    // l'enregistre en appel manqué, pas en refus).
    if (_outgoing && _connectedAt == null) {
      await call.reject(reason: CallRejectReason.cancel());
    }
    await call.leave();
    _active.add(
      const ActiveCallSnapshot(phase: CallPhase.ended, endReason: 'hangup'),
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    final call = _call;
    if (call != null) {
      _check(await call.setMicrophoneEnabled(enabled: enabled));
    }
  }

  @override
  Future<void> setSpeakerOn(bool on) async {
    final call = _call;
    if (call == null) return;
    final devices =
        (await RtcMediaDeviceNotifier.instance.audioOutputs())
            .getDataOrNull() ??
        const [];
    final target = on
        ? devices.where((d) => d.isSpeaker).firstOrNull
        : devices.where((d) => !d.isSpeaker).firstOrNull;
    if (target != null) {
      _check(await call.setAudioOutputDevice(target));
    }
  }

  void _bind(Call call, {required bool outgoing}) {
    if (identical(_call, call)) return;
    unawaited(_stateSub?.cancel());
    _call = call;
    _outgoing = outgoing;
    _connectedAt = null;
    _stateSub = call.state.listen(_onState);
  }

  void _onState(CallState state) {
    final remote = state.callParticipants.where((p) => !p.isLocal).firstOrNull;
    final status = state.status;
    if (status is CallStatusDisconnected) {
      _active.add(
        ActiveCallSnapshot(
          phase: CallPhase.ended,
          remoteName: remote?.name,
          endReason: _endReason(status.reason),
        ),
      );
      return;
    }
    if (remote != null) {
      _connectedAt ??= DateTime.now();
      _active.add(
        ActiveCallSnapshot(
          phase: CallPhase.connected,
          connectedAt: _connectedAt,
          remoteName: remote.name,
        ),
      );
    } else {
      _active.add(
        ActiveCallSnapshot(
          phase: _outgoing ? CallPhase.ringing : CallPhase.connecting,
        ),
      );
    }
  }

  static String _endReason(DisconnectReason reason) => switch (reason) {
    DisconnectReasonRejected() => 'rejected',
    DisconnectReasonTimeout() => 'missed',
    DisconnectReasonCancelled() ||
    DisconnectReasonEnded() ||
    DisconnectReasonLastParticipantLeft() ||
    DisconnectReasonCallEnded() => 'hangup',
    _ => 'failed',
  };

  StreamVideo _requireClient() {
    final client = _client;
    if (client == null) throw StateError('Stream Video non connecté');
    return client;
  }

  static void _check(Result<Object?> result) {
    if (result.isFailure) {
      throw StateError('Opération Stream Video refusée : $result');
    }
  }
}
