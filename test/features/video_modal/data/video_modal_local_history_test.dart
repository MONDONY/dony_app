import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

void main() {
  const shown = VideoModalEventType.shown;
  const opened = VideoModalEventType.opened;
  const completed = VideoModalEventType.completed;
  const dismissed = VideoModalEventType.dismissed;

  group('VideoModalVersionRecord', () {
    test('compte les affichages et ne rétrograde jamais le statut', () {
      final r = const VideoModalVersionRecord()
          .apply(shown)
          .apply(completed)
          .apply(opened)
          .apply(dismissed)
          .apply(shown);
      expect(r.displays, 2);
      expect(r.status, completed);
      expect(r.answered, isTrue);
      expect(r.watched, isTrue);
    });
  });

  group('isEligible (visiteur sans compte)', () {
    test('sans historique : éligible', () {
      expect(const VideoModalLocalHistory().isEligible(campaign()), isTrue);
    });

    test('plafond maxDisplays atteint par des fermetures au geste', () {
      var h = const VideoModalLocalHistory();
      for (var i = 0; i < 2; i++) {
        h = h.apply('c1', 2, shown);
      }
      expect(h.isEligible(campaign()), isTrue);
      h = h.apply('c1', 2, shown);
      expect(h.isEligible(campaign()), isFalse);
    });

    test('version courante répondue : plus affichée', () {
      final h = const VideoModalLocalHistory()
          .apply('c1', 2, shown)
          .apply('c1', 2, dismissed);
      expect(
        h.isEligible(campaign(audience: VideoModalAudience.everyone)),
        isFalse,
      );
    });

    test('NEVER_ANSWERED : une réponse à une version précédente exclut', () {
      final h = const VideoModalLocalHistory().apply('c1', 1, dismissed);
      expect(h.isEligible(campaign()), isFalse);
      final shownOnly = const VideoModalLocalHistory().apply('c1', 1, shown);
      expect(shownOnly.isEligible(campaign()), isTrue);
    });

    test('EVERYONE : même ceux qui ont répondu avant', () {
      final h = const VideoModalLocalHistory().apply('c1', 1, completed);
      expect(
        h.isEligible(campaign(audience: VideoModalAudience.everyone)),
        isTrue,
      );
    });

    test(
      'NOT_WATCHED_PREVIOUS : exclut qui a ouvert une version précédente',
      () {
        final c = campaign(audience: VideoModalAudience.notWatchedPrevious);
        expect(
          const VideoModalLocalHistory().apply('c1', 1, opened).isEligible(c),
          isFalse,
        );
        expect(
          const VideoModalLocalHistory()
              .apply('c1', 1, dismissed)
              .isEligible(c),
          isTrue,
        );
      },
    );

    test("l'historique d'une autre campagne ne compte pas", () {
      final h = const VideoModalLocalHistory().apply('autre', 2, dismissed);
      expect(h.isEligible(campaign()), isTrue);
    });
  });

  test('aller-retour JSON', () {
    final h = const VideoModalLocalHistory()
        .apply('c1', 1, shown)
        .apply('c1', 2, opened)
        .apply('c2', 1, dismissed);
    expect(VideoModalLocalHistory.fromJson(h.toJson()), h);
    expect(VideoModalLocalHistory.fromJson('x').isEmpty, isTrue);
    expect(
      VideoModalLocalHistory.fromJson({
        'c1': {'abc': {}, '3': 'x'},
        'c2': 'x',
      }).recordOf('c1', 3),
      const VideoModalVersionRecord(),
    );
  });

  test('PendingVideoModalEvent : aller-retour et entrée cassée', () {
    final e = PendingVideoModalEvent(
      campaignId: 'c1',
      version: 2,
      event: opened,
      occurredAt: DateTime.utc(2026, 11, 10, 10),
    );
    expect(PendingVideoModalEvent.tryParse(e.toJson()), e);
    expect(e.toJson()['occurredAt'], '2026-11-10T10:00:00.000Z');
    expect(PendingVideoModalEvent.tryParse({'campaignId': 'c1'}), isNull);
    expect(PendingVideoModalEvent.tryParse(3), isNull);
  });
}
