import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  final now = DateTime(2026, 11, 10, 9, 30);
  const empty = VideoModalLocalHistory();

  VideoModalLocalHistory after(
    VideoModalCampaign c,
    List<VideoModalEventType> events, {
    DateTime? at,
    VideoModalLocalHistory from = empty,
  }) {
    var h = from;
    for (final e in events) {
      h = h.apply(c.id, c.version, e, at: at ?? now);
    }
    return h;
  }

  group('ONCE', () {
    final c = campaign(
      frequency: VideoModalFrequency.once,
      stopAfterAnswer: false,
      maxDisplays: 5,
    );

    test('jamais affichée : éligible', () {
      expect(empty.isEligible(c, now: now), isTrue);
    });

    test(
      'affichée une fois : plus éligible, même si maxDisplays le permet',
      () {
        final h = after(c, [VideoModalEventType.shown]);
        expect(h.isEligible(c, now: now), isFalse);
      },
    );
  });

  group('UP_TO_N', () {
    final c = campaign(maxDisplays: 2, stopAfterAnswer: false);

    test('éligible tant que le plafond n\'est pas atteint', () {
      final one = after(c, [VideoModalEventType.shown]);
      expect(one.isEligible(c, now: now), isTrue);
      final two = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.shown,
      ]);
      expect(two.isEligible(c, now: now), isFalse);
    });
  });

  group('EVERY_OPEN', () {
    final c = campaign(
      frequency: VideoModalFrequency.everyOpen,
      stopAfterAnswer: false,
    );

    test('toujours éligible, aucun plafond', () {
      final h = after(c, List.filled(20, VideoModalEventType.shown));
      expect(h.isEligible(c, now: now), isTrue);
    });
  });

  group('EVERY_N_DAYS', () {
    final c = campaign(
      frequency: VideoModalFrequency.everyNDays,
      frequencyDays: 7,
      stopAfterAnswer: false,
    );

    test('jamais affichée : éligible', () {
      expect(empty.isEligible(c, now: now), isTrue);
    });

    test('affichée il y a moins de N jours : pas encore', () {
      final h = after(c, [
        VideoModalEventType.shown,
      ], at: now.subtract(const Duration(days: 6, hours: 23)));
      expect(h.isEligible(c, now: now), isFalse);
    });

    test('affichée il y a N jours pile ou plus : éligible', () {
      final h = after(c, [
        VideoModalEventType.shown,
      ], at: now.subtract(const Duration(days: 7)));
      expect(h.isEligible(c, now: now), isTrue);
    });

    test('le dernier affichage compte, pas le premier', () {
      final first = after(c, [
        VideoModalEventType.shown,
      ], at: now.subtract(const Duration(days: 30)));
      final h = after(
        c,
        [VideoModalEventType.shown],
        at: now.subtract(const Duration(days: 2)),
        from: first,
      );
      expect(h.recordOf(c.id, c.version).lastShownAt, isNotNull);
      expect(h.isEligible(c, now: now), isFalse);
    });

    test(
      'sans jours (cas théorique) : seule l\'absence d\'affichage compte',
      () {
        final noDays = campaign(
          frequency: VideoModalFrequency.everyNDays,
          stopAfterAnswer: false,
        );
        final h = after(noDays, [VideoModalEventType.shown]);
        expect(h.isEligible(noDays, now: now), isTrue);
      },
    );

    test('now absent : horloge de l\'appareil', () {
      final h = after(c, [
        VideoModalEventType.shown,
      ], at: DateTime.now().subtract(const Duration(days: 1)));
      expect(h.isEligible(c), isFalse);
    });
  });

  group('stopAfterAnswer', () {
    test('vrai : une réponse bloque les affichages suivants', () {
      final c = campaign(frequency: VideoModalFrequency.everyOpen);
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.dismissed,
      ]);
      expect(h.isEligible(c, now: now), isFalse);
    });

    test('faux : une réponse ne bloque pas, la fréquence juge', () {
      final c = campaign(
        frequency: VideoModalFrequency.everyOpen,
        stopAfterAnswer: false,
      );
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.opened,
      ]);
      expect(h.isEligible(c, now: now), isTrue);
    });

    test('faux : le plafond d\'affichages bloque quand même', () {
      final c = campaign(stopAfterAnswer: false, maxDisplays: 1);
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.opened,
      ]);
      expect(h.isEligible(c, now: now), isFalse);
    });

    test('faux : la réponse de la version courante n\'exclut pas le public '
        '« jamais répondu »', () {
      final c = campaign(stopAfterAnswer: false);
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.opened,
      ]);
      expect(h.isEligible(c, now: now), isTrue);
    });

    test('faux : une réponse à une version précédente exclut ce public', () {
      final c = campaign(stopAfterAnswer: false);
      final h = empty.apply(c.id, 1, VideoModalEventType.dismissed, at: now);
      expect(h.isEligible(c, now: now), isFalse);
    });
  });

  group('DONT_SHOW_AGAIN', () {
    test(
      'bloque la version, quelles que soient frequency et stopAfterAnswer',
      () {
        for (final f in VideoModalFrequency.values) {
          final c = campaign(
            frequency: f,
            frequencyDays: 1,
            stopAfterAnswer: false,
          );
          final h = after(c, [VideoModalEventType.dontShowAgain]);
          expect(h.isEligible(c, now: now), isFalse, reason: f.wire);
        }
      },
    );

    test('ne touche ni les affichages ni le statut', () {
      final c = campaign();
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.opened,
        VideoModalEventType.dontShowAgain,
      ]);
      final r = h.recordOf(c.id, c.version);
      expect(r.displays, 1);
      expect(r.status, VideoModalEventType.opened);
      expect(r.dontShowAgain, isTrue);
      expect(r.lastShownAt, now);
    });

    test('ne vaut que pour sa version : la suivante revient', () {
      final c = campaign();
      final h = after(c, [VideoModalEventType.dontShowAgain]);
      final v3 = campaign(version: 3, audience: VideoModalAudience.everyone);
      expect(h.isEligible(v3, now: now), isTrue);
    });

    test('ne rétrograde pas un statut (même sans réponse avant)', () {
      final c = campaign();
      final h = after(c, [VideoModalEventType.dontShowAgain]);
      expect(h.recordOf(c.id, c.version).answered, isFalse);
      expect(h.recordOf(c.id, c.version).status, isNull);
    });
  });

  group('plafond d\'un modal par jour', () {
    test('aucun modal : pas de plafond', () {
      expect(empty.dailyCapReached(now), isFalse);
    });

    test('un SHOWN aujourd\'hui : plafond atteint, toutes campagnes', () {
      final h = empty.apply(
        'autre',
        1,
        VideoModalEventType.shown,
        at: DateTime(2026, 11, 10, 0, 5),
      );
      expect(h.dailyCapReached(now), isTrue);
      expect(h.dailyCapReached(DateTime(2026, 11, 10, 23, 59)), isTrue);
    });

    test('changement de jour (minuit passé) : le plafond retombe', () {
      final h = empty.apply(
        'autre',
        1,
        VideoModalEventType.shown,
        at: DateTime(2026, 11, 10, 23, 59),
      );
      expect(h.dailyCapReached(DateTime(2026, 11, 11, 0, 1)), isFalse);
      expect(h.dailyCapReached(DateTime(2026, 12, 10, 9)), isFalse);
      expect(h.dailyCapReached(DateTime(2027, 11, 10, 9)), isFalse);
    });

    test('seul un SHOWN compte, pas une réponse', () {
      final h = empty.apply('c', 1, VideoModalEventType.opened, at: now);
      expect(h.lastModalAt, isNull);
      expect(h.dailyCapReached(now), isFalse);
    });

    test('le dernier SHOWN fait foi', () {
      final h = empty
          .apply('a', 1, VideoModalEventType.shown, at: DateTime(2026, 11, 8))
          .apply('b', 1, VideoModalEventType.shown, at: now);
      expect(h.lastModalAt, now);
      expect(h.dailyCapReached(now), isTrue);
    });
  });

  group('public de la version', () {
    test('EVERYONE : tout le monde', () {
      final c = campaign(audience: VideoModalAudience.everyone);
      final h = empty.apply(c.id, 1, VideoModalEventType.opened, at: now);
      expect(h.isEligible(c, now: now), isTrue);
    });

    test(
      'NOT_WATCHED_PREVIOUS : exclut qui a ouvert une version précédente',
      () {
        final c = campaign(audience: VideoModalAudience.notWatchedPrevious);
        expect(
          empty
              .apply(c.id, 1, VideoModalEventType.dismissed, at: now)
              .isEligible(c, now: now),
          isTrue,
        );
        expect(
          empty
              .apply(c.id, 1, VideoModalEventType.opened, at: now)
              .isEligible(c, now: now),
          isFalse,
        );
      },
    );
  });

  group('stockage', () {
    test('aller-retour du nouveau format', () {
      final c = campaign();
      final h = after(c, [
        VideoModalEventType.shown,
        VideoModalEventType.opened,
        VideoModalEventType.dontShowAgain,
      ]);
      final back = VideoModalLocalHistory.fromJson(h.toJson());
      expect(back.toJson(), h.toJson());
      expect(back.lastModalAt!.isAtSameMomentAs(now), isTrue);
      final r = back.recordOf(c.id, c.version);
      expect(r.dontShowAgain, isTrue);
      expect(r.lastShownAt!.isAtSameMomentAs(now), isTrue);
      expect(r.status, VideoModalEventType.opened);
    });

    test('lit l\'ancien format (campagnes à la racine)', () {
      final back = VideoModalLocalHistory.fromJson({
        'c1': {
          '2': {'displays': 2, 'status': 'DISMISSED'},
        },
      });
      expect(back.lastModalAt, isNull);
      final r = back.recordOf('c1', 2);
      expect(r.displays, 2);
      expect(r.status, VideoModalEventType.dismissed);
      expect(r.lastShownAt, isNull);
      expect(r.dontShowAgain, isFalse);
    });

    test('un statut DONT_SHOW_AGAIN stocké n\'est pas un statut', () {
      final r = VideoModalVersionRecord.fromJson({
        'displays': 1,
        'status': 'DONT_SHOW_AGAIN',
      });
      expect(r.status, isNull);
    });

    test('dernier modal illisible : ignoré', () {
      final back = VideoModalLocalHistory.fromJson({
        'v': 2,
        'campaigns': <String, Object?>{},
        'lastModalAt': 'hier',
      });
      expect(back.lastModalAt, isNull);
      expect(back.isEmpty, isTrue);
    });

    test('un historique qui n\'a que le dernier modal n\'est pas vide', () {
      final h = empty.apply('c', 1, VideoModalEventType.shown, at: now);
      expect(h.isEmpty, isFalse);
    });
  });
}
