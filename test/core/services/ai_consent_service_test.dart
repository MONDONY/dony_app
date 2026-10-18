import 'package:dony/core/services/ai_consent_service.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/map_backed_box.dart';
import '../../helpers/mock_analytics_backend.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late Map<String, dynamic> stored;
  late _MockAnalytics analytics;
  late AiConsentService service;

  setUp(() {
    stored = {};
    final box = mapBackedBox(stored);
    final hive = MockHiveService();
    when(() => hive.userPrefs).thenReturn(box);
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    service = AiConsentService(hive, analytics);
  });

  test('pas d’accord tant que rien n’est enregistré', () {
    expect(service.granted, isFalse);
  });

  test('accepter mémorise l’accord et le trace', () async {
    await service.answer(granted: true, entry: AiConsentEntry.assistant);

    expect(stored[HiveService.kAiConsentGranted], isTrue);
    expect(service.granted, isTrue);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.aiConsentAnswered,
        properties: {'granted': true, 'entry': 'assistant'},
      ),
    ).called(1);
  });

  test('refuser ne mémorise rien : la question reviendra', () async {
    await service.answer(granted: false, entry: AiConsentEntry.formTrip);

    expect(stored.containsKey(HiveService.kAiConsentGranted), isFalse);
    expect(service.granted, isFalse);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.aiConsentAnswered,
        properties: {'granted': false, 'entry': 'form_trip'},
      ),
    ).called(1);
  });

  test('l’affichage est tracé avec son point d’entrée', () {
    service.markShown(AiConsentEntry.formPackageRequest);

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.aiConsentShown,
        properties: {'entry': 'form_package_request'},
      ),
    ).called(1);
  });
}
