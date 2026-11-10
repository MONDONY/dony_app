import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

Map<String, Object?> info(Map<String, Object?> extra) => infoJson(extra: extra);

const _url = 'https://cdn.yadony.com/video-modals/c1/1.webp';

void main() {
  group('lecture tolérante des nouveaux champs', () {
    test('absents : feuille du bas, taille auto, sans image', () {
      final c = VideoModalCampaign.tryParse(campaignJson())!;
      expect(c.layout, VideoModalLayout.bottomSheet);
      expect(c.sizePercent, isNull);
      expect(c.imageMode, VideoModalImageMode.none);
      expect(c.imageUrl, isNull);
      expect(c.hasImage, isFalse);
      expect(c.isPoster, isFalse);
      final i = VideoModalCampaign.tryParse(infoJson())!;
      expect(i.layout, VideoModalLayout.bottomSheet);
      expect(i.imageFit, VideoModalImageFit.cover);
      expect(i.hasImage, isFalse);
    });

    test('null explicite : valeurs par défaut', () {
      final c = VideoModalCampaign.tryParse(
        info({
          'layout': null,
          'sizePercent': null,
          'imageMode': null,
          'imageFit': null,
          'imageUrl': null,
        }),
      )!;
      expect(c.layout, VideoModalLayout.bottomSheet);
      expect(c.imageMode, VideoModalImageMode.none);
    });

    for (final l in VideoModalLayout.values) {
      test('layout ${l.wire}', () {
        final v = VideoModalCampaign.tryParse({
          ...campaignJson(),
          'layout': l.wire,
        })!;
        expect(v.layout, l);
        final i = VideoModalCampaign.tryParse(info({'layout': l.wire}))!;
        expect(i.layout, l);
      });
    }

    test('layout inconnu : campagne ignorée (vidéo et information)', () {
      expect(
        VideoModalCampaign.tryParse({...campaignJson(), 'layout': 'MODAL3D'}),
        isNull,
      );
      expect(VideoModalCampaign.tryParse(info({'layout': 'MODAL3D'})), isNull);
      expect(VideoModalCampaign.tryParse(info({'layout': 3})), isNull);
      // Une liste mélangée garde les campagnes valides.
      final list = VideoModalCampaign.parseList([
        campaignJson(id: 'ok'),
        {...campaignJson(id: 'ko'), 'layout': 'X'},
      ]);
      expect(list.map((c) => c.id), ['ok']);
    });

    test('sizePercent : 30 à 100 gardé, hors bornes ou illisible = auto', () {
      for (final v in [30, 55, 100]) {
        expect(
          VideoModalCampaign.tryParse(info({'sizePercent': v}))!.sizePercent,
          v,
        );
      }
      expect(
        VideoModalCampaign.tryParse(info({'sizePercent': 60.0}))!.sizePercent,
        60,
      );
      for (final v in [0, 29, 101, -5, 'beaucoup']) {
        expect(
          VideoModalCampaign.tryParse(info({'sizePercent': v}))!.sizePercent,
          isNull,
          reason: '$v',
        );
      }
    });

    test('bannière : mode, cadrage, adresse et texte alternatif', () {
      final c = VideoModalCampaign.tryParse(
        info({
          'imageMode': 'TOP',
          'imageFit': 'CONTAIN',
          'imageUrl': _url,
          'imageAlt': '  Affiche du concours  ',
        }),
      )!;
      expect(c.imageMode, VideoModalImageMode.top);
      expect(c.imageFit, VideoModalImageFit.contain);
      expect(c.imageUrl, _url);
      expect(c.imageAlt, 'Affiche du concours');
      expect(c.hasImage, isTrue);
      expect(c.isPoster, isFalse);
    });

    test('affiche : cadrage par défaut COVER', () {
      final c = VideoModalCampaign.tryParse(
        info({'imageMode': 'POSTER', 'imageUrl': _url}),
      )!;
      expect(c.isPoster, isTrue);
      expect(c.imageFit, VideoModalImageFit.cover);
      expect(c.imageAlt, isNull);
    });

    test('mode d\'image inconnu : campagne ignorée', () {
      expect(
        VideoModalCampaign.tryParse(
          info({'imageMode': 'MOSAIC', 'imageUrl': _url}),
        ),
        isNull,
      );
    });

    test('cadrage inconnu avec image : campagne ignorée', () {
      expect(
        VideoModalCampaign.tryParse(
          info({'imageMode': 'TOP', 'imageUrl': _url, 'imageFit': 'STRETCH'}),
        ),
        isNull,
      );
      // Sans image, le cadrage n'est pas lu.
      expect(
        VideoModalCampaign.tryParse(info({'imageFit': 'STRETCH'})),
        isNotNull,
      );
    });

    test('affiche sans adresse https valide : campagne ignorée', () {
      for (final u in [null, '', 'http://x.com/a.png', 'data:image/png', 12]) {
        expect(
          VideoModalCampaign.tryParse(
            info({'imageMode': 'POSTER', 'imageUrl': u}),
          ),
          isNull,
          reason: '$u',
        );
      }
    });

    test('bannière sans adresse valide : modal affiché sans image', () {
      final c = VideoModalCampaign.tryParse(
        info({'imageMode': 'TOP', 'imageUrl': 'ftp://x'}),
      )!;
      expect(c.imageMode, VideoModalImageMode.none);
      expect(c.hasImage, isFalse);
    });

    test('vidéo : image ignorée, même avec un mode inconnu', () {
      final c = VideoModalCampaign.tryParse({
        ...campaignJson(),
        'imageMode': 'WHATEVER',
        'imageUrl': _url,
      })!;
      expect(c.imageMode, VideoModalImageMode.none);
      expect(c.imageUrl, isNull);
    });

    test('égalité : le format et l\'image comptent', () {
      final a = VideoModalCampaign.tryParse(info({'layout': 'CENTERED'}))!;
      final b = VideoModalCampaign.tryParse(info({'layout': 'FULLSCREEN'}))!;
      expect(a, isNot(b));
      expect(a, VideoModalCampaign.tryParse(info({'layout': 'CENTERED'})));
    });
  });
}
