import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/scan_submitter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSubmitter extends Mock implements ScanSubmitter {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _event = TrackingEventModel(
  id: 'e1',
  bidId: 'bid-1',
  eventType: 'TRANSIT',
  scannedAt: DateTime(2026, 9, 28),
  createdAt: DateTime(2026, 9, 28),
);

void main() {
  setUpAll(() => registerFallbackValue(ScanMethod.qr));

  late _MockSubmitter submitter;
  late _MockLocator locator;
  late _MockAnalytics analytics;

  const here = ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar');

  setUp(() {
    submitter = _MockSubmitter();
    locator = _MockLocator();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => locator.capture()).thenAnswer((_) async => here);
    when(
      () => submitter.submit(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        photoPath: any(named: 'photoPath'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        queueOnNetworkFailure: any(named: 'queueOnNetworkFailure'),
        scanMethod: any(named: 'scanMethod'),
      ),
    ).thenAnswer((_) async => ScanSubmitSent(_event));
  });

  SuiviValidationCubit build({Duration delay = const Duration(seconds: 5)}) =>
      SuiviValidationCubit(
        submitter,
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

  void verifySubmitted({
    String bidId = 'bid-1',
    String step = 'TRANSIT',
    String? photoPath,
    ScanMethod method = ScanMethod.qr,
    int times = 1,
  }) => verify(
    () => submitter.submit(
      bidId: bidId,
      eventType: step,
      photoPath: photoPath,
      gpsLat: 14.7,
      gpsLon: -17.4,
      gpsLabel: 'Dakar',
      scanMethod: method,
      queueOnNetworkFailure: true,
    ),
  ).called(times);

  test('rien ne part pendant le délai, tout part à la fin', () {
    fakeAsync((async) {
      final c = build();
      final id = scheduleTransit(c);
      expect(id, isNotNull);
      expect(c.state.pending.single.deadline, DateTime(2026, 9, 28, 12, 0, 5));
      expect(c.state.pendingBidIds, {'bid-1'});

      async.elapse(const Duration(seconds: 4));
      verifyNever(
        () => submitter.submit(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          photoPath: any(named: 'photoPath'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          queueOnNetworkFailure: any(named: 'queueOnNetworkFailure'),
          scanMethod: any(named: 'scanMethod'),
        ),
      );

      async.elapse(const Duration(seconds: 2));
      verifySubmitted();
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

  test('Annuler : rien n\'est envoyé', () {
    fakeAsync((async) {
      final c = build();
      final id = scheduleTransit(c)!;
      c.undo(id);
      expect(c.state.pending, isEmpty);
      async.elapse(const Duration(seconds: 10));
      verifyNever(
        () => submitter.submit(
          bidId: any(named: 'bidId'),
          eventType: any(named: 'eventType'),
          photoPath: any(named: 'photoPath'),
          gpsLat: any(named: 'gpsLat'),
          gpsLon: any(named: 'gpsLon'),
          gpsLabel: any(named: 'gpsLabel'),
          queueOnNetworkFailure: any(named: 'queueOnNetworkFailure'),
          scanMethod: any(named: 'scanMethod'),
        ),
      );
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.suiviStepUndone,
          properties: {'step': 'TRANSIT'},
        ),
      ).called(1);
      // Deuxième « Annuler » : sans effet.
      c.undo(id);
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

  test('plusieurs colis : chacun son délai', () {
    fakeAsync((async) {
      final c = build();
      scheduleTransit(c, bidId: 'a');
      async.elapse(const Duration(seconds: 3));
      scheduleTransit(c, bidId: 'b');
      expect(c.state.pending.map((p) => p.bidId), ['a', 'b']);

      async.elapse(const Duration(seconds: 2));
      verifySubmitted(bidId: 'a');
      expect(c.state.pending.map((p) => p.bidId), ['b']);

      async.elapse(const Duration(seconds: 3));
      verifySubmitted(bidId: 'b');
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
      position: const ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar'),
    );
    await c.flush();
    verifySubmitted(
      step: 'DEPART',
      photoPath: '/tmp/photo.jpg',
      method: ScanMethod.manual,
    );
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
    verifySubmitted();
  });

  blocTest<SuiviValidationCubit, SuiviValidationState>(
    'sans réseau : mise en file, issue « en attente »',
    setUp: () => when(
      () => submitter.submit(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        photoPath: any(named: 'photoPath'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        queueOnNetworkFailure: any(named: 'queueOnNetworkFailure'),
        scanMethod: any(named: 'scanMethod'),
      ),
    ).thenAnswer((_) async => const ScanSubmitQueued()),
    build: () => build(delay: const Duration(milliseconds: 10)),
    act: (c) => scheduleTransit(c),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<SuiviValidationState>().having(
        (s) => s.pending,
        'pending',
        hasLength(1),
      ),
      isA<SuiviValidationState>().having((s) => s.pending, 'pending', isEmpty),
      isA<SuiviValidationState>()
          .having((s) => s.outcome, 'outcome', isA<SuiviValidationQueued>())
          .having((s) => s.outcome!.parcelLabel, 'parcel', 'Madou'),
    ],
  );

  blocTest<SuiviValidationCubit, SuiviValidationState>(
    'refus du back : issue en échec, rien de tracé comme validé',
    setUp: () => when(
      () => submitter.submit(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        photoPath: any(named: 'photoPath'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        queueOnNetworkFailure: any(named: 'queueOnNetworkFailure'),
        scanMethod: any(named: 'scanMethod'),
      ),
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

  test('position trop lente : l\'étape part sans elle', () {
    fakeAsync((async) {
      when(
        () => locator.capture(),
      ).thenAnswer((_) => Completer<ScanPosition?>().future);
      final c = build();
      scheduleTransit(c);
      async.elapse(
        const Duration(seconds: 5) + SuiviValidationCubit.positionTimeout,
      );
      verify(
        () => submitter.submit(
          bidId: 'bid-1',
          eventType: 'TRANSIT',
          scanMethod: ScanMethod.qr,
          queueOnNetworkFailure: true,
        ),
      ).called(1);
      unawaited(c.close());
      async.flushMicrotasks();
    });
  });
}
