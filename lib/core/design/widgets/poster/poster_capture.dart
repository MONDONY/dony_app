import 'dart:async';
import 'dart:ui' as ui;

import 'package:dony/core/design/widgets/poster/poster_parts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Rastérise une affiche en PNG, une seule fois par écran.
///
/// Partagé par l'affiche de trajet et celle de demande d'envoi. Le
/// `RepaintBoundary` porté par [key] doit garder la taille logique de
/// l'affiche : la réduction appliquée pour l'aperçu (un `FittedBox`) est posée
/// au-dessus de lui, hors du calque capturé, si bien que la sortie fait
/// toujours 1080 x 1350.
///
/// Attention : sur l'émulateur `dony_test`, dont le GPU est logiciel, la
/// capture d'un `RepaintBoundary` rend un écran noir ou gèle. Valider sur un
/// appareil réel, pas sur l'AVD.
class PosterCapture {
  PosterCapture({this.images = const []});

  /// Images réseau peintes par l'affiche (photo du colis), à décoder avant la
  /// capture au même titre que les assets.
  final List<ImageProvider> images;

  final GlobalKey key = GlobalKey();

  /// PNG mémoïsé : l'affiche est immuable pour la durée de l'écran, et
  /// l'écran invite à enchaîner « Partager » puis « Enregistrer ». Sans
  /// mémoïsation, chaque action referait une rastérisation identique.
  Uint8List? _bytes;

  Future<void>? _ready;

  /// Lance le décodage des images, à appeler dès `didChangeDependencies`.
  ///
  /// `toImage()` fige ce qui est peint à l'instant où on l'appelle. Un
  /// `Image.asset` se charge de façon asynchrone : sans cette attente, un
  /// utilisateur qui tape « Partager » aussitôt l'écran ouvert exporterait une
  /// affiche amputée de son mot-logo et de ses badges. Une photo qui ne se
  /// charge pas (URL présignée expirée, hors ligne) ne bloque rien :
  /// `precacheImage` avale l'erreur et l'affiche garde son illustration.
  void warmUp(BuildContext context) {
    _ready ??= Future.wait([
      for (final asset in PosterAssets.all)
        precacheImage(AssetImage(asset), context),
      for (final image in images)
        precacheImage(image, context, onError: (_, _) {}),
    ]);
  }

  Future<Uint8List?> capture() async {
    if (_bytes != null) {
      return _bytes;
    }
    // Les images doivent être décodées ET peintes. Le décodage seul ne suffit
    // pas : il déclenche une reconstruction, dont il faut attendre la frame,
    // faute de quoi on rastérise l'état précédent.
    await _ready;
    await WidgetsBinding.instance.endOfFrame;
    return rasterize();
  }

  /// Rastérisation seule, sans attente des images ni de la frame. Séparée de
  /// [capture] pour les tests, où `endOfFrame` n'est jamais servi dans un
  /// `runAsync`.
  @visibleForTesting
  Future<Uint8List?> rasterize() async {
    final cached = _bytes;
    if (cached != null) {
      return cached;
    }
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: PosterLayout.pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      // ~5,8 Mo de pixels natifs : sans dispose explicite, la libération
      // dépend d'un finalizer non déterministe.
      return _bytes = byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
