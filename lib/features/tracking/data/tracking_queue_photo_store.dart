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
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? now,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  static const folder = 'tracking_queue_photos';

  final Future<Directory> Function() _baseDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _now;

  Future<Directory> _directory() async {
    final dir = Directory('${(await _baseDirectory()).path}/$folder');
    await dir.create(recursive: true);
    return dir;
  }

  /// Copie [path] dans le répertoire persistant et rend le nom de la copie,
  /// ou `null` si la copie a échoué.
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

  /// Reprend la photo d'une entrée mise en file avant les copies (#599), qui
  /// ne garde que son chemin absolu [legacyPath] : rend le nom de sa copie,
  /// ou `null` si le fichier est introuvable.
  ///
  /// FLUTTER-F : sur iOS, ce chemin pointe vers le répertoire temporaire de
  /// l'ancien conteneur, dont l'identifiant change à chaque mise à jour. Le
  /// fichier, s'il a survécu, est cherché par son nom dans le répertoire
  /// temporaire actuel, puis parmi les copies.
  Future<String?> adoptLegacy(String legacyPath) async {
    try {
      if (File(legacyPath).existsSync()) return await keep(legacyPath);
      final name = _basename(legacyPath);
      if (name.isEmpty) return null;
      final inTemp = File('${(await _temporaryDirectory()).path}/$name');
      if (inTemp.existsSync()) return await keep(inTemp.path);
      if (File(await resolve(name)).existsSync()) return name;
      return null;
    } catch (error) {
      AppLog.warn(
        'tracking.queue_photo_legacy_failed',
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
