import 'dart:async';

import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BrokenLocal extends VideoModalLocalDatasource {
  @override
  Future<String?> readLastAppVersion() => throw StateError('illisible');

  @override
  Future<Map<String, int>> readTripViews() => throw StateError('illisible');
}

void main() {
  late VideoModalLocalDatasource local;
  late VideoModalMoments moments;
  late List<VideoModalMomentSignal> received;
  late StreamSubscription<VideoModalMomentSignal> sub;
  String? appVersion;
  var now = DateTime.utc(2026, 11, 10, 12);

  Future<VideoModalMoments> build({
    VideoModalLocalDatasource? datasource,
    String? Function()? version,
  }) async {
    SharedPreferences.setMockInitialValues({});
    local = datasource ?? VideoModalLocalDatasource();
    final m = VideoModalMoments(
      local: local,
      appVersion: () async => (version ?? () => appVersion)(),
      clock: () => now,
    );
    received = [];
    sub = m.signals.listen(received.add);
    addTearDown(() async {
      await sub.cancel();
      await m.dispose();
    });
    return m;
  }

  setUp(() async {
    appVersion = '1.0.4';
    now = DateTime.utc(2026, 11, 10, 12);
    moments = await build();
  });

  group('émission', () {
    test('le moment part avec son heure et son écran d\'origine', () async {
      final moment = VideoModalMoment.action(VideoModalTrigger.kycVerified);
      moments.emit(moment);
      await pumpEventQueue();
      expect(received, hasLength(1));
      expect(received.single.moment, moment);
      expect(received.single.emittedAt, now);
      expect(received.single.origin, isNull);
    });

    test('sans écouteur : rien, aucune erreur', () async {
      final alone = VideoModalMoments(local: local, clock: () => now);
      alone.emit(VideoModalMoment.action(VideoModalTrigger.kycVerified));
      await alone.dispose();
      // Fermé : toujours sans erreur.
      alone.emit(VideoModalMoment.action(VideoModalTrigger.kycVerified));
    });

    test('notify passe par l\'instance de l\'app', () async {
      VideoModalMoments.useForTest(moments);
      addTearDown(VideoModalMoments.resetForTest);
      VideoModalMoments.notify(
        VideoModalMoment.action(VideoModalTrigger.paymentFailed),
      );
      await pumpEventQueue();
      expect(received.single.moment.trigger, VideoModalTrigger.paymentFailed);
    });
  });

  group('APP_UPDATED', () {
    test(
      'toute première installation : version retenue, aucun moment',
      () async {
        expect(await moments.checkAppUpdated(), isFalse);
        await pumpEventQueue();
        expect(received, isEmpty);
        expect(await local.readLastAppVersion(), '1.0.4');
      },
    );

    test('même version : aucun moment', () async {
      await moments.checkAppUpdated();
      expect(await moments.checkAppUpdated(), isFalse);
      expect(received, isEmpty);
    });

    test('changement de version : un moment, puis plus rien', () async {
      await moments.checkAppUpdated();
      appVersion = '1.0.5';
      expect(await moments.checkAppUpdated(), isTrue);
      await pumpEventQueue();
      expect(received.single.moment.trigger, VideoModalTrigger.appUpdated);
      expect(await local.readLastAppVersion(), '1.0.5');
      // Le lancement suivant : même version, rien de plus.
      expect(await moments.checkAppUpdated(), isFalse);
      expect(received, hasLength(1));
    });

    test('un retour à une version plus ancienne compte aussi', () async {
      await moments.checkAppUpdated();
      appVersion = '1.0.3';
      expect(await moments.checkAppUpdated(), isTrue);
    });

    test('version illisible ou vide : rien, rien de mémorisé', () async {
      appVersion = null;
      expect(await moments.checkAppUpdated(), isFalse);
      appVersion = '';
      expect(await moments.checkAppUpdated(), isFalse);
      expect(await local.readLastAppVersion(), isNull);
    });

    test('stockage illisible : aucun moment, aucune erreur', () async {
      final broken = await build(datasource: _BrokenLocal());
      expect(await broken.checkAppUpdated(), isFalse);
    });
  });

  group('consultations d\'une fiche trajet', () {
    final corridor = VideoModalMomentCorridor(
      fromCity: 'Paris',
      toCity: 'Abidjan',
    );

    test(
      'compteur par identifiant ; le moment part dès la 2e consultation',
      () async {
        expect(await moments.recordTripView('t1', corridor: corridor), 1);
        await pumpEventQueue();
        expect(received, isEmpty);
        expect(await moments.recordTripView('t1', corridor: corridor), 2);
        expect(await moments.recordTripView('t2'), 1);
        expect(await moments.recordTripView('t1', corridor: corridor), 3);
        await pumpEventQueue();
        final counts = received.map((s) => s.moment.viewCount).toList();
        expect(counts, [2, 3]);
        expect(received.first.moment.tripId, 't1');
        expect(
          received.first.moment.trigger,
          VideoModalTrigger.tripViewedRepeatedly,
        );
        expect(received.first.moment.corridor, corridor);
      },
    );

    test('remise à zéro après l\'affichage du modal', () async {
      await moments.recordTripView('t1');
      await moments.recordTripView('t1');
      await moments.recordTripView('t2');
      await moments.resetTripViews('t1');
      expect(await local.readTripViews(), {'t2': 1});
      // Le compteur repart de 1 : pas de moment avant la 2e consultation.
      received.clear();
      expect(await moments.recordTripView('t1'), 1);
      await pumpEventQueue();
      expect(received, isEmpty);
      // Remettre à zéro un trajet inconnu : sans effet.
      await moments.resetTripViews('inconnu');
    });

    test('au plus 50 trajets suivis : les plus anciens partent', () async {
      for (var i = 0; i < VideoModalMoments.maxTrackedTrips + 5; i++) {
        await moments.recordTripView('t$i');
      }
      final views = await local.readTripViews();
      expect(views, hasLength(VideoModalMoments.maxTrackedTrips));
      expect(views.containsKey('t0'), isFalse);
      expect(views.containsKey('t54'), isTrue);
      // Un trajet revu passe en dernier et survit.
      await moments.recordTripView('t5');
      await moments.recordTripView('t55');
      final after = await local.readTripViews();
      expect(after.containsKey('t5'), isTrue);
      expect(after.containsKey('t6'), isFalse);
    });

    test('consultations simultanées : aucune n\'est perdue', () async {
      await Future.wait([
        for (var i = 0; i < 5; i++) moments.recordTripView('t1'),
      ]);
      expect((await local.readTripViews())['t1'], 5);
    });

    test('identifiant vide : ignoré', () async {
      expect(await moments.recordTripView(''), 0);
      expect(await local.readTripViews(), isEmpty);
    });

    test('notifyTripViewed passe par l\'instance de l\'app', () async {
      VideoModalMoments.useForTest(moments);
      addTearDown(VideoModalMoments.resetForTest);
      VideoModalMoments.notifyTripViewed(tripId: 't9');
      VideoModalMoments.notifyTripViewed(tripId: 't9');
      await pumpEventQueue(times: 50);
      expect(received.single.moment.viewCount, 2);
    });

    test('stockage illisible : 0, aucune erreur', () async {
      final broken = await build(datasource: _BrokenLocal());
      expect(await broken.recordTripView('t1'), 0);
      await broken.resetTripViews('t1');
    });
  });

  group('stockage local', () {
    test('compteurs illisibles ou malformés : ignorés', () async {
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.tripViewsKey: '{"a": 2, "b": "x", "c": 0}',
      });
      expect(await VideoModalLocalDatasource().readTripViews(), {'a': 2});
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.tripViewsKey: '[1,2]',
      });
      expect(await VideoModalLocalDatasource().readTripViews(), isEmpty);
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.tripViewsKey: '{pas du json',
      });
      expect(await VideoModalLocalDatasource().readTripViews(), isEmpty);
    });

    test('écrire une liste vide supprime la clé', () async {
      final d = VideoModalLocalDatasource();
      await d.writeTripViews({'a': 1});
      await d.writeTripViews({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(VideoModalLocalDatasource.tripViewsKey),
        isFalse,
      );
    });

    test('la synchro de la connexion n\'efface pas les moments', () async {
      final d = VideoModalLocalDatasource();
      await d.writeLastAppVersion('1.0.4');
      await d.writeTripViews({'a': 1});
      await d.clear();
      expect(await d.readLastAppVersion(), '1.0.4');
      expect(await d.readTripViews(), {'a': 1});
    });
  });
}
