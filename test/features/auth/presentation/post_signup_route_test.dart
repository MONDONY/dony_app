import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/presentation/post_signup_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

/// Couvre `resolvePostSignupRoute` — la décision de routing après création de
/// PIN selon le consentement analytics. Le cas critique : un utilisateur
/// réinstallé (Hive local vide) qui a déjà consenti côté backend ne doit PAS
/// être redemandé.
void main() {
  late MockAnalyticsBackend backend;
  late MockAnalyticsConsentRemote remote;
  late MockHiveService hive;
  late MockBox box;
  late AnalyticsService service;

  // État Hive piloté par chaque test.
  Object? storedConsent;
  String? detectedCountry;
  bool currencyOnboardingSeen = false;

  setUp(() {
    backend = MockAnalyticsBackend();
    remote = MockAnalyticsConsentRemote();
    hive = MockHiveService();
    box = MockBox();
    storedConsent = null;
    detectedCountry = null;
    currencyOnboardingSeen = false;

    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(HiveService.kAnalyticsConsent),
    ).thenAnswer((_) => storedConsent);
    when(
      () => box.get(HiveService.kDetectedCountryCode),
    ).thenAnswer((_) => detectedCountry);
    when(
      () => box.get(HiveService.kCurrencyOnboardingSeen, defaultValue: false),
    ).thenAnswer((_) => currencyOnboardingSeen);
    when(() => box.put(HiveService.kAnalyticsConsent, any())).thenAnswer((
      invocation,
    ) async {
      storedConsent = invocation.positionalArguments[1];
    });

    when(() => backend.optIn()).thenAnswer((_) async {});
    when(() => backend.optOut()).thenAnswer((_) async {});

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

  group('resolvePostSignupRoute — réinstall (Hive vide, backend renseigné)', () {
    test(
      'backend granted=true → /auth/currency-selection, PAS de re-prompt (régression corrigée)',
      () async {
        // Réinstall dans un pays RGPD : sans le sync backend, hasAnswered serait
        // faux → l'utilisateur verrait à tort /auth/analytics-consent.
        storedConsent = null;
        detectedCountry = 'FR';
        when(() => remote.fetch()).thenAnswer((_) async => true);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(service, box);

        expect(route, '/auth/currency-selection');
        verify(() => remote.fetch()).called(1);
      },
    );

    test(
      'backend granted=false → /auth/currency-selection (révocation respectée, pas de re-prompt)',
      () async {
        storedConsent = null;
        detectedCountry = 'FR';
        when(() => remote.fetch()).thenAnswer((_) async => false);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(service, box);

        expect(route, '/auth/currency-selection');
        verify(() => remote.fetch()).called(1);
      },
    );
  });

  group('resolvePostSignupRoute — jamais répondu (backend null)', () {
    test(
      'pays RGPD (FR) → /auth/analytics-consent, aucun consentement poussé',
      () async {
        storedConsent = null;
        detectedCountry = 'FR';
        when(() => remote.fetch()).thenAnswer((_) async => null);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(service, box);

        expect(route, '/auth/analytics-consent');
        verifyNever(
          () => remote.push(
            granted: any(named: 'granted'),
            policyVersion: any(named: 'policyVersion'),
            source: any(named: 'source'),
          ),
        );
      },
    );

    test(
      'pays hors RGPD (SN) → /auth/analytics-consent aussi (affiché partout au 1er lancement)',
      () async {
        storedConsent = null;
        detectedCountry = 'SN';
        when(() => remote.fetch()).thenAnswer((_) async => null);
        await service.onConfigured();

        final route = await resolvePostSignupRoute(service, box);

        // L'écran de consentement est désormais présenté à tout nouvel
        // utilisateur, quel que soit le pays. Aucun consentement auto poussé :
        // c'est l'écran qui recueillera le choix explicite.
        expect(route, '/auth/analytics-consent');
        verifyNever(
          () => remote.push(
            granted: any(named: 'granted'),
            policyVersion: any(named: 'policyVersion'),
            source: any(named: 'source'),
          ),
        );
      },
    );
  });

  group('resolvePostSignupRoute — pas de sync inutile', () {
    test(
      'non configuré (analytics off) → /auth/currency-selection sans appel backend',
      () async {
        // onConfigured non appelé → isConfigured=false.
        final route = await resolvePostSignupRoute(service, box);

        expect(route, '/auth/currency-selection');
        verifyNever(() => remote.fetch());
      },
    );

    test('devise déjà vue → /auth/referral-code sans re-sync', () async {
      storedConsent = true;
      detectedCountry = 'FR';
      currencyOnboardingSeen = true;
      await service.onConfigured();

      final route = await resolvePostSignupRoute(service, box);

      expect(route, '/auth/referral-code');
      verifyNever(() => remote.fetch());
    });

    test(
      'devise non vue → /auth/currency-selection après consentement local',
      () async {
        storedConsent = true;
        await service.onConfigured();

        final route = await resolvePostSignupRoute(service, box);

        expect(route, '/auth/currency-selection');
      },
    );
  });
}
