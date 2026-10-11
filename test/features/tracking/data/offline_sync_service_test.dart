import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockReporter extends Mock implements ErrorReportingService {}

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
