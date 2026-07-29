import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validTutorialsJson = [
    {
      'id': 'payment-basics',
      'title': 'Payer un envoi',
      'description': 'Le paiement en toute simplicité.',
      'youtubeVideoId': 'dQw4w9WgXcQ',
      'order': 2,
      'active': true,
      'contexts': ['payment'],
      'durationLabel': '2 min',
    },
    {
      'id': 'search-basics',
      'title': 'Trouver un trajet',
      'description': 'Recherchez un voyageur.',
      'youtubeVideoId': 'M7lc1UVf-VE',
      'order': 1,
      'active': true,
      'contexts': ['search', 'activities'],
    },
  ];

  group('HelpCenterConfig', () {
    test('parse une configuration complète et trie les tutoriels', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'youtubeChannelUrl': 'https://www.youtube.com/@yadony',
        'socialLinks': [
          {
            'network': 'whatsapp',
            'url': 'https://wa.me/123456789',
            'active': true,
          },
        ],
        'tutorials': validTutorialsJson,
      });

      expect(config.schemaVersion, 1);
      expect(
        config.youtubeChannelUrl,
        Uri.parse('https://www.youtube.com/@yadony'),
      );
      expect(config.socialLinks.single.network, SocialNetwork.whatsapp);
      expect(
        config.socialLinks.single.url.toString(),
        'https://wa.me/123456789',
      );
      expect(config.socialLinks.single.active, isTrue);
      expect(config.tutorials.map((item) => item.id), [
        'search-basics',
        'payment-basics',
      ]);
      expect(config.tutorials.first.contexts, [
        TutorialContext.search,
        TutorialContext.activities,
      ]);
      expect(config.tutorials.last.durationLabel, '2 min');
    });

    test('rejette une version de schéma non prise en charge', () {
      expect(
        () => HelpCenterConfig.fromJson({'schemaVersion': 2}),
        throwsA(isA<FormatException>()),
      );
    });

    test('ignore une entrée sociale invalide sans perdre le catalogue', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'youtubeChannelUrl': 'https://www.youtube.com/@yadony',
        'socialLinks': [
          {'network': 'whatsapp', 'url': 'javascript:alert(1)', 'active': true},
          {
            'network': 'instagram',
            'url': 'https://instagram.com/yadony',
            'active': true,
          },
        ],
        'tutorials': validTutorialsJson,
      });

      expect(config.socialLinks.map((item) => item.network), [
        SocialNetwork.instagram,
      ]);
      expect(config.tutorials, isNotEmpty);
    });

    test('ignore un tutoriel avec un identifiant vidéo invalide', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {...validTutorialsJson.first, 'youtubeVideoId': 'short'},
          validTutorialsJson.last,
        ],
      });

      expect(config.tutorials.map((item) => item.id), ['search-basics']);
    });

    test('ignore un tutoriel dont l’identifiant est dupliqué', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          validTutorialsJson.first,
          {...validTutorialsJson.last, 'id': 'payment-basics'},
        ],
      });

      expect(config.tutorials, hasLength(1));
      expect(config.tutorials.single.id, 'payment-basics');
    });

    test('ignore un tutoriel ayant un contexte inconnu', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {
            ...validTutorialsJson.first,
            'contexts': ['unknown'],
          },
          validTutorialsJson.last,
        ],
      });

      expect(config.tutorials.map((item) => item.id), ['search-basics']);
    });

    test(
      'renvoie seulement les tutoriels actifs correspondant aux recherches',
      () {
        final config = HelpCenterConfig.fromJson({
          'schemaVersion': 1,
          'tutorials': [
            ...validTutorialsJson,
            {
              ...validTutorialsJson.first,
              'id': 'inactive-payment',
              'active': false,
              'order': 3,
            },
          ],
        });

        expect(
          config.tutorialFor(TutorialContext.payment)?.id,
          'payment-basics',
        );
        expect(config.tutorialById('inactive-payment'), isNull);
        expect(config.tutorialById('missing'), isNull);
      },
    );
  });
}
