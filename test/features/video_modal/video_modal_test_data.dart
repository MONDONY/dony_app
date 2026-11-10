import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';

Map<String, Object?> campaignJson({
  String id = 'c1',
  int version = 2,
  List<String> triggers = const ['SEARCH_TAB'],
  String audience = 'NEVER_ANSWERED',
  int maxDisplays = 3,
  int displays = 0,
  String? primaryLabel = 'Voir la vidéo (3 min)',
  String? secondaryLabel = 'Commencer',
}) => {
  'id': id,
  'version': version,
  'triggers': triggers,
  'title': 'Bienvenue sur Yadony',
  'subtitle': "Envoyez ou voyagez, c'est vous qui choisissez.",
  'youtubeVideoId': 'dQw4w9WgXcQ',
  'durationSeconds': 204,
  'highlights': [
    {'icon': 'PARCEL', 'text': 'Envoyer un colis avec un voyageur'},
    {'icon': 'SUITCASE', 'text': 'Vendre vos kilos libres'},
    {'icon': 'LOCK', 'text': 'Payer en sécurité, suivre le colis'},
  ],
  'primaryLabel': primaryLabel,
  'secondaryLabel': secondaryLabel,
  'maxDisplays': maxDisplays,
  'displays': displays,
  'audience': audience,
};

VideoModalCampaign campaign({
  String id = 'c1',
  int version = 2,
  Set<VideoModalTrigger> triggers = const {VideoModalTrigger.searchTab},
  VideoModalAudience audience = VideoModalAudience.neverAnswered,
  int maxDisplays = 3,
  int displays = 0,
  String? primaryLabel = 'Voir la vidéo (3 min)',
  String? secondaryLabel = 'Commencer',
  List<VideoModalHighlight> highlights = const [
    VideoModalHighlight(
      icon: VideoModalIcon.parcel,
      text: 'Envoyer un colis avec un voyageur',
    ),
  ],
}) => VideoModalCampaign(
  id: id,
  version: version,
  triggers: triggers,
  title: 'Bienvenue sur Yadony',
  subtitle: "Envoyez ou voyagez, c'est vous qui choisissez.",
  youtubeVideoId: 'dQw4w9WgXcQ',
  durationSeconds: 204,
  highlights: highlights,
  primaryLabel: primaryLabel,
  secondaryLabel: secondaryLabel,
  maxDisplays: maxDisplays,
  displays: displays,
  audience: audience,
);
