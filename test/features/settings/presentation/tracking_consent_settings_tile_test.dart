import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/map_backed_box.dart';

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late Map<String, dynamic> stored;
  late _MockLocator locator;
  late bool osGranted;
  late int sheetShown;

  Switch sw(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.byKey(const Key('privacy-tracking-consent')),
      matching: find.byType(Switch),
    ),
  );

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: TrackingConsentSettingsTile())),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    stored = {};
    osGranted = true;
    sheetShown = 0;
    locator = _MockLocator();
    when(
      () => locator.isPermissionGranted(),
    ).thenAnswer((_) async => osGranted);
    when(() => locator.requestPermission()).thenAnswer((_) async => true);
    when(() => locator.isPermanentlyDenied()).thenAnswer((_) async => false);
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<TrackingConsentCubit>(
      TrackingConsentCubit(
        box: () => mapBackedBox(stored),
        locator: locator,
        analytics: analytics,
        showSheet: (_) async {
          sheetShown++;
          return true;
        },
      ),
    );
    addTearDown(() => getIt.unregister<TrackingConsentCubit>());
  });

  testWidgets('shows on when granted in app and in the system', (tester) async {
    stored[HiveService.kTrackingConsent] = 'granted';
    await pumpTile(tester);
    expect(sw(tester).value, isTrue);
  });

  testWidgets('shows off when the system permission was revoked', (
    tester,
  ) async {
    stored[HiveService.kTrackingConsent] = 'granted';
    osGranted = false;
    await pumpTile(tester);
    expect(sw(tester).value, isFalse);
  });

  testWidgets('shows off before any answer', (tester) async {
    await pumpTile(tester);
    expect(sw(tester).value, isFalse);
  });

  testWidgets('toggling on reruns the consent flow', (tester) async {
    stored[HiveService.kTrackingConsent] = 'declined';
    await pumpTile(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(sheetShown, 1);
    expect(stored[HiveService.kTrackingConsent], 'granted');
    expect(sw(tester).value, isTrue);
  });

  testWidgets('toggling off records a refusal and explains the system part', (
    tester,
  ) async {
    stored[HiveService.kTrackingConsent] = 'granted';
    await pumpTile(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(stored[HiveService.kTrackingConsent], 'declined');
    expect(sw(tester).value, isFalse);
    expect(find.textContaining('réglages de votre téléphone'), findsOneWidget);
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: TrackingConsentSettingsSection())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trackingTileHiddenForSenderOnly', (tester) async {
    getIt<TrackingConsentCubit>().updateRoles(['SENDER']);
    await pumpSection(tester);
    expect(find.byKey(const Key('privacy-tracking-consent')), findsNothing);
  });

  testWidgets('trackingTileShownForTraveler', (tester) async {
    getIt<TrackingConsentCubit>().updateRoles(['SENDER', 'TRAVELER']);
    await pumpSection(tester);
    expect(find.byKey(const Key('privacy-tracking-consent')), findsOneWidget);
  });

  testWidgets('trackingTileShownWhenRolesUnknown', (tester) async {
    await pumpSection(tester);
    expect(find.byKey(const Key('privacy-tracking-consent')), findsOneWidget);
  });
}
