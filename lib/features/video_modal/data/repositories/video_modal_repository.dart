import 'package:dio/dio.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_remote_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Modals vidéo : campagnes éligibles et réponses.
///
/// Ne lève jamais : back absent (404), hors ligne ou réponse illisible
/// donnent « aucune campagne », et une réponse non envoyée est perdue sans
/// bruit pour un compte (le compteur du back en sera simplement plus bas).
class VideoModalRepository {
  VideoModalRepository(
    this._remote,
    this._local, {
    DateTime Function()? clock,
    Future<String?> Function()? appVersion,
    String Function()? platform,
  }) : _clock = clock ?? DateTime.now,
       _appVersionLoader = appVersion ?? readAppVersion,
       _platform = platform ?? _currentPlatform;

  final VideoModalRemoteDatasource _remote;
  final VideoModalLocalDatasource _local;
  final DateTime Function() _clock;
  final Future<String?> Function() _appVersionLoader;
  final String Function() _platform;

  /// Version de l'app (`1.0.6`, sans le numéro de build), lue une fois.
  static Future<String?> readAppVersion() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version;
      return version.isEmpty ? null : version;
    } on Object {
      return null;
    }
  }

  static String _currentPlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Campagnes à proposer, triées par priorité (à égalité, l'ordre du back).
  /// Sans compte, les règles du back (« Ne plus afficher », réponse,
  /// fréquence, public) sont appliquées avec
  /// l'historique local.
  Future<List<VideoModalCampaign>> loadEligible({
    required String lang,
    required bool realSession,
  }) async {
    final List<VideoModalCampaign> campaigns;
    try {
      String? version;
      try {
        version = await _appVersionLoader();
      } on Object {
        version = null;
      }
      campaigns = VideoModalCampaign.parseList(
        await _remote.fetchEligible(
          lang,
          appVersion: version,
          platform: _platform(),
        ),
      );
    } on Object catch (e) {
      AppLog.debug(
        'video_modal.eligible_unavailable',
        data: {'error': '${e.runtimeType}'},
      );
      return const [];
    }
    final capped = campaigns.where((c) => c.underDisplayCap);
    if (realSession) return capped.toList(growable: false);
    final history = await _readHistory();
    final now = _clock();
    return capped
        .where((c) => history.isEligible(c, now: now))
        .toList(growable: false);
  }

  /// Envoie l'événement au back (compte) ou le garde sur le téléphone
  /// (visiteur), pour l'appliquer localement puis l'envoyer à la connexion.
  Future<void> record(
    VideoModalCampaign campaign,
    VideoModalEventType event, {
    required bool realSession,
  }) async {
    if (realSession) {
      try {
        await _remote.postEvent(
          campaign.id,
          version: campaign.version,
          event: event.wire,
        );
      } on Object catch (e) {
        AppLog.debug(
          'video_modal.event_not_sent',
          data: {'error': '${e.runtimeType}'},
        );
      }
      return;
    }
    try {
      final history = await _readHistory();
      final at = _clock();
      await _local.writeHistory(
        history.apply(campaign.id, campaign.version, event, at: at),
      );
      final pending = await _local.readPending();
      await _local.writePending([
        ...pending,
        PendingVideoModalEvent(
          campaignId: campaign.id,
          version: campaign.version,
          event: event,
          occurredAt: at,
        ),
      ]);
    } on Object catch (e) {
      AppLog.debug(
        'video_modal.local_write_failed',
        data: {'error': '${e.runtimeType}'},
      );
    }
  }

  /// À la connexion : envoie au back les réponses faites sans compte, dans
  /// l'ordre, avec leur heure réelle, puis efface l'historique local.
  ///
  /// Une campagne inconnue (404) ou un 4xx ne sera jamais acceptée : la ligne
  /// est abandonnée. Une panne réseau ou un 5xx arrête l'envoi, le reste est
  /// gardé pour la prochaine connexion. Rend le nombre d'événements envoyés.
  Future<int> syncGuestEvents() async {
    final List<PendingVideoModalEvent> pending;
    try {
      pending = await _local.readPending();
    } on Object {
      return 0;
    }
    if (pending.isEmpty) {
      await _clearQuietly();
      return 0;
    }
    var sent = 0;
    for (var i = 0; i < pending.length; i++) {
      final e = pending[i];
      try {
        await _remote.postEvent(
          e.campaignId,
          version: e.version,
          event: e.event.wire,
          occurredAt: e.occurredAt,
        );
        sent++;
      } on DioException catch (err) {
        final status = err.response?.statusCode;
        if (status != null && status >= 400 && status < 500) continue;
        await _keep(pending.sublist(i));
        return sent;
      } on Object {
        await _keep(pending.sublist(i));
        return sent;
      }
    }
    await _clearQuietly();
    return sent;
  }

  Future<VideoModalLocalHistory> _readHistory() async {
    try {
      return await _local.readHistory();
    } on Object {
      return const VideoModalLocalHistory();
    }
  }

  Future<void> _keep(List<PendingVideoModalEvent> rest) async {
    try {
      await _local.writePending(rest);
    } on Object {
      // Rien de plus à faire : la ligne sera perdue.
    }
  }

  Future<void> _clearQuietly() async {
    try {
      await _local.clear();
    } on Object {
      // Historique illisible : il sera réécrit à la prochaine réponse.
    }
  }
}
