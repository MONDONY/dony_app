import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:equatable/equatable.dart';

enum VideoModalStatus { initial, loading, ready }

/// Case de la limite « un seul modal par lancement » : le type du modal
/// (vidéo ou information) croisé avec la nature de son déclencheur (« où » :
/// lancement, onglet, formulaire ; ou « moment » d'action). Les quatre cases
/// sont indépendantes : un modal affiché dans l'une ne bloque jamais les autres.
enum VideoModalSlot {
  videoAmbient,
  videoMoment,
  infoAmbient,
  infoMoment;

  static VideoModalSlot of(VideoModalCampaign c, {required bool moment}) =>
      c.isInfo
      ? (moment ? infoMoment : infoAmbient)
      : (moment ? videoMoment : videoAmbient);
}

class VideoModalState extends Equatable {
  const VideoModalState({
    this.status = VideoModalStatus.initial,
    this.campaigns = const [],
    this.usedSlots = const {},
    this.loadedAt,
    this.appOpenConsumed = false,
    this.loadedLang,
    this.loadedForRealSession,
  });

  final VideoModalStatus status;
  final List<VideoModalCampaign> campaigns;

  /// Cases déjà occupées pendant ce lancement. Les campagnes « à chaque fois »
  /// n'en occupent aucune.
  final Set<VideoModalSlot> usedSlots;

  /// Fin du dernier chargement des campagnes (réussi ou non).
  final DateTime? loadedAt;
  final bool appOpenConsumed;
  final String? loadedLang;
  final bool? loadedForRealSession;

  /// Campagne à ouvrir pour l'un de ces déclencheurs, ou `null`. À
  /// déclencheur égal, l'ordre du back (version la plus récente d'abord).
  VideoModalCampaign? candidateFor(Set<VideoModalTrigger> triggers) {
    if (status != VideoModalStatus.ready) return null;
    for (final c in campaigns) {
      if (_blocked(c, moment: false)) continue;
      if (c.triggers.any(triggers.contains)) return c;
    }
    return null;
  }

  /// Campagne à ouvrir pour ce moment d'action, ou `null` : même ordre que
  /// [candidateFor] (priorité puis version la plus récente), et le moment doit
  /// convenir à la campagne (seuils, corridor : voir `VideoModalMoment.accepts`).
  VideoModalCampaign? candidateForMoment(VideoModalMoment moment) {
    if (status != VideoModalStatus.ready) return null;
    for (final c in campaigns) {
      if (_blocked(c, moment: true)) continue;
      if (moment.accepts(c)) return c;
    }
    return null;
  }

  bool _blocked(VideoModalCampaign c, {required bool moment}) =>
      !c.isEveryTime &&
      usedSlots.contains(VideoModalSlot.of(c, moment: moment));

  /// La campagne a déjà occupé sa case (ou n'en occupe jamais).
  bool hasShown(VideoModalCampaign c, {required bool moment}) =>
      c.isEveryTime || usedSlots.contains(VideoModalSlot.of(c, moment: moment));

  VideoModalState copyWith({
    VideoModalStatus? status,
    List<VideoModalCampaign>? campaigns,
    Set<VideoModalSlot>? usedSlots,
    DateTime? loadedAt,
    bool? appOpenConsumed,
    String? loadedLang,
    bool? loadedForRealSession,
  }) => VideoModalState(
    status: status ?? this.status,
    campaigns: campaigns ?? this.campaigns,
    usedSlots: usedSlots ?? this.usedSlots,
    loadedAt: loadedAt ?? this.loadedAt,
    appOpenConsumed: appOpenConsumed ?? this.appOpenConsumed,
    loadedLang: loadedLang ?? this.loadedLang,
    loadedForRealSession: loadedForRealSession ?? this.loadedForRealSession,
  );

  @override
  List<Object?> get props => [
    status,
    campaigns,
    usedSlots,
    loadedAt,
    appOpenConsumed,
    loadedLang,
    loadedForRealSession,
  ];
}
