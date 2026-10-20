import 'dart:async';

import 'package:flutter/foundation.dart';

/// Passage de relais entre les lecteurs QR intégrés (mobile_scanner) et
/// l'appareil photo du système (image_picker).
///
/// Sur iOS, une seule session AVCaptureSession tient la caméra. Ouvrir
/// l'appareil photo système pendant qu'un lecteur QR tourne encore (bouton
/// scarabée ou feuille posée sur l'écran de scan), ou relancer le lecteur
/// juste après la fermeture de l'appareil photo, fait se croiser l'arrêt
/// d'une session et le démarrage de l'autre : le thread principal traite la
/// notification « session arrêtée » pendant qu'un autre thread démarre la
/// nouvelle session et garde son verrou. L'app gèle plusieurs secondes
/// (Sentry YADONY-FLUTTER-PROD-V, `_handleDidStopRunningNotificationWithPayload`
/// bloqué sur un mutex pendant `CAMCaptureEngine startRunning`).
///
/// Règle : avant d'ouvrir l'appareil photo système, chaque lecteur QR monté
/// s'arrête ([runWithSystemCamera] attend cet arrêt), puis on laisse
/// [settleDelay] à iOS pour clore la session. Les lecteurs ne redémarrent
/// qu'une fois l'appareil photo refermé, et pas avant [settleDelay].
///
/// Une seule instance pour toute l'app, enregistrée dans GetIt : celle que
/// reçoivent `DonyMediaService` et `QrCameraView`.
class CameraHandoff {
  CameraHandoff({
    this.settleDelay = defaultSettleDelay,
    this.releaseTimeout = defaultReleaseTimeout,
  });

  /// Délai laissé à iOS entre l'arrêt d'une session caméra et le démarrage
  /// d'une autre.
  static const defaultSettleDelay = Duration(milliseconds: 500);

  final Duration settleDelay;

  /// Attente maximale de l'arrêt d'un lecteur : un démarrage resté en
  /// suspens (permission, caméra occupée) ne doit pas empêcher l'appareil
  /// photo de s'ouvrir.
  static const defaultReleaseTimeout = Duration(seconds: 2);

  final Duration releaseTimeout;

  final _systemCameraActive = ValueNotifier<bool>(false);
  final _releasers = <Future<bool> Function()>{};
  int _depth = 0;
  DateTime? _lastSystemCameraEnd;

  /// `true` tant que l'appareil photo système est ouvert (ou en train de
  /// s'ouvrir) : les lecteurs QR restent arrêtés.
  ValueListenable<bool> get systemCameraActive => _systemCameraActive;

  /// Moment où l'appareil photo système s'est refermé pour la dernière fois.
  DateTime? get lastSystemCameraEnd => _lastSystemCameraEnd;

  @visibleForTesting
  int get releaserCount => _releasers.length;

  /// Inscrit un lecteur. [release] arrête sa caméra, attend la fin de l'arrêt
  /// et rend `true` si elle tournait. La fonction rendue désinscrit.
  VoidCallback register(Future<bool> Function() release) {
    _releasers.add(release);
    return () => _releasers.remove(release);
  }

  /// Arrête un lecteur. Un lecteur en erreur ne bloque pas l'appareil photo
  /// (`false`) ; sans réponse avant [releaseTimeout], on fait comme s'il
  /// tournait (`true`) pour que [settleDelay] s'applique.
  Future<bool> _releaseWithTimeout(Future<bool> Function() release) {
    final completer = Completer<bool>();
    final timer = Timer(releaseTimeout, () {
      if (!completer.isCompleted) completer.complete(true);
    });
    Future<bool>.sync(release).then(
      (wasRunning) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(wasRunning);
      },
      onError: (Object _) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  /// Ouvre l'appareil photo système via [open], une fois les lecteurs QR
  /// arrêtés et la caméra libérée.
  Future<T> runWithSystemCamera<T>(Future<T> Function() open) async {
    _depth++;
    _systemCameraActive.value = true;
    try {
      final released = await Future.wait(
        _releasers.toList().map(_releaseWithTimeout),
      );
      if (released.any((wasRunning) => wasRunning)) {
        await Future<void>.delayed(settleDelay);
      }
      return await open();
    } finally {
      _depth--;
      if (_depth == 0) {
        _lastSystemCameraEnd = DateTime.now();
        _systemCameraActive.value = false;
      }
    }
  }
}
