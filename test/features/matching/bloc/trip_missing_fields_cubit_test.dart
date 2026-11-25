import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_missing_fields_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalytics analytics;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  const both = [TripRequiredField.departureCity, TripRequiredField.arrivalCity];

  test('état initial : rien de marqué', () {
    final state = TripMissingFieldsCubit(analytics).state;
    expect(state.attempted, isFalse);
    expect(state.missing, isEmpty);
    expect(state.showSummaryAt(0), isFalse);
    expect(state.isMarked(TripRequiredField.departureCity), isFalse);
  });

  blocTest<TripMissingFieldsCubit, TripMissingFieldsState>(
    'sync seul ne marque rien',
    build: () => TripMissingFieldsCubit(analytics),
    act: (c) => c.sync(0, both),
    expect: () => [const TripMissingFieldsState(missing: both)],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<TripMissingFieldsCubit, TripMissingFieldsState>(
    'rien ne manque : on avance, sans marque ni événement',
    build: () => TripMissingFieldsCubit(analytics),
    act: (c) => expect(c.tryContinue(1, const []), isTrue),
    expect: () => [const TripMissingFieldsState(step: 1)],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<TripMissingFieldsCubit, TripMissingFieldsState>(
    'champs vides : refus, marques, premier champ visé, événement sans valeur',
    build: () => TripMissingFieldsCubit(analytics),
    act: (c) => expect(c.tryContinue(0, both), isFalse),
    expect: () => [
      const TripMissingFieldsState(missing: both),
      const TripMissingFieldsState(
        missing: both,
        attempted: true,
        focusField: TripRequiredField.departureCity,
        focusSeq: 1,
      ),
    ],
    verify: (c) {
      expect(c.state.isMarked(TripRequiredField.arrivalCity), isTrue);
      expect(c.state.isMarked(TripRequiredField.departureDate), isFalse);
      expect(c.state.showSummaryAt(0), isTrue);
      expect(c.state.showSummaryAt(1), isFalse);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripStepBlockedMissingFields,
          properties: {
            'step': 0,
            'count': 2,
            'fields': ['departureCity', 'arrivalCity'],
          },
        ),
      ).called(1);
    },
  );

  test('remplir un champ retire sa marque et fait baisser le compteur ; '
      'tout remplir efface le résumé', () {
    final c = TripMissingFieldsCubit(analytics)..tryContinue(0, both);
    c.sync(0, const [TripRequiredField.arrivalCity]);
    expect(c.state.attempted, isTrue);
    expect(c.state.missing, [TripRequiredField.arrivalCity]);
    expect(c.state.isMarked(TripRequiredField.departureCity), isFalse);
    c.sync(0, const []);
    expect(c.state.showSummaryAt(0), isFalse);
  });

  test('changer d\'étape efface la tentative', () {
    final c = TripMissingFieldsCubit(analytics)..tryContinue(0, both);
    c.sync(1, const [TripRequiredField.pickupAddress]);
    expect(c.state.step, 1);
    expect(c.state.attempted, isFalse);
    expect(c.state.isMarked(TripRequiredField.pickupAddress), isFalse);
  });

  test(
    'pastille : défilement renouvelé et événement avec le nom technique',
    () {
      final c = TripMissingFieldsCubit(analytics)
        ..chipTapped(TripRequiredField.handoverDeadline)
        ..chipTapped(TripRequiredField.handoverDeadline);
      expect(c.state.focusField, TripRequiredField.handoverDeadline);
      expect(c.state.focusSeq, 2);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripMissingFieldChipTapped,
          properties: {'field': 'handoverDeadline'},
        ),
      ).called(2);
    },
  );
}
