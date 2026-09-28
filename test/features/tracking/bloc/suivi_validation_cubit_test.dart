import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockQueue extends Mock implements OfflineSyncService {}

class _MockRepo extends Mock implements TrackingRepository {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _event = TrackingEventModel(
  id: 'e1',
  bidId: 'bid-1',
  eventType: 'TRANSIT',
  scannedAt: DateTime(2026, 9, 28),
  createdAt: DateTime(2026, 9, 28),
);

const _here = ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar');

void main() {
  setUpAll(() => registerFallbackValue(ScanMethod.qr));

  late _MockLocator locator;
  late _MockAnalytics analytics;

  setUp(() {
    locator = _MockLocator();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => locator.capture()).thenAnswer((_) async => _here);
  });

  group('avec une file simulée', () {
    late _MockQueue queue;

    void stubQueueScan(Future<int> Function(Invocation) answer) => when(
      () => queue.queueScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        photoPath: any(named: 'photoPath'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        scanMethod: any(named: 'scanMethod'),
        notBefore: any(named: 'notBefore'),
      ),
    ).thenAnswer(answer);

    void stubSend(Future<TrackingEventModel?> Function(Invocation) answer) =>
        when(
          () => queue.sendScheduled(any(), position: any(named: 'position')),
        ).thenAnswer(answer);

    setUp(() {
      queue = _MockQueue();
      stubQueueScan((_) async => 7);
      stubSend((_) async => _event);
      when(() => queue.discard(any())).thenAnswer((_) async {});
    });

    SuiviValidationCubit build({Duration delay = const Duration(seconds: 5)}) =>
        SuiviValidationCubit(
          queue,
          locator,
          analytics,
          delay: delay,
          now: () => DateTime(2026, 9, 28, 12),
        );

    int? scheduleTransit(SuiviValidationCubit c, {String bidId = 'bid-1'}) =>
        c.schedule(
          bidId: bidId,
          step: 'TRANSIT',
          parcelLabel: 'Madou',
          method: ScanMethod.qr,
        );

    void verifyNeverSent() => verifyNever(
      () => queue.sendScheduled(any(), position: any(named: 'position')),
    );

    /// Position passée à l'envoi de l'entrée [key].
    Future<ScanPosition?> sentPosition(int key) =>
        verify(
              () => queue.sendScheduled(
                key,
                position: captureAny(named: 'position'),
              ),
            ).captured.single
            as Future<ScanPosition?>;

    test('écrite dans la file dès « Valider », envoyée à la fin du délai', () {
      fakeAsync((async) {
        final c = build();
        final id = scheduleTransit(c);
        expect(id, isNotNull);
        expect(
          c.state.pending.single.deadline,
          DateTime(2026, 9, 28, 12, 0, 5),
        );
        expect(c.state.pendingBidIds, {'bid-1'});
        // Échéance de rejeu : délai d'annulation plus la marge du cubit.
        verify(
          () => queue.queueScan(
            bidId: 'bid-1',
            eventType: 'TRANSIT',
            scanMethod: ScanMethod.qr,
            notBefore: DateTime(2026, 9, 28, 12, 0, 7),
          ),
        ).called(1);

        async.elapse(const Duration(seconds: 4));
        verifyNeverSent();

        async.elapse(const Duration(seconds: 2));
        ScanPosition? sent;
        unawaited(sentPosition(7).then((p) => sent = p));
        async.flushMicrotasks();
        expect(sent, same(_here));
        expect(c.state.pending, isEmpty);
        expect(c.state.outcome, isA<SuiviValidationSent>());
        expect(c.state.outcomeId, 1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.suiviStepValidated,
            properties: {'step': 'TRANSIT', 'method': 'qr'},
          ),
        ).called(1);
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('Annuler : retirée de la file, rien n\'est envoyé', () {
      fakeAsync((async) {
        final c = build();
        final id = scheduleTransit(c)!;
        c.undo(id);
        async.flushMicrotasks();
        expect(c.state.pending, isEmpty);
        verify(() => queue.discard(7)).called(1);
        async.elapse(const Duration(seconds: 10));
        verifyNeverSent();
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.suiviStepUndone,
            properties: {'step': 'TRANSIT'},
          ),
        ).called(1);
        // Deuxième « Annuler » : sans effet.
        c.undo(id);
        async.flushMicrotasks();
        verifyNever(() => queue.discard(any()));
        verifyNever(
          () => analytics.logEvent(
            AnalyticsEvents.suiviStepValidated,
            properties: any(named: 'properties'),
          ),
        );
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('un colis déjà en attente n\'est pas reprogrammé', () {
      final c = build();
      expect(scheduleTransit(c), isNotNull);
      expect(scheduleTransit(c), isNull);
      expect(c.state.pending, hasLength(1));
      unawaited(c.close());
    });

    test('plusieurs colis : chacun son délai, chacun son entrée', () {
      fakeAsync((async) {
        stubQueueScan((inv) async => inv.namedArguments[#bidId] == 'a' ? 1 : 2);
        final c = build();
        scheduleTransit(c, bidId: 'a');
        async.elapse(const Duration(seconds: 3));
        scheduleTransit(c, bidId: 'b');
        expect(c.state.pending.map((p) => p.bidId), ['a', 'b']);

        async.elapse(const Duration(seconds: 2));
        verify(
          () => queue.sendScheduled(1, position: any(named: 'position')),
        ).called(1);
        expect(c.state.pending.map((p) => p.bidId), ['b']);

        async.elapse(const Duration(seconds: 3));
        verify(
          () => queue.sendScheduled(2, position: any(named: 'position')),
        ).called(1);
        expect(c.state.outcomeId, 2);
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('flush : envoie tout de suite (onglet ou app quitté)', () async {
      final c = build();
      c.schedule(
        bidId: 'bid-1',
        step: 'DEPART',
        parcelLabel: 'Madou',
        method: ScanMethod.manual,
        photoPath: '/tmp/photo.jpg',
        position: _here,
      );
      await c.flush();
      // Photo et position de la photo écrites dans l'entrée dès le départ.
      verify(
        () => queue.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: '/tmp/photo.jpg',
          gpsLat: 14.7,
          gpsLon: -17.4,
          gpsLabel: 'Dakar',
          scanMethod: ScanMethod.manual,
          notBefore: any(named: 'notBefore'),
        ),
      ).called(1);
      expect(await sentPosition(7), same(_here));
      // Position fournie par la photo : pas de nouveau relevé.
      verifyNever(() => locator.capture());
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviStepValidated,
          properties: {'step': 'DEPART', 'method': 'manual'},
        ),
      ).called(1);
      await c.close();
    });

    test('fermé pendant le délai : la validation part quand même', () async {
      final c = build();
      scheduleTransit(c);
      await c.close();
      await Future<void>.delayed(Duration.zero);
      verify(
        () => queue.sendScheduled(7, position: any(named: 'position')),
      ).called(1);
    });

    blocTest<SuiviValidationCubit, SuiviValidationState>(
      'restée en file (réseau) : issue « en attente »',
      setUp: () => stubSend((_) async => null),
      build: () => build(delay: const Duration(milliseconds: 10)),
      act: (c) => scheduleTransit(c),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<SuiviValidationState>().having(
          (s) => s.pending,
          'pending',
          hasLength(1),
        ),
        isA<SuiviValidationState>().having(
          (s) => s.pending,
          'pending',
          isEmpty,
        ),
        isA<SuiviValidationState>()
            .having((s) => s.outcome, 'outcome', isA<SuiviValidationQueued>())
            .having((s) => s.outcome!.parcelLabel, 'parcel', 'Madou'),
      ],
    );

    blocTest<SuiviValidationCubit, SuiviValidationState>(
      'refus du back : issue en échec, rien de tracé comme validé',
      setUp: () => when(
        () => queue.sendScheduled(any(), position: any(named: 'position')),
      ).thenThrow(const ConflictException('déjà scanné')),
      build: () => build(delay: const Duration(milliseconds: 10)),
      act: (c) => scheduleTransit(c),
      wait: const Duration(milliseconds: 50),
      skip: 2,
      expect: () => [
        isA<SuiviValidationState>().having(
          (s) => (s.outcome! as SuiviValidationFailed).error,
          'error',
          isA<ConflictException>(),
        ),
      ],
      verify: (_) => verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.suiviStepValidated,
          properties: any(named: 'properties'),
        ),
      ),
    );

    test('écriture dans la file impossible : issue en échec à l\'envoi', () {
      fakeAsync((async) {
        stubQueueScan((_) async => throw const StorageException('disque'));
        final c = build();
        final id = scheduleTransit(c)!;
        // Erreur d'écriture gardée pour l'envoi, jamais « non interceptée ».
        async.elapse(const Duration(seconds: 5));
        expect(
          (c.state.outcome! as SuiviValidationFailed).error,
          isA<StorageException>(),
        );
        verifyNeverSent();
        // « Annuler » après coup : sans effet.
        c.undo(id);
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('Annuler alors que l\'écriture a échoué : rien ne remonte', () {
      fakeAsync((async) {
        stubQueueScan((_) async => throw const StorageException('disque'));
        final c = build();
        c.undo(scheduleTransit(c)!);
        async.elapse(const Duration(seconds: 10));
        verifyNever(() => queue.discard(any()));
        verifyNeverSent();
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('position trop lente : l\'étape part sans elle', () {
      fakeAsync((async) {
        when(
          () => locator.capture(),
        ).thenAnswer((_) => Completer<ScanPosition?>().future);
        final c = build();
        scheduleTransit(c);
        async.elapse(const Duration(seconds: 5));
        var resolved = false;
        ScanPosition? sent = _here;
        unawaited(
          sentPosition(7).then((p) {
            resolved = true;
            sent = p;
          }),
        );
        async.elapse(SuiviValidationCubit.positionTimeout);
        expect(resolved, isTrue);
        expect(sent, isNull);
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });
  });

  group('avec la vraie file Hive', () {
    late Directory dir;
    late HiveService hive;
    late _MockRepo repo;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('suivi_validation_');
      Hive.init(dir.path);
      await Hive.openBox<Map>(HiveService.offlineQueueBox);
      hive = HiveService();
    });

    tearDownAll(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    /// Appels à `postScan`, réussis ou non.
    var posts = 0;

    void stubPost(Future<TrackingEventModel> Function(Invocation) answer) =>
        when(
          () => repo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).thenAnswer((inv) {
          posts++;
          return answer(inv);
        });

    setUp(() async {
      repo = _MockRepo();
      posts = 0;
      stubPost((_) async => _event);
      when(
        () => repo.uploadTrackingPhoto(any(), any()),
      ).thenAnswer((_) async => 'tracking/bid-1/photo.jpg');
      await hive.offlineQueue.clear();
    });

    /// Attend (en temps réel) que [done] soit vrai.
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 400 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(done(), isTrue);
    }

    Map<String, dynamic> onlyEntry() =>
        Map<String, dynamic>.from(hive.offlineQueue.values.single);

    SuiviValidationCubit build(
      OfflineSyncService queue, {
      Duration delay = const Duration(milliseconds: 30),
    }) => SuiviValidationCubit(queue, locator, analytics, delay: delay);

    int? scheduleDepart(SuiviValidationCubit c) => c.schedule(
      bidId: 'bid-1',
      step: 'DEPART',
      parcelLabel: 'Madou',
      method: ScanMethod.manual,
      photoPath: '/tmp/colis.jpg',
    );

    test('écrite dès « Valider » avec échéance, photo et provenance', () async {
      final queue = OfflineSyncService(hive, repo);
      final c = build(queue, delay: const Duration(minutes: 1));
      final before = DateTime.now();
      final id = scheduleDepart(c)!;
      await until(() => hive.offlineQueue.length == 1);
      final entry = onlyEntry();
      expect(entry['bidId'], 'bid-1');
      expect(entry['eventType'], 'DEPART');
      expect(entry['photoPath'], '/tmp/colis.jpg');
      expect(entry['scanMethod'], 'MANUAL');
      final notBefore = DateTime.parse(entry['notBefore'] as String);
      expect(
        notBefore.isAfter(
              before.add(
                const Duration(minutes: 1) + SuiviValidationCubit.replayGrace,
              ),
            ) ||
            notBefore.isAtSameMomentAs(
              before.add(
                const Duration(minutes: 1) + SuiviValidationCubit.replayGrace,
              ),
            ),
        isTrue,
      );
      // Encore annulable : pas compté parmi les scans en attente de réseau.
      expect(queue.pendingCount, 0);

      c.undo(id);
      await until(() => hive.offlineQueue.isEmpty);
      await c.close();
      expect(posts, 0);
    });

    test('à l\'échéance : envoyée une fois, retirée de la file', () async {
      final queue = OfflineSyncService(hive, repo);
      final c = build(queue);
      scheduleDepart(c);
      await until(() => c.state.outcome != null);
      expect(c.state.outcome, isA<SuiviValidationSent>());
      expect(hive.offlineQueue.isEmpty, isTrue);
      verify(
        () => repo.postScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          gpsLat: 14.7,
          gpsLon: -17.4,
          gpsLabel: 'Dakar',
          photoUrl: 'tracking/bid-1/photo.jpg',
          scanMethod: ScanMethod.manual,
        ),
      ).called(1);
      await c.close();
    });

    test(
      'réseau coupé : reste en file avec sa position, syncAll la renvoie',
      () async {
        final queue = OfflineSyncService(hive, repo);
        stubPost(
          (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            type: DioExceptionType.connectionError,
          ),
        );
        final c = build(queue);
        scheduleDepart(c);
        await until(() => c.state.outcome != null);
        expect(c.state.outcome, isA<SuiviValidationQueued>());
        final entry = onlyEntry();
        // Échéance levée : c'est désormais un scan hors ligne ordinaire.
        expect(entry.containsKey('notBefore'), isFalse);
        expect(entry['gpsLat'], 14.7);
        expect(entry['photoPath'], '/tmp/colis.jpg');
        expect(queue.pendingCount, 1);

        stubPost((_) async => _event);
        await queue.syncAll();
        expect(hive.offlineQueue.isEmpty, isTrue);
        verify(
          () => repo.postScan(
            bidId: 'bid-1',
            eventType: 'DEPART',
            gpsLat: 14.7,
            gpsLon: -17.4,
            gpsLabel: 'Dakar',
            photoUrl: 'tracking/bid-1/photo.jpg',
            scanMethod: ScanMethod.manual,
            offlineTimestamp: any(named: 'offlineTimestamp', that: isNotNull),
          ),
        ).called(1);
        await c.close();
      },
    );

    test('refus définitif du back : retirée de la file', () async {
      final queue = OfflineSyncService(hive, repo);
      stubPost(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: '/tracking/events'),
          error: const ConflictException('déjà scanné'),
        ),
      );
      final c = build(queue);
      scheduleDepart(c);
      await until(() => c.state.outcome != null);
      expect(
        (c.state.outcome! as SuiviValidationFailed).error,
        isA<ConflictException>(),
      );
      expect(hive.offlineQueue.isEmpty, isTrue);
      await c.close();
    });

    test('arrêt brutal pendant le délai : rejouée au redémarrage', () async {
      final first = OfflineSyncService(hive, repo);
      final c = build(first, delay: const Duration(minutes: 1));
      scheduleDepart(c);
      await until(() => hive.offlineQueue.length == 1);

      // Le process meurt : seule la box sur disque survit.
      await Hive.close();
      await Hive.openBox<Map>(HiveService.offlineQueueBox);
      expect(hive.offlineQueue.length, 1);

      // Redémarré avant l'échéance : pas encore envoyée.
      final early = OfflineSyncService(hive, repo);
      await early.syncAll();
      expect(posts, 0);
      early.dispose();

      // Redémarré après l'échéance : rejouée une fois, avec sa photo.
      final restarted = OfflineSyncService(
        hive,
        repo,
        null,
        () => DateTime.now().add(const Duration(minutes: 5)),
      );
      await restarted.syncAll();
      expect(hive.offlineQueue.isEmpty, isTrue);
      verify(
        () => repo.postScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoUrl: 'tracking/bid-1/photo.jpg',
          scanMethod: ScanMethod.manual,
          offlineTimestamp: any(named: 'offlineTimestamp', that: isNotNull),
        ),
      ).called(1);

      // Le cubit de l'ancien process (ici encore vivant) ne la renvoie pas.
      await c.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(posts, 1);
    });

    test(
      'course : syncAll pendant l\'envoi du cubit ne la renvoie pas',
      () async {
        // Toute entrée est échue pour cette file : seul le verrou protège.
        final queue = OfflineSyncService(
          hive,
          repo,
          null,
          () => DateTime.now().add(const Duration(minutes: 5)),
        );
        final answer = Completer<TrackingEventModel>();
        stubPost((_) => answer.future);
        final c = build(queue);
        scheduleDepart(c);
        await until(() => posts == 1);

        await queue.syncAll();
        answer.complete(_event);
        await until(() => c.state.outcome != null);
        expect(c.state.outcome, isA<SuiviValidationSent>());
        expect(posts, 1);
        expect(hive.offlineQueue.isEmpty, isTrue);
        await c.close();
      },
    );

    test(
      'course : envoi du cubit pendant un syncAll, pas de double envoi',
      () async {
        final queue = OfflineSyncService(
          hive,
          repo,
          null,
          () => DateTime.now().add(const Duration(minutes: 5)),
        );
        final answer = Completer<TrackingEventModel>();
        stubPost((_) => answer.future);
        final c = build(queue, delay: const Duration(minutes: 1));
        scheduleDepart(c);
        await until(() => hive.offlineQueue.length == 1);

        final sync = queue.syncAll();
        await until(() => posts == 1);
        // L'onglet est quitté pendant que syncAll l'envoie.
        await c.flush();
        expect(c.state.outcome, isA<SuiviValidationQueued>());

        answer.complete(_event);
        await sync;
        expect(posts, 1);
        expect(hive.offlineQueue.isEmpty, isTrue);
        await c.close();
      },
    );
  });
}
