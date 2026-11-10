import 'dart:async';

import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/repositories/video_modal_repository.dart';
import 'package:flutter/widgets.dart';

/// Un moment émis, avec l'écran d'où il part (facultatif) et son heure.
///
/// [origin] sert à ouvrir le modal sur l'écran concerné tant qu'il est monté
/// (écran de succès, par exemple) ; sans lui, ou une fois l'écran fermé, le
/// modal s'ouvre sur l'écran du shell.
class VideoModalMomentSignal {
  const VideoModalMomentSignal(this.moment, this.emittedAt, {this.origin});

  final VideoModalMoment moment;
  final DateTime emittedAt;
  final BuildContext? origin;
}

/// Point d'entrée UNIQUE des moments d'action des modals : les écrans et les
/// BLoCs n'appellent jamais l'hôte, ils appellent [notify]. L'hôte
/// (`VideoModalHost`) écoute [signals] et décide d'ouvrir ou non un modal
/// (campagnes déjà chargées pour la session : aucun appel réseau ici).
///
/// Garde aussi, sur le téléphone, ce que deux moments calculent dans l'app :
/// la version de l'app vue au dernier lancement (`APP_UPDATED`) et le
/// nombre de consultations de chaque fiche trajet (`TRIP_VIEWED_REPEATEDLY`).
/// Ne lève jamais : un stockage illisible fait perdre le moment, pas l'écran.
class VideoModalMoments {
  VideoModalMoments({
    VideoModalLocalDatasource? local,
    Future<String?> Function()? appVersion,
    DateTime Function()? clock,
  }) : _local = local ?? VideoModalLocalDatasource(),
       _appVersion = appVersion ?? VideoModalRepository.readAppVersion,
       _clock = clock ?? DateTime.now;

  /// Instance de l'app. Les tests la remplacent par [useForTest].
  static VideoModalMoments instance = VideoModalMoments();

  /// Fiches trajet dont on garde le compteur : les plus récentes seulement.
  static const maxTrackedTrips = 50;

  /// Une fiche trajet n'a de sens qu'à partir de la deuxième consultation
  /// (borne basse de `tripViewedTimes`).
  static const minViewsToEmit = 2;

  final VideoModalLocalDatasource _local;
  final Future<String?> Function() _appVersion;
  final DateTime Function() _clock;
  final StreamController<VideoModalMomentSignal> _controller =
      StreamController<VideoModalMomentSignal>.broadcast();

  /// Écriture des compteurs, une à la fois (lecture puis écriture).
  Future<void> _tripViewsQueue = Future<void>.value();

  /// Entrée des écrans et des BLoCs. Sans effet si personne n'écoute (hors
  /// shell, tests) ; ne lève jamais.
  static void notify(VideoModalMoment moment, {BuildContext? origin}) =>
      instance.emit(moment, origin: origin);

  /// Consultation d'une fiche trajet : le compteur local monte, et le moment
  /// part à partir de la deuxième consultation (chaque campagne a son seuil).
  static void notifyTripViewed({
    required String tripId,
    VideoModalMomentCorridor? corridor,
  }) => unawaited(instance.recordTripView(tripId, corridor: corridor));

  @visibleForTesting
  static void useForTest(VideoModalMoments moments) => instance = moments;

  @visibleForTesting
  static void resetForTest() => instance = VideoModalMoments();

  Stream<VideoModalMomentSignal> get signals => _controller.stream;

  void emit(VideoModalMoment moment, {BuildContext? origin}) {
    if (_controller.isClosed || !_controller.hasListener) return;
    _controller.add(VideoModalMomentSignal(moment, _clock(), origin: origin));
  }

  /// `APP_UPDATED` : première ouverture après un changement de version. À la
  /// toute première installation (aucune version mémorisée) la version est
  /// seulement retenue. Rend `true` si le moment a été émis.
  Future<bool> checkAppUpdated() async {
    try {
      final current = await _appVersion();
      if (current == null || current.isEmpty) return false;
      final last = await _local.readLastAppVersion();
      if (last == current) return false;
      await _local.writeLastAppVersion(current);
      if (last == null) return false;
      emit(VideoModalMoment.action(VideoModalTrigger.appUpdated));
      return true;
    } on Object {
      return false;
    }
  }

  /// Compte une consultation de la fiche [tripId] et émet le moment à partir
  /// de [minViewsToEmit]. Rend le nombre de consultations (0 si illisible).
  Future<int> recordTripView(
    String tripId, {
    VideoModalMomentCorridor? corridor,
  }) {
    if (tripId.isEmpty) return Future.value(0);
    final completer = Completer<int>();
    _tripViewsQueue = _tripViewsQueue.then((_) async {
      try {
        final views = await _local.readTripViews();
        final count = (views.remove(tripId) ?? 0) + 1;
        // Réinséré en dernier : les plus anciens partent en premier.
        views[tripId] = count;
        while (views.length > maxTrackedTrips) {
          views.remove(views.keys.first);
        }
        await _local.writeTripViews(views);
        if (count >= minViewsToEmit) {
          emit(
            VideoModalMoment.tripViewed(
              tripId: tripId,
              viewCount: count,
              corridor: corridor,
            ),
          );
        }
        completer.complete(count);
      } on Object {
        completer.complete(0);
      }
    });
    return completer.future;
  }

  /// Remise à zéro du compteur d'une fiche trajet, une fois le modal affiché.
  Future<void> resetTripViews(String tripId) {
    final completer = Completer<void>();
    _tripViewsQueue = _tripViewsQueue.then((_) async {
      try {
        final views = await _local.readTripViews();
        if (views.remove(tripId) != null) await _local.writeTripViews(views);
      } on Object {
        // Compteur illisible : il sera réécrit à la prochaine consultation.
      }
      completer.complete();
    });
    return completer.future;
  }

  Future<void> dispose() => _controller.close();
}
