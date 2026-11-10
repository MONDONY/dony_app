import 'dart:convert';

import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réponses des visiteurs sans compte, gardées sur le téléphone
/// (`shared_preferences`) jusqu'à leur envoi au back à la connexion.
class VideoModalLocalDatasource {
  VideoModalLocalDatasource({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const historyKey = 'video_modal_history_v1';
  static const pendingKey = 'video_modal_pending_v1';

  /// Moments d'action (étape 2), propres à l'appareil : jamais envoyés au
  /// back, jamais effacés par la synchro de la connexion.
  static const lastAppVersionKey = 'video_modal_last_app_version_v1';
  static const tripViewsKey = 'video_modal_trip_views_v1';

  Future<VideoModalLocalHistory> readHistory() async {
    final raw = (await _prefs()).getString(historyKey);
    return VideoModalLocalHistory.fromJson(_decode(raw));
  }

  Future<void> writeHistory(VideoModalLocalHistory history) async {
    await (await _prefs()).setString(historyKey, jsonEncode(history.toJson()));
  }

  Future<List<PendingVideoModalEvent>> readPending() async {
    final decoded = _decode((await _prefs()).getString(pendingKey));
    if (decoded is! List) return const [];
    return decoded
        .map(PendingVideoModalEvent.tryParse)
        .whereType<PendingVideoModalEvent>()
        .toList(growable: false);
  }

  Future<void> writePending(List<PendingVideoModalEvent> pending) async {
    final prefs = await _prefs();
    if (pending.isEmpty) {
      await prefs.remove(pendingKey);
      return;
    }
    await prefs.setString(
      pendingKey,
      jsonEncode(pending.map((e) => e.toJson()).toList()),
    );
  }

  /// Dernière version de l'app vue au lancement (`1.0.6`), `null` tant
  /// qu'aucune n'a été mémorisée (première installation).
  Future<String?> readLastAppVersion() async {
    final value = (await _prefs()).getString(lastAppVersionKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> writeLastAppVersion(String version) async {
    await (await _prefs()).setString(lastAppVersionKey, version);
  }

  /// Consultations des fiches trajet par identifiant de trajet, du moins
  /// récent au plus récent (l'ordre de la liste fait foi pour l'élagage).
  Future<Map<String, int>> readTripViews() async {
    final decoded = _decode((await _prefs()).getString(tripViewsKey));
    if (decoded is! Map) return {};
    final result = <String, int>{};
    for (final e in decoded.entries) {
      final count = e.value;
      if (e.key is String && count is int && count > 0) {
        result[e.key as String] = count;
      }
    }
    return result;
  }

  Future<void> writeTripViews(Map<String, int> views) async {
    final prefs = await _prefs();
    if (views.isEmpty) {
      await prefs.remove(tripViewsKey);
      return;
    }
    await prefs.setString(tripViewsKey, jsonEncode(views));
  }

  /// Efface tout l'historique local (après la synchro au back).
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(historyKey);
    await prefs.remove(pendingKey);
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
