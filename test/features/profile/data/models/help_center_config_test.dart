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
      final config = HelpCenterConfig.fromJson(const {
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
        () => HelpCenterConfig.fromJson(const {'schemaVersion': 2}),
        throwsA(isA<FormatException>()),
      );
    });

    test('ignore une entrée sociale invalide sans perdre le catalogue', () {
      final config = HelpCenterConfig.fromJson(const {
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

    test(
      'ignore une URL de chaîne YouTube invalide sans perdre les tutoriels',
      () {
        final config = HelpCenterConfig.fromJson(const {
          'schemaVersion': 1,
          'youtubeChannelUrl': 'http://www.youtube.com/@yadony',
          'tutorials': validTutorialsJson,
        });

        expect(config.youtubeChannelUrl, isNull);
        expect(config.tutorials, isNotEmpty);
      },
    );

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

    // Un contexte ajouté par une version plus récente ne doit
    // plus faire disparaître le tutoriel des builds qui ne le connaissent pas.
    test('garde les contextes connus et ignore les inconnus', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {
            ...validTutorialsJson.last,
            'contexts': const ['payment', 'futureContext'],
          },
        ],
      });

      expect(config.tutorials.single.contexts, [TutorialContext.payment]);
    });

    test('refuse toujours un contexte en double', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {
            ...validTutorialsJson.last,
            'contexts': const ['payment', 'payment'],
          },
        ],
      });

      expect(config.tutorials, isEmpty);
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

    test('lit une démo sans contexte, avec sa langue et son format', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          const {
            'id': 'demo_fr_01',
            'title': 'Rechercher un voyageur',
            'description': 'La recherche.',
            'youtubeVideoId': 'dQw4w9WgXcQ',
            'order': 101,
            'active': true,
            'language': 'fr',
            'vertical': true,
          },
          validTutorialsJson.last,
        ],
      });

      final demo = config.tutorialById('demo_fr_01')!;
      expect(demo.isDemo, isTrue);
      expect(demo.vertical, isTrue);
      expect(demo.appliesToLanguage('fr'), isTrue);
      expect(demo.appliesToLanguage('en'), isFalse);

      final guide = config.tutorialById('search-basics')!;
      expect(guide.isDemo, isFalse);
      expect(guide.vertical, isFalse);
      expect(guide.appliesToLanguage('en'), isTrue);
    });

    test('ignore un tutoriel dont la langue ou le format est invalide', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {...validTutorialsJson.first, 'language': 1},
          {...validTutorialsJson.last, 'id': 'b', 'vertical': 'oui'},
        ],
      });

      expect(config.tutorials, isEmpty);
    });

    test('le catalogue distant ne masque pas les démos embarquées', () {
      Map<String, dynamic> withTutorials(List<Object> tutorials) => {
        'schemaVersion': 1,
        'tutorials': tutorials,
      };
      final remote = HelpCenterConfig.fromJson(
        withTutorials([validTutorialsJson.first]),
      );
      final bundled = HelpCenterConfig.fromJson(
        withTutorials([
          {
            'id': 'demo_fr_01',
            'title': 'Démo',
            'description': 'Une démo.',
            'youtubeVideoId': 'M7lc1UVf-VE',
            'order': 101,
            'active': true,
          },
        ]),
      );

      expect(remote.completedWith(bundled).tutorials.map((t) => t.id), [
        'payment-basics',
        'demo_fr_01',
      ]);
    });

    test('ignore un tutoriel ayant un contexte inconnu', () {
      final config = HelpCenterConfig.fromJson({
        'schemaVersion': 1,
        'tutorials': [
          {
            ...validTutorialsJson.first,
            'contexts': const ['unknown'],
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
