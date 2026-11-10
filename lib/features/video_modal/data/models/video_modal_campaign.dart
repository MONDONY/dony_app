import 'package:equatable/equatable.dart';

/// Où une campagne peut s'ouvrir (enum `VideoModalTrigger` du back).
enum VideoModalTrigger {
  appOpen('APP_OPEN'),
  searchTab('SEARCH_TAB'),
  activitiesTab('ACTIVITIES_TAB'),
  trackingTab('TRACKING_TAB'),
  messagesTab('MESSAGES_TAB'),
  profileTab('PROFILE_TAB'),
  publishTrip('PUBLISH_TRIP'),
  sendParcel('SEND_PARCEL');

  const VideoModalTrigger(this.wire);

  /// Valeur échangée avec le back, aussi propriété `trigger` des analytics.
  final String wire;

  /// Déclencheur posé devant un formulaire : après le modal, l'app poursuit
  /// vers le formulaire demandé.
  bool get opensForm => this == publishTrip || this == sendParcel;

  static VideoModalTrigger? fromWire(Object? value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }

  /// Onglet du shell (`StatefulShellRoute` de `router.dart`, branches 0 à 4 :
  /// Rechercher, Activités, Suivi, Messages, Moi) vers son déclencheur.
  static VideoModalTrigger? forShellTab(int index) => switch (index) {
    0 => searchTab,
    1 => activitiesTab,
    2 => trackingTab,
    3 => messagesTab,
    4 => profileTab,
    _ => null,
  };
}

/// Public d'une version (enum `VideoModalAudience` du back).
enum VideoModalAudience {
  neverAnswered('NEVER_ANSWERED'),
  everyone('EVERYONE'),
  notWatchedPrevious('NOT_WATCHED_PREVIOUS');

  const VideoModalAudience(this.wire);

  final String wire;

  /// Valeur inconnue ou absente : le public le plus prudent.
  static VideoModalAudience fromWire(Object? value) {
    for (final a in values) {
      if (a.wire == value) return a;
    }
    return neverAnswered;
  }
}

/// Réponse ou affichage (enum `VideoModalEvent` du back), du plus faible au
/// plus fort : un statut n'est jamais rétrogradé.
enum VideoModalEventType {
  shown('SHOWN'),
  dismissed('DISMISSED'),
  opened('OPENED'),
  completed('COMPLETED');

  const VideoModalEventType(this.wire);

  final String wire;

  /// OPENED, COMPLETED ou DISMISSED : la personne a répondu.
  bool get isAnswer => this != shown;

  /// OPENED ou COMPLETED : la vidéo a été ouverte.
  bool get isWatch => this == opened || this == completed;

  static VideoModalEventType? fromWire(Object? value) {
    for (final e in values) {
      if (e.wire == value) return e;
    }
    return null;
  }
}

/// Icône d'un point fort, fermée côté back. Une valeur inconnue retombe sur
/// [star] plutôt que de faire disparaître le point fort.
enum VideoModalIcon {
  parcel('PARCEL'),
  suitcase('SUITCASE'),
  lock('LOCK'),
  search('SEARCH'),
  chat('CHAT'),
  qr('QR'),
  star('STAR'),
  wallet('WALLET');

  const VideoModalIcon(this.wire);

  final String wire;

  static VideoModalIcon fromWire(Object? value) {
    for (final i in values) {
      if (i.wire == value) return i;
    }
    return star;
  }
}

class VideoModalHighlight extends Equatable {
  const VideoModalHighlight({required this.icon, required this.text});

  final VideoModalIcon icon;
  final String text;

  static VideoModalHighlight? tryParse(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return VideoModalHighlight(
      icon: VideoModalIcon.fromWire(json['icon']),
      text: text.trim(),
    );
  }

  @override
  List<Object?> get props => [icon, text];
}

/// Une campagne éligible (`GET /video-modals/eligible`), textes déjà dans la
/// langue demandée.
class VideoModalCampaign extends Equatable {
  const VideoModalCampaign({
    required this.id,
    required this.version,
    required this.triggers,
    required this.title,
    required this.youtubeVideoId,
    this.subtitle,
    this.durationSeconds,
    this.highlights = const [],
    this.primaryLabel,
    this.secondaryLabel,
    this.maxDisplays = defaultMaxDisplays,
    this.displays = 0,
    this.audience = VideoModalAudience.neverAnswered,
  });

  static const defaultMaxDisplays = 3;
  static const maxHighlights = 3;
  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  final String id;
  final int version;
  final Set<VideoModalTrigger> triggers;
  final String title;
  final String? subtitle;
  final String youtubeVideoId;
  final int? durationSeconds;
  final List<VideoModalHighlight> highlights;
  final String? primaryLabel;
  final String? secondaryLabel;
  final int maxDisplays;
  final int displays;
  final VideoModalAudience audience;

  /// Campagne lisible, ou `null` si un champ indispensable manque ou est
  /// invalide : le back peut être plus ancien ou plus récent que l'app, une
  /// entrée inexploitable est ignorée sans erreur.
  static VideoModalCampaign? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final version = _int(json['version']);
    final title = _text(json['title']);
    final videoId = json['youtubeVideoId'];
    final rawTriggers = json['triggers'];
    if (id is! String || id.isEmpty) return null;
    if (version == null || version < 1) return null;
    if (title == null) return null;
    if (videoId is! String || !_youtubeId.hasMatch(videoId)) return null;
    if (rawTriggers is! List) return null;
    final triggers = rawTriggers
        .map(VideoModalTrigger.fromWire)
        .whereType<VideoModalTrigger>()
        .toSet();
    if (triggers.isEmpty) return null;
    final rawHighlights = json['highlights'];
    final highlights = rawHighlights is List
        ? rawHighlights
              .map(VideoModalHighlight.tryParse)
              .whereType<VideoModalHighlight>()
              .take(maxHighlights)
              .toList(growable: false)
        : const <VideoModalHighlight>[];
    final duration = _int(json['durationSeconds']);
    final maxDisplays = _int(json['maxDisplays']);
    return VideoModalCampaign(
      id: id,
      version: version,
      triggers: triggers,
      title: title,
      subtitle: _text(json['subtitle']),
      youtubeVideoId: videoId,
      durationSeconds: duration != null && duration > 0 ? duration : null,
      highlights: highlights,
      primaryLabel: _text(json['primaryLabel']),
      secondaryLabel: _text(json['secondaryLabel']),
      maxDisplays: maxDisplays != null && maxDisplays > 0
          ? maxDisplays
          : defaultMaxDisplays,
      displays: _int(json['displays']) ?? 0,
      audience: VideoModalAudience.fromWire(json['audience']),
    );
  }

  /// Liste de la réponse, dans l'ordre du back (version publiée la plus
  /// récente d'abord). Tout autre corps (objet, HTML d'un 404) donne une
  /// liste vide.
  static List<VideoModalCampaign> parseList(Object? body) {
    if (body is! List) return const [];
    return body
        .map(tryParse)
        .whereType<VideoModalCampaign>()
        .toList(growable: false);
  }

  /// Durée affichée sur la miniature (`3:24`), `null` sans durée.
  String? get durationLabel {
    final s = durationSeconds;
    if (s == null) return null;
    final minutes = s ~/ 60;
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static String? _text(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  @override
  List<Object?> get props => [
    id,
    version,
    triggers,
    title,
    subtitle,
    youtubeVideoId,
    durationSeconds,
    highlights,
    primaryLabel,
    secondaryLabel,
    maxDisplays,
    displays,
    audience,
  ];
}
