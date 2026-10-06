import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Tonalité de retour d'appel (« tuut… tuut… ») jouée chez l'appelant tant
/// que l'autre ne décroche pas (FLUTTER-9V).
///
/// Stream Video ne la joue pas ici : l'appel est créé par le back, l'appelant
/// le rejoint ensuite et n'est donc pas dans le « ringing flow » du SDK.
///
/// L'appelant est déjà connecté à l'appel (micro ouvert) pendant la
/// sonnerie : la tonalité reprend la configuration audio de Stream
/// (`BroadcasterAudioPolicy`) pour ne pas la casser. iOS : `playAndRecord`
/// avec `mixWithOthers` ; Android : flux « communication », sans prise du
/// focus audio. Elle sort donc par l'écouteur, ou le haut-parleur s'il est
/// activé, comme la voix.
abstract interface class RingbackTone {
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

class AudioPlayersRingbackTone implements RingbackTone {
  AudioPlayersRingbackTone({AudioPlayer? player})
    : _player = player ?? AudioPlayer(playerId: nextPlayerId());

  static int _created = 0;

  /// Identifiant du lecteur natif, UNIQUE par instance.
  ///
  /// Il était fixe (`yadony-ringback`) alors que chaque appel crée sa propre
  /// instance : sur iOS, `audioplayers_darwin` range les lecteurs natifs par
  /// identifiant, si bien que la fermeture de l'appel précédent détruisait le
  /// lecteur de l'appel suivant. Le `play()` recevait alors « Player has not
  /// yet been created or has already been disposed » (Sentry FLUTTER-9V, 30
  /// échecs en 24 h, tous sur iPhone).
  @visibleForTesting
  static String nextPlayerId() => 'yadony-ringback-${_created++}';

  static const asset = 'sounds/ringback_fr.wav';

  final AudioPlayer _player;
  bool _playing = false;

  static final _context = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.allowBluetooth,
        AVAudioSessionOptions.allowBluetoothA2DP,
        AVAudioSessionOptions.allowAirPlay,
      },
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
      audioMode: AndroidAudioMode.inCommunication,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.setAudioContext(_context);
      await _player.setReleaseMode(ReleaseMode.loop);
      // Arrêtée entre-temps (décroché pendant le chargement) : rien à jouer.
      if (!_playing) return;
      await _player.play(AssetSource(asset), volume: 0.6);
    } catch (e) {
      // Jamais bloquant : sans tonalité, l'appel continue.
      _playing = false;
      AppLog.warn('ringback: playback failed', data: {'error': '$e'});
    }
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (e) {
      AppLog.warn('ringback: stop failed', data: {'error': '$e'});
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
