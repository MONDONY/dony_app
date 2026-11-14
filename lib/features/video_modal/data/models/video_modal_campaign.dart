import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
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
  sendParcel('SEND_PARCEL'),

  // Moments d'action (étape 2) : l'app les déclenche quand quelque chose se
  // passe, avec le corridor concerné quand il existe.
  deliveryConfirmed('DELIVERY_CONFIRMED'),
  paymentSucceeded('PAYMENT_SUCCEEDED'),
  tripPublished('TRIP_PUBLISHED'),
  requestPublished('REQUEST_PUBLISHED'),
  kycVerified('KYC_VERIFIED'),
  searchNoTripResults('SEARCH_NO_TRIP_RESULTS'),
  searchNoParcelResults('SEARCH_NO_PARCEL_RESULTS'),
  searchFewResults('SEARCH_FEW_RESULTS'),
  favoriteAdded('FAVORITE_ADDED'),
  formAbandoned('FORM_ABANDONED'),
  tripViewedRepeatedly('TRIP_VIEWED_REPEATEDLY'),
  paymentFailed('PAYMENT_FAILED'),
  appUpdated('APP_UPDATED');

  const VideoModalTrigger(this.wire);

  /// Valeur échangée avec le back, aussi propriété `trigger` des analytics.
  final String wire;

  /// Déclencheur posé devant un formulaire : après le modal, l'app poursuit
  /// vers le formulaire demandé.
  bool get opensForm => this == publishTrip || this == sendParcel;

  /// Déclenché par l'app sur un événement (action réussie, recherche,
  /// favori…), et non par l'arrivée sur un écran ou un bouton.
  bool get isMoment => switch (this) {
    appOpen ||
    searchTab ||
    activitiesTab ||
    trackingTab ||
    messagesTab ||
    profileTab ||
    publishTrip ||
    sendParcel => false,
    _ => true,
  };

  /// Les `corridors` d'une campagne s'appliquent à ce déclencheur.
  bool get usesCorridors => switch (this) {
    searchNoTripResults ||
    searchNoParcelResults ||
    searchFewResults ||
    favoriteAdded ||
    tripViewedRepeatedly ||
    formAbandoned ||
    tripPublished ||
    requestPublished => true,
    _ => false,
  };

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
  completed('COMPLETED'),

  /// Case « Ne plus afficher » cochée : réponse définitive pour la version.
  /// Hors de l'échelle des statuts (voir [isStatus]) : elle ne rétrograde ni
  /// ne remplace OPENED, COMPLETED ou DISMISSED.
  dontShowAgain('DONT_SHOW_AGAIN');

  const VideoModalEventType(this.wire);

  final String wire;

  /// SHOWN, DISMISSED, OPENED, COMPLETED : l'échelle des statuts d'une version.
  bool get isStatus => this != dontShowAgain;

  /// OPENED, COMPLETED ou DISMISSED : la personne a répondu.
  bool get isAnswer => isStatus && this != shown;

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
  wallet('WALLET'),
  bell('BELL'),
  info('INFO');

  const VideoModalIcon(this.wire);

  final String wire;

  static VideoModalIcon fromWire(Object? value) {
    for (final i in values) {
      if (i.wire == value) return i;
    }
    return star;
  }
}

/// Type d'une campagne (enum `VideoModalType` du back). Une entrée sans
/// `type` est une vidéo : c'est le contrat des versions d'avant les modals
/// d'information.
enum VideoModalType {
  video('VIDEO'),
  info('INFO');

  const VideoModalType(this.wire);

  final String wire;

