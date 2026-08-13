import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

void main() {
  late MockAnalyticsBackend backend;
  late MockAnalyticsConsentRemote remote;
  late MockHiveService hive;
  late MockBox box;
  late AnalyticsService service;

  // Valeur de consentement « stockée » en mémoire, pilotée par les tests.
  Object? storedConsent;

  setUp(() {
    backend = MockAnalyticsBackend();
    remote = MockAnalyticsConsentRemote();
    hive = MockHiveService();
    box = MockBox();
    storedConsent = null;

    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(HiveService.kAnalyticsConsent),
    ).thenAnswer((_) => storedConsent);
    when(() => box.put(HiveService.kAnalyticsConsent, any())).thenAnswer((
      invocation,
    ) async {
      storedConsent = invocation.positionalArguments[1];
    });

    when(() => backend.optIn()).thenAnswer((_) async {});
    when(() => backend.optOut()).thenAnswer((_) async {});
    when(() => backend.reset()).thenAnswer((_) async {});
    when(() => backend.capture(any(), any())).thenAnswer((_) async {});
    when(() => backend.screen(any(), any())).thenAnswer((_) async {});
    when(() => backend.identify(any(), any())).thenAnswer((_) async {});

    when(() => remote.fetch()).thenAnswer((_) async => null);
    when(
      () => remote.push(
        granted: any(named: 'granted'),
        policyVersion: any(named: 'policyVersion'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});

    service = AnalyticsService(hive, backend: backend, remote: remote);
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

    test(
      'pushes the decision to the remote with default source manual',
      () async {
        await service.setConsent(granted: true);
        verify(
          () => remote.push(
            granted: true,
            policyVersion: kAnalyticsPolicyVersion,
            source: 'manual',
          ),
        ).called(1);
      },
    );

    test('forwards a custom source to the remote', () async {
      await service.setConsent(granted: false, source: 'settings');
      verify(
        () => remote.push(
          granted: false,
          policyVersion: kAnalyticsPolicyVersion,
          source: 'settings',
        ),
      ).called(1);
    });

    test('a failing remote push never blocks/breaks setConsent', () async {
      // Cas réaliste : push() async dont la Future est rejetée (erreur réseau).
      // `unawaited` → l'échec ne doit pas faire échouer setConsent ni bloquer
      // l'écriture Hive / l'application du consentement.
      when(
        () => remote.push(
          granted: any(named: 'granted'),
          policyVersion: any(named: 'policyVersion'),
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async => throw Exception('network down'));
      await service.setConsent(granted: true);
      expect(storedConsent, isTrue);
      verify(() => box.put(HiveService.kAnalyticsConsent, true)).called(1);
    });
  });

  group('syncFromBackend — backend has an answer (wins over local)', () {
    test(
      'aligns local Hive when backend differs (revoked elsewhere)',
      () async {
        storedConsent = true;
        when(() => remote.fetch()).thenAnswer((_) async => false);

        await service.syncFromBackend();

        expect(storedConsent, isFalse);
        verify(() => box.put(HiveService.kAnalyticsConsent, false)).called(1);
      },
    );

    test('does not rewrite Hive when backend matches local', () async {
      storedConsent = true;
      when(() => remote.fetch()).thenAnswer((_) async => true);

      await service.syncFromBackend();

      verifyNever(() => box.put(HiveService.kAnalyticsConsent, any()));
    });

    test('applies the backend value to PostHog when configured', () async {
      storedConsent = false;
      await service.onConfigured(); // optOut
      clearInteractions(backend);
      when(() => remote.fetch()).thenAnswer((_) async => true);

      await service.syncFromBackend();

      expect(storedConsent, isTrue);
      verify(() => backend.optIn()).called(1);
    });

    test(
      'opts out locally when backend granted=false and configured',
      () async {
        storedConsent = true;
        await service.onConfigured(); // optIn
        clearInteractions(backend);
        when(() => remote.fetch()).thenAnswer((_) async => false);

        await service.syncFromBackend();

        verify(() => backend.optOut()).called(1);
      },
    );

    test('does not touch PostHog when not configured', () async {
      when(() => remote.fetch()).thenAnswer((_) async => true);

      await service.syncFromBackend();

      verifyNever(() => backend.optIn());
      verifyNever(() => backend.optOut());
    });

    test('never pushes back when backend already has an answer', () async {
      storedConsent = false;
      when(() => remote.fetch()).thenAnswer((_) async => true);

      await service.syncFromBackend();

      verifyNever(
        () => remote.push(
          granted: any(named: 'granted'),
          policyVersion: any(named: 'policyVersion'),
          source: any(named: 'source'),
        ),
      );
    });
  });

  group('syncFromBackend — backend has no answer (null)', () {
    test(
      'pushes local answer up with source=sync when user has answered',
      () async {
        storedConsent = true;
        when(() => remote.fetch()).thenAnswer((_) async => null);

        await service.syncFromBackend();

        verify(
          () => remote.push(
            granted: true,
            policyVersion: kAnalyticsPolicyVersion,
            source: 'sync',
          ),
        ).called(1);
        // Hive inchangé : pas de réponse backend à appliquer.
        verifyNever(() => box.put(HiveService.kAnalyticsConsent, any()));
      },
    );

    test('pushes a local refusal up too', () async {
      storedConsent = false;
      when(() => remote.fetch()).thenAnswer((_) async => null);

      await service.syncFromBackend();

      verify(
        () => remote.push(
          granted: false,
          policyVersion: kAnalyticsPolicyVersion,
          source: 'sync',
        ),
      ).called(1);
    });

    test('does nothing when neither backend nor local has an answer', () async {
      storedConsent = null;
      when(() => remote.fetch()).thenAnswer((_) async => null);

      await service.syncFromBackend();

      verifyNever(
        () => remote.push(
          granted: any(named: 'granted'),
          policyVersion: any(named: 'policyVersion'),
          source: any(named: 'source'),
        ),
      );
      verifyNever(() => box.put(HiveService.kAnalyticsConsent, any()));
    });
  });

  group('syncFromBackend — network error tolerance', () {
    test('keeps local state when fetch throws', () async {
      storedConsent = true;
      when(() => remote.fetch()).thenThrow(Exception('offline'));

      await service.syncFromBackend(); // ne doit pas lever

      expect(storedConsent, isTrue);
      verifyNever(() => box.put(HiveService.kAnalyticsConsent, any()));
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
