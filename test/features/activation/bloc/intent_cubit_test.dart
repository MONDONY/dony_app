import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/data/activation_repository.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ActivationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(UserIntent.sender);
    registerFallbackValue(IntentSource.signup);
  });

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void stubDeclare() => when(
    () => repo.declareIntent(
      intent: any(named: 'intent'),
      destinationCountry: any(named: 'destinationCountry'),
      source: any(named: 'source'),
    ),
  ).thenAnswer((_) async {});

  test('isValid est vrai avec une intention et sans destination', () {
    final c = IntentCubit(repo, analytics);
    expect(c.state.isValid, isFalse);
    c.selectIntent(UserIntent.sender);
    expect(c.state.isValid, isTrue);
    expect(c.state.destinationForApi, isNull);
    c.selectDestination('CI');
    expect(c.state.isValid, isTrue);
  });

  blocTest<IntentCubit, IntentFormState>(
    'submit envoie destinationCountry null quand aucune destination n\'est choisie',
    build: () {
      stubDeclare();
      return IntentCubit(repo, analytics, initialIntent: UserIntent.sender);
    },
    act: (c) => c.submit(IntentSource.signup),
    verify: (c) {
      expect(c.state.status, IntentFormStatus.saved);
      verify(
        () => repo.declareIntent(
          intent: UserIntent.sender,
          destinationCountry: null,
          source: IntentSource.signup,
        ),
      ).called(1);
    },
  );

  test('« Autre » envoie une destination nulle', () {
    final c = IntentCubit(repo, analytics)
      ..selectIntent(UserIntent.traveler)
      ..selectDestination(kIntentOtherDestination);
    expect(c.state.isValid, isTrue);
    expect(c.state.destinationForApi, isNull);
  });

  test('FLUTTER-H9 : un pays choisi derrière « Autre » part en ISO2', () {
    final c = IntentCubit(repo, analytics)
      ..selectIntent(UserIntent.sender)
      ..selectDestination('FR');
    expect(c.state.isValid, isTrue);
    expect(c.state.destinationForApi, 'FR');
  });

  blocTest<IntentCubit, IntentFormState>(
    'submit enregistre et trace',
    build: () {
      stubDeclare();
      return IntentCubit(
        repo,
        analytics,
        initialIntent: UserIntent.sender,
        initialDestination: 'SN',
      );
    },
    act: (c) => c.submit(IntentSource.signup),
    expect: () => [
      const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
        status: IntentFormStatus.saving,
      ),
      const IntentFormState(
        intent: UserIntent.sender,
        destination: 'SN',
        status: IntentFormStatus.saved,
      ),
    ],
    verify: (_) {
      verify(
        () => repo.declareIntent(
          intent: UserIntent.sender,
          destinationCountry: 'SN',
          source: IntentSource.signup,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.intentDeclared,
          properties: {
            'intent': 'SENDER',
            'destination_country': 'SN',
            'source': 'SIGNUP',
          },
        ),
      ).called(1);
    },
  );

  blocTest<IntentCubit, IntentFormState>(
    'sans destination, la propriété destination_country est omise',
    build: () {
      stubDeclare();
      return IntentCubit(repo, analytics, initialIntent: UserIntent.sender);
    },
    act: (c) => c.submit(IntentSource.signup),
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.intentDeclared,
          properties: {'intent': 'SENDER', 'source': 'SIGNUP'},
        ),
      ).called(1);
    },
  );

  blocTest<IntentCubit, IntentFormState>(
    '« Autre » trace OTHER',
    build: () {
      stubDeclare();
      return IntentCubit(
        repo,
        analytics,
        initialIntent: UserIntent.traveler,
        initialDestination: kIntentOtherDestination,
      );
    },
    act: (c) => c.submit(IntentSource.prompt),
    verify: (_) {
      verify(
        () => repo.declareIntent(
          intent: UserIntent.traveler,
          destinationCountry: null,
          source: IntentSource.prompt,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.intentDeclared,
          properties: {
            'intent': 'TRAVELER',
            'destination_country': 'OTHER',
            'source': 'PROMPT',
          },
        ),
      ).called(1);
    },
  );

  blocTest<IntentCubit, IntentFormState>(
    'erreur réseau : état error',
    build: () {
      when(
        () => repo.declareIntent(
          intent: any(named: 'intent'),
          destinationCountry: any(named: 'destinationCountry'),
          source: any(named: 'source'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions()));
      return IntentCubit(
        repo,
        analytics,
        initialIntent: UserIntent.both,
        initialDestination: 'ML',
      );
    },
    act: (c) => c.submit(IntentSource.prompt),
    expect: () => [
      const IntentFormState(
        intent: UserIntent.both,
        destination: 'ML',
        status: IntentFormStatus.saving,
      ),
      const IntentFormState(
        intent: UserIntent.both,
        destination: 'ML',
        status: IntentFormStatus.error,
      ),
    ],
  );

  blocTest<IntentCubit, IntentFormState>(
    'submit reste inactif sans intention',
    build: () => IntentCubit(repo, analytics),
    act: (c) => c.submit(IntentSource.signup),
    expect: () => <IntentFormState>[],
  );
}
