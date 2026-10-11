import 'dart:io';

import 'package:dony/core/services/app_log.dart';
import 'package:path_provider/path_provider.dart';

/// Photos des étapes de la file hors ligne, copiées hors du cache.
///
/// FLUTTER-MJ : la photo prise par l'appareil vit dans le répertoire
/// temporaire, que le système purge sans prévenir. Une étape restée en file
/// pointait alors vers un fichier disparu. La copie va dans le répertoire de
/// support de l'app (jamais purgé par le système, jamais sauvegardé par
/// l'utilisateur), et la file ne garde que son nom : sur iOS, le chemin
/// absolu du conteneur change à chaque mise à jour de l'app.
class TrackingQueuePhotoStore {
  TrackingQueuePhotoStore({
    Future<Directory> Function()? baseDirectory,
    DateTime Function()? now,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  static const folder = 'tracking_queue_photos';

  final Future<Directory> Function() _baseDirectory;
  final DateTime Function() _now;

  Future<Directory> _directory() async {
    final dir = Directory('${(await _baseDirectory()).path}/$folder');
    await dir.create(recursive: true);
    return dir;
  }

  /// Copie [path] dans le répertoire persistant et rend le nom de la copie,
  /// ou `null` si la copie a échoué (la file garde alors le chemin d'origine).
  Future<String?> keep(String path) async {
    try {
      final dir = await _directory();
      final name = '${_now().microsecondsSinceEpoch}_${_basename(path)}';
      await File(path).copy('${dir.path}/$name');
      return name;
    } catch (error) {
      AppLog.warn(
        'tracking.queue_photo_copy_failed',
        data: {'type': error.runtimeType.toString()},
      );
      return null;
    }
  }

  /// Chemin actuel de la copie [name].
  Future<String> resolve(String name) async =>
      '${(await _directory()).path}/${_basename(name)}';

  /// Dernier segment du chemin : un nom lu dans la file ne sort jamais du
  /// répertoire des copies.
  static String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

  /// Supprime la copie [name] ; sans effet si elle n'existe plus.
  Future<void> remove(String? name) async {
    if (name == null) return;
    try {
      await File(await resolve(name)).delete();
    } catch (_) {
      // Déjà absente : rien à libérer.
    }
  }
}
