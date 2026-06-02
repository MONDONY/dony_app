import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

void main() {
  late MockAnalyticsBackend backend;
  late MockHiveService hive;
  late MockBox box;
  late AnalyticsService service;

  // Valeur de consentement « stockée » en mémoire, pilotée par les tests.
  Object? storedConsent;

  setUp(() {
    backend = MockAnalyticsBackend();
    hive = MockHiveService();
    box = MockBox();
    storedConsent = null;

    when(() => hive.userPrefs).thenReturn(box);
    when(() => box.get(HiveService.kAnalyticsConsent))
        .thenAnswer((_) => storedConsent);
    when(() => box.put(HiveService.kAnalyticsConsent, any()))
        .thenAnswer((invocation) async {
      storedConsent = invocation.positionalArguments[1];
    });

    when(() => backend.optIn()).thenAnswer((_) async {});
    when(() => backend.optOut()).thenAnswer((_) async {});
    when(() => backend.reset()).thenAnswer((_) async {});
    when(() => backend.capture(any(), any())).thenAnswer((_) async {});
    when(() => backend.screen(any(), any())).thenAnswer((_) async {});
    when(() => backend.identify(any(), any())).thenAnswer((_) async {});

    service = AnalyticsService(hive, backend: backend);
  });

  group('consent reading', () {
    test('consent is null and hasAnswered=false when nothing stored', () {
      expect(service.consent, isNull);
      expect(service.hasAnswered, isFalse);
    });

    test('consent reflects stored true/false', () {
      storedConsent = true;
      expect(service.consent, isTrue);
      expect(service.hasAnswered, isTrue);

      storedConsent = false;
      expect(service.consent, isFalse);
      expect(service.hasAnswered, isTrue);
    });

    test('non-bool stored value is treated as not answered', () {
      storedConsent = 'garbage';
      expect(service.consent, isNull);
      expect(service.hasAnswered, isFalse);
    });
  });

  group('isEnabled gating', () {
    test('is false before onConfigured even with consent granted', () {
      storedConsent = true;
      expect(service.isConfigured, isFalse);
      expect(service.isEnabled, isFalse);
    });

    test('is true only when configured AND consent granted', () async {
      storedConsent = true;
      await service.onConfigured();
      expect(service.isConfigured, isTrue);
      expect(service.isEnabled, isTrue);
    });

    test('is false when configured but consent refused', () async {
      storedConsent = false;
      await service.onConfigured();
      expect(service.isEnabled, isFalse);
    });
  });

  group('onConfigured applies stored consent to backend', () {
    test('opts in when consent granted', () async {
      storedConsent = true;
      await service.onConfigured();
      verify(() => backend.optIn()).called(1);
      verifyNever(() => backend.optOut());
    });

    test('opts out when consent absent', () async {
      await service.onConfigured();
      verify(() => backend.optOut()).called(1);
      verifyNever(() => backend.optIn());
    });
  });

  group('setConsent', () {
    test('stores the value', () async {
      await service.setConsent(granted: true);
      expect(storedConsent, isTrue);
      verify(() => box.put(HiveService.kAnalyticsConsent, true)).called(1);
    });

    test('does not touch backend when not configured', () async {
      await service.setConsent(granted: true);
      verifyNever(() => backend.optIn());
      verifyNever(() => backend.optOut());
    });

    test('opts in on grant once configured', () async {
      await service.onConfigured(); // optOut (no consent yet)
      clearInteractions(backend);
      await service.setConsent(granted: true);
      verify(() => backend.optIn()).called(1);
    });

    test('opts out on refusal once configured', () async {
      storedConsent = true;
      await service.onConfigured(); // optIn
      clearInteractions(backend);
      await service.setConsent(granted: false);
      verify(() => backend.optOut()).called(1);
    });
  });

  group('event APIs are no-ops until enabled', () {
    test('logEvent does nothing when not enabled', () async {
      await service.logEvent('bid_accepted', properties: {'k': 'v'});
      verifyNever(() => backend.capture(any(), any()));
    });

    test('logScreen does nothing when not enabled', () async {
      await service.logScreen('Home');
      verifyNever(() => backend.screen(any(), any()));
    });

    test('identify does nothing when not enabled', () async {
      await service.identify('user-1');
      verifyNever(() => backend.identify(any(), any()));
    });
  });

  group('event APIs forward to backend once enabled', () {
    setUp(() async {
      storedConsent = true;
      await service.onConfigured();
      clearInteractions(backend);
    });

    test('logEvent forwards name + properties', () async {
      await service.logEvent('bid_accepted', properties: {'k': 'v'});
      verify(() => backend.capture('bid_accepted', {'k': 'v'})).called(1);
    });

    test('logScreen forwards screen name', () async {
      await service.logScreen('Home');
      verify(() => backend.screen('Home', null)).called(1);
    });

    test('identify forwards user id', () async {
      await service.identify('user-1');
      verify(() => backend.identify('user-1', null)).called(1);
    });
  });

  group('reset', () {
    test('is a no-op when not configured', () async {
      await service.reset();
      verifyNever(() => backend.reset());
    });

    test('forwards to backend when configured', () async {
      await service.onConfigured();
      clearInteractions(backend);
      await service.reset();
      verify(() => backend.reset()).called(1);
    });
  });
}
