/// Frontière avec le fournisseur d'appels (Stream Video). Les BLoC et écrans ne
/// connaissent que cette interface : seul `StreamCallGateway` touche au SDK.
library;

import 'package:dony/core/error/app_exception.dart';

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
    this.audioOutput,
  });

  final CallPhase phase;
  final DateTime? connectedAt;
  final String? remoteName;

  /// `rejected` | `missed` | `hangup` | `failed`, seulement en [CallPhase.ended].
  final String? endReason;

  /// Sortie audio réellement utilisée, `null` tant que le SDK ne la connaît
  /// pas (iOS laisse l'OS choisir quand un casque est branché au départ).
  final CallAudioOutput? audioOutput;
}

/// Sortie audio d'un appel (FLUTTER-E1).
class CallAudioOutput {
  const CallAudioOutput({
    required this.type,
    required this.speaker,
    required this.external,
  });

  /// Type de port (`Headphones`, `BluetoothHFP`, `Speaker`, `Receiver`,
  /// `wired-headset`…), jamais le nom de l'appareil.
  final String type;

  /// Haut-parleur du téléphone.
  final bool speaker;

  /// Casque filaire, Bluetooth ou voiture.
  final bool external;

  @override
  bool operator ==(Object other) =>
      other is CallAudioOutput &&
      other.type == type &&
      other.speaker == speaker &&
      other.external == external;

  @override
  int get hashCode => Object.hash(type, speaker, external);
}

abstract class CallGateway {
  Future<void> connect({
    required String apiKey,
    required CallUser user,
    required Future<String> Function() tokenLoader,
  });

  Future<void> disconnect();

  /// Vrai si le micro est utilisable ; demande l'autorisation système la
  /// première fois. Appelé avant de faire sonner qui que ce soit.
  Future<bool> ensureMicrophone();

  bool get isConnected;

  /// Rejoint un appel déjà créé (et mis en sonnerie) par le back.
  Future<void> joinOutgoing(String callId);

  /// Annule la sonnerie d'un appel créé par le back mais jamais rejoint
  /// (écran fermé pendant la création).
  Future<void> cancelOutgoing(String callId);

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

/// Accès au micro refusé par le système : l'appel ne peut pas avoir lieu.
class CallPermissionDeniedException extends AppException {
  const CallPermissionDeniedException()
    : super('Microphone permission denied', code: 'microphone-denied');
}
