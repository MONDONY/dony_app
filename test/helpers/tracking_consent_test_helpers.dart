import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'map_backed_box.dart';

class _MockLocator extends Mock implements ScanLocator {}

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Enregistre un [TrackingConsentCubit] adossé à une box en mémoire le temps
/// du test (la feuille n'est jamais montrée : [sheetAnswer] répond d'office).
/// Rend le cubit.
TrackingConsentCubit useTrackingConsent({
  bool? sheetAnswer = false,
  void Function()? onSheet,
}) {
  final locator = _MockLocator();
  when(() => locator.isPermissionGranted()).thenAnswer((_) async => false);
  when(() => locator.requestPermission()).thenAnswer((_) async => false);
  final analytics = _MockAnalytics();
  when(
    () => analytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final cubit = TrackingConsentCubit(
    box: () => mapBackedBox(<String, dynamic>{}),
    locator: locator,
    analytics: analytics,
    showSheet: (_) async {
      onSheet?.call();
      return sheetAnswer;
    },
  );
  if (getIt.isRegistered<TrackingConsentCubit>()) {
    getIt.unregister<TrackingConsentCubit>();
  }
  getIt.registerSingleton<TrackingConsentCubit>(cubit);
  addTearDown(() {
    if (getIt.isRegistered<TrackingConsentCubit>()) {
      getIt.unregister<TrackingConsentCubit>();
    }
  });
  return cubit;
}
