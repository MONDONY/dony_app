import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:equatable/equatable.dart';

/// Ce qu'un visiteur sans compte a fait d'une version : affichages et statut
/// le plus fort atteint (jamais rétrogradé, comme côté back).
class VideoModalVersionRecord extends Equatable {
  const VideoModalVersionRecord({this.displays = 0, this.status});

  final int displays;
  final VideoModalEventType? status;

  bool get answered => status?.isAnswer ?? false;
  bool get watched => status?.isWatch ?? false;

  VideoModalVersionRecord apply(VideoModalEventType event) {
    final current = status;
    return VideoModalVersionRecord(
      displays: event == VideoModalEventType.shown ? displays + 1 : displays,
      status: current == null || event.index > current.index ? event : current,
    );
  }

  Map<String, Object?> toJson() => {
    'displays': displays,
    'status': status?.wire,
  };

  static VideoModalVersionRecord fromJson(Object? json) {
    if (json is! Map) return const VideoModalVersionRecord();
    final displays = json['displays'];
    return VideoModalVersionRecord(
      displays: displays is int ? displays : 0,
      status: VideoModalEventType.fromWire(json['status']),
    );
  }

  @override
  List<Object?> get props => [displays, status];
}

/// Historique local des réponses d'un visiteur sans compte, campagne par
/// campagne puis version par version.
class VideoModalLocalHistory extends Equatable {
  const VideoModalLocalHistory([this.campaigns = const {}]);

  final Map<String, Map<int, VideoModalVersionRecord>> campaigns;

  bool get isEmpty => campaigns.isEmpty;

  VideoModalVersionRecord recordOf(String id, int version) =>
      campaigns[id]?[version] ?? const VideoModalVersionRecord();

  VideoModalLocalHistory apply(
    String id,
    int version,
    VideoModalEventType event,
  ) {
    final versions = Map<int, VideoModalVersionRecord>.of(
      campaigns[id] ?? const {},
    );
    versions[version] = recordOf(id, version).apply(event);
    return VideoModalLocalHistory({...campaigns, id: versions});
  }

  /// Mêmes règles que le filtre du back pour un compte : plafond
  /// d'affichages, version déjà répondue, public de la version.
  bool isEligible(VideoModalCampaign campaign) {
    final versions = campaigns[campaign.id] ?? const {};
    final current =
        versions[campaign.version] ?? const VideoModalVersionRecord();
    if (current.answered) return false;
    if (current.displays >= campaign.maxDisplays) return false;
    return switch (campaign.audience) {
      VideoModalAudience.everyone => true,
      VideoModalAudience.neverAnswered => !versions.values.any(
        (r) => r.answered,
      ),
      VideoModalAudience.notWatchedPrevious => !versions.entries.any(
        (e) => e.key < campaign.version && e.value.watched,
      ),
    };
  }

  Map<String, Object?> toJson() => {
    for (final c in campaigns.entries)
      c.key: {for (final v in c.value.entries) '${v.key}': v.value.toJson()},
  };

  static VideoModalLocalHistory fromJson(Object? json) {
    if (json is! Map) return const VideoModalLocalHistory();
    final result = <String, Map<int, VideoModalVersionRecord>>{};
    for (final c in json.entries) {
      final versions = c.value;
      if (c.key is! String || versions is! Map) continue;
      final parsed = <int, VideoModalVersionRecord>{};
      for (final v in versions.entries) {
        final version = int.tryParse('${v.key}');
        if (version == null) continue;
        parsed[version] = VideoModalVersionRecord.fromJson(v.value);
      }
      result[c.key as String] = parsed;
    }
    return VideoModalLocalHistory(result);
  }

  @override
  List<Object?> get props => [campaigns];
}

/// Événement d'un visiteur sans compte, en attente d'envoi au back à la
/// connexion (`occurredAt` garde l'heure réelle de la réponse).
class PendingVideoModalEvent extends Equatable {
  const PendingVideoModalEvent({
    required this.campaignId,
    required this.version,
    required this.event,
    required this.occurredAt,
  });

  final String campaignId;
  final int version;
  final VideoModalEventType event;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'campaignId': campaignId,
    'version': version,
    'event': event.wire,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  static PendingVideoModalEvent? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['campaignId'];
    final version = json['version'];
    final event = VideoModalEventType.fromWire(json['event']);
    final at = DateTime.tryParse('${json['occurredAt']}');
    if (id is! String || version is! int || event == null || at == null) {
      return null;
    }
    return PendingVideoModalEvent(
      campaignId: id,
      version: version,
      event: event,
      occurredAt: at,
    );
  }

  @override
  List<Object?> get props => [campaignId, version, event, occurredAt];
}
