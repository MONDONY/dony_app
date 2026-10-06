/// Choix de la sortie audio d'un appel, sans plugin natif : testable seul.
/// `StreamCallGateway` ne fait qu'appliquer ce choix (FLUTTER-E1).
library;

import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    show RtcMediaDevice, RtcMediaDeviceKind;

/// Sortie « hors haut-parleur » à demander quand la liste du SDK n'en contient
/// aucune. Sur iOS, la liste ne montre que la route courante (plus un
/// « Speaker » factice quand la route n'est pas déjà le haut-parleur) : une
/// fois sur le haut-parleur, elle vaut `[Speaker]`. Le natif iOS traite tout
/// identifiant autre que `Speaker` par `overrideOutputAudioPort(None)`, ce qui
/// rend le son au casque branché, sinon au combiné.
const syntheticEarpiece = RtcMediaDevice(
  id: 'earpiece',
  label: 'Earpiece',
  kind: RtcMediaDeviceKind.audioOutput,
);

/// Sortie à demander pour [speakerOn] parmi [outputs] : le haut-parleur, ou
/// la première sortie qui n'en est pas un. Sans sortie hors haut-parleur,
/// [syntheticEarpiece] si [allowSyntheticEarpiece] (iOS seulement : sur
/// Android la liste énumère toutes les sorties, et un « earpiece » absent n'y
/// serait pas sélectionnable). `null` = rien à demander.
RtcMediaDevice? audioOutputTarget(
  List<RtcMediaDevice> outputs, {
  required bool speakerOn,
  required bool allowSyntheticEarpiece,
}) {
  if (speakerOn) return outputs.where((d) => d.isSpeaker).firstOrNull;
  return outputs.where((d) => !d.isSpeaker).firstOrNull ??
      (allowSyntheticEarpiece ? syntheticEarpiece : null);
}

/// Sortie réelle telle que le bloc la voit. [type] est le type de port
/// (`Headphones`, `BluetoothHFP`, `Speaker`, `wired-headset`…), jamais le nom
/// de l'appareil : un nom Bluetooth (« AirPods de … ») est une donnée
/// personnelle et ne doit pas partir dans les logs.
CallAudioOutput? callAudioOutputOf(RtcMediaDevice? device) {
  if (device == null) return null;
  final group = device.groupId;
  // Sans type de port, l'identifiant n'est repris que s'il est générique : un
  // UID Bluetooth contient l'adresse de l'appareil.
  final fallback = device.isSpeaker
      ? 'speaker'
      : device.isEarpiece
      ? 'earpiece'
      : 'unknown';
  return CallAudioOutput(
    type: group == null || group.isEmpty ? fallback : group,
    speaker: device.isSpeaker,
    external: device.isExternal,
  );
}
