import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/map_backed_box.dart';

class _MockTracking extends Mock implements TripTrackingRepository {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockConsent extends Mock implements TrackingConsentCubit {}

class _FakeContext extends Fake implements BuildContext {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockTracking tracking;
  late _MockLocator locator;
  late _MockConsent consent;
  late _MockAnalytics analytics;
  late Map<String, dynamic> stored;
  late BuildContext ctx;

  setUpAll(() {
    registerFallbackValue(TrackingConsentSource.depart);
    registerFallbackValue(_FakeContext());
  });

  setUp(() {
    tracking = _MockTracking();
    locator = _MockLocator();
    consent = _MockConsent();
    analytics = _MockAnalytics();
    stored = <String, dynamic>{};
    when(
      () => locator.lastKnownCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => consent.ensureAsked(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => true);
    when(
      () => tracking.depart(
        any(),
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
      ),
    ).thenAnswer((_) async {});
  });

  TripDepartCubit build({String id = 'trip-1'}) => TripDepartCubit(
    announcementId: id,
    tracking: tracking,
    locator: locator,
    consent: consent,
    analytics: analytics,
    box: () => mapBackedBox(stored),
  );

  Future<void> withContext(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );
    await body();
  }

  testWidgets('departSendsPositionWhenGranted', (tester) async {
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 48.85, lon: 2.35));
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(() => tracking.depart('trip-1', lat: 48.85, lon: 2.35)).called(1);
      expect(cubit.state.departed, isTrue);
      expect(stored['${HiveService.kTripDepartedPrefix}trip-1'], isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripDepartureConfirmed,
          properties: {'has_position': true},
        ),
      ).called(1);
    });
  });

  testWidgets('departWithoutPositionStillCallsApi', (tester) async {
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(() => tracking.depart('trip-1')).called(1);
      expect(cubit.state.departed, isTrue);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripDepartureConfirmed,
          properties: {'has_position': false},
        ),
      ).called(1);
    });
  });

  testWidgets('refusalStillAllowsDepart', (tester) async {
    when(
      () => consent.ensureAsked(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => false);
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(
        () => consent.ensureAsked(any(), source: TrackingConsentSource.depart),
      ).called(1);
      verify(() => tracking.depart('trip-1')).called(1);
      expect(cubit.state.departed, isTrue);
    });
  });

  testWidgets('captureFailureStillCallsApi', (tester) async {
    when(() => locator.captureCoordinatesIfGranted()).thenThrow(Exception('x'));
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(() => tracking.depart('trip-1')).called(1);
    });
  });

  testWidgets('failureKeepsButtonAndExposesError', (tester) async {
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    when(
      () => tracking.depart(
        any(),
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
      ),
    ).thenThrow(const NetworkException('x'));
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      expect(cubit.state.departed, isFalse);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(stored, isEmpty);
    });
  });

  for (final fails in [false, true]) {
    testWidgets(
      'cubit fermé pendant l\'appel (${fails ? 'échec' : 'succès'}) : '
      'aucune StateError',
      (tester) async {
        when(
          () => locator.captureCoordinatesIfGranted(),
        ).thenAnswer((_) async => null);
        final reply = Completer<void>();
        when(
          () => tracking.depart(
            any(),
            lat: any(named: 'lat'),
            lon: any(named: 'lon'),
          ),
        ).thenAnswer((_) => reply.future);
        await withContext(tester, () async {
          final cubit = build();
          final pending = cubit.depart(ctx);
          await tester.pump();
          expect(cubit.state.loading, isTrue);
          // L'écran qui fournit le cubit se ferme, la réponse arrive ensuite.
          await cubit.close();
          if (fails) {
            reply.completeError(const NetworkException('x'));
          } else {
            reply.complete();
          }
          await pending;
          expect(tester.takeException(), isNull);
          // Départ fait côté serveur : le drapeau local est quand même posé.
          expect(
            stored['${HiveService.kTripDepartedPrefix}trip-1'],
            fails ? isNull : isTrue,
          );
        });
      },
    );
  }

  test('startsDepartedWhenFlagStored', () {
    stored['${HiveService.kTripDepartedPrefix}trip-1'] = true;
    expect(build().state.departed, isTrue);
    expect(build(id: 'other').state.departed, isFalse);
  });

  testWidgets('departNotBlockedWhenLocatorNeverAnswers', (tester) async {
    final never = Completer<ScanPosition?>();
    when(
      () => locator.lastKnownCoordinatesIfGranted(),
    ).thenAnswer((_) => never.future);
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) => never.future);
    await withContext(tester, () async {
      final cubit = build();
      await tester.runAsync(() => cubit.depart(ctx));
      verify(() => tracking.depart('trip-1')).called(1);
      expect(cubit.state.departed, isTrue);
    });
  });

  testWidgets('departUsesLastKnownPositionFirst', (tester) async {
    when(
      () => locator.lastKnownCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 3, lon: 4));
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(() => tracking.depart('trip-1', lat: 3, lon: 4)).called(1);
      verifyNever(() => locator.captureCoordinatesIfGranted());
    });
  });

  testWidgets('departWithoutPositionWhenDeclined', (tester) async {
    when(
      () => consent.ensureAsked(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => false);
    when(
      () => locator.lastKnownCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 1, lon: 2));
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 1, lon: 2));
    await withContext(tester, () async {
      final cubit = build();
      await cubit.depart(ctx);
      verify(() => tracking.depart('trip-1')).called(1);
      verifyNever(() => locator.lastKnownCoordinatesIfGranted());
      verifyNever(() => locator.captureCoordinatesIfGranted());
      expect(cubit.state.departed, isTrue);
    });
  });
}
