import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/scan_send_guard.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TrackingRepository {}

TrackingEventModel _event(String id, {String type = 'DEPART'}) =>
    TrackingEventModel(
      id: id,
      bidId: 'bid-1',
      eventType: type,
      scannedAt: DateTime(2026, 10, 10, 14, 45),
      createdAt: DateTime(2026, 10, 10, 14, 45),
    );

DioException _conflict(String code) => DioException(
  requestOptions: RequestOptions(path: '/tracking/events'),
  error: ConflictException('x', code: code),
);

void main() {
  late ScanSendGuard guard;
  final at = DateTime(2026, 10, 10, 16);

  setUp(() => guard = ScanSendGuard(now: () => at));

  test(
    'FLUTTER-JV : deux envois simultanés du même DEPART, un seul POST',
    () async {
      final answer = Completer<TrackingEventModel>();
      var posts = 0;
      Future<TrackingEventModel> post() {
        posts++;
        return answer.future;
      }

      final first = guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'DEPART',
        post: post,
      );
      expect(guard.isSending('bid-1', 'DEPART'), isTrue);
      final second = guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'DEPART',
        post: post,
      );
      answer.complete(_event('e1'));

      expect((await first).id, 'e1');
      expect((await second).id, 'e1');
      expect(posts, 1);
      expect(guard.isSending('bid-1', 'DEPART'), isFalse);
    },
  );

  test('étapes différentes : chacune part', () async {
    var posts = 0;
    await Future.wait([
      guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'DEPART',
        post: () async {
          posts++;
          return _event('d');
        },
      ),
      guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        post: () async {
          posts++;
          return _event('t', type: 'TRANSIT');
        },
      ),
    ]);
    expect(posts, 2);
  });

  test('le premier échoue : le second tente à son tour', () async {
    final answer = Completer<TrackingEventModel>();
    final first = guard.postStepOnce(
      bidId: 'bid-1',
      eventType: 'DEPART',
      post: () => answer.future,
    );
    var secondPosted = false;
    final second = guard.postStepOnce(
      bidId: 'bid-1',
      eventType: 'DEPART',
      post: () async {
        secondPosted = true;
        return _event('e2');
      },
    );
    answer.completeError(const ServerException('x'));

    await expectLater(first, throwsA(isA<ServerException>()));
    expect((await second).id, 'e2');
    expect(secondPosted, isTrue);
  });

  test('409 depart-already-scanned : succès, étape relue au back', () async {
    final repo = _MockRepo();
    when(
      () => repo.getEvents('bid-1'),
    ).thenAnswer((_) async => [_event('t', type: 'TRANSIT'), _event('d')]);

    final event = await guard.postStepOnce(
      bidId: 'bid-1',
      eventType: 'DEPART',
      repository: repo,
      post: () async => throw _conflict('depart-already-scanned'),
    );

    expect(event.id, 'd');
  });

  test(
    '409 scan-already-recorded, relecture impossible : étape locale',
    () async {
      final repo = _MockRepo();
      when(() => repo.getEvents(any())).thenThrow(const NetworkException('x'));

      final event = await guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'DEPART',
        repository: repo,
        post: () async => throw _conflict('scan-already-recorded'),
      );

      expect(event.eventType, 'DEPART');
      expect(event.bidId, 'bid-1');
      expect(event.scannedAt, at);
    },
  );

  test('409 sans relecture possible ni étape trouvée : étape locale', () async {
    final repo = _MockRepo();
    when(() => repo.getEvents(any())).thenAnswer((_) async => []);
    final viaRepo = await guard.postStepOnce(
      bidId: 'bid-1',
      eventType: 'DEPART',
      repository: repo,
      post: () async => throw _conflict('depart-already-scanned'),
    );
    final withoutRepo = await guard.postStepOnce(
      bidId: 'bid-1',
      eventType: 'DEPART',
      post: () async => throw _conflict('depart-already-scanned'),
    );
    expect(viaRepo.id, isEmpty);
    expect(withoutRepo.eventType, 'DEPART');
  });

  test('un autre 409 remonte', () async {
    await expectLater(
      guard.postStepOnce(
        bidId: 'bid-1',
        eventType: 'DEPART',
        post: () async => throw _conflict('bid-cancelled'),
      ),
      throwsA(isA<DioException>()),
    );
    expect(guard.isSending('bid-1', 'DEPART'), isFalse);
  });

  test('isAlreadyRecorded', () {
    expect(
      ScanSendGuard.isAlreadyRecorded(
        const ConflictException('x', code: 'scan-already-recorded'),
      ),
      isTrue,
    );
    expect(
      ScanSendGuard.isAlreadyRecorded(
        const ConflictException('x', code: 'depart-already-scanned'),
      ),
      isTrue,
    );
    expect(
      ScanSendGuard.isAlreadyRecorded(const ConflictException('x')),
      isFalse,
    );
    expect(
      ScanSendGuard.isAlreadyRecorded(
        const ValidationException('x', code: 'scan-already-recorded'),
      ),
      isFalse,
    );
    expect(ScanSendGuard.shared, same(ScanSendGuard.shared));
  });
}
