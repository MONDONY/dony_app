import 'package:dony/features/calls/data/ringback_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sentry FLUTTER-9V : un identifiant de lecteur fixe, partagé entre les
  // appels, faisait détruire le lecteur d'un appel par la fermeture du
  // précédent (« Player has not yet been created or has already been
  // disposed », iPhone).
  group('AudioPlayersRingbackTone.nextPlayerId', () {
    test('chaque appel reçoit un identifiant de lecteur différent', () {
      final ids = {
        for (var i = 0; i < 50; i++) AudioPlayersRingbackTone.nextPlayerId(),
      };
      expect(ids, hasLength(50));
    });

    test('garde le préfixe repérable dans les journaux natifs', () {
      expect(
        AudioPlayersRingbackTone.nextPlayerId(),
        startsWith('yadony-ringback-'),
      );
    });

    test('jamais l\'ancien identifiant fixe', () {
      expect(AudioPlayersRingbackTone.nextPlayerId(), isNot('yadony-ringback'));
    });
  });
}
