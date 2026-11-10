import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:equatable/equatable.dart';

enum VideoModalStatus { initial, loading, ready }

class VideoModalState extends Equatable {
  const VideoModalState({
    this.status = VideoModalStatus.initial,
    this.campaigns = const [],
    this.shownThisSession = false,
    this.appOpenConsumed = false,
    this.loadedLang,
    this.loadedForRealSession,
  });

  final VideoModalStatus status;
  final List<VideoModalCampaign> campaigns;

  /// Un seul modal par session (lancement de l'app).
  final bool shownThisSession;
  final bool appOpenConsumed;
  final String? loadedLang;
  final bool? loadedForRealSession;

  /// Campagne à ouvrir pour l'un de ces déclencheurs, ou `null`. À
  /// déclencheur égal, l'ordre du back (version la plus récente d'abord).
  VideoModalCampaign? candidateFor(Set<VideoModalTrigger> triggers) {
    if (status != VideoModalStatus.ready || shownThisSession) return null;
    for (final c in campaigns) {
      if (c.triggers.any(triggers.contains)) return c;
    }
    return null;
  }

  VideoModalState copyWith({
    VideoModalStatus? status,
    List<VideoModalCampaign>? campaigns,
    bool? shownThisSession,
    bool? appOpenConsumed,
    String? loadedLang,
    bool? loadedForRealSession,
  }) => VideoModalState(
    status: status ?? this.status,
    campaigns: campaigns ?? this.campaigns,
    shownThisSession: shownThisSession ?? this.shownThisSession,
    appOpenConsumed: appOpenConsumed ?? this.appOpenConsumed,
    loadedLang: loadedLang ?? this.loadedLang,
    loadedForRealSession: loadedForRealSession ?? this.loadedForRealSession,
  );

  @override
  List<Object?> get props => [
    status,
    campaigns,
    shownThisSession,
    appOpenConsumed,
    loadedLang,
    loadedForRealSession,
  ];
}
