import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_signup_cubit.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements GpProRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(GpProFrequency.weekly);
    registerFallbackValue(GpProSource.signup);
  });

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => repo.apply(
        frequency: any(named: 'frequency'),
        commercialName: any(named: 'commercialName'),
        documentIds: any(named: 'documentIds'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => const GpProStatus(state: GpProState.pending));
  });

  GpProSignupCubit build() => GpProSignupCubit(repo, analytics);

  void verifyNoApply() => verifyNever(
    () => repo.apply(
      frequency: any(named: 'frequency'),
      commercialName: any(named: 'commercialName'),
      documentIds: any(named: 'documentIds'),
      source: any(named: 'source'),
    ),
  );

  group('état', () {
    test('isComplete : vrai décochée, faux cochée sans fréquence', () {
      expect(const GpProSignupState().isComplete, isTrue);
      expect(const GpProSignupState(checked: true).isComplete, isFalse);
      expect(
        const GpProSignupState(
          checked: true,
          frequency: GpProFrequency.monthly,
        ).isComplete,
        isTrue,
      );
    });

    blocTest<GpProSignupCubit, GpProSignupState>(
      'toggle, fréquence et nom alimentent l\'état',
      build: build,
      act: (c) => c
        ..toggle(true)
        ..selectFrequency(GpProFrequency.weekly)
        ..setCommercialName('Awa'),
      expect: () => const [
        GpProSignupState(checked: true),
        GpProSignupState(checked: true, frequency: GpProFrequency.weekly),
        GpProSignupState(
          checked: true,
          frequency: GpProFrequency.weekly,
          commercialName: 'Awa',
        ),
      ],
    );
  });

  group('submitIfChecked', () {
    test('ne fait rien si la case n\'est pas cochée', () async {
      final c = build()..selectFrequency(GpProFrequency.weekly);
      await c.submitIfChecked(UserIntent.traveler);
      verifyNoApply();
    });

    test('ne fait rien pour l\'intention expéditeur', () async {
      final c = build()
        ..toggle(true)
        ..selectFrequency(GpProFrequency.weekly);
      await c.submitIfChecked(UserIntent.sender);
      verifyNoApply();
    });

    test('ne fait rien sans intention', () async {
      final c = build()
        ..toggle(true)
        ..selectFrequency(GpProFrequency.weekly);
      await c.submitIfChecked(null);
      verifyNoApply();
    });

    test('ne fait rien sans fréquence', () async {
      final c = build()..toggle(true);
      await c.submitIfChecked(UserIntent.both);
      verifyNoApply();
    });

    test('envoie avec la source SIGNUP et le nom trimé, puis trace', () async {
      final c = build()
        ..toggle(true)
        ..selectFrequency(GpProFrequency.twiceAMonth)
        ..setCommercialName('  Awa Express  ');
      await c.submitIfChecked(UserIntent.traveler);
      verify(
        () => repo.apply(
          frequency: GpProFrequency.twiceAMonth,
          commercialName: 'Awa Express',
          source: GpProSource.signup,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: {
            'source': 'signup',
            'frequency': 'TWICE_A_MONTH',
            'document_count': 0,
            'has_commercial_name': true,
          },
        ),
      ).called(1);
      expect(c.state.submitting, isFalse);
    });

    test('nom vide : envoyé nul, has_commercial_name faux', () async {
      final c = build()
        ..toggle(true)
        ..selectFrequency(GpProFrequency.monthly)
        ..setCommercialName('   ');
      await c.submitIfChecked(UserIntent.both);
      verify(
        () => repo.apply(
          frequency: GpProFrequency.monthly,
          source: GpProSource.signup,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: any(
            named: 'properties',
            that: containsPair('has_commercial_name', false),
          ),
        ),
      ).called(1);
    });

    test('une exception du repository est avalée, sans event', () async {
      when(
        () => repo.apply(
          frequency: any(named: 'frequency'),
          commercialName: any(named: 'commercialName'),
          documentIds: any(named: 'documentIds'),
          source: any(named: 'source'),
        ),
      ).thenThrow(Exception('boom'));
      final c = build()
        ..toggle(true)
        ..selectFrequency(GpProFrequency.weekly);
      await c.submitIfChecked(UserIntent.traveler);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: any(named: 'properties'),
        ),
      );
      expect(c.state.submitting, isFalse);
    });
  });
}
