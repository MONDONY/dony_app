import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  group('VideoModalCampaign.tryParse', () {
    test('lit une campagne complète du contrat', () {
      final c = VideoModalCampaign.tryParse(campaignJson())!;
      expect(c.id, 'c1');
      expect(c.version, 2);
      expect(c.triggers, {VideoModalTrigger.searchTab});
      expect(c.title, 'Bienvenue sur Yadony');
      expect(c.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(c.durationLabel, '3:24');
      expect(c.highlights, hasLength(3));
      expect(c.highlights.first.icon, VideoModalIcon.parcel);
      expect(c.primaryLabel, 'Voir la vidéo (3 min)');
      expect(c.maxDisplays, 3);
      expect(c.audience, VideoModalAudience.neverAnswered);
    });

    test('ignore une entrée sans champ indispensable', () {
      for (final key in [
        'id',
        'version',
        'title',
        'youtubeVideoId',
        'triggers',
      ]) {
        final json = campaignJson()..remove(key);
        expect(VideoModalCampaign.tryParse(json), isNull, reason: key);
      }
      expect(VideoModalCampaign.tryParse('texte'), isNull);
      expect(
        VideoModalCampaign.tryParse(
          campaignJson()..['youtubeVideoId'] = 'court',
        ),
        isNull,
      );
      expect(
        VideoModalCampaign.tryParse(campaignJson(triggers: ['INCONNU'])),
        isNull,
      );
      expect(VideoModalCampaign.tryParse(campaignJson(version: 0)), isNull);
    });

    test('tolère les champs facultatifs absents ou inconnus', () {
      final json = campaignJson(triggers: ['SEARCH_TAB', 'NOUVEAU'])
        ..remove('subtitle')
        ..remove('durationSeconds')
        ..remove('primaryLabel')
        ..remove('maxDisplays')
        ..remove('displays')
        ..['audience'] = 'NOUVEAU_PUBLIC'
        ..['highlights'] = [
          {'icon': 'NOUVELLE', 'text': 'Un'},
          {'icon': 'QR', 'text': ''},
          'pas un objet',
          {'icon': 'CHAT', 'text': 'Deux'},
          {'icon': 'WALLET', 'text': 'Trois'},
          {'icon': 'STAR', 'text': 'Quatre'},
        ];
      final c = VideoModalCampaign.tryParse(json)!;
      expect(c.triggers, {VideoModalTrigger.searchTab});
      expect(c.subtitle, isNull);
      expect(c.durationLabel, isNull);
      expect(c.primaryLabel, isNull);
      expect(c.maxDisplays, VideoModalCampaign.defaultMaxDisplays);
      expect(c.displays, 0);
      expect(c.audience, VideoModalAudience.neverAnswered);
      expect(c.highlights.map((h) => h.text), ['Un', 'Deux', 'Trois']);
      expect(c.highlights.first.icon, VideoModalIcon.star);
    });

    test('parseList ne garde que les entrées lisibles, dans l\'ordre', () {
      final list = VideoModalCampaign.parseList([
        campaignJson(id: 'a'),
        {'id': 'cassée'},
        campaignJson(id: 'b'),
      ]);
      expect(list.map((c) => c.id), ['a', 'b']);
      expect(VideoModalCampaign.parseList({'type': 'about:blank'}), isEmpty);
      expect(VideoModalCampaign.parseList(null), isEmpty);
      expect(VideoModalCampaign.parseList('<html>'), isEmpty);
    });
  });

  test('déclencheurs : onglets du shell et formulaires', () {
    expect(VideoModalTrigger.forShellTab(0), VideoModalTrigger.searchTab);
    expect(VideoModalTrigger.forShellTab(1), VideoModalTrigger.activitiesTab);
    expect(VideoModalTrigger.forShellTab(2), VideoModalTrigger.trackingTab);
    expect(VideoModalTrigger.forShellTab(3), VideoModalTrigger.messagesTab);
    expect(VideoModalTrigger.forShellTab(4), VideoModalTrigger.profileTab);
    expect(VideoModalTrigger.forShellTab(5), isNull);
    expect(VideoModalTrigger.publishTrip.opensForm, isTrue);
    expect(VideoModalTrigger.sendParcel.opensForm, isTrue);
    expect(VideoModalTrigger.appOpen.opensForm, isFalse);
    expect(VideoModalTrigger.fromWire('APP_OPEN'), VideoModalTrigger.appOpen);
  });

  test('événements : réponse et vidéo ouverte', () {
    expect(VideoModalEventType.shown.isAnswer, isFalse);
    expect(VideoModalEventType.dismissed.isAnswer, isTrue);
    expect(VideoModalEventType.dismissed.isWatch, isFalse);
    expect(VideoModalEventType.opened.isWatch, isTrue);
    expect(VideoModalEventType.completed.isWatch, isTrue);
    expect(VideoModalEventType.fromWire('X'), isNull);
  });

  test('icônes : valeur inconnue → étoile', () {
    for (final i in VideoModalIcon.values) {
      expect(VideoModalIcon.fromWire(i.wire), i);
    }
    expect(VideoModalIcon.fromWire(null), VideoModalIcon.star);
  });

  test('durée sous la minute', () {
    expect(
      VideoModalCampaign.tryParse(
        campaignJson()..['durationSeconds'] = 65,
      )!.durationLabel,
      '1:05',
    );
  });
}
