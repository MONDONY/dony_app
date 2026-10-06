/// Décisions d'un appel audio, sans le SDK : ce que l'adaptateur Stream doit
/// émettre et faire à chaque changement d'état. Séparé de `StreamCallGateway`
/// pour être testé ; l'adaptateur ne fait qu'exécuter ces décisions.
///
/// Le back crée l'appel avec sonnerie, l'appelant le rejoint ensuite : côté
/// appelant le SDK n'est donc pas en « ringing flow » et ne détecte ni le
/// refus, ni la sonnerie sans réponse, ni le raccroché de l'autre. C'est ici.
library;

import 'package:dony/features/calls/data/call_gateway.dart';

/// Ce que l'adaptateur voit de l'appel Stream à un instant donné.
class CallObservation {
  const CallObservation({
    this.remotePresent = false,
    this.remoteName,
    this.otherMemberRejected = false,
    this.disconnectReason,
    this.audioOutput,
  });

  /// L'autre partie est dans l'appel (participant connecté).
  final bool remotePresent;
  final String? remoteName;

  /// L'autre membre a refusé l'appel.
  final bool otherMemberRejected;

  /// Non nul quand le SDK a déconnecté l'appel : `rejected` | `missed` |
  /// `hangup` | `failed`.
  final String? disconnectReason;

  /// Sortie audio réellement utilisée, recopiée telle quelle dans le snapshot.
  final CallAudioOutput? audioOutput;
}

enum CallFlowAction {
  none,

  /// Quitter l'appel (session SFU fermée, micro relâché).
  leave,

  /// Appelant avant décroché : refuser avec « cancel » (le back enregistre un
  /// appel manqué) puis quitter.
  cancelRinging,

  /// L'autre a disparu : attendre un peu (coupure réseau) avant de conclure.
  armRemoteGoneTimer,
  cancelRemoteGoneTimer,
}

class CallFlowDecision {
  const CallFlowDecision([this.snapshot, this.action = CallFlowAction.none]);

  static const nothing = CallFlowDecision();

  /// À émettre sur `CallGateway.activeCall`, null = rien à émettre.
  final ActiveCallSnapshot? snapshot;
  final CallFlowAction action;
}

class CallFlow {
  CallFlow({required this.outgoing, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final bool outgoing;
  final DateTime Function() _now;

  bool _ended = false;
  bool _remoteGone = false;
  DateTime? _connectedAt;
  String? _remoteName;

  bool get ended => _ended;

  CallFlowDecision onObservation(CallObservation o) {
    if (_ended) return CallFlowDecision.nothing;
    final reason = o.disconnectReason;
    if (reason != null) {
      return _end(reason, CallFlowAction.none);
    }
    if (o.remotePresent) {
      _connectedAt ??= _now();
      _remoteName = o.remoteName ?? _remoteName;
      final wasGone = _remoteGone;
      _remoteGone = false;
      return CallFlowDecision(
        ActiveCallSnapshot(
          phase: CallPhase.connected,
          connectedAt: _connectedAt,
          remoteName: _remoteName,
          audioOutput: o.audioOutput,
        ),
        wasGone ? CallFlowAction.cancelRemoteGoneTimer : CallFlowAction.none,
      );
    }
    if (_connectedAt != null) {
      // Déjà connecté, l'autre n'est plus là : coupure ou raccroché.
      if (_remoteGone) return CallFlowDecision.nothing;
      _remoteGone = true;
      return const CallFlowDecision(null, CallFlowAction.armRemoteGoneTimer);
    }
    if (outgoing && o.otherMemberRejected) {
      return _end('rejected', CallFlowAction.leave);
    }
    return CallFlowDecision(
      ActiveCallSnapshot(
        phase: outgoing ? CallPhase.ringing : CallPhase.connecting,
        audioOutput: o.audioOutput,
      ),
    );
  }

  /// Sonnerie sortante restée sans réponse.
  CallFlowDecision onRingTimeout() {
    if (_ended || !outgoing || _connectedAt != null) {
      return CallFlowDecision.nothing;
    }
    return _end('missed', CallFlowAction.cancelRinging);
  }

  /// L'autre n'est pas revenu après le délai de grâce.
  CallFlowDecision onRemoteGoneTimeout() {
    if (_ended || !_remoteGone) return CallFlowDecision.nothing;
    return _end('hangup', CallFlowAction.leave);
  }

  CallFlowDecision onLocalHangUp() {
    if (_ended) return CallFlowDecision.nothing;
    return _end(
      'hangup',
      outgoing && _connectedAt == null
          ? CallFlowAction.cancelRinging
          : CallFlowAction.leave,
    );
  }

  CallFlowDecision _end(String reason, CallFlowAction action) {
    _ended = true;
    return CallFlowDecision(
      ActiveCallSnapshot(
        phase: CallPhase.ended,
        remoteName: _remoteName,
        endReason: reason,
      ),
      action,
    );
  }
}

/// Étapes pour décrocher un appel entrant selon ce que le SDK a déjà fait :
/// un décroché depuis CallKit ou la notification accepte et rejoint déjà
/// l'appel ; un décroché app tuée (Android) accepte sans rejoindre.
({bool accept, bool join}) incomingSteps({
  required bool ringingNotAccepted,
  required bool alreadyActive,
}) => (accept: ringingNotAccepted, join: !alreadyActive);

/// Le SDK peut signaler plusieurs fois le même décroché natif : un appel ne
/// doit ouvrir qu'un écran.
class SeenCallIds {
  final _ids = <String>{};

  bool firstTime(String id) => _ids.add(id);
}
