import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:equatable/equatable.dart';

/// Ce qu'une recherche a cherché : un trajet ou un colis.
enum VideoModalSearchKind { trip, parcel }

/// Un « moment » : quelque chose vient de se passer dans l'app (action
/// réussie, recherche, favori, formulaire quitté…) et une campagne peut s'y
/// ouvrir. L'app l'émet vers l'hôte des modals avec son contexte.
///
/// Un moment porte UN seul déclencheur : une recherche donne soit « sans
/// résultat », soit « peu de résultats », jamais les deux.
class VideoModalMoment extends Equatable {
  const VideoModalMoment._(
    this.trigger, {
    this.corridor,
    this.resultCount,
    this.tripId,
    this.viewCount,
  });

  /// Action ou événement sans autre contexte que le corridor éventuel
  /// (livraison, paiement, publication, identité, favori, formulaire quitté,
  /// mise à jour de l'app).
  factory VideoModalMoment.action(
    VideoModalTrigger trigger, {
    VideoModalMomentCorridor? corridor,
  }) {
    assert(
      trigger.isMoment &&
          trigger != VideoModalTrigger.searchNoTripResults &&
          trigger != VideoModalTrigger.searchNoParcelResults &&
          trigger != VideoModalTrigger.searchFewResults &&
          trigger != VideoModalTrigger.tripViewedRepeatedly,
      'utiliser VideoModalMoment.search / .tripViewed',
    );
    return VideoModalMoment._(trigger, corridor: corridor);
  }

  /// Résultat d'une recherche : sans résultat (0) ou peu de résultats (au
  /// moins 1, le seuil de chaque campagne tranche).
  factory VideoModalMoment.search({
    required VideoModalSearchKind kind,
    required int resultCount,
    VideoModalMomentCorridor? corridor,
  }) {
    final count = resultCount < 0 ? 0 : resultCount;
    final trigger = count == 0
        ? (kind == VideoModalSearchKind.trip
              ? VideoModalTrigger.searchNoTripResults
              : VideoModalTrigger.searchNoParcelResults)
        : VideoModalTrigger.searchFewResults;
    return VideoModalMoment._(trigger, corridor: corridor, resultCount: count);
  }

  /// Fiche d'un trajet consultée pour la [viewCount]-ième fois.
  const factory VideoModalMoment.tripViewed({
    required String tripId,
    required int viewCount,
    VideoModalMomentCorridor? corridor,
  }) = _TripViewedMoment;

  final VideoModalTrigger trigger;
  final VideoModalMomentCorridor? corridor;

  /// Nombre de résultats d'une recherche.
  final int? resultCount;

  /// Fiche trajet consultée : identifiant et nombre de consultations.
  final String? tripId;
  final int? viewCount;

  /// La campagne peut s'ouvrir pour ce moment : elle liste le déclencheur,
  /// ses options sont respectées (seuil de « peu de résultats », nombre de
  /// consultations) et, pour les déclencheurs concernés, son corridor
  /// correspond (liste vide : tous).
  bool accepts(VideoModalCampaign campaign) {
    if (!campaign.triggers.contains(trigger)) return false;
    switch (trigger) {
      case VideoModalTrigger.searchFewResults:
        final n = resultCount ?? 0;
        if (n < 1 || n > campaign.triggerOptions.fewResultsMax) return false;
      case VideoModalTrigger.tripViewedRepeatedly:
        if ((viewCount ?? 0) < campaign.triggerOptions.tripViewedTimes) {
          return false;
        }
      default:
        break;
    }
    if (trigger.usesCorridors && campaign.corridors.isNotEmpty) {
      return campaign.corridors.any((c) => c.matches(corridor));
    }
    return true;
  }

  @override
  List<Object?> get props => [
    trigger,
    corridor,
    resultCount,
    tripId,
    viewCount,
  ];
}

final class _TripViewedMoment extends VideoModalMoment {
  const _TripViewedMoment({
    required String tripId,
    required int viewCount,
    super.corridor,
  }) : super._(
         VideoModalTrigger.tripViewedRepeatedly,
         tripId: tripId,
         viewCount: viewCount,
       );
}
