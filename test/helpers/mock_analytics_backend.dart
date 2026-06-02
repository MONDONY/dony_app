import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsBackend extends Mock implements AnalyticsBackend {}

class MockHiveService extends Mock implements HiveService {}

class MockBox extends Mock implements Box<dynamic> {}

/// Crée un AnalyticsService déjà configuré + consenti (isEnabled = true).
AnalyticsService makeEnabledAnalytics(MockAnalyticsBackend backend) {
  final hive = MockHiveService();
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(true);
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => backend.optIn()).thenAnswer((_) async {});
  when(() => backend.optOut()).thenAnswer((_) async {});
  when(() => backend.reset()).thenAnswer((_) async {});
  when(() => backend.capture(any(), any())).thenAnswer((_) async {});
  when(() => backend.screen(any(), any())).thenAnswer((_) async {});
  when(() => backend.identify(any(), any())).thenAnswer((_) async {});
  final service = AnalyticsService(hive, backend: backend);
  return service;
}

/// Crée un AnalyticsService configuré mais sans consentement (isEnabled = false).
AnalyticsService makeDisabledAnalytics(MockAnalyticsBackend backend) {
  final hive = MockHiveService();
  final box = MockBox();
  when(() => hive.userPrefs).thenReturn(box);
  when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(false);
  when(() => box.put(any(), any())).thenAnswer((_) async {});
  when(() => backend.optIn()).thenAnswer((_) async {});
  when(() => backend.optOut()).thenAnswer((_) async {});
  when(() => backend.reset()).thenAnswer((_) async {});
  when(() => backend.capture(any(), any())).thenAnswer((_) async {});
  when(() => backend.screen(any(), any())).thenAnswer((_) async {});
  when(() => backend.identify(any(), any())).thenAnswer((_) async {});
  final service = AnalyticsService(hive, backend: backend);
  return service;
}
