import 'dart:collection';

import 'package:equatable/equatable.dart';

enum SocialNetwork { whatsapp, facebook, instagram, tiktok, youtube }

enum TutorialContext {
  search,
  activities,
  tripPublish,
  requestPublish,
  negotiation,
  payment,
  qrHandover,
  tracking,
  dispute,
  corridorAlerts,
  tripTemplates,
  recipients,
  receivedRequests,
}

final class SocialLink extends Equatable {
  const SocialLink({
    required this.network,
    required this.url,
    required this.active,
  });

  final SocialNetwork network;
  final Uri url;
  final bool active;

  @override
  List<Object?> get props => [network, url, active];
}

final class HelpTutorial extends Equatable {
  const HelpTutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeVideoId,
    required this.order,
    required this.active,
    required List<TutorialContext> contexts,
    this.durationLabel,
  }) : _contexts = contexts;

  final String id;
  final String title;
  final String description;
  final String youtubeVideoId;
  final int order;
  final bool active;
  final List<TutorialContext> _contexts;

  List<TutorialContext> get contexts => UnmodifiableListView(_contexts);
  final String? durationLabel;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    youtubeVideoId,
    order,
    active,
    _contexts,
    durationLabel,
  ];
}

final class HelpCenterConfig extends Equatable {
  const HelpCenterConfig({
    required this.schemaVersion,
    required List<SocialLink> socialLinks,
    required List<HelpTutorial> tutorials,
    this.youtubeChannelUrl,
  }) : _socialLinks = socialLinks,
       _tutorials = tutorials;

  static const empty = HelpCenterConfig(
    schemaVersion: 1,
    socialLinks: [],
    tutorials: [],
  );

  final int schemaVersion;
  final List<SocialLink> _socialLinks;
  final List<HelpTutorial> _tutorials;
  final Uri? youtubeChannelUrl;

  List<SocialLink> get socialLinks => UnmodifiableListView(_socialLinks);
  List<HelpTutorial> get tutorials => UnmodifiableListView(_tutorials);

  factory HelpCenterConfig.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('unsupported_schema');
    }

    final tutorials = _parseValidTutorials(json['tutorials'])
      ..sort((a, b) => a.order.compareTo(b.order));

    Uri? youtubeChannelUrl;
    try {
      youtubeChannelUrl = _parseHttpsUri(json['youtubeChannelUrl']);
    } on FormatException {
      // Le canal est optionnel : un lien invalide ne doit pas masquer le catalogue.
    }

    return HelpCenterConfig(
      schemaVersion: 1,
      socialLinks: _parseValidSocialLinks(json['socialLinks']),
      tutorials: tutorials,
      youtubeChannelUrl: youtubeChannelUrl,
    );
  }

  HelpTutorial? tutorialFor(TutorialContext context) {
    for (final item in tutorials) {
      if (item.active && item.contexts.contains(context)) {
        return item;
      }
    }
    return null;
  }

  HelpTutorial? tutorialById(String id) {
    for (final item in tutorials) {
      if (item.active && item.id == id) {
        return item;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    socialLinks,
    tutorials,
    youtubeChannelUrl,
  ];
}

List<SocialLink> _parseValidSocialLinks(Object? value) {
  if (value is! List) {
    return [];
  }

  final links = <SocialLink>[];
  final networks = <String>{};
  for (final entry in value) {
    try {
      final link = _parseSocialLink(entry);
      if (networks.add(link.network.name)) {
        links.add(link);
      }
    } on FormatException {
      // Une entrée distante invalide ne doit pas rendre le catalogue inutilisable.
    }
  }
  return links;
}

List<HelpTutorial> _parseValidTutorials(Object? value) {
  if (value is! List) {
    return [];
  }

  final tutorials = <HelpTutorial>[];
  final ids = <String>{};
  for (final entry in value) {
    try {
      final tutorial = _parseTutorial(entry);
      if (ids.add(tutorial.id)) {
        tutorials.add(tutorial);
      }
    } on FormatException {
      // Les autres tutoriels valides restent disponibles.
    }
  }
  return tutorials;
}

Uri? _parseHttpsUri(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const FormatException('invalid_url');
  }

  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('invalid_url');
  }
  return uri;
}

SocialLink _parseSocialLink(Object? value) {
  final json = _asJsonObject(value);
  final network = _socialNetworkFromJson(json['network']);
  final url = _parseHttpsUri(json['url']);
  final active = json['active'];
  if (url == null || active is! bool) {
    throw const FormatException('invalid_social_link');
  }

  return SocialLink(network: network, url: url, active: active);
}

HelpTutorial _parseTutorial(Object? value) {
  final json = _asJsonObject(value);
  final id = _requiredString(json['id'], 'invalid_tutorial_id');
  final title = _requiredString(json['title'], 'invalid_tutorial_title');
  final description = _requiredString(
    json['description'],
    'invalid_tutorial_description',
  );
  final youtubeVideoId = _requiredString(
    json['youtubeVideoId'],
    'invalid_video_id',
  );
  final order = json['order'];
  final active = json['active'];
  final durationLabel = json['durationLabel'];

  if (!_youtubeVideoIdPattern.hasMatch(youtubeVideoId)) {
    throw const FormatException('invalid_video_id');
  }
  if (order is! int ||
      active is! bool ||
      (durationLabel != null && durationLabel is! String)) {
    throw const FormatException('invalid_tutorial');
  }

  return HelpTutorial(
    id: id,
    title: title,
    description: description,
    youtubeVideoId: youtubeVideoId,
    order: order,
    active: active,
    contexts: _tutorialContextsFromJson(json['contexts']),
    durationLabel: durationLabel as String?,
  );
}

final _youtubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

Map<String, dynamic> _asJsonObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('invalid_entry');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Object? value, String error) {
  if (value is! String || value.isEmpty) {
    throw FormatException(error);
  }
  return value;
}

SocialNetwork _socialNetworkFromJson(Object? value) {
  if (value is! String) {
    throw const FormatException('invalid_social_network');
  }
  for (final network in SocialNetwork.values) {
    if (network.name == value) {
      return network;
    }
  }
  throw const FormatException('invalid_social_network');
}

List<TutorialContext> _tutorialContextsFromJson(Object? value) {
  if (value is! List || value.isEmpty) {
    throw const FormatException('invalid_context');
  }

  final contexts = <TutorialContext>[];
  for (final item in value) {
    if (item is! String) {
      throw const FormatException('invalid_context');
    }
    final context = TutorialContext.values
        .where((candidate) => candidate.name == item)
        .firstOrNull;
    if (context == null || contexts.contains(context)) {
      throw const FormatException('invalid_context');
    }
    contexts.add(context);
  }
  return contexts;
}
