import 'dart:async';

import 'package:dony/features/calls/data/call_gateway.dart';

/// Passerelle d'appel en mémoire : enregistre les appels reçus et laisse le
/// test piloter l'état de l'appel et les appels entrants.
class FakeCallGateway implements CallGateway {
  final List<String> log = [];
  final activeCallController = StreamController<ActiveCallSnapshot>.broadcast();
  final incomingController = StreamController<IncomingCall>.broadcast();

  bool connected = false;
  String? connectedUserId;
  Future<String> Function()? tokenLoader;
  Object? throwOnJoin;
  Object? throwOnConnect;

  @override
  Future<void> connect({
    required String apiKey,
    required CallUser user,
    required Future<String> Function() tokenLoader,
  }) async {
    log.add('connect:$apiKey:${user.id}:${user.name}');
    if (throwOnConnect != null) throw throwOnConnect!;
    connected = true;
    connectedUserId = user.id;
    this.tokenLoader = tokenLoader;
  }

  @override
  Future<void> disconnect() async {
    log.add('disconnect');
    connected = false;
    connectedUserId = null;
  }

  @override
  bool get isConnected => connected;

  @override
  Future<void> joinOutgoing(String callId) async {
    log.add('join:$callId');
    if (throwOnJoin != null) throw throwOnJoin!;
  }

  @override
  Future<void> acceptIncoming(String callId) async => log.add('accept:$callId');

  @override
  Future<void> rejectIncoming(String callId) async => log.add('reject:$callId');

  @override
  Future<void> hangUp() async => log.add('hangUp');

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async =>
      log.add('mic:$enabled');

  @override
  Future<void> setSpeakerOn(bool on) async => log.add('speaker:$on');

  @override
  Stream<ActiveCallSnapshot> get activeCall => activeCallController.stream;

  @override
  Stream<IncomingCall> get incomingCalls => incomingController.stream;

  Future<void> dispose() async {
    await activeCallController.close();
    await incomingController.close();
  }
}
