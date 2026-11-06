import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/features/auth/bloc/analytics_consent_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

/// `AnalyticsConsentCubit` : décide si l'écran « Une dernière chose » doit
/// s'afficher après le code, puis enregistre la réponse.
void main() {
  late _MockAnalytics analytics;
  late ConsentPrompt prompt;
  var requiresConsent = true;

  AnalyticsConsentCubit build() => AnalyticsConsentCubit(
    analytics,
    prompt,
    requiresConsent: () => requiresConsent,
  );

  setUp(() {
    analytics = _MockAnalytics();
    prompt = ConsentPrompt();
    requiresConsent = true;
    when(() => analytics.syncFromBackend()).thenAnswer((_) async {});
    when(() => analytics.isConfigured).thenReturn(true);
    when(() => analytics.hasAnswered).thenReturn(false);
    when(
      () => analytics.setConsent(granted: any(named: 'granted')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('resolve', () {
    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      'zone RGPD sans réponse : la question est posée',
      build: build,
      act: (c) => c.resolve(),
      expect: () => [const AnalyticsConsentAsk()],
      verify: (_) => verify(() => analytics.syncFromBackend()).called(1),
    );

    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      'déjà répondu (réinstallation, second appareil) : rien à demander',
      build: () {
        when(() => analytics.hasAnswered).thenReturn(true);
        return build();
      },
      act: (c) => c.resolve(),
      expect: () => [const AnalyticsConsentDone()],
    );

    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      'hors zone RGPD : l\'écran passe son chemin (le garde accorde)',
      build: () {
        requiresConsent = false;
        return build();
      },
      act: (c) => c.resolve(),
      expect: () => [const AnalyticsConsentDone()],
    );

    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      'mesure non configurée : rien à demander',
      build: () {
        when(() => analytics.isConfigured).thenReturn(false);
        return build();
      },
      act: (c) => c.resolve(),
      expect: () => [const AnalyticsConsentDone()],
    );

    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      'serveur injoignable : la décision continue sur le consentement local',
      build: () {
        when(() => analytics.syncFromBackend()).thenThrow(Exception('offline'));
        return build();
      },
      act: (c) => c.resolve(),
      expect: () => [const AnalyticsConsentAsk()],
    );
  });

  group('answer', () {
    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      '« Accepter » : consentement accordé, événement émis, demande levée '
      'retirée',
      build: () {
        prompt.request();
        return build();
      },
      act: (c) => c.answer(granted: true),
      expect: () => [const AnalyticsConsentDone()],
      verify: (_) {
        verify(() => analytics.setConsent(granted: true)).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.analyticsConsentAnswered,
            properties: {'granted': true, 'surface': 'signup_screen'},
          ),
        ).called(1);
        expect(prompt.wanted.value, isFalse);
      },
    );

    blocTest<AnalyticsConsentCubit, AnalyticsConsentState>(
      '« Non merci » : consentement refusé, rien n\'est mesuré',
      build: build,
      act: (c) => c.answer(granted: false),
      expect: () => [const AnalyticsConsentDone()],
      verify: (_) {
        verify(() => analytics.setConsent(granted: false)).called(1);
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.analyticsConsentAnswered,
            properties: {'granted': false, 'surface': 'signup_screen'},
          ),
        ).called(1);
      },
    );

    test('écriture locale en échec : l\'inscription continue et la demande est '
        'retirée', () async {
      when(
        () => analytics.setConsent(granted: any(named: 'granted')),
      ).thenThrow(StateError('disque plein'));
      prompt.request();
      final cubit = build();
      final states = <AnalyticsConsentState>[];
      final sub = cubit.stream.listen(states.add);

      await expectLater(cubit.answer(granted: true), throwsStateError);
      await Future<void>.delayed(Duration.zero);

      expect(states, [const AnalyticsConsentDone()]);
      expect(prompt.wanted.value, isFalse);
      await sub.cancel();
      await cubit.close();
    });
  });
}
