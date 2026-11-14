import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:equatable/equatable.dart';

/// Ce qu'un visiteur sans compte a fait d'une version : affichages, dernier
/// affichage, statut le plus fort atteint (jamais rétrogradé, comme côté back)
/// et case « Ne plus afficher ».
class VideoModalVersionRecord extends Equatable {
  const VideoModalVersionRecord({
    this.displays = 0,
    this.status,
    this.lastShownAt,
    this.dontShowAgain = false,
  });

  final int displays;
  final VideoModalEventType? status;
  final DateTime? lastShownAt;
  final bool dontShowAgain;

  bool get answered => status?.isAnswer ?? false;
  bool get watched => status?.isWatch ?? false;

  /// [at] : heure de l'événement, retenue comme dernier affichage pour SHOWN.
  VideoModalVersionRecord apply(VideoModalEventType event, {DateTime? at}) {
    if (event == VideoModalEventType.dontShowAgain) {
      return VideoModalVersionRecord(
        displays: displays,
        status: status,
        lastShownAt: lastShownAt,
        dontShowAgain: true,
      );
    }
    final current = status;
    final shown = event == VideoModalEventType.shown;
    return VideoModalVersionRecord(
      displays: shown ? displays + 1 : displays,
      status: current == null || event.index > current.index ? event : current,
      lastShownAt: shown ? (at ?? lastShownAt) : lastShownAt,
      dontShowAgain: dontShowAgain,
    );
  }

  Map<String, Object?> toJson() => {
    'displays': displays,
    'status': status?.wire,
    if (lastShownAt != null)
      'lastShownAt': lastShownAt!.toUtc().toIso8601String(),
    if (dontShowAgain) 'dontShowAgain': true,
  };

  static VideoModalVersionRecord fromJson(Object? json) {
    if (json is! Map) return const VideoModalVersionRecord();
    final displays = json['displays'];
    final lastShown = json['lastShownAt'];
    final status = VideoModalEventType.fromWire(json['status']);
    return VideoModalVersionRecord(
      displays: displays is int ? displays : 0,
      status: status != null && status.isStatus ? status : null,
      lastShownAt: lastShown is String ? DateTime.tryParse(lastShown) : null,
      dontShowAgain: json['dontShowAgain'] == true,
    );
  }

  @override
  List<Object?> get props => [displays, status, lastShownAt, dontShowAgain];
}

/// Historique local d'un visiteur sans compte, campagne par campagne puis
/// version par version. Aucun plafond global : seule la fréquence de chaque
/// campagne décide.
class VideoModalLocalHistory extends Equatable {
  const VideoModalLocalHistory([this.campaigns = const {}]);

  final Map<String, Map<int, VideoModalVersionRecord>> campaigns;

  bool get isEmpty => campaigns.isEmpty;

  VideoModalVersionRecord recordOf(String id, int version) =>
      campaigns[id]?[version] ?? const VideoModalVersionRecord();

  /// [at] : heure de l'événement (SHOWN : dernier affichage de la version).
  VideoModalLocalHistory apply(
    String id,
    int version,
    VideoModalEventType event, {
    DateTime? at,
  }) {
    final versions = Map<int, VideoModalVersionRecord>.of(
      campaigns[id] ?? const {},
    );
    versions[version] = recordOf(id, version).apply(event, at: at);
    return VideoModalLocalHistory({...campaigns, id: versions});
  }

  /// Mêmes règles que le filtre du back pour un compte : « Ne plus afficher »,
  /// réponse (si la campagne s'arrête après une réponse), fréquence, public de
  /// la version.
  bool isEligible(VideoModalCampaign campaign, {DateTime? now}) {
    final versions = campaigns[campaign.id] ?? const {};
    final current =
        versions[campaign.version] ?? const VideoModalVersionRecord();
    if (current.dontShowAgain) return false;
    if (campaign.stopAfterAnswer && current.answered) return false;
    switch (campaign.frequency) {
      case VideoModalFrequency.once:
        if (current.displays >= 1) return false;
      case VideoModalFrequency.upToN:
        if (current.displays >= campaign.maxDisplays) return false;
      case VideoModalFrequency.everyOpen:
      case VideoModalFrequency.everyTime:
        break;
      case VideoModalFrequency.everyNDays:
        final last = current.lastShownAt;
        final days = campaign.frequencyDays;
        if (last != null &&
            days != null &&
            (now ?? DateTime.now()).difference(last) < Duration(days: days)) {
          return false;
        }
    }
    // Quand une réponse ne bloque pas, celle de la version courante ne doit
    // pas non plus exclure le public « jamais répondu ».
    final others = campaign.stopAfterAnswer
        ? versions.values
        : versions.entries
              .where((e) => e.key != campaign.version)
              .map((e) => e.value);
    return switch (campaign.audience) {
      VideoModalAudience.everyone => true,
      VideoModalAudience.neverAnswered => !others.any((r) => r.answered),
      VideoModalAudience.notWatchedPrevious => !versions.entries.any(
        (e) => e.key < campaign.version && e.value.watched,
      ),
    };
  }

  Map<String, Object?> toJson() => {
    'v': 2,
    'campaigns': {
      for (final c in campaigns.entries)
        c.key: {for (final v in c.value.entries) '${v.key}': v.value.toJson()},
    },
  };

  /// Lit l'ancien format (campagnes à la racine) comme le nouveau
  /// (`{"v": 2, "campaigns": {...}}`). Une clé inconnue (ancien `lastModalAt`)
  /// est ignorée.
  static VideoModalLocalHistory fromJson(Object? json) {
    if (json is! Map) return const VideoModalLocalHistory();
    final isV2 = json['v'] == 2 && json['campaigns'] is Map;
    final raw = isV2 ? json['campaigns'] as Map : json;
    final result = <String, Map<int, VideoModalVersionRecord>>{};
    for (final c in raw.entries) {
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