  /// Absent : [video]. Valeur inconnue : `null`, la campagne est ignorée.
  static VideoModalType? fromWire(Object? value) {
    if (value == null) return video;
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

enum VideoModalActionKind {
  screen('SCREEN'),
  url('URL'),
  close('CLOSE');

  const VideoModalActionKind(this.wire);

  final String wire;

  static VideoModalActionKind? fromWire(Object? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// Écrans qu'un bouton d'information peut ouvrir (enum `InfoScreen` du
/// back), liste fermée : chaque valeur correspond à une route de
/// `router.dart`. Une valeur inconnue de cette version de l'app fait ignorer
/// la campagne entière.
enum InfoScreen {
  search('SEARCH', '/home', isShellTab: true),
  activities('ACTIVITIES', '/announcements', isShellTab: true),
  tracking('TRACKING', '/tracking', isShellTab: true),
  messages('MESSAGES', '/messages', isShellTab: true),
  profile('PROFILE', '/profile', isShellTab: true),
  publishTrip('PUBLISH_TRIP', '/trips/publish-intro'),
  sendParcel('SEND_PARCEL', '/parcels/send-intro'),
  settings('SETTINGS', '/settings'),
  myMoney('MY_MONEY', '/payments/money'),
  referral('REFERRAL', '/profile/referral'),
  tripAlerts('TRIP_ALERTS', '/corridor-alerts'),
  help('HELP', '/profile/help/faq');

  const InfoScreen(this.wire, this.route, {this.isShellTab = false});

  final String wire;

  /// Route GoRouter. `PUBLISH_TRIP` et `SEND_PARCEL` pointent les écrans
  /// d'intro des formulaires, sans repasser par le modal déclencheur.
  final String route;

  /// Onglet du shell : on y va avec `go`, les autres écrans se poussent.
  final bool isShellTab;

  static InfoScreen? fromWire(Object? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Habillage d'un modal (enum `layout` du back). Absent : [bottomSheet], le
/// rendu d'avant ce choix. Valeur inconnue : `null`, la campagne est ignorée.
enum VideoModalLayout {
  bottomSheet('BOTTOM_SHEET'),
  centered('CENTERED'),
  fullscreen('FULLSCREEN');

  const VideoModalLayout(this.wire);

  final String wire;

  static VideoModalLayout? fromWire(Object? value) {
    if (value == null) return bottomSheet;
    for (final l in values) {
      if (l.wire == value) return l;
    }
    return null;
  }
}

/// Fréquence d'affichage d'une campagne (enum `frequency` du back). Absent :
/// [upToN], le comportement d'avant ce choix. Valeur inconnue : `null`, la
/// campagne est ignorée.
enum VideoModalFrequency {
  /// Une seule fois par version (équivaut à [upToN] avec 1).
  once('ONCE'),

  /// Jusqu'à `maxDisplays` fois par version.
  upToN('UP_TO_N'),

  /// À chaque lancement de l'app (un seul modal par lancement côté app).
  everyOpen('EVERY_OPEN'),

  /// Une fois tous les `frequencyDays` jours.
  everyNDays('EVERY_N_DAYS'),

  /// À chaque fois que l'action se produit : aucun plafond, aucun drapeau de
  /// session (un modal d'écran ou de moment peut revenir à chaque occurrence).
  everyTime('EVERY_TIME');

  const VideoModalFrequency(this.wire);

  final String wire;

  static VideoModalFrequency? fromWire(Object? value) {
    if (value == null) return upToN;
    for (final f in values) {
      if (f.wire == value) return f;
    }
    return null;
  }
}

/// Place de l'image d'un modal d'information (enum `imageMode` du back).
enum VideoModalImageMode {
  none('NONE'),

  /// Bannière au-dessus du titre et du texte.
  top('TOP'),

  /// L'image occupe tout le modal au-dessus des boutons ; ni titre ni texte
  /// affichés (le titre reste le libellé d'accessibilité).
  poster('POSTER');

  const VideoModalImageMode(this.wire);

  final String wire;

  /// Absent : [none]. Valeur inconnue : `null`, la campagne est ignorée.
  static VideoModalImageMode? fromWire(Object? value) {
    if (value == null) return none;
    for (final m in values) {
      if (m.wire == value) return m;
    }
    return null;
  }
}

/// Cadrage de l'image (enum `imageFit` du back).
enum VideoModalImageFit {
  /// Remplit le cadre en recadrant.
  cover('COVER'),

  /// Image entière.
  contain('CONTAIN');

  const VideoModalImageFit(this.wire);

  final String wire;

  /// Absent : [cover]. Valeur inconnue : `null`.
  static VideoModalImageFit? fromWire(Object? value) {
    if (value == null) return cover;
    for (final f in values) {
      if (f.wire == value) return f;
    }
    return null;
  }
}

/// Action d'un bouton d'un modal d'information.
class VideoModalAction extends Equatable {
  const VideoModalAction._(this.kind, {this.screen, this.url});

  const VideoModalAction.close() : this._(VideoModalActionKind.close);

  const VideoModalAction.openScreen(InfoScreen screen)
    : this._(VideoModalActionKind.screen, screen: screen);

  const VideoModalAction.openUrl(String url)
    : this._(VideoModalActionKind.url, url: url);

  static const maxUrlLength = 2000;

  final VideoModalActionKind kind;
  final InfoScreen? screen;
  final String? url;

  /// Action lisible, ou `null` (genre inconnu, écran inconnu, lien qui n'est
  /// pas un https valide).
  static VideoModalAction? tryParse(Object? json) {
    if (json is! Map) return null;
    switch (VideoModalActionKind.fromWire(json['kind'])) {
      case VideoModalActionKind.close:
        return const VideoModalAction.close();
      case VideoModalActionKind.screen:
        final screen = InfoScreen.fromWire(json['screen']);
        return screen == null ? null : VideoModalAction.openScreen(screen);
      case VideoModalActionKind.url:
        final url = json['url'];
        return isValidUrl(url)
            ? VideoModalAction.openUrl(url! as String)
            : null;
      case null:
        return null;
    }
  }

  /// https seulement, avec un hôte, sans espace, 2000 caractères au plus.
  static bool isValidUrl(Object? value) {
    if (value is! String || value.isEmpty || value.length > maxUrlLength) {
      return false;
    }
    if (value.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  @override
  List<Object?> get props => [kind, screen, url];
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
    this.youtubeVideoId = '',
    this.type = VideoModalType.video,
    this.body,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.subtitle,
    this.durationSeconds,
    this.highlights = const [],
    this.primaryLabel,
    this.secondaryLabel,
    this.maxDisplays = defaultMaxDisplays,
    this.displays = 0,
    this.audience = VideoModalAudience.neverAnswered,
    this.layout = VideoModalLayout.bottomSheet,
    this.sizePercent,
    this.imageMode = VideoModalImageMode.none,
    this.imageFit = VideoModalImageFit.cover,
    this.imageUrl,
    this.imageAlt,
    this.priority = 0,
    this.frequency = VideoModalFrequency.upToN,
    this.frequencyDays,
    this.stopAfterAnswer = true,
    this.allowDontShowAgain = false,
    this.lastShownAt,
    this.triggerOptions = const VideoModalTriggerOptions(),
    this.corridors = const [],
  });

  static const defaultMaxDisplays = 3;
  static const maxFrequencyDays = 365;
  static const minSizePercent = 30;
  static const maxSizePercent = 100;
  static const maxHighlights = 3;
  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  final String id;
  final int version;
  final Set<VideoModalTrigger> triggers;
  final String title;
  final String? subtitle;
  final String youtubeVideoId;

  /// Modal d'information : texte, icône et actions des deux boutons. Ces
  /// champs restent vides pour une vidéo.
  final VideoModalType type;
  final String? body;
  final VideoModalIcon? icon;
  final VideoModalAction? primaryAction;
  final VideoModalAction? secondaryAction;
  final int? durationSeconds;
  final List<VideoModalHighlight> highlights;
  final String? primaryLabel;
  final String? secondaryLabel;
  final int maxDisplays;
  final int displays;
  final VideoModalAudience audience;

  /// Habillage et hauteur maximale en % de l'écran (`null` : selon le
  /// contenu ; sans effet en plein écran).
  final VideoModalLayout layout;
  final int? sizePercent;

  /// Image d'un modal d'information (jamais pour une vidéo). [imageUrl] est
  /// renseignée dès que [imageMode] n'est pas [VideoModalImageMode.none].
  final VideoModalImageMode imageMode;
  final VideoModalImageFit imageFit;
  final String? imageUrl;
  final String? imageAlt;

  /// Ciblage et fréquence (étape 1 « moment, ciblage, fréquence »). Les
  /// valeurs par défaut sont celles d'un back qui ne les envoie pas : le
  /// comportement d'avant (jusqu'à [maxDisplays] fois, une réponse arrête).
  ///
  /// [priority] : plus haut passe d'abord. [frequencyDays] : seulement pour
  /// [VideoModalFrequency.everyNDays]. [stopAfterAnswer] : une réponse (bouton
  /// touché) bloque les affichages suivants de la version.
  /// [allowDontShowAgain] : la case « Ne plus afficher » est proposée.
  /// [lastShownAt] : dernier affichage de la personne pour la version.
  final int priority;
  final VideoModalFrequency frequency;
  final int? frequencyDays;
  final bool stopAfterAnswer;
  final bool allowDontShowAgain;
  final DateTime? lastShownAt;

  /// Moments d'action (étape 2) : seuils des déclencheurs « peu de résultats »
  /// et « trajet consulté N fois », et corridors ciblés (liste vide : tous).
  final VideoModalTriggerOptions triggerOptions;
  final List<VideoModalCorridor> corridors;

  /// Plafond d'affichages de la version, `null` : pas de plafond (à chaque
  /// lancement, tous les N jours).
  int? get displayCap => switch (frequency) {
    VideoModalFrequency.once => 1,
    VideoModalFrequency.upToN => maxDisplays,
    VideoModalFrequency.everyOpen ||
    VideoModalFrequency.everyNDays ||
    VideoModalFrequency.everyTime => null,
  };

  /// Le plafond d'affichages n'est pas atteint.
  bool get underDisplayCap {
    final cap = displayCap;
    return cap == null || displays < cap;
  }

  /// Une image est à précharger avant d'afficher le modal.
  bool get hasImage =>
      imageMode != VideoModalImageMode.none && imageUrl != null;

  bool get isPoster => hasImage && imageMode == VideoModalImageMode.poster;

  bool get isInfo => type == VideoModalType.info;

  /// Affichée à chaque occurrence de l'action, hors limites de session.
  bool get isEveryTime => frequency == VideoModalFrequency.everyTime;

  /// Campagne lisible, ou `null` si un champ indispensable manque ou est
  /// invalide : le back peut être plus ancien ou plus récent que l'app, une
  /// entrée inexploitable est ignorée sans erreur.
  static VideoModalCampaign? tryParse(Object? json) {
    if (json is! Map) return null;
    final type = VideoModalType.fromWire(json['type']);
    if (type == null) return null;
    final id = json['id'];
    final version = _int(json['version']);
    final title = _text(json['title']);
    final videoId = json['youtubeVideoId'];
    final rawTriggers = json['triggers'];
    if (id is! String || id.isEmpty) return null;
    if (version == null || version < 1) return null;
    if (title == null) return null;
    if (type == VideoModalType.video &&
        (videoId is! String || !_youtubeId.hasMatch(videoId))) {
      return null;
    }
    if (rawTriggers is! List) return null;
    final triggers = rawTriggers
        .map(VideoModalTrigger.fromWire)
        .whereType<VideoModalTrigger>()
        .toSet();
    if (triggers.isEmpty) return null;
    final info = type == VideoModalType.info ? _parseInfo(json) : null;
    if (type == VideoModalType.info && info == null) return null;
    final layout = VideoModalLayout.fromWire(json['layout']);
    if (layout == null) return null;
    final image = type == VideoModalType.info ? _parseImage(json) : null;
    if (type == VideoModalType.info && image == null) return null;
    final frequency = VideoModalFrequency.fromWire(json['frequency']);
    if (frequency == null) return null;
    final frequencyDays = _int(json['frequencyDays']);
    // Tous les N jours sans N valide : la fréquence est illisible.
    if (frequency == VideoModalFrequency.everyNDays &&
        (frequencyDays == null ||
            frequencyDays < 1 ||
            frequencyDays > maxFrequencyDays)) {
      return null;
    }
    final rawCorridors = json['corridors'];
    final corridors = rawCorridors is List
        ? rawCorridors
              .map(VideoModalCorridor.tryParse)
              .whereType<VideoModalCorridor>()
              .take(VideoModalCorridor.maxEntries)
              .toList(growable: false)
        : const <VideoModalCorridor>[];
    // Des corridors envoyés mais tous illisibles : mieux vaut ignorer la
    // campagne que l'ouvrir pour tous les corridors.
    if (rawCorridors is List && rawCorridors.isNotEmpty && corridors.isEmpty) {
      return null;
    }
    final size = _int(json['sizePercent']);
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
      youtubeVideoId: type == VideoModalType.info ? '' : videoId! as String,
      type: type,
      body: info?.body,
      icon: info?.icon,
      primaryAction: info?.primary,
      secondaryAction: info?.secondary,
      durationSeconds: duration != null && duration > 0 ? duration : null,
      highlights: highlights,
      primaryLabel: _text(json['primaryLabel']),
      secondaryLabel: _text(json['secondaryLabel']),
      maxDisplays: maxDisplays != null && maxDisplays > 0
          ? maxDisplays
          : defaultMaxDisplays,
      displays: _int(json['displays']) ?? 0,
      audience: VideoModalAudience.fromWire(json['audience']),
      layout: layout,
      sizePercent: size != null && size >= minSizePercent && size <= 100
          ? size
          : null,
      imageMode: image?.mode ?? VideoModalImageMode.none,
      imageFit: image?.fit ?? VideoModalImageFit.cover,
      imageUrl: image?.url,
      imageAlt: image?.alt,
      priority: _int(json['priority']) ?? 0,
      frequency: frequency,
      frequencyDays: frequency == VideoModalFrequency.everyNDays
          ? frequencyDays
          : null,
      stopAfterAnswer: json['stopAfterAnswer'] is bool
          ? json['stopAfterAnswer'] as bool
          : true,
      allowDontShowAgain: json['allowDontShowAgain'] == true,
      lastShownAt: _instant(json['lastShownAt']),
      triggerOptions: VideoModalTriggerOptions.parse(json['triggerOptions']),
      corridors: corridors,
    );
  }

  /// Image d'un modal d'information, ou `null` s'il est inutilisable : mode
  /// ou cadrage inconnu de cette version, affiche sans adresse https valide.
  /// Une bannière sans adresse valide devient un modal sans image.
  static ({
    VideoModalImageMode mode,
    VideoModalImageFit fit,
    String? url,
    String? alt,
  })?
  _parseImage(Map<dynamic, dynamic> json) {
    final mode = VideoModalImageMode.fromWire(json['imageMode']);
    if (mode == null) return null;
    const none = (
      mode: VideoModalImageMode.none,
      fit: VideoModalImageFit.cover,
      url: null,
      alt: null,
    );
    if (mode == VideoModalImageMode.none) return none;
    final fit = VideoModalImageFit.fromWire(json['imageFit']);
    if (fit == null) return null;
    final url = json['imageUrl'];
    if (!VideoModalAction.isValidUrl(url)) {
      return mode == VideoModalImageMode.poster ? null : none;
    }
    return (
      mode: mode,
      fit: fit,
      url: url! as String,
      alt: _text(json['imageAlt']),
    );
  }

  /// Champs propres à un modal d'information, ou `null` s'il est inutilisable :
  /// texte vide, bouton principal absent ou invalide, bouton secondaire présent
  /// mais invalide (écran inconnu de cette version).
  static ({
    String body,
    VideoModalIcon icon,
    VideoModalAction primary,
    VideoModalAction? secondary,
  })?
  _parseInfo(Map<dynamic, dynamic> json) {
    final body = _text(json['body']);
    final primary = VideoModalAction.tryParse(json['primaryAction']);
    if (body == null || primary == null) return null;
    VideoModalAction? secondary;
    final rawSecondary = json['secondaryAction'];
    if (rawSecondary != null) {
      secondary = VideoModalAction.tryParse(rawSecondary);
      if (secondary == null) return null;
    }
    var icon = VideoModalIcon.info;
    for (final i in VideoModalIcon.values) {
      if (i.wire == json['icon']) icon = i;
    }
    return (body: body, icon: icon, primary: primary, secondary: secondary);
  }

  /// Liste de la réponse, triée par priorité décroissante ; à priorité égale,
  /// l'ordre du back (version publiée la plus récente d'abord) est gardé. Tout
  /// autre corps (objet, HTML d'un 404) donne une liste vide.
  static List<VideoModalCampaign> parseList(Object? body) {
    if (body is! List) return const [];
    final parsed = body
        .map(tryParse)
        .whereType<VideoModalCampaign>()
        .toList(growable: false);
    return sortByPriority(parsed);
  }

  /// Tri stable par priorité décroissante (le `sort` de Dart ne l'est pas).
  static List<VideoModalCampaign> sortByPriority(
    List<VideoModalCampaign> campaigns,
  ) {
    final indexed = campaigns.indexed.toList()
      ..sort((a, b) {
        final byPriority = b.$2.priority.compareTo(a.$2.priority);
        return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
      });
    return indexed.map((e) => e.$2).toList(growable: false);
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

  static DateTime? _instant(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

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
    type,
    body,
    icon,
    primaryAction,
    secondaryAction,
    durationSeconds,
    highlights,
    primaryLabel,
    secondaryLabel,
    maxDisplays,
    displays,
    audience,
    layout,
    sizePercent,
    imageMode,
    imageFit,
    imageUrl,
    imageAlt,
    priority,
    frequency,
    frequencyDays,
    stopAfterAnswer,
    allowDontShowAgain,
    lastShownAt,
    triggerOptions,
    corridors,
  ];
}
