import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/config/api_config.dart';
import 'package:dony/core/config/stream_push_providers.dart';
import 'package:dony/core/firebase/firebase_options.dart';
import 'package:dony/features/calls/data/call_flow.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:dony/features/calls/data/models/call_token.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart' show CompositeSubscription;
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Absence tolérée de l'autre partie (coupure réseau) avant de conclure
  /// qu'elle a raccroché.
  static const _remoteGoneGrace = Duration(seconds: 8);

  StreamVideo? _client;
  Call? _call;
  CallFlow? _flow;
  Timer? _ringTimer;
  Timer? _remoteGoneTimer;
  CompositeSubscription? _ringing;
  StreamSubscription<CallState>? _stateSub;
  final _announced = SeenCallIds();
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
    // Le SDK ne réinscrit pas un jeton push qu'il croit déjà inscrit ; or un
    // désenregistrement raté (déconnexion hors ligne) le laisse en mémoire et
    // le compte suivant ne recevrait aucun appel. On repart à zéro : le jeton
    // est réinscrit pour ce compte (Stream le retire à l'ancien).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StreamVideoPushNotificationManager.userDeviceTokenKey);
    await prefs.remove(
      StreamVideoPushNotificationManager.userDeviceTokenVoIPKey,
    );
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

    // Android : service de premier plan + notification « appel en cours »
    // pendant chaque appel actif. Sans lui, l'appel est coupé (micro, réseau)
    // dès que l'app passe en arrière-plan ou que l'écran se verrouille.
    StreamBackgroundService.init(
      client,
      callNotificationOptionsBuilder: _callNotificationOptions,
      // Par défaut le SDK quitte tous les appels quand l'activité Android est
      // détachée. Le moteur Flutter lui survit (MainActivity), l'appel doit
      // donc continuer : on raccroche depuis l'écran ou la notification.
      onPlatformUiLayerDestroyed: (_) async {},
    );

    // Décroché depuis CallKit ou la notification Android.
    _ringing = client.observeCoreRingingEvents(onCallAccepted: _onNativeAccept);
    // Android : appel décroché pendant que l'app était tuée.
    unawaited(
      client.consumeAndAcceptActiveCall(onCallAccepted: _onNativeAccept),
    );
  }

  void _onNativeAccept(Call call) {
    // Le SDK peut signaler plusieurs fois le même décroché.
    if (!_announced.firstTime(call.id)) return;
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
    // Un appel en cours ne survit pas à la déconnexion : sinon micro et
    // audio continuent sans écran.
    final call = _call;
    _flow?.onLocalHangUp();
    _unbind();
    if (call != null) await call.leave();
    unawaited(_ringing?.cancel());
    _ringing = null;
    if (_client != null) {
      _client = null;
      await StreamVideo.reset(disconnect: true);
    }
  }

  @override
  Future<bool> ensureMicrophone() async {
    // Demande la permission système, sans passer par le SDK WebRTC : à ce
    // stade aucun appel n'existe encore, donc aucune « factory » n'est créée
    // côté natif. `getUserMedia` sans factory échoue toujours sur Android
    // avec ce SDK (`unknown factoryId null`, MethodCallHandlerImpl.resolveFactory
    // ne connaît jamais `null`) : vu en recette, le message confondait un bug
    // avec un refus réel de permission.
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) return false;
    return (await Permission.microphone.request()).isGranted;
  }

  Call _makeCall(String callId) => _requireClient().makeCall(
    callType: StreamCallType.custom(_callType),
    id: callId,
  );

  @override
  Future<void> joinOutgoing(String callId) async {
    final call = _makeCall(callId);
    _bind(call, outgoing: true);
    _check(await call.join());
    // Côté appelant le SDK n'arme pas la fin de sonnerie (appel créé par le
    // back) : on l'arme ici, avec le réglage du type d'appel.
    if (identical(_call, call) && !(_flow?.ended ?? true)) {
      _ringTimer?.cancel();
      _ringTimer = Timer(
        call.state.value.settings.ring.autoCancelTimeout,
        () => _apply(call, _flow?.onRingTimeout()),
      );
    }
  }

  @override
  Future<void> cancelOutgoing(String callId) async {
    await _makeCall(callId).reject(reason: CallRejectReason.cancel());
  }

  @override
  Future<void> acceptIncoming(String callId) async {
    final client = _requireClient();
    final call = _call?.id == callId ? _call! : _makeCall(callId);
    _bind(call, outgoing: false);
    final status = call.state.value.status;
    final steps = incomingSteps(
      ringingNotAccepted: status is CallStatusIncoming && !status.acceptedByMe,
      alreadyActive: client.state.activeCalls.value.any(
        (c) => c.callCid == call.callCid,
      ),
    );
    if (steps.accept) _check(await call.accept());
    if (steps.join) _check(await call.join());
  }

  @override
  Future<void> rejectIncoming(String callId) async {
    final bound = _call;
    if (bound != null && bound.id == callId) {
      // Déjà décroché nativement (voire rejoint) : refuser cet appel-là.
      _flow?.onLocalHangUp();
      _unbind();
      await bound.reject(reason: CallRejectReason.decline());
      return;
    }
    await _makeCall(callId).reject(reason: CallRejectReason.decline());
  }

  @override
  Future<void> hangUp() async {
    final call = _call;
    final flow = _flow;
    if (call == null || flow == null) return;
    // La fin d'un raccroché local est émise par le bloc, pas ici : la
    // déconnexion qui suit est ignorée par le flow.
    await _execute(call, flow.onLocalHangUp().action);
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
    _unbind();
    _call = call;
    _flow = CallFlow(outgoing: outgoing);
    _stateSub = call.state.listen((state) => _onState(call, state));
  }

  void _unbind() {
    _ringTimer?.cancel();
    _remoteGoneTimer?.cancel();
    _ringTimer = null;
    _remoteGoneTimer = null;
    unawaited(_stateSub?.cancel());
    _stateSub = null;
    _call = null;
    _flow = null;
  }

  void _onState(Call call, CallState state) {
    final flow = _flow;
    if (flow == null || !identical(_call, call)) return;
    final remote = state.callParticipants.where((p) => !p.isLocal).firstOrNull;
    final status = state.status;
    _apply(
      call,
      flow.onObservation(
        CallObservation(
          remotePresent: remote != null,
          remoteName: remote?.name,
          otherMemberRejected: state.callMembers.any(
            (m) => m.userId != state.currentUserId && m.callRejectedAt != null,
          ),
          disconnectReason: status is CallStatusDisconnected
              ? _endReason(status.reason)
              : null,
        ),
      ),
    );
  }

  void _apply(Call call, CallFlowDecision? decision) {
    if (decision == null || !identical(_call, call)) return;
    final snapshot = decision.snapshot;
    if (snapshot != null) _active.add(snapshot);
    switch (decision.action) {
      case CallFlowAction.armRemoteGoneTimer:
        _remoteGoneTimer?.cancel();
        _remoteGoneTimer = Timer(
          _remoteGoneGrace,
          () => _apply(call, _flow?.onRemoteGoneTimeout()),
        );
      case CallFlowAction.cancelRemoteGoneTimer:
        _remoteGoneTimer?.cancel();
      case CallFlowAction.none:
      case CallFlowAction.leave:
      case CallFlowAction.cancelRinging:
        unawaited(_execute(call, decision.action));
    }
    if (_flow?.ended ?? false) {
      _ringTimer?.cancel();
      _remoteGoneTimer?.cancel();
    }
  }

  Future<void> _execute(Call call, CallFlowAction action) async {
    switch (action) {
      case CallFlowAction.cancelRinging:
        // Le back enregistre l'appel en manqué, pas en refus.
        _unbindIf(call);
        await call.reject(reason: CallRejectReason.cancel());
      case CallFlowAction.leave:
        _unbindIf(call);
        // Appel à deux : raccrocher termine l'appel pour l'autre aussi, sinon
        // son écran reste « en appel ». `end` exige un droit côté Stream ; à
        // défaut, quitter suffit (l'autre conclut seul après le délai de grâce).
        await call.end();
        await call.leave();
      case CallFlowAction.none:
        if (_flow?.ended ?? false) _unbindIf(call);
      case CallFlowAction.armRemoteGoneTimer:
      case CallFlowAction.cancelRemoteGoneTimer:
        break;
    }
  }

  void _unbindIf(Call call) {
    if (identical(_call, call)) _unbind();
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

/// Notification Android de l'appel en cours : nom de l'autre partie, toucher
/// la notification rouvre l'app sur l'écran d'appel.
NotificationOptions _callNotificationOptions(Call call) {
  final l = AppL10n.current;
  final remote = call.state.valueOrNull?.callParticipants
      .where((p) => !p.isLocal)
      .firstOrNull;
  return NotificationOptions(
    content: NotificationContent(
      title: l.callNotificationTitle,
      text: remote?.name ?? l.callStatusConnecting,
    ),
  );
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
