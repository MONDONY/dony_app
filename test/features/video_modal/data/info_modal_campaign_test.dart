import 'dart:io';

import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  group('lecture tolérante des modals d\'information', () {
    test('INFO valide, sans vidéo', () {
      final c = VideoModalCampaign.tryParse(infoJson())!;
      expect(c.type, VideoModalType.info);
      expect(c.isInfo, isTrue);
      expect(c.youtubeVideoId, '');
      expect(c.body, 'Votre argent est à un seul endroit.');
      expect(c.icon, VideoModalIcon.wallet);
      expect(
        c.primaryAction,
        const VideoModalAction.openScreen(InfoScreen.myMoney),
      );
      expect(c.secondaryAction, const VideoModalAction.close());
      expect(c.primaryLabel, 'Voir mon argent');
      expect(c.highlights, isEmpty);
    });

    test('youtubeVideoId et durationSeconds null sont acceptés', () {
      final c = VideoModalCampaign.tryParse({
        ...infoJson(),
        'youtubeVideoId': null,
        'durationSeconds': null,
        'highlights': null,
      });
      expect(c, isNotNull);
    });

    test('un second bouton absent ou null : un seul bouton', () {
      expect(
        VideoModalCampaign.tryParse(
          infoJson(secondaryAction: null),
        )!.secondaryAction,
        isNull,
      );
      final json = infoJson()..remove('secondaryAction');
      expect(VideoModalCampaign.tryParse(json)!.secondaryAction, isNull);
    });

    test('icône absente ou inconnue : INFO', () {
      expect(
        VideoModalCampaign.tryParse(infoJson(icon: null))!.icon,
        VideoModalIcon.info,
      );
      expect(
        VideoModalCampaign.tryParse(infoJson(icon: 'ROCKET'))!.icon,
        VideoModalIcon.info,
      );
      expect(
        VideoModalCampaign.tryParse(infoJson(icon: 'BELL'))!.icon,
        VideoModalIcon.bell,
      );
    });

    test('type inconnu : campagne ignorée', () {
      expect(
        VideoModalCampaign.tryParse({...infoJson(), 'type': 'POLL'}),
        isNull,
      );
    });

    test('type absent : vidéo, comme avant', () {
      final c = VideoModalCampaign.tryParse(campaignJson())!;
      expect(c.type, VideoModalType.video);
      expect(c.isInfo, isFalse);
      expect(c.primaryAction, isNull);
      expect(c.body, isNull);
    });

    test('type VIDEO explicite sans vidéo : ignorée', () {
      final json = campaignJson()..['type'] = 'VIDEO';
      expect(VideoModalCampaign.tryParse(json), isNotNull);
      json['youtubeVideoId'] = null;
      expect(VideoModalCampaign.tryParse(json), isNull);
    });

    test(
      'une entrée sans type ni vidéo (back neuf, app ancienne) : ignorée',
      () {
        final json = infoJson()..remove('type');
        expect(VideoModalCampaign.tryParse(json), isNull);
      },
    );

    test('INFO inexploitable : ignorée sans erreur', () {
      for (final json in [
        infoJson(body: null),
        infoJson(body: '   '),
        infoJson(body: 12),
        infoJson(primaryAction: null),
        infoJson(primaryAction: 'CLOSE'),
        infoJson(primaryAction: const {'kind': 'SHARE'}),
        infoJson(primaryAction: const {'kind': 'SCREEN'}),
        infoJson(primaryAction: const {'kind': 'SCREEN', 'screen': 'GAMES'}),
        infoJson(primaryAction: const {'kind': 'URL', 'url': 'http://a.fr'}),
        // Second bouton illisible : toute la campagne est ignorée.
        infoJson(secondaryAction: const {'kind': 'SCREEN', 'screen': 'GAMES'}),
        infoJson(triggers: const ['NOWHERE']),
      ]) {
        expect(VideoModalCampaign.tryParse(json), isNull, reason: '$json');
      }
    });

    test('parseList garde les valides et saute le reste', () {
      final list = VideoModalCampaign.parseList([
        campaignJson(),
        infoJson(primaryAction: const {'kind': 'SCREEN', 'screen': 'GAMES'}),
        infoJson(id: 'i2'),
        {...infoJson(id: 'i3'), 'type': 'POLL'},
      ]);
      expect(list.map((c) => c.id), ['c1', 'i2']);
    });
  });

  group('VideoModalAction', () {
    test('liens : https valide seulement', () {
      const bad = [
        'http://a.fr',
        'javascript:alert(1)',
        'data:text/html,x',
        'mailto:a@b.fr',
        'https://',
        'https://a.fr/ x',
        '',
        'ftp://a.fr',
      ];
      for (final u in bad) {
        expect(VideoModalAction.isValidUrl(u), isFalse, reason: u);
      }
      expect(VideoModalAction.isValidUrl(null), isFalse);
      expect(VideoModalAction.isValidUrl(12), isFalse);
      expect(VideoModalAction.isValidUrl('https://yadony.com/a?b=1'), isTrue);
      expect(
        VideoModalAction.isValidUrl('https://a.fr/${'x' * 2000}'),
        isFalse,
      );
    });

    test('lecture de chaque genre', () {
      expect(
        VideoModalAction.tryParse(const {'kind': 'URL', 'url': 'https://a.fr'}),
        const VideoModalAction.openUrl('https://a.fr'),
      );
      expect(VideoModalAction.tryParse(null), isNull);
      expect(
        VideoModalAction.tryParse(const {'kind': 'URL', 'url': 12}),
        isNull,
      );
    });
  });

  group('InfoScreen', () {
    test('valeur inconnue : null', () {
      expect(InfoScreen.fromWire('GAMES'), isNull);
      expect(InfoScreen.fromWire(null), isNull);
      expect(InfoScreen.fromWire('HELP'), InfoScreen.help);
    });

    test('liste finale du contrat', () {
      expect(InfoScreen.values.map((s) => s.wire), [
        'SEARCH',
        'ACTIVITIES',
        'TRACKING',
        'MESSAGES',
        'PROFILE',
        'PUBLISH_TRIP',
        'SEND_PARCEL',
        'SETTINGS',
        'MY_MONEY',
        'REFERRAL',
        'TRIP_ALERTS',
        'HELP',
      ]);
    });

    test('chaque route existe dans router.dart', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      for (final s in InfoScreen.values) {
        final declared =
            router.contains("path: '${s.route}'") ||
            // Mon argent passe par la constante `kMoneyOverviewRoute`.
            (s == InfoScreen.myMoney &&
                router.contains('path: kMoneyOverviewRoute') &&
                File(
                  'lib/features/payments/money/presentation/widgets/money_header_button.dart',
                ).readAsStringSync().contains(
                  "kMoneyOverviewRoute = '${s.route}'",
                ));
        expect(declared, isTrue, reason: '${s.wire} -> ${s.route}');
      }
    });
  });

  group('historique local', () {
    test('un INFO suit les mêmes règles qu\'une vidéo', () {
      final c = infoCampaign();
      const empty = VideoModalLocalHistory();
      expect(empty.isEligible(c), isTrue);
      final shown = empty.apply(c.id, c.version, VideoModalEventType.shown);
      expect(shown.isEligible(c), isTrue);
      final answered = shown.apply(
        c.id,
        c.version,
        VideoModalEventType.dismissed,
      );
      expect(answered.isEligible(c), isFalse);
      // Nouvelle version, public « tout le monde » : de retour.
      final v2 = VideoModalCampaign(
        id: c.id,
        version: 2,
        triggers: c.triggers,
        title: c.title,
        type: VideoModalType.info,
        body: c.body,
        primaryAction: c.primaryAction,
        audience: VideoModalAudience.everyone,
      );
      expect(answered.isEligible(v2), isTrue);
    });
  });
}
