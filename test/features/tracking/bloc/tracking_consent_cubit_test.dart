import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/map_backed_box.dart';

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockContext extends Mock implements BuildContext {}

void main() {
  late Map<String, dynamic> stored;
  late _MockLocator locator;
  late _MockAnalytics analytics;
  late _MockContext context;
  late int sheetShown;
  late bool? sheetAnswer;

  TrackingConsentCubit build() => TrackingConsentCubit(
    box: () => mapBackedBox(stored),
    locator: locator,
    analytics: analytics,
    showSheet: (_) async {
      sheetShown++;
      return sheetAnswer;
    },
  );

  setUp(() {
    stored = {};
    sheetShown = 0;
    sheetAnswer = true;
    locator = _MockLocator();
    analytics = _MockAnalytics();
    context = _MockContext();
    when(() => context.mounted).thenReturn(true);
    when(() => locator.requestPermission()).thenAnswer((_) async => true);
    when(() => locator.isPermissionGranted()).thenAnswer((_) async => true);
    when(() => locator.isPermanentlyDenied()).thenAnswer((_) async => false);
    when(() => locator.openSettings()).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void expectAnswered({required bool granted, required String source}) {
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.trackingConsentAnswered,
        properties: {'granted': granted, 'source': source},
      ),
    ).called(1);
  }

  test('consentSheetShownOnlyOnce', () async {
    final cubit = build();
    await cubit.ensureAsked(
      context,
      source: TrackingConsentSource.acceptedParcel,
    );
    await cubit.ensureAsked(context, source: TrackingConsentSource.depart);
    await build().ensureAsked(
      context,
      source: TrackingConsentSource.tripScreen,
    );
    expect(sheetShown, 1);
  });

  test('refusalIsRememberedAndNeverBlocks', () async {
    sheetAnswer = false;
    final cubit = build();
    final first = await cubit.ensureAsked(
      context,
      source: TrackingConsentSource.acceptedParcel,
    );
    final second = await build().ensureAsked(
      context,
      source: TrackingConsentSource.depart,
    );
    expect(first, isFalse);
    expect(second, isFalse);
    expect(sheetShown, 1);
    expect(stored[HiveService.kTrackingConsent], 'declined');
    verifyNever(() => locator.requestPermission());
    expectAnswered(granted: false, source: 'accepted_parcel');
  });

  test('dismissingTheSheetCountsAsRefusal', () async {
    sheetAnswer = null;
    final granted = await build().ensureAsked(
      context,
      source: TrackingConsentSource.tripScreen,
    );
    expect(granted, isFalse);
    expect(stored[HiveService.kTrackingConsent], 'declined');
  });

  test('grantedAfterOsPermissionAccepted', () async {
    final cubit = build();
    final granted = await cubit.ensureAsked(
      context,
      source: TrackingConsentSource.depart,
    );
    expect(granted, isTrue);
    expect(stored[HiveService.kTrackingConsent], 'granted');
    expect(cubit.state.enabled, isTrue);
    expectAnswered(granted: true, source: 'depart');
  });

  test('declinedWhenOsPermissionDenied', () async {
    when(() => locator.requestPermission()).thenAnswer((_) async => false);
    final cubit = build();
    final granted = await cubit.ensureAsked(
      context,
      source: TrackingConsentSource.depart,
    );
    expect(granted, isFalse);
    expect(stored[HiveService.kTrackingConsent], 'declined');
    expect(cubit.state.enabled, isFalse);
    expectAnswered(granted: false, source: 'depart');
  });

  test('acceptedParcelTriggersConsentOnlyForTraveler', () async {
    final cubit = build()..updateRoles(['SENDER']);
    await cubit.onParcelAccepted(context);
    expect(sheetShown, 0);

    cubit.updateRoles(['SENDER', 'TRAVELER']);
    await cubit.onParcelAccepted(context);
    expect(sheetShown, 1);
    expectAnswered(granted: true, source: 'accepted_parcel');
  });

  test('settingsTurnOnReRunsTheFlowEvenAfterRefusal', () async {
    stored[HiveService.kTrackingConsent] = 'declined';
    final cubit = build();
    await cubit.setEnabled(context, true);
    expect(sheetShown, 1);
    expect(stored[HiveService.kTrackingConsent], 'granted');
    expectAnswered(granted: true, source: 'settings');
  });

  test('settingsTurnOnOpensSystemSettingsWhenPermanentlyDenied', () async {
    stored[HiveService.kTrackingConsent] = 'declined';
    when(() => locator.isPermanentlyDenied()).thenAnswer((_) async => true);
    final cubit = build();
    final outcome = await cubit.setEnabled(context, true);
    expect(outcome, TrackingConsentOutcome.openedSystemSettings);
    expect(sheetShown, 0);
    verify(() => locator.openSettings()).called(1);
  });

  test('settingsTurnOffRecordsRefusal', () async {
    stored[HiveService.kTrackingConsent] = 'granted';
    final cubit = build();
    await cubit.setEnabled(context, false);
    expect(stored[HiveService.kTrackingConsent], 'declined');
    expect(cubit.state.enabled, isFalse);
    expectAnswered(granted: false, source: 'settings');
  });

  test('refreshReadsStoredAnswerAndOsPermission', () async {
    stored[HiveService.kTrackingConsent] = 'granted';
    when(() => locator.isPermissionGranted()).thenAnswer((_) async => false);
    final cubit = build();
    await cubit.refresh();
    expect(cubit.state.answer, TrackingConsentAnswer.granted);
    expect(cubit.state.osGranted, isFalse);
    expect(cubit.state.enabled, isFalse);
  });

  test('resetsOnLogout', () async {
    final cubit = build()..updateRoles(['TRAVELER']);
    await cubit.ensureAsked(context, source: TrackingConsentSource.depart);
    expect(cubit.state.enabled, isTrue);

    cubit.updateRoles(null);
    expect(cubit.state, const TrackingConsentState());
  });

  test('relevantOnlyWhenRolesUnknownOrTraveler', () {
    final cubit = build();
    expect(cubit.state.relevant, isTrue);
    cubit.updateRoles(['SENDER']);
    expect(cubit.state.relevant, isFalse);
    cubit.updateRoles(['SENDER', 'TRAVELER']);
    expect(cubit.state.relevant, isTrue);
  });
}
