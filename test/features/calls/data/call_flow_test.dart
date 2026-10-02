import 'package:dony/features/calls/data/call_flow.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 2, 12);
  CallFlow outgoing() => CallFlow(outgoing: true, now: () => t0);
  CallFlow incoming() => CallFlow(outgoing: false, now: () => t0);

  const alone = CallObservation();
  const withRemote = CallObservation(remotePresent: true, remoteName: 'Awa D.');

  group('appel sortant', () {
    test('personne en face : ça sonne, minuteur de sonnerie armé', () {
      final d = outgoing().onObservation(alone);
      expect(d.snapshot?.phase, CallPhase.ringing);
      expect(d.action, CallFlowAction.none);
    });

    test('l\'appelé refuse avant de décrocher : fin « rejected » et on quitte',
        () {
      final d = outgoing().onObservation(
        const CallObservation(otherMemberRejected: true),
      );
      expect(d.snapshot?.phase, CallPhase.ended);
      expect(d.snapshot?.endReason, 'rejected');
      expect(d.action, CallFlowAction.leave);
    });

    test('sonnerie sans réponse : fin « missed », sonnerie annulée', () {
      final flow = outgoing()..onObservation(alone);
      final d = flow.onRingTimeout();
      expect(d.snapshot?.endReason, 'missed');
      expect(d.action, CallFlowAction.cancelRinging);
    });

    test('expiration après connexion : ignorée', () {
      final flow = outgoing()..onObservation(withRemote);
      final d = flow.onRingTimeout();
      expect(d.snapshot, isNull);
      expect(d.action, CallFlowAction.none);
    });

    test('raccrocher avant décroché annule la sonnerie', () {
      final d = (outgoing()..onObservation(alone)).onLocalHangUp();
      expect(d.snapshot?.endReason, 'hangup');
      expect(d.action, CallFlowAction.cancelRinging);
    });
  });

  group('appel connecté', () {
    test('participant distant : connecté, heure de connexion fixée', () {
      final d = outgoing().onObservation(withRemote);
      expect(d.snapshot?.phase, CallPhase.connected);
      expect(d.snapshot?.connectedAt, t0);
      expect(d.snapshot?.remoteName, 'Awa D.');
    });

    test('l\'autre disparaît : délai de grâce, pas de retour à « ça sonne »',
        () {
      final flow = outgoing()..onObservation(withRemote);
      final d = flow.onObservation(alone);
      expect(d.snapshot, isNull);
      expect(d.action, CallFlowAction.armRemoteGoneTimer);
    });

    test('l\'autre revient pendant le délai : minuteur annulé, connecté', () {
      final flow = outgoing()
        ..onObservation(withRemote)
        ..onObservation(alone);
      final d = flow.onObservation(withRemote);
      expect(d.snapshot?.phase, CallPhase.connected);
      expect(d.action, CallFlowAction.cancelRemoteGoneTimer);
    });

    test('l\'autre n\'est pas revenu : fin « hangup », on quitte', () {
      final flow = outgoing()
        ..onObservation(withRemote)
        ..onObservation(alone);
      final d = flow.onRemoteGoneTimeout();
      expect(d.snapshot?.endReason, 'hangup');
      expect(d.action, CallFlowAction.leave);
    });

    test('raccrocher une fois connecté : on quitte (pas d\'annulation)', () {
      final d = (incoming()..onObservation(withRemote)).onLocalHangUp();
      expect(d.snapshot?.endReason, 'hangup');
      expect(d.action, CallFlowAction.leave);
    });
  });

  group('fin émise une seule fois', () {
    test('après raccroché local, la déconnexion du SDK n\'émet plus rien', () {
      final flow = outgoing()
        ..onObservation(alone)
        ..onLocalHangUp();
      final d = flow.onObservation(
        const CallObservation(disconnectReason: 'rejected'),
      );
      expect(d.snapshot, isNull);
      expect(d.action, CallFlowAction.none);
    });

    test('déconnexion du SDK : fin avec sa raison, puis plus rien', () {
      final flow = incoming()..onObservation(withRemote);
      final first = flow.onObservation(
        const CallObservation(disconnectReason: 'hangup'),
      );
      expect(first.snapshot?.endReason, 'hangup');
      expect(flow.onLocalHangUp().snapshot, isNull);
      expect(flow.onRingTimeout().snapshot, isNull);
    });
  });

  group('appel entrant', () {
    test('en attente de l\'autre : connexion, jamais « ça sonne »', () {
      expect(incoming().onObservation(alone).snapshot?.phase,
          CallPhase.connecting);
    });

    test('le refus d\'un membre ne termine pas un appel entrant', () {
      final d = incoming().onObservation(
        const CallObservation(otherMemberRejected: true),
      );
      expect(d.snapshot?.phase, CallPhase.connecting);
    });
  });

  group('incomingSteps', () {
    test('sonnerie non décrochée : accepter puis rejoindre', () {
      final s = incomingSteps(
        ringingNotAccepted: true,
        alreadyActive: false,
      );
      expect((s.accept, s.join), (true, true));
    });

    test('décroché natif, déjà rejoint par le SDK : ni accept ni join', () {
      final s = incomingSteps(ringingNotAccepted: false, alreadyActive: true);
      expect((s.accept, s.join), (false, false));
    });

    test('décroché app tuée (accepté, pas rejoint) : rejoindre seulement', () {
      final s = incomingSteps(ringingNotAccepted: false, alreadyActive: false);
      expect((s.accept, s.join), (false, true));
    });
  });

  test('SeenCallIds : un appel n\'est annoncé qu\'une fois', () {
    final seen = SeenCallIds();
    expect(seen.firstTime('a'), isTrue);
    expect(seen.firstTime('a'), isFalse);
    expect(seen.firstTime('b'), isTrue);
  });
}
