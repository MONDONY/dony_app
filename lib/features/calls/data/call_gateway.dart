/// Frontière avec le fournisseur d'appels (Stream Video). Les BLoC et écrans ne
/// connaissent que cette interface : seul `StreamCallGateway` touche au SDK.
library;

enum CallPhase { connecting, ringing, connected, ended }

class CallUser {
  const CallUser({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;
  final String? imageUrl;
}

class ActiveCallSnapshot {
  const ActiveCallSnapshot({
    required this.phase,
    this.connectedAt,
    this.remoteName,
    this.endReason,
  });

  final CallPhase phase;
  final DateTime? connectedAt;
  final String? remoteName;

  /// `rejected` | `missed` | `hangup` | `failed`, seulement en [CallPhase.ended].
  final String? endReason;
}

abstract class CallGateway {
  Future<void> connect({
    required String apiKey,
    required CallUser user,
    required Future<String> Function() tokenLoader,
  });

  Future<void> disconnect();

  bool get isConnected;

  /// Rejoint un appel déjà créé (et mis en sonnerie) par le back.
  Future<void> joinOutgoing(String callId);

  /// Décroche l'appel entrant [callId].
  Future<void> acceptIncoming(String callId);

  Future<void> rejectIncoming(String callId);

  Future<void> hangUp();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setSpeakerOn(bool on);

  /// Push Stream reçu app ouverte : fait sonner (notification d'appel native).
  Future<void> handlePush(Map<String, dynamic> data);

  /// État de l'appel en cours, tant qu'il y en a un.
  Stream<ActiveCallSnapshot> get activeCall;

  /// Appels entrants (id) pendant que l'app est ouverte, ou décrochés depuis
  /// l'interface native (CallKit, notification Android).
  Stream<IncomingCall> get incomingCalls;
}

class IncomingCall {
  const IncomingCall({
    required this.callId,
    required this.callerName,
    this.callerImageUrl,
    this.acceptedNatively = false,
  });

  final String callId;
  final String callerName;
  final String? callerImageUrl;

  /// Déjà décroché depuis CallKit ou la notification Android : il ne reste
  /// qu'à ouvrir l'écran d'appel.
  final bool acceptedNatively;
}
