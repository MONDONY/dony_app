import 'dart:convert';
import 'dart:io';

import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('help_center_config.default.json', () {
    late HelpCenterConfig config;

    setUpAll(() {
      final raw = File(
        HelpCenterRemoteConfigDatasource.fallbackAssetPath,
      ).readAsStringSync();
      config = HelpCenterConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });

    test('se lit avec le parseur de production', () {
      expect(config.tutorials, isNotEmpty);
    });

    test(
      'les tutoriels actifs pointent vers les vidéos de la chaîne Yadony',
      () {
        final active = {
          for (final tutorial in config.tutorials.where((t) => t.active))
            tutorial.id: tutorial.youtubeVideoId,
        };

        expect(active, {
          'tuto_activites': 'CbRcG5lrYSY',
          'tuto_publier_trajet': 'rHaqqQUaPXU',
          'tuto_publier_demande': '0LoEdvquUkI',
          'tuto_negociation': '6qEiHiuKf4E',
          'tuto_alertes_corridor': '22_4Rnh9FpQ',
          'tuto_destinataires': 'jV2E3J1H8gM',
          'tuto_recharge_mobile_money': 'iBQQPfrBioQ',
        });
      },
    );

    test('un contexte sans vidéo ne propose aucun tutoriel', () {
      for (final context in [
        TutorialContext.search,
        TutorialContext.payment,
        TutorialContext.qrHandover,
        TutorialContext.tracking,
        TutorialContext.dispute,
        TutorialContext.tripTemplates,
        TutorialContext.receivedRequests,
      ]) {
        expect(config.tutorialFor(context), isNull, reason: context.name);
      }
    });
  });
}
