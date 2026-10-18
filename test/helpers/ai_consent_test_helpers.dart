import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/ai_consent_service.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'map_backed_box.dart';
import 'mock_analytics_backend.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

/// Enregistre un [AiConsentService] adossé à une box en mémoire le temps du
/// test. [granted] : accord IA déjà donné (la feuille ne s'ouvre pas).
/// Rend la box pour vérifier ce qui a été écrit.
Map<String, dynamic> useAiConsent({bool granted = true}) {
  final stored = <String, dynamic>{
    if (granted) HiveService.kAiConsentGranted: true,
  };
  final box = mapBackedBox(stored);
  final hive = MockHiveService();
  when(() => hive.userPrefs).thenReturn(box);
  final analytics = _MockAnalytics();
  when(
    () => analytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  if (getIt.isRegistered<AiConsentService>()) {
    getIt.unregister<AiConsentService>();
  }
  getIt.registerSingleton<AiConsentService>(AiConsentService(hive, analytics));
  addTearDown(() {
    if (getIt.isRegistered<AiConsentService>()) {
      getIt.unregister<AiConsentService>();
    }
  });
  return stored;
}
