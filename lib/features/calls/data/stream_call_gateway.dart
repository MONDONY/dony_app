import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/config/stream_push_providers.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/models/call_token.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart' show CompositeSubscription;
import 'package:stream_video_flutter/stream_video_flutter.dart' hide CallUser;
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:stream_webrtc_flutter/stream_webrtc_flutter.dart' as rtc;

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
      pushNotificationManagerProvider: _pushManager(),
    );
    final result = await client.connect();
    if (result.isFailure) {
      await StreamVideo.reset(disconnect: true);
      throw StateError('Stream Video connection failed');
    }
    _client = client;

    // Décroché depuis CallKit ou la notification Android.
    _ringing = client.observeCoreRingingEvents(onCallAccepted: _onNativeAccept);
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
    unawaited(_ringing?.cancel());
    _stateSub = null;
    _ringing = null;
    _call = null;
    if (_client != null) {
      _client = null;
      await StreamVideo.reset(disconnect: true);
    }
  }

  @override
  Future<bool> ensureMicrophone() async {
    try {
      // Ouvre puis relâche aussitôt le micro : déclenche la demande système la
      // première fois, échoue si l'utilisateur l'a refusée.
      final stream = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      return true;
    } catch (_) {
      return false;
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

  @override
  Future<void> handlePush(Map<String, dynamic> data) async {
    await _client?.handleRingingFlowNotifications(data);
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
    if (client == null) throw StateError('Stream Video not connected');
    return client;
  }

  static void _check(Result<Object?> result) {
    if (result.isFailure) {
      throw StateError('Stream Video operation failed: $result');
    }
  }
}

/// Push Stream reçu app fermée ou en arrière-plan : l'isolate ne partage rien
/// avec l'app (ni GetIt, ni ApiClient), on reconstruit un client Stream avec
/// un jeton frais du back, le temps de faire sonner puis de résoudre l'appel.
/// Tout échec est avalé : au pire, pas de sonnerie (le back enregistre
/// l'appel manqué et envoie son push).
@pragma('vm:entry-point')
Future<void> handleStreamVideoBackgroundPush(Map<String, dynamic> data) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) return;
    final response = await Dio(BaseOptions(baseUrl: kApiBaseUrl))
        .get<Map<String, dynamic>>(
          '/calls/token',
          options: Options(
            headers: {'Authorization': 'Bearer $idToken'},
          ), // i18n-ignore
        );
    final token = CallToken.fromJson(response.data!);
    final client = StreamVideo(
      token.apiKey,
      user: User.regular(userId: token.userId),
      userToken: token.token,
      failIfSingletonExists: false,
      pushNotificationManagerProvider: _pushManager(),
    );
    final ringing = client.observeCoreRingingEventsForBackground();
    client.disposeAfterResolvingRinging(disposingCallback: ringing.cancel);
    await client.handleRingingFlowNotifications(data);
  } catch (e) {
    if (kDebugMode) debugPrint('[calls] background push failed: $e');
  }
}

PNManagerProvider _pushManager() => StreamVideoPushNotificationManager.create(
  iosPushProvider: StreamVideoPushProvider.apn(name: streamIosPushProvider),
  androidPushProvider: StreamVideoPushProvider.firebase(
    name: streamAndroidPushProvider,
  ),
  pushConfiguration: const StreamVideoPushConfiguration(
    android: AndroidPushConfiguration(
      telecom: TelecomPushConfiguration(enabled: true),
    ),
  ),
);
