import 'package:dony/features/calls/data/audio_output_choice.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    show RtcMediaDevice, RtcMediaDeviceKind;

RtcMediaDevice _out(String id, {String? groupId}) => RtcMediaDevice(
  id: id,
  label: id,
  groupId: groupId,
  kind: RtcMediaDeviceKind.audioOutput,
);

void main() {
  // Listes telles que le natif iOS les renvoie : la route courante seule, plus
  // un « Speaker » factice quand la route n'est pas déjà le haut-parleur.
  final speakerOnly = [_out('Speaker', groupId: 'Speaker')];
  final speakerAndHeadphones = [
    _out('Speaker', groupId: 'Speaker'),
    _out('Wired Headphones', groupId: 'Headphones'),
  ];

  group('audioOutputTarget (FLUTTER-E1)', () {
    test('couper le HP alors que la liste ne contient que lui (iOS) : '
        'sortie non-HP de repli, plus de bascule silencieuse', () {
      final target = audioOutputTarget(
        speakerOnly,
        speakerOn: false,
        allowSyntheticEarpiece: true,
      );
      expect(target, syntheticEarpiece);
      expect(target!.isSpeaker, isFalse);
      expect(target.kind, RtcMediaDeviceKind.audioOutput);
    });

    test('couper le HP avec un casque dans la liste : le casque', () {
      final target = audioOutputTarget(
        speakerAndHeadphones,
        speakerOn: false,
        allowSyntheticEarpiece: true,
      );
      expect(target?.id, 'Wired Headphones');
    });

    test('activer le HP : le haut-parleur', () {
      for (final list in [speakerOnly, speakerAndHeadphones]) {
        final target = audioOutputTarget(
          list,
          speakerOn: true,
          allowSyntheticEarpiece: true,
        );
        expect(target?.id, 'Speaker');
      }
    });

    test('Android : pas de sortie inventée, rien à demander', () {
      expect(
        audioOutputTarget(
          [_out('speaker', groupId: 'speaker')],
          speakerOn: false,
          allowSyntheticEarpiece: false,
        ),
        isNull,
      );
    });

    test('Android : la première sortie non-HP de la liste', () {
      final target = audioOutputTarget(
        [
          _out('wired-headset', groupId: 'wired-headset'),
          _out('earpiece', groupId: 'earpiece'),
          _out('speaker', groupId: 'speaker'),
        ],
        speakerOn: false,
        allowSyntheticEarpiece: false,
      );
      expect(target?.id, 'wired-headset');
    });

    test('aucun haut-parleur connu : rien à demander', () {
      expect(
        audioOutputTarget(
          const [],
          speakerOn: true,
          allowSyntheticEarpiece: true,
        ),
        isNull,
      );
    });
  });

  group('callAudioOutputOf', () {
    test('null tant que le SDK ne connaît pas la sortie', () {
      expect(callAudioOutputOf(null), isNull);
    });

    test('haut-parleur : type de port, speaker', () {
      expect(
        callAudioOutputOf(_out('Speaker', groupId: 'Speaker')),
        const CallAudioOutput(type: 'Speaker', speaker: true, external: false),
      );
    });

    test('casque Bluetooth : externe, type de port sans le nom', () {
      final output = callAudioOutputOf(
        const RtcMediaDevice(
          id: '00:11:22:33:44:55-tacl',
          label: 'AirPods de Awa',
          groupId: 'BluetoothHFP',
          kind: RtcMediaDeviceKind.audioOutput,
        ),
      );
      expect(output?.type, 'BluetoothHFP');
      expect(output?.speaker, isFalse);
      expect(output?.external, isTrue);
    });

    test('sans type de port : jamais l\'identifiant brut', () {
      expect(callAudioOutputOf(syntheticEarpiece)?.type, 'earpiece');
      expect(callAudioOutputOf(_out('speaker'))?.type, 'speaker');
      expect(callAudioOutputOf(_out('00:11:22-tacl'))?.type, 'unknown');
    });

    test('égalité par valeur', () {
      const a = CallAudioOutput(type: 'x', speaker: false, external: true);
      const b = CallAudioOutput(type: 'x', speaker: false, external: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
