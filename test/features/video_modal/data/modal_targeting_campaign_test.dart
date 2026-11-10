import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  group('valeurs par défaut (back sans les nouveaux champs)', () {
    test('une vidéo ancienne garde le comportement d\'avant', () {
      final c = VideoModalCampaign.tryParse(campaignJson())!;
      expect(c.priority, 0);
      expect(c.frequency, VideoModalFrequency.upToN);
      expect(c.frequencyDays, isNull);
      expect(c.stopAfterAnswer, isTrue);
      expect(c.allowDontShowAgain, isFalse);
      expect(c.lastShownAt, isNull);
      expect(c.displayCap, 3);
    });

    test('une information ancienne aussi', () {
      final c = VideoModalCampaign.tryParse(infoJson())!;
      expect(c.frequency, VideoModalFrequency.upToN);
      expect(c.stopAfterAnswer, isTrue);
      expect(c.allowDontShowAgain, isFalse);
    });

    test('champs de types inattendus : valeurs par défaut', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          extra: {
            'priority': 'haut',
            'stopAfterAnswer': 'oui',
            'allowDontShowAgain': 'oui',
            'lastShownAt': 12,
          },
        ),
      )!;
      expect(c.priority, 0);
      expect(c.stopAfterAnswer, isTrue);
      expect(c.allowDontShowAgain, isFalse);
      expect(c.lastShownAt, isNull);
    });

    test('lastShownAt illisible : ignoré', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(extra: {'lastShownAt': 'hier'}),
      )!;
      expect(c.lastShownAt, isNull);
    });
  });

  group('nouveaux champs', () {
    test('tous les champs sont lus', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          extra: {
            'priority': 7,
            'frequency': 'EVERY_N_DAYS',
            'frequencyDays': 14,
            'stopAfterAnswer': false,
            'allowDontShowAgain': true,
            'lastShownAt': '2026-11-01T08:00:00Z',
          },
        ),
      )!;
      expect(c.priority, 7);
      expect(c.frequency, VideoModalFrequency.everyNDays);
      expect(c.frequencyDays, 14);
      expect(c.stopAfterAnswer, isFalse);
      expect(c.allowDontShowAgain, isTrue);
      expect(c.lastShownAt, DateTime.utc(2026, 11, 1, 8));
    });

    test('les informations portent les mêmes champs', () {
      final c = VideoModalCampaign.tryParse(
        infoJson(
          extra: {
            'frequency': 'EVERY_OPEN',
            'allowDontShowAgain': true,
            'priority': -2,
          },
        ),
      )!;
      expect(c.frequency, VideoModalFrequency.everyOpen);
      expect(c.allowDontShowAgain, isTrue);
      expect(c.priority, -2);
    });

    test('fréquence inconnue : la campagne est ignorée', () {
      expect(
        VideoModalCampaign.tryParse(
          campaignJson(extra: {'frequency': 'EVERY_HOUR'}),
        ),
        isNull,
      );
    });

    test('EVERY_N_DAYS sans jours valides : ignorée', () {
      for (final days in <Object?>[null, 0, -1, 366, 'trois']) {
        expect(
          VideoModalCampaign.tryParse(
            campaignJson(
              extra: {'frequency': 'EVERY_N_DAYS', 'frequencyDays': days},
            ),
          ),
          isNull,
          reason: '$days',
        );
      }
    });

    test('frequencyDays est ignoré hors EVERY_N_DAYS', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(extra: {'frequency': 'ONCE', 'frequencyDays': 9}),
      )!;
      expect(c.frequencyDays, isNull);
    });
  });

  group('plafond d\'affichages selon la fréquence', () {
    test('ONCE = jusqu\'à 1 fois, même avec maxDisplays', () {
      final c = campaign(frequency: VideoModalFrequency.once, maxDisplays: 5);
      expect(c.displayCap, 1);
      expect(c.underDisplayCap, isTrue);
      expect(
        campaign(
          frequency: VideoModalFrequency.once,
          maxDisplays: 5,
          displays: 1,
        ).underDisplayCap,
        isFalse,
      );
    });

    test('UP_TO_N : maxDisplays', () {
      expect(campaign(displays: 2).underDisplayCap, isTrue);
      expect(campaign(displays: 3).underDisplayCap, isFalse);
    });

    test('à chaque lancement et tous les N jours : sans plafond', () {
      for (final f in [
        VideoModalFrequency.everyOpen,
        VideoModalFrequency.everyNDays,
      ]) {
        final c = campaign(frequency: f, frequencyDays: 2, displays: 99);
        expect(c.displayCap, isNull);
        expect(c.underDisplayCap, isTrue);
      }
    });
  });

  group('tri par priorité', () {
    test('priorité décroissante, ordre du back à égalité', () {
      final list = VideoModalCampaign.parseList([
        campaignJson(id: 'a'),
        campaignJson(id: 'b', extra: {'priority': 5}),
        campaignJson(id: 'c'),
        campaignJson(id: 'd', extra: {'priority': 5}),
        campaignJson(id: 'e', extra: {'priority': 10}),
        campaignJson(id: 'f', extra: {'priority': -1}),
      ]);
      expect(list.map((c) => c.id), ['e', 'b', 'd', 'a', 'c', 'f']);
    });

    test('sans priorité : l\'ordre du back est gardé', () {
      final list = VideoModalCampaign.parseList([
        campaignJson(id: 'x'),
        infoJson(id: 'y'),
        campaignJson(id: 'z'),
      ]);
      expect(list.map((c) => c.id), ['x', 'y', 'z']);
    });
  });

  group('événement DONT_SHOW_AGAIN', () {
    test('lu et écrit sur le fil', () {
      expect(
        VideoModalEventType.fromWire('DONT_SHOW_AGAIN'),
        VideoModalEventType.dontShowAgain,
      );
      expect(VideoModalEventType.dontShowAgain.wire, 'DONT_SHOW_AGAIN');
    });

    test('ni réponse ni statut : il ne rétrograde rien', () {
      const e = VideoModalEventType.dontShowAgain;
      expect(e.isAnswer, isFalse);
      expect(e.isWatch, isFalse);
      expect(e.isStatus, isFalse);
      expect(VideoModalEventType.completed.isStatus, isTrue);
    });
  });
}
