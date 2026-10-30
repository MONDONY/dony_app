import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/report_severity.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/scan_send_guard.dart';
import 'package:dony/features/tracking/data/tracking_photo_upload.dart';
import 'package:dony/features/tracking/data/tracking_queue_photo_store.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockReporter extends Mock implements ErrorReportingService {}

class _MockAnalytics extends Mock implements AnalyticsService {}

late Directory _tempDir;
late HiveService _hiveService;

Future<void> _setUp() async {
  _tempDir = await Directory.systemTemp.createTemp('offline_sync_test_');
  Hive.init(_tempDir.path);
  await Hive.openBox<Map>(HiveService.offlineQueueBox);
  await Hive.openBox(HiveService.userPrefsBox);
  _hiveService = HiveService();
}

Future<void> _tearDown() async {
  await Hive.close();
  await _tempDir.delete(recursive: true);
}

void main() {
  setUpAll(() async => _setUp());
  tearDownAll(() async => _tearDown());

  late MockTrackingRepository mockRepo;
  late OfflineSyncService service;

  setUp(() async {
    mockRepo = MockTrackingRepository();
    service = OfflineSyncService(_hiveService, mockRepo);
    addTearDown(service.dispose);
    await _hiveService.offlineQueue.clear();
  });

  group('pendingCount', () {
    test('returns 0 on empty queue', () {
      expect(service.pendingCount, 0);
    });

    test('returns count after queueScan', () async {
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      expect(service.pendingCount, 1);
    });
  });

  group('pendingCountFor / queueChanges', () {
    test('ne compte que les scans des colis demandés', () async {
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      await service.queueScan(bidId: 'bid-2', eventType: 'DEPART');
      expect(service.pendingCountFor({'bid-1'}), 2);
      expect(service.pendingCountFor({'bid-1', 'bid-2'}), 3);
      expect(service.pendingCountFor(const {}), 0);
    });

    test('notifie chaque ajout à la file', () async {
      var calls = 0;
      void listener() => calls++;
      service.queueChanges.addListener(listener);
      addTearDown(() => service.queueChanges.removeListener(listener));
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      await Future<void>.delayed(Duration.zero);
      expect(calls, greaterThan(0));
    });
  });

  group('queueScan', () {
    test('adds entry to queue with required fields', () async {
      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.values.first,
      );
      expect(entry['bidId'], 'bid-1');
      expect(entry['eventType'], 'TRANSIT');
      expect(entry['offlineTimestamp'], isNotNull);
    });

    test('adds optional gps and photoPath when provided', () async {
      await service.queueScan(
        bidId: 'bid-2',
        eventType: 'ARRIVEE',
        gpsLat: 48.8566,
        gpsLon: 2.3522,
        gpsLabel: 'Paris',
        photoPath: '/tmp/photo.jpg',
      );
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.values.first,
      );
      expect(entry['gpsLat'], 48.8566);
      expect(entry['gpsLon'], 2.3522);
      expect(entry['gpsLabel'], 'Paris');
      expect(entry['photoPath'], '/tmp/photo.jpg');
    });

    test('does not include null fields', () async {
      await service.queueScan(bidId: 'bid-3', eventType: 'DEPART');
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.values.first,
      );
      expect(entry.containsKey('gpsLat'), isFalse);
      expect(entry.containsKey('photoPath'), isFalse);
      expect(entry.containsKey('scanMethod'), isFalse);
      // Scan hors ligne ordinaire : aucune échéance.
      expect(entry.containsKey('notBefore'), isFalse);
    });

    test('garde la provenance du scan', () async {
      await service.queueScan(
        bidId: 'bid-4',
        eventType: 'TRANSIT',
        scanMethod: ScanMethod.manual,
      );
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.values.first,
      );
      expect(entry['scanMethod'], 'MANUAL');
    });

    test(
      'garde le numéro de suivi saisi à la remise, le rejoue à l\'envoi',
      () async {
        await service.queueScan(
          bidId: 'bid-5',
          eventType: 'DEPART',
          trackingNumber: 'DON-AB23CD45',
        );
        final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.values.first,
        );
        expect(entry['trackingNumber'], 'DON-AB23CD45');

        when(
          () => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            trackingNumber: 'DON-AB23CD45',
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).thenAnswer((_) async => _fakeEvent());

        await service.syncAll();

        verify(
          () => mockRepo.postScan(
            bidId: 'bid-5',
            eventType: 'DEPART',
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            trackingNumber: 'DON-AB23CD45',
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).called(1);
      },
    );

    test('sans numéro de suivi, la clé n\'existe pas dans l\'entrée', () async {
      await service.queueScan(bidId: 'bid-6', eventType: 'TRANSIT');
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.values.first,
      );
      expect(entry.containsKey('trackingNumber'), isFalse);
    });
  });

  group('syncAll', () {
    test('does nothing on empty queue', () async {
      await service.syncAll();
      verifyNever(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
        ),
      );
    });

    test('sends queued entries and removes them on success', () async {
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenAnswer((_) async => _fakeEvent());
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenAnswer((_) async => 'photo-key');

      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      expect(service.pendingCount, 1);

      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'TRANSIT',
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(1);
    });

    test('keeps entry in queue when postScan fails', () async {
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenThrow(Exception('network error'));

      await service.queueScan(bidId: 'bid-2', eventType: 'DEPART');
      await service.syncAll();

      expect(service.pendingCount, 1);
    });

    // FLUTTER-KZ / FLUTTER-KK : une étape refusée par le réseau ou un 5xx
    // n'était rejouée qu'au prochain changement de réseau du téléphone.
    group('nouvel essai automatique', () {
      void postScanFails() => when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenThrow(Exception('network error'));

      test(
        'échec : nouvel essai programmé, délai doublé puis plafonné',
        () async {
          postScanFails();
          service
            ..retryBase = const Duration(minutes: 1)
            ..retryMax = const Duration(minutes: 3);
          await service.queueScan(bidId: 'bid-2', eventType: 'DEPART');

          await service.syncAll();
          expect(service.nextRetryDelay, const Duration(minutes: 1));
          await service.syncAll();
          expect(service.nextRetryDelay, const Duration(minutes: 2));
          await service.syncAll();
          expect(service.nextRetryDelay, const Duration(minutes: 3));
          await service.syncAll();
          expect(service.nextRetryDelay, const Duration(minutes: 3));
        },
      );

      test(
        'le nouvel essai part seul et vide la file au retour du back',
        () async {
          var calls = 0;
          when(
            () => mockRepo.postScan(
              bidId: any(named: 'bidId'),
              eventType: any(named: 'eventType'),
              gpsLat: any(named: 'gpsLat'),
              gpsLon: any(named: 'gpsLon'),
              gpsLabel: any(named: 'gpsLabel'),
              photoUrl: any(named: 'photoUrl'),
              offlineTimestamp: any(named: 'offlineTimestamp'),
            ),
          ).thenAnswer((_) async {
            if (calls++ == 0) throw Exception('502');
            return _fakeEvent();
          });
          service.retryBase = const Duration(milliseconds: 30);
          await service.queueScan(bidId: 'bid-2', eventType: 'DEPART');

          await service.syncAll();
          expect(service.pendingCount, 1);
          for (
            var i = 0;
            i < 100 && _hiveService.offlineQueue.isNotEmpty;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }

          expect(_hiveService.offlineQueue.isEmpty, isTrue);
          expect(service.nextRetryDelay, isNull);
        },
      );

      test('file vidée sans erreur : aucun essai programmé', () async {
        await service.syncAll();
        expect(service.nextRetryDelay, isNull);
      });
    });

    test('drops the entry when the server rejects it for good (409)', () async {
      // Un DEPART déjà enregistré côté serveur (409 depart-already-scanned)
      // ne doit pas être rejoué à chaque retour du réseau : chaque tentative
      // finissait en 500 côté back (Sentry YADONY-BACK-STAGING-8).
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/tracking/events'),
          error: const ConflictException(
            'Le départ de ce colis a déjà été scanné',
            code: 'depart-already-scanned',
          ),
        ),
      );

      await service.queueScan(bidId: 'bid-3', eventType: 'DEPART');
      await service.syncAll();

      expect(service.pendingCount, 0);
    });

    test(
      'keeps the entry on a server error (5xx) or expired session',
      () async {
        when(
          () => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            error: const ServerException('Erreur serveur'),
          ),
        );

        await service.queueScan(bidId: 'bid-4', eventType: 'DEPART');
        await service.syncAll();

        expect(service.pendingCount, 1);
      },
    );

    test('isDefinitiveRejection classe les erreurs', () {
      expect(
        OfflineSyncService.isDefinitiveRejection(
          const ConflictException('x', code: 'depart-already-scanned'),
        ),
        isTrue,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(
          const ValidationException('x', code: 'invalid-timestamp'),
        ),
        isTrue,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const NotFoundException()),
        isTrue,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const ForbiddenException()),
        isTrue,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const UnauthorizedException()),
        isFalse,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const ServerException()),
        isFalse,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const OfflineException()),
        isFalse,
      );
      expect(
        OfflineSyncService.isDefinitiveRejection(const TimeoutException()),
        isFalse,
      );
    });

    test('syncs multiple entries successfully, empties the queue', () async {
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenAnswer((_) async => _fakeEvent());
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenAnswer((_) async => 'photo-key');

      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      await service.queueScan(bidId: 'bid-2', eventType: 'ARRIVEE');
      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(2);
    });
  });

  group('syncAll et provenance', () {
    void stubPost(ScanMethod? method) {
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
          scanMethod: method,
        ),
      ).thenAnswer((_) async => _fakeEvent());
    }

    test('renvoie la provenance mise en file', () async {
      stubPost(ScanMethod.qr);
      await service.queueScan(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        scanMethod: ScanMethod.qr,
      );

      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'TRANSIT',
          offlineTimestamp: any(named: 'offlineTimestamp'),
          scanMethod: ScanMethod.qr,
        ),
      ).called(1);
    });

    test('entrée mise en file avant la provenance : rien envoyé', () async {
      stubPost(null);
      // Entrée écrite par une version précédente de l'app : pas de clé.
      await _hiveService.offlineQueue.add({
        'bidId': 'bid-legacy',
        'eventType': 'DEPART',
        'offlineTimestamp': DateTime.utc(2026, 9).toIso8601String(),
      });

      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-legacy',
          eventType: 'DEPART',
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(1);
    });
  });

  group('validation annulable (notBefore)', () {
    final t0 = DateTime.utc(2026, 9, 28, 12);
    late DateTime now;
    late OfflineSyncService timed;

    void stubPost(Future<TrackingEventModel> Function(Invocation) answer) =>
        when(
          () => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).thenAnswer(answer);

    void verifyNeverPosted() => verifyNever(
      () => mockRepo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
        scanMethod: any(named: 'scanMethod'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    );

    setUp(() {
      now = t0;
      timed = OfflineSyncService(_hiveService, mockRepo, null, () => now);
      stubPost((_) async => _fakeEvent());
    });

    tearDown(() => timed.dispose());

    Future<int> schedule() => timed.queueScan(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      scanMethod: ScanMethod.manual,
      notBefore: t0.add(const Duration(seconds: 7)),
    );

    test('échéance et provenance écrites dans l\'entrée', () async {
      final key = await schedule();
      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.get(key)!,
      );
      expect(entry['notBefore'], '2026-09-28T12:00:07.000Z');
      expect(entry['scanMethod'], 'MANUAL');
    });

    test('syncAll l\'ignore avant l\'échéance, l\'envoie après', () async {
      await schedule();
      await timed.syncAll();
      verifyNeverPosted();
      expect(timed.pendingCount, 0);
      expect(timed.pendingCountFor({'bid-1'}), 0);

      now = t0.add(const Duration(seconds: 8));
      expect(timed.pendingCount, 1);
      await timed.syncAll();
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'TRANSIT',
          scanMethod: ScanMethod.manual,
          offlineTimestamp: any(named: 'offlineTimestamp', that: isNotNull),
        ),
      ).called(1);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('syncAll repasse de lui-même à l\'échéance', () async {
      final real = OfflineSyncService(_hiveService, mockRepo);
      addTearDown(real.dispose);
      await real.queueScan(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        notBefore: DateTime.now().add(const Duration(milliseconds: 40)),
      );
      await real.syncAll();
      verifyNeverPosted();
      for (var i = 0; i < 100 && _hiveService.offlineQueue.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('discard retire l\'entrée', () async {
      final key = await schedule();
      await timed.discard(key);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('sendScheduled : envoi immédiat, position écrite, retirée', () async {
      final key = await schedule();
      final event = await timed.sendScheduled(
        key,
        position: Future.value(
          const ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar'),
        ),
      );
      expect(event, isNotNull);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      // Envoi en direct : pas daté comme un scan hors ligne.
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'TRANSIT',
          gpsLat: 14.7,
          gpsLon: -17.4,
          gpsLabel: 'Dakar',
          scanMethod: ScanMethod.manual,
        ),
      ).called(1);
    });

    test(
      'FLUTTER-JV : deux entrées du même DEPART (onglet + file), un seul POST',
      () async {
        final answer = Completer<TrackingEventModel>();
        stubPost((_) => answer.future);
        final direct = await timed.queueScan(
          bidId: 'bid-jv',
          eventType: 'DEPART',
          notBefore: t0.add(const Duration(seconds: 7)),
        );
        // Seconde entrée du même scan, due tout de suite (file hors ligne).
        await timed.queueScan(bidId: 'bid-jv', eventType: 'DEPART');
        final first = timed.sendScheduled(direct);
        await Future<void>.delayed(Duration.zero);
        final replay = timed.syncAll();
        await Future<void>.delayed(Duration.zero);
        answer.complete(_fakeEvent());
        expect(await first, isNotNull);
        await replay;
        verify(
          () => mockRepo.postScan(
            bidId: 'bid-jv',
            eventType: 'DEPART',
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).called(1);
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
      },
    );

    test(
      'sendScheduled : 409 scan-already-recorded = succès, étape relue',
      () async {
        final recorded = _fakeEvent();
        stubPost(
          (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            error: const ConflictException('x', code: 'scan-already-recorded'),
          ),
        );
        when(
          () => mockRepo.getEvents('bid-1'),
        ).thenAnswer((_) async => [recorded]);
        final key = await schedule();
        expect((await timed.sendScheduled(key))?.event, same(recorded));
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
      },
    );

    test('sendScheduled : entrée absente → null, rien envoyé', () async {
      expect(await timed.sendScheduled(42), isNull);
      verifyNeverPosted();
    });

    test('sendScheduled : deux appels concurrents, un seul envoi', () async {
      final answer = Completer<TrackingEventModel>();
      stubPost((_) => answer.future);
      final key = await schedule();
      final first = timed.sendScheduled(key);
      // Réservée : ni un second envoi ni syncAll ne la reprennent.
      expect(await timed.sendScheduled(key), isNull);
      now = t0.add(const Duration(minutes: 1));
      expect(timed.pendingCount, 0);
      await timed.syncAll();
      answer.complete(_fakeEvent());
      expect(await first, isNotNull);
      verify(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          scanMethod: any(named: 'scanMethod'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(1);
    });

    test(
      'sendScheduled : erreur inattendue signalée, gardée en file',
      () async {
        final reporter = _MockReporter();
        when(
          () => reporter.report(
            any(),
            operation: any(named: 'operation'),
            stackTrace: any(named: 'stackTrace'),
            context: any(named: 'context'),
          ),
        ).thenAnswer((_) async {});
        final reported = OfflineSyncService(
          _hiveService,
          mockRepo,
          reporter,
          () => now,
        );
        stubPost((_) async => throw StateError('bug'));
        final key = await schedule();
        expect(await reported.sendScheduled(key), isNull);
        final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.get(key)!,
        );
        expect(entry.containsKey('notBefore'), isFalse);
        expect(reported.pendingCount, 1);
        verify(
          () => reporter.report(
            any(that: isA<StateError>()),
            operation: 'tracking.offline_sync',
            stackTrace: any(named: 'stackTrace'),
            context: any(named: 'context'),
          ),
        ).called(1);
      },
    );

    test(
      'sendScheduled : refus définitif retiré de la file et remonté',
      () async {
        stubPost(
          (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            error: const ForbiddenException(),
          ),
        );
        final key = await schedule();
        await expectLater(
          timed.sendScheduled(key),
          throwsA(isA<DioException>()),
        );
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
      },
    );

    test('entrée vidée pendant l\'envoi (déconnexion) : pas recréée', () async {
      final answer = Completer<TrackingEventModel>();
      stubPost((_) => answer.future);
      final key = await schedule();
      final sending = timed.sendScheduled(key);
      await Future<void>.delayed(Duration.zero);
      await _hiveService.offlineQueue.clear();
      answer.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/tracking/events'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(await sending, isNull);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });
  });

  group('photo refusée par le serveur', () {
    late _MockReporter reporter;
    late OfflineSyncService reported;

    setUp(() {
      reporter = _MockReporter();
      when(
        () => reporter.report(
          any(),
          operation: any(named: 'operation'),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async {});
      reported = OfflineSyncService(_hiveService, mockRepo, reporter);
      when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          scanMethod: any(named: 'scanMethod'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).thenAnswer((_) async => _fakeEvent());
    });

    void stubUploadError(AppException error) =>
        when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/storage/upload/tracking'),
            error: error,
          ),
        );

    Future<void> queueWithPhoto() => reported.queueScan(
      bidId: 'bid-1',
      eventType: 'ARRIVEE',
      photoPath: '/tmp/arrivee.jpg',
    );

    void verifyPostedWithoutPhoto() => verify(
      () => mockRepo.postScan(
        bidId: 'bid-1',
        eventType: 'ARRIVEE',
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl', that: isNull),
        scanMethod: any(named: 'scanMethod'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    ).called(1);

    void verifyNeverReported() => verifyNever(
      () => reporter.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
        context: any(named: 'context'),
      ),
    );

    final refusals = <String, AppException>{
      '429 tracking-photo-limit-reached': const RateLimitException(
        'Limite de photos atteinte',
        'tracking-photo-limit-reached',
      ),
      '429 photo-upload-quota-exceeded': const RateLimitException(
        'Quota journalier atteint',
        'photo-upload-quota-exceeded',
      ),
      '413 file-too-large': const ValidationException(
        'Fichier trop lourd',
        code: 'file-too-large',
      ),
      '422 image/too-large': const ValidationException(
        'Image trop grande',
        code: 'image/too-large',
      ),
    };

    for (final MapEntry(key: label, value: error) in refusals.entries) {
      test('$label : étape postée sans photo, entrée retirée', () async {
        stubUploadError(error);
        await queueWithPhoto();

        await reported.syncAll();

        verifyPostedWithoutPhoto();
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        verifyNeverReported();
      });
    }

    test('sendScheduled : résultat photoDropped, entrée retirée', () async {
      stubUploadError(refusals['429 tracking-photo-limit-reached']!);
      final key = await reported.queueScan(
        bidId: 'bid-1',
        eventType: 'ARRIVEE',
        photoPath: '/tmp/arrivee.jpg',
        notBefore: DateTime.now().add(const Duration(minutes: 1)),
      );

      final sent = await reported.sendScheduled(key);

      expect(sent, isNotNull);
      expect(sent!.photoDropped, isTrue);
      expect(sent.event.id, 'ev-1');
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      verifyNeverReported();
    });

    test('photo envoyée : photoDropped faux, clé transmise', () async {
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenAnswer((_) async => 'tracking/bid-1/1_ARRIVEE.jpg');
      final key = await reported.queueScan(
        bidId: 'bid-1',
        eventType: 'ARRIVEE',
        photoPath: '/tmp/arrivee.jpg',
        notBefore: DateTime.now().add(const Duration(minutes: 1)),
      );

      final sent = await reported.sendScheduled(key);

      expect(sent!.photoDropped, isFalse);
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'ARRIVEE',
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: 'tracking/bid-1/1_ARRIVEE.jpg',
          scanMethod: any(named: 'scanMethod'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(1);
    });

    test('upload en erreur réseau : entrée gardée, étape pas postée', () async {
      when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/storage/upload/tracking'),
          type: DioExceptionType.connectionError,
        ),
      );
      await queueWithPhoto();

      await reported.syncAll();

      expect(reported.pendingCount, 1);
      verifyNever(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          scanMethod: any(named: 'scanMethod'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      );
    });

    test('autre 429 (limite de débit) : entrée gardée', () async {
      stubUploadError(const RateLimitException());
      await queueWithPhoto();

      await reported.syncAll();

      expect(reported.pendingCount, 1);
    });

    test('autre refus définitif de l\'upload : étape postée sans photo, '
        'jamais le scan entier jeté', () async {
      // Le scan d'arrivée déclenche la capture du paiement : un refus de la
      // seule photo ne doit jamais le faire disparaître de la file.
      stubUploadError(
        const ValidationException('Type refusé', code: 'invalid-file-type'),
      );
      await queueWithPhoto();

      await reported.syncAll();

      verifyPostedWithoutPhoto();
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test(
      'photo abandonnée puis postScan en 409 : rejet définitif, entrée retirée',
      () async {
        stubUploadError(refusals['429 tracking-photo-limit-reached']!);
        when(
          () => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            gpsLabel: any(named: 'gpsLabel'),
            photoUrl: any(named: 'photoUrl'),
            scanMethod: any(named: 'scanMethod'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            error: const ConflictException(
              'Étape hors séquence',
              code: 'invalid-step-order',
            ),
          ),
        );
        final key = await reported.queueScan(
          bidId: 'bid-1',
          eventType: 'ARRIVEE',
          photoPath: '/tmp/arrivee.jpg',
          notBefore: DateTime.now().add(const Duration(minutes: 1)),
        );

        await expectLater(
          reported.sendScheduled(key),
          throwsA(isA<DioException>()),
        );
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        verifyPostedWithoutPhoto();
      },
    );
  });

  group('photo disparue du téléphone (FLUTTER-MJ)', () {
    late _MockReporter reporter;
    late OfflineSyncService reported;
    late Directory supportDir;
    late Directory tmpDir;
    late TrackingQueuePhotoStore store;

    void stubPost({Object? error}) {
      final when_ = when(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          scanMethod: any(named: 'scanMethod'),
          trackingNumber: any(named: 'trackingNumber'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      );
      if (error != null) {
        when_.thenThrow(error);
      } else {
        when_.thenAnswer((_) async => _fakeEvent());
      }
    }

    void verifyPosted({required Matcher photoUrl, int times = 1}) => verify(
      () => mockRepo.postScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl', that: photoUrl),
        scanMethod: any(named: 'scanMethod'),
        trackingNumber: any(named: 'trackingNumber'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    ).called(times);

    List<Map<String, Object>> reports() => verify(
      () => reporter.report(
        any(),
        operation: any(named: 'operation'),
        stackTrace: any(named: 'stackTrace'),
        context: captureAny(named: 'context'),
      ),
    ).captured.cast<Map<String, Object>>();

    Future<File> photo(String name) async {
      final file = File('${_tempDir.path}/$name');
      await file.writeAsBytes([1, 2, 3]);
      return file;
    }

    setUp(() async {
      await _hiveService.userPrefs.delete(OfflineSyncService.lostPhotosKey);
      reporter = _MockReporter();
      when(
        () => reporter.report(
          any(),
          operation: any(named: 'operation'),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async {});
      supportDir = await _tempDir.createTemp('support_');
      tmpDir = await _tempDir.createTemp('tmp_');
      store = TrackingQueuePhotoStore(
        baseDirectory: () async => supportDir,
        temporaryDirectory: () async => tmpDir,
      );
      reported = OfflineSyncService(
        _hiveService,
        mockRepo,
        reporter,
        DateTime.now,
        ScanSendGuard(),
        store,
      );
    });

    test('fichier absent : étape postée sans photo, entrée retirée, '
        'un seul avertissement, utilisateur prévenu', () async {
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenThrow(const PathNotFoundException('/tmp/gone.jpg', OSError()));
      stubPost();
      // Ancienne entrée : chemin absolu dans le cache, purgé depuis.
      await OfflineSyncService(_hiveService, mockRepo).queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        photoPath: '/tmp/gone.jpg',
      );

      await reported.syncAll();

      verifyPosted(photoUrl: isNull);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      final captured = verify(
        () => reporter.report(
          captureAny(),
          operation: captureAny(named: 'operation'),
          stackTrace: any(named: 'stackTrace'),
          context: captureAny(named: 'context'),
        ),
      ).captured;
      expect(captured, hasLength(3));
      expect(captured[0], isA<TrackingPhotoLostError>());
      expect(
        (captured[0] as TrackingPhotoLostError).reportSeverity,
        ReportSeverity.warning,
      );
      expect(captured[1], 'tracking.photo_lost');
      expect((captured[2] as Map)['tracking_step'], 'DEPART');
      expect(reported.lostPhotosFor({'bid-1'}), [
        const LostTrackingPhoto(bidId: 'bid-1', eventType: 'DEPART'),
      ]);
      expect(reported.lostPhotosFor({'bid-2'}), isEmpty);
    });

    test('photo perdue puis panne réseau : la photo n\'est plus cherchée, '
        'rien n\'est remonté au nouvel essai', () async {
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenThrow(const PathNotFoundException('/tmp/gone.jpg', OSError()));
      stubPost(
        error: DioException(
          requestOptions: RequestOptions(path: '/tracking/events'),
          type: DioExceptionType.connectionError,
        ),
      );
      await OfflineSyncService(_hiveService, mockRepo).queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        photoPath: '/tmp/gone.jpg',
      );

      await reported.syncAll();
      expect(reported.pendingCount, 1);
      final entry = _hiveService.offlineQueue.values.single;
      expect(entry.containsKey('photoPath'), isFalse);
      expect(reports(), hasLength(1));

      stubPost();
      await reported.syncAll();

      verify(() => mockRepo.uploadTrackingPhoto(any(), any())).called(1);
      verifyPosted(photoUrl: isNull, times: 2);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      verifyNever(
        () => reporter.report(
          any(),
          operation: any(named: 'operation'),
          stackTrace: any(named: 'stackTrace'),
          context: any(named: 'context'),
        ),
      );
      expect(reported.lostPhotosFor({'bid-1'}), hasLength(1));
    });

    test(
      'fichier disparu pendant l\'envoi (Dio) : étape postée sans photo',
      () async {
        when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenAnswer((
          invocation,
        ) async {
          await File(invocation.positionalArguments[1] as String).delete();
          throw DioException(
            requestOptions: RequestOptions(path: '/storage/upload/tracking'),
            error: const FileSystemException('gone'),
          );
        });
        stubPost();
        final key = await reported.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: (await photo('depart.jpg')).path,
          notBefore: DateTime.now().add(const Duration(minutes: 1)),
        );

        final sent = await reported.sendScheduled(key);

        expect(sent, isNotNull);
        expect(sent!.photoDropped, isFalse);
        verifyPosted(photoUrl: isNull);
        expect(reported.lostPhotosFor({'bid-1'}), hasLength(1));
      },
    );

    test('la photo est copiée hors du cache, envoyée depuis la copie, '
        'puis supprimée', () async {
      final original = await photo('transit.jpg');
      String? uploadedPath;
      bool? existedAtUpload;
      when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenAnswer((
        invocation,
      ) async {
        uploadedPath = invocation.positionalArguments[1] as String;
        existedAtUpload = File(uploadedPath!).existsSync();
        return 'tracking/bid-1/1_DEPART.jpg';
      });
      stubPost();

      await reported.queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        photoPath: original.path,
      );
      final entry = _hiveService.offlineQueue.values.single;
      expect(entry.containsKey('photoPath'), isFalse);
      expect(entry['photoFile'], endsWith('_transit.jpg'));
      // Le cache purgé ne fait plus rien perdre.
      await original.delete();

      await reported.syncAll();

      expect(existedAtUpload, isTrue);
      expect(
        uploadedPath,
        startsWith('${supportDir.path}/${TrackingQueuePhotoStore.folder}/'),
      );
      verifyPosted(photoUrl: equals('tracking/bid-1/1_DEPART.jpg'));
      expect(File(uploadedPath!).existsSync(), isFalse);
      expect(reported.lostPhotosFor({'bid-1'}), isEmpty);
    });

    test('discard supprime aussi la copie de la photo', () async {
      final key = await reported.queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        photoPath: (await photo('annule.jpg')).path,
      );
      final name = _hiveService.offlineQueue.get(key)!['photoFile'] as String;
      final copy = File(await store.resolve(name));
      expect(copy.existsSync(), isTrue);

      await reported.discard(key);

      expect(copy.existsSync(), isFalse);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test(
      'refus définitif de l\'étape : copie supprimée avec l\'entrée',
      () async {
        when(
          () => mockRepo.uploadTrackingPhoto(any(), any()),
        ).thenAnswer((_) async => 'tracking/bid-1/1_DEPART.jpg');
        stubPost(
          error: DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            error: const ConflictException('Hors séquence', code: 'x'),
          ),
        );
        final key = await reported.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: (await photo('refus.jpg')).path,
        );
        final name = _hiveService.offlineQueue.get(key)!['photoFile'] as String;

        await reported.syncAll();

        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        expect(File(await store.resolve(name)).existsSync(), isFalse);
      },
    );

    group('entrées héritées et copies ratées (FLUTTER-F)', () {
      void stubUploadCapturing(List<String> paths) {
        when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenAnswer((
          invocation,
        ) async {
          final path = invocation.positionalArguments[1] as String;
          if (!File(path).existsSync()) {
            throw PathNotFoundException(path, const OSError());
          }
          paths.add(path);
          return 'tracking/bid-1/1_DEPART.jpg';
        });
      }

      Future<void> queueLegacy(String photoPath) =>
          _hiveService.offlineQueue.add({
            'bidId': 'bid-1',
            'eventType': 'DEPART',
            'photoPath': photoPath,
            'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
          });

      test('chemin hérité encore présent : migré en photoFile, envoyé '
          'avec sa photo', () async {
        final uploaded = <String>[];
        stubUploadCapturing(uploaded);
        stubPost(
          error: DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            type: DioExceptionType.connectionError,
          ),
        );
        final original = await photo('herite.jpg');
        await queueLegacy(original.path);

        await reported.syncAll();

        // Réécrite avant l'envoi : le cache peut être purgé ensuite.
        final entry = _hiveService.offlineQueue.values.single;
        expect(entry.containsKey('photoPath'), isFalse);
        expect(entry['photoFile'], endsWith('_herite.jpg'));
        await original.delete();

        stubPost();
        await reported.syncAll();

        expect(
          uploaded.last,
          startsWith('${supportDir.path}/${TrackingQueuePhotoStore.folder}/'),
        );
        verifyPosted(photoUrl: equals('tracking/bid-1/1_DEPART.jpg'), times: 2);
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        expect(reported.lostPhotosFor({'bid-1'}), isEmpty);
      });

      test('ancien conteneur iOS : photo retrouvée par son nom dans le '
          'répertoire temporaire actuel', () async {
        final uploaded = <String>[];
        stubUploadCapturing(uploaded);
        stubPost();
        await File('${tmpDir.path}/image_picker_1.jpg').writeAsBytes([7]);
        await queueLegacy(
          '/private/var/mobile/Containers/Data/Application/OLD-UUID/tmp/'
          'image_picker_1.jpg',
        );

        await reported.syncAll();

        expect(uploaded.single, endsWith('_image_picker_1.jpg'));
        verifyPosted(photoUrl: equals('tracking/bid-1/1_DEPART.jpg'));
        expect(reported.lostPhotosFor({'bid-1'}), isEmpty);
        verifyNever(
          () => reporter.report(
            any(),
            operation: any(named: 'operation'),
            stackTrace: any(named: 'stackTrace'),
            context: any(named: 'context'),
          ),
        );
      });

      test('chemin hérité introuvable : étape envoyée sans photo, un seul '
          'signalement', () async {
        when(
          () => mockRepo.uploadTrackingPhoto(any(), any()),
        ).thenThrow(const FileSystemException('cannot open'));
        stubPost(
          error: DioException(
            requestOptions: RequestOptions(path: '/tracking/events'),
            type: DioExceptionType.connectionError,
          ),
        );
        await queueLegacy('/var/OLD-UUID/tmp/introuvable.jpg');

        await reported.syncAll();
        stubPost();
        await reported.syncAll();

        verifyPosted(photoUrl: isNull, times: 2);
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        expect(reports(), hasLength(1));
        expect(reported.lostPhotosFor({'bid-1'}), hasLength(1));
      });

      test('copie ratée deux fois : aucun chemin absolu en file, photo '
          'perdue signalée tout de suite', () async {
        // Le répertoire des copies ne peut pas être créé : c'est un fichier.
        final blocker = File('${_tempDir.path}/bloque_${supportDir.hashCode}');
        await blocker.writeAsBytes([0]);
        final failing = OfflineSyncService(
          _hiveService,
          mockRepo,
          reporter,
          DateTime.now,
          ScanSendGuard(),
          TrackingQueuePhotoStore(
            baseDirectory: () async => Directory(blocker.path),
            temporaryDirectory: () async => tmpDir,
          ),
        );
        stubPost();

        await failing.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: (await photo('ratee.jpg')).path,
        );

        final entry = _hiveService.offlineQueue.values.single;
        expect(entry.containsKey('photoPath'), isFalse);
        expect(entry.containsKey('photoFile'), isFalse);
        expect(failing.lostPhotosFor({'bid-1'}), hasLength(1));
        final captured = reports();
        expect(captured, hasLength(1));
        expect(captured.single['tracking_step'], 'DEPART');

        await failing.syncAll();

        verifyNever(() => mockRepo.uploadTrackingPhoto(any(), any()));
        verifyPosted(photoUrl: isNull);
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
      });

      test('photo présente mais illisible (téléphone verrouillé) : gardée, '
          'renvoyée au nouvel essai', () async {
        var calls = 0;
        when(() => mockRepo.uploadTrackingPhoto(any(), any())).thenAnswer((
          _,
        ) async {
          if (calls++ == 0) {
            throw DioException(
              requestOptions: RequestOptions(path: '/storage/upload/tracking'),
              error: const FileSystemException(
                'Operation not permitted',
                '',
                OSError('Operation not permitted', 1),
              ),
            );
          }
          return 'tracking/bid-1/1_DEPART.jpg';
        });
        stubPost();
        await reported.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: (await photo('verrouille.jpg')).path,
        );
        final name =
            _hiveService.offlineQueue.values.single['photoFile'] as String;

        await reported.syncAll();

        expect(reported.pendingCount, 1);
        expect(_hiveService.offlineQueue.values.single['photoFile'], name);
        expect(File(await store.resolve(name)).existsSync(), isTrue);
        expect(reported.lostPhotosFor({'bid-1'}), isEmpty);
        expect(reported.nextRetryDelay, isNotNull);
        verifyNever(
          () => reporter.report(
            any(),
            operation: any(named: 'operation'),
            stackTrace: any(named: 'stackTrace'),
            context: any(named: 'context'),
          ),
        );

        await reported.syncAll();

        verifyPosted(photoUrl: equals('tracking/bid-1/1_DEPART.jpg'));
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
      });

      test('FileSystemException directe, fichier présent : relancée', () async {
        final file = await photo('directe.jpg');
        when(
          () => mockRepo.uploadTrackingPhoto(any(), any()),
        ).thenThrow(const FileSystemException('locked'));
        stubPost();
        final key = await reported.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoPath: file.path,
          notBefore: DateTime.now().add(const Duration(minutes: 1)),
        );

        expect(await reported.sendScheduled(key), isNull);
        expect(_hiveService.offlineQueue.get(key)!['photoFile'], isNotNull);
        expect(reported.lostPhotosFor({'bid-1'}), isEmpty);
      });
    });

    test('dismissLostPhoto retire le message et notifie', () async {
      await _hiveService.userPrefs.put(OfflineSyncService.lostPhotosKey, [
        {'bidId': 'bid-1', 'eventType': 'DEPART'},
        {'bidId': 'bid-1', 'eventType': 'TRANSIT'},
        'illisible',
      ]);
      var calls = 0;
      void listener() => calls++;
      reported.lostPhotoChanges.addListener(listener);
      addTearDown(() => reported.lostPhotoChanges.removeListener(listener));

      expect(reported.lostPhotosFor({'bid-1'}), hasLength(2));
      await reported.dismissLostPhoto(
        const LostTrackingPhoto(bidId: 'bid-1', eventType: 'DEPART'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(reported.lostPhotosFor({'bid-1'}), [
        const LostTrackingPhoto(bidId: 'bid-1', eventType: 'TRANSIT'),
      ]);
      expect(calls, greaterThan(0));
    });

    test('LostTrackingPhoto : égalité et lecture défensive', () {
      const a = LostTrackingPhoto(bidId: 'b', eventType: 'DEPART');
      expect(a, const LostTrackingPhoto(bidId: 'b', eventType: 'DEPART'));
      expect(a.hashCode, Object.hash('b', 'DEPART'));
      expect(a == const LostTrackingPhoto(bidId: 'b', eventType: 'X'), isFalse);
      expect(LostTrackingPhoto.fromJson({'bidId': 1}), isNull);
      expect(LostTrackingPhoto.fromJson(null), isNull);
      expect(const TrackingPhotoLostError().toString(), contains('Lost'));
    });
  });

  group('supplément en attente (409 handover-supplement-pending)', () {
    final t0 = DateTime.utc(2026, 10, 19, 12);
    late DateTime now;
    late _MockAnalytics analytics;
    late OfflineSyncService timed;

    DioException blocked() => DioException(
      requestOptions: RequestOptions(path: '/tracking/events'),
      error: const ConflictException(
        'Un supplément attend',
        code: 'handover-supplement-pending',
      ),
    );

    void stubPost(Future<TrackingEventModel> Function() answer) => when(
      () => mockRepo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
        scanMethod: any(named: 'scanMethod'),
        trackingNumber: any(named: 'trackingNumber'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    ).thenAnswer((_) => answer());

    setUp(() {
      now = t0;
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      timed = OfflineSyncService(
        _hiveService,
        mockRepo,
        null,
        () => now,
        null,
        null,
        analytics,
      );
    });

    tearDown(() => timed.dispose());

    test('ni définitif, ni passager : refusé pour l\'instant', () {
      const pending = ConflictException(
        'x',
        code: 'handover-supplement-pending',
      );
      expect(isRetryLaterTrackingRejection(pending), isTrue);
      expect(OfflineSyncService.isDefinitiveRejection(pending), isFalse);
      expect(
        isRetryLaterTrackingRejection(
          const ConflictException('x', code: 'depart-already-scanned'),
        ),
        isFalse,
      );
      expect(
        isRetryLaterTrackingRejection(
          const ValidationException('x', code: 'handover-supplement-pending'),
        ),
        isFalse,
      );
    });

    test('syncAll garde l\'étape et la renvoie 5 min plus tard', () async {
      stubPost(() async => throw blocked());
      final key = await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');

      await timed.syncAll();

      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.get(key)!,
      );
      expect(entry['notBefore'], '2026-10-19T12:05:00.000Z');
      expect(timed.nextRetryDelay, isNull, reason: 'pas une panne');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSupplement,
          properties: {'channel': 'offline'},
        ),
      ).called(1);

      // Avant l'échéance : rien ne part.
      now = t0.add(const Duration(minutes: 4));
      await timed.syncAll();
      verify(
        () => mockRepo.postScan(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          photoUrl: any(named: 'photoUrl'),
          scanMethod: any(named: 'scanMethod'),
          trackingNumber: any(named: 'trackingNumber'),
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(1);

      // Après la réponse de l'expéditeur : l'étape passe et quitte la file.
      stubPost(() async => _fakeEvent());
      now = t0.add(const Duration(minutes: 6));
      await timed.syncAll();
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('rejeux : la photo n\'est envoyée qu\'une fois', () async {
      final dir = await Directory.systemTemp.createTemp('supp_photo');
      addTearDown(() => dir.delete(recursive: true));
      final photo = File('${dir.path}/depart.jpg')..writeAsBytesSync([1]);
      when(
        () => mockRepo.uploadTrackingPhoto(any(), any()),
      ).thenAnswer((_) async => 'tracking/bid-1/depart.jpg');
      stubPost(() async => throw blocked());
      final key = await timed.queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        photoPath: photo.path,
      );

      await timed.syncAll();
      expect(
        _hiveService.offlineQueue.get(key)!['photoKey'],
        'tracking/bid-1/depart.jpg',
      );

      now = t0.add(const Duration(minutes: 6));
      await timed.syncAll();
      now = t0.add(const Duration(minutes: 12));
      stubPost(() async => _fakeEvent());
      await timed.syncAll();

      verify(() => mockRepo.uploadTrackingPhoto(any(), any())).called(1);
      verify(
        () => mockRepo.postScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          photoUrl: 'tracking/bid-1/depart.jpg',
          offlineTimestamp: any(named: 'offlineTimestamp'),
        ),
      ).called(3);
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('événement offline émis au premier report seulement', () async {
      stubPost(() async => throw blocked());
      await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');

      await timed.syncAll();
      now = t0.add(const Duration(minutes: 6));
      await timed.syncAll();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSupplement,
          properties: {'channel': 'offline'},
        ),
      ).called(1);
    });

    test(
      'sendScheduled sans écran pour le motif : étape gardée et comptée',
      () async {
        stubPost(() async => throw blocked());
        final key = await timed.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          notBefore: t0.add(const Duration(seconds: 7)),
        );

        expect(await timed.sendScheduled(key, canShowRefusal: false), isNull);

        final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.get(key)!,
        );
        expect(entry['notBefore'], '2026-10-19T12:05:00.000Z');
        // Le bandeau des scans en attente la montre : la remise n'est pas
        // validée.
        expect(timed.pendingCountFor({'bid-1'}), 1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.handoverBlockedSupplement,
            properties: {'channel': 'direct'},
          ),
        ).called(1);
      },
    );

    test(
      'sendScheduled (onglet Suivi) : retirée de la file, erreur remontée',
      () async {
        stubPost(() async => throw blocked());
        final key = await timed.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
          notBefore: t0.add(const Duration(seconds: 7)),
        );

        await expectLater(
          timed.sendScheduled(key),
          throwsA(
            isA<DioException>().having(
              (e) => (e.error as ConflictException?)?.code,
              'code',
              'handover-supplement-pending',
            ),
          ),
        );
        expect(_hiveService.offlineQueue.isEmpty, isTrue);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.handoverBlockedSupplement,
            properties: {'channel': 'direct'},
          ),
        ).called(1);
      },
    );
  });

  group('remise bloquée : absence contestée ou modification en attente', () {
    final t0 = DateTime.utc(2026, 10, 30, 9);
    late DateTime now;
    late _MockAnalytics analytics;
    late OfflineSyncService timed;

    DioException conflict(String code) => DioException(
      requestOptions: RequestOptions(path: '/tracking/events'),
      error: ConflictException('Remise bloquée', code: code),
    );

    void stubPost(Future<TrackingEventModel> Function() answer) => when(
      () => mockRepo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
        scanMethod: any(named: 'scanMethod'),
        trackingNumber: any(named: 'trackingNumber'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    ).thenAnswer((_) => answer());

    setUp(() {
      now = t0;
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      timed = OfflineSyncService(
        _hiveService,
        mockRepo,
        null,
        () => now,
        null,
        null,
        analytics,
      );
    });

    tearDown(() => timed.dispose());

    test('absence contestée, hors ligne : étape gardée, renvoyée plus tard, '
        'événement dédié', () async {
      stubPost(() async => throw conflict('handover-sender-noshow-pending'));
      final key = await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');

      await timed.syncAll();

      final entry = Map<String, dynamic>.from(
        _hiveService.offlineQueue.get(key)!,
      );
      expect(entry['notBefore'], '2026-10-30T09:05:00.000Z');
      expect(timed.pendingCountFor({'bid-1'}), 1);
      expect(timed.nextRetryDelay, isNull, reason: 'pas une panne');
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSenderNoShow,
          properties: {'channel': 'offline'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSupplement,
          properties: any(named: 'properties'),
        ),
      );

      // L'équipe rejette la déclaration : le rejeu passe.
      stubPost(() async => _fakeEvent());
      now = t0.add(const Duration(minutes: 6));
      await timed.syncAll();
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
    });

    test('absence contestée, onglet Suivi affiché : étape retirée, motif '
        'remonté', () async {
      stubPost(() async => throw conflict('handover-sender-noshow-pending'));
      final key = await timed.queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        notBefore: t0.add(const Duration(seconds: 7)),
      );

      await expectLater(
        timed.sendScheduled(key),
        throwsA(
          isA<DioException>().having(
            (e) => (e.error as ConflictException?)?.code,
            'code',
            'handover-sender-noshow-pending',
          ),
        ),
      );
      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSenderNoShow,
          properties: {'channel': 'direct'},
        ),
      ).called(1);
    });

    // L'équipe peut mettre des jours à trancher : le rejeu s'espace (5 min,
    // 15 min, puis toutes les heures) au lieu de repartir toutes les 5 min.
    test(
      'absence examinée : rejeux espacés à 5, 15 puis 60 min au plus',
      () async {
        stubPost(() async => throw conflict('handover-sender-noshow-pending'));
        final key = await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');

        String notBefore() =>
            _hiveService.offlineQueue.get(key)!['notBefore'] as String;

        await timed.syncAll();
        expect(notBefore(), '2026-10-30T09:05:00.000Z');

        now = DateTime.utc(2026, 10, 30, 9, 6);
        await timed.syncAll();
        expect(notBefore(), '2026-10-30T09:21:00.000Z');

        now = DateTime.utc(2026, 10, 30, 9, 22);
        await timed.syncAll();
        expect(notBefore(), '2026-10-30T10:22:00.000Z');

        now = DateTime.utc(2026, 10, 30, 10, 23);
        await timed.syncAll();
        expect(
          notBefore(),
          '2026-10-30T11:23:00.000Z',
          reason: 'plafond 60 min',
        );
        expect(timed.awaitingDecisionCountFor({'bid-1'}), 1);
        expect(timed.awaitingDecisionCountFor({'bid-2'}), 0);
      },
    );

    test(
      'compteur remis à zéro : nouvelle étape et changement de motif',
      () async {
        stubPost(() async => throw conflict('handover-sender-noshow-pending'));
        final first = await timed.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
        );
        await timed.syncAll();
        now = DateTime.utc(2026, 10, 30, 9, 6);
        await timed.syncAll();

        // L'étape part : la suivante repart de 5 min.
        stubPost(() async => _fakeEvent());
        now = DateTime.utc(2026, 10, 30, 9, 22);
        await timed.syncAll();
        expect(_hiveService.offlineQueue.containsKey(first), isFalse);

        stubPost(() async => throw conflict('handover-sender-noshow-pending'));
        final second = await timed.queueScan(
          bidId: 'bid-1',
          eventType: 'DEPART',
        );
        await timed.syncAll();
        expect(
          _hiveService.offlineQueue.get(second)!['notBefore'],
          '2026-10-30T09:27:00.000Z',
        );

        // Le motif change (un supplément attend) : 5 min, sans décision de
        // l'équipe à annoncer.
        stubPost(() async => throw conflict('handover-supplement-pending'));
        now = DateTime.utc(2026, 10, 30, 9, 28);
        await timed.syncAll();
        expect(
          _hiveService.offlineQueue.get(second)!['notBefore'],
          '2026-10-30T09:33:00.000Z',
        );
        expect(timed.awaitingDecisionCountFor({'bid-1'}), 0);
        expect(timed.pendingCountFor({'bid-1'}), 1);
      },
    );

    test('supplément en attente : toujours 5 min', () async {
      stubPost(() async => throw conflict('handover-supplement-pending'));
      final key = await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      await timed.syncAll();
      now = DateTime.utc(2026, 10, 30, 9, 6);
      await timed.syncAll();
      expect(
        _hiveService.offlineQueue.get(key)!['notBefore'],
        '2026-10-30T09:11:00.000Z',
      );
    });

    test('modification en attente : son propre événement', () async {
      stubPost(() async => throw conflict('handover-amendment-pending'));
      await timed.queueScan(bidId: 'bid-1', eventType: 'DEPART');

      await timed.syncAll();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedAmendment,
          properties: {'channel': 'offline'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.handoverBlockedSupplement,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('colis clos avant la synchronisation (422 bid-not-accepted)', () {
    DioException closed() => DioException(
      requestOptions: RequestOptions(path: '/tracking/events'),
      error: const ValidationException('Colis clos', code: 'bid-not-accepted'),
    );

    void stubPost(Future<TrackingEventModel> Function() answer) => when(
      () => mockRepo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
        scanMethod: any(named: 'scanMethod'),
        trackingNumber: any(named: 'trackingNumber'),
        offlineTimestamp: any(named: 'offlineTimestamp'),
      ),
    ).thenAnswer((_) => answer());

    setUp(() async {
      await _hiveService.userPrefs.delete(OfflineSyncService.closedScansKey);
    });

    test('remise resynchronisée refusée : étape retirée, voyageur prévenu une '
        'fois', () async {
      stubPost(() async => throw closed());
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      var calls = 0;
      void listener() => calls++;
      service.closedScanChanges.addListener(listener);
      addTearDown(() => service.closedScanChanges.removeListener(listener));

      await service.syncAll();
      await Future<void>.delayed(Duration.zero);

      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      expect(service.closedScansFor({'bid-1', 'bid-2'}), ['bid-1']);
      expect(service.closedScansFor({'bid-2'}), isEmpty);
      expect(calls, greaterThan(0));
    });

    test('le voyageur ferme le message', () async {
      stubPost(() async => throw closed());
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      await service.syncAll();

      await service.dismissClosedScan('bid-1');

      expect(service.closedScansFor({'bid-1'}), isEmpty);
    });

    test('envoi direct de l\'onglet Suivi : motif remonté, pas de message '
        'différé', () async {
      stubPost(() async => throw closed());
      final key = await service.queueScan(
        bidId: 'bid-1',
        eventType: 'DEPART',
        notBefore: DateTime.now().add(const Duration(seconds: 7)),
      );

      await expectLater(service.sendScheduled(key), throwsA(anything));

      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      expect(service.closedScansFor({'bid-1'}), isEmpty);
    });

    test('autre étape refusée en 422 : pas de message', () async {
      stubPost(() async => throw closed());
      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');

      await service.syncAll();

      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      expect(service.closedScansFor({'bid-1'}), isEmpty);
    });

    test('autre refus définitif de la remise : pas de message', () async {
      stubPost(
        () async => throw DioException(
          requestOptions: RequestOptions(path: '/tracking/events'),
          error: const ForbiddenException('x'),
        ),
      );
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');

      await service.syncAll();

      expect(_hiveService.offlineQueue.isEmpty, isTrue);
      expect(service.closedScansFor({'bid-1'}), isEmpty);
    });
  });

  group('dispose', () {
    test('cancel does not throw when not started', () {
      final s = OfflineSyncService(_hiveService, mockRepo);
      expect(() => s.dispose(), returnsNormally);
    });
  });
}

TrackingEventModel _fakeEvent() => TrackingEventModel(
  id: 'ev-1',
  bidId: 'bid-1',
  eventType: 'TRANSIT',
  scannedAt: DateTime(2024, 6),
  createdAt: DateTime(2024, 6),
);
