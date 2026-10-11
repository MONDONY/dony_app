// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('HelpCenterEvent — égalité de valeur', () {
    test('chargement et ouverture : sans champ, distincts', () {
      expectValueEquality(() => HelpCenterLoadRequested(), [
        HelpCenterOpenRequested(),
      ]);
      expectValueEquality(() => HelpCenterOpenRequested(), [
        HelpCenterLoadRequested(),
      ]);
    });

    test('ouverture d’un tutoriel : identifiant et contexte', () {
      expectValueEquality(
        () => HelpTutorialOpenRequested(
          tutorialId: 'tuto-1',
          source: TutorialContext.payment,
        ),
        [
          HelpTutorialOpenRequested(tutorialId: 'tuto-1', source: null),
          HelpTutorialOpenRequested(
            tutorialId: 'tuto-2',
            source: TutorialContext.payment,
          ),
        ],
      );
    });

    test('lecture d’un tutoriel : identifiant et action', () {
      expectValueEquality(
        () => HelpTutorialPlaybackRequested(
          tutorialId: 'tuto-1',
          action: HelpPlaybackAction.started,
        ),
        [
          HelpTutorialPlaybackRequested(
            tutorialId: 'tuto-1',
            action: HelpPlaybackAction.completed,
          ),
        ],
      );
    });

    test('lien externe : cible, réseau et contexte distinguent', () {
      final uri = Uri.parse('https://youtube.com/@yadony');
      final link = SocialLink(
        network: SocialNetwork.whatsapp,
        url: uri,
        active: true,
      );
      expectValueEquality(
        () => HelpExternalOpenRequested.tutorial(uri: uri, tutorialId: 't-1'),
        [
          HelpExternalOpenRequested.tutorial(uri: uri, tutorialId: 't-2'),
          HelpExternalOpenRequested.social(link: link),
          HelpExternalOpenRequested.posterGroup(link: link),
          HelpExternalOpenRequested.youtubeSubscription(
            uri: uri,
            source: TutorialContext.search,
          ),
        ],
      );
      final social = HelpExternalOpenRequested.social(link: link);
      expect(social.target, HelpExternalTarget.social);
      expect(social.network, SocialNetwork.whatsapp);
    });
  });

  group('FaqEvent — égalité de valeur', () {
    test('recherche, question ouverte et contact', () {
      expectValueEquality(() => FaqSearchChanged('colis'), [
        FaqSearchChanged('paiement'),
      ]);
      expectValueEquality(
        () => FaqQuestionOpened(categoryId: 'c-1', questionId: 'q-1'),
        [
          FaqQuestionOpened(categoryId: 'c-1', questionId: 'q-2'),
          FaqQuestionOpened(categoryId: 'c-2', questionId: 'q-1'),
        ],
      );
      expectValueEquality(() => FaqContactRequested(), [FaqSearchChanged('')]);
      expect(FaqContactRequested().props, isEmpty);
    });
  });

  group('UpgradeToProEvent — égalité de valeur', () {
    test('rétrogradation : sans champ', () {
      expectValueEquality(() => DowngradeRequested(), const []);
      expect(DowngradeRequested().props, isEmpty);
    });
  });
}
