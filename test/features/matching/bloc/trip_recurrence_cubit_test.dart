import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_recurrence_cubit.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  final today = DateTime(2026, 11, 25, 9);

  group('TripRecurrenceDates', () {
    test('chaque semaine : 4 dates après le départ', () {
      expect(
        TripRecurrenceDates.compute(
          DateTime(2026, 12, 12),
          TripRecurrenceFrequency.weekly,
          today: today,
        ),
        [
          DateTime(2026, 12, 19),
          DateTime(2026, 12, 26),
          DateTime(2027, 1, 2),
          DateTime(2027, 1, 9),
        ],
      );
    });

    test('toutes les 2 semaines : 3 dates, passage d\'année', () {
      expect(
        TripRecurrenceDates.compute(
          DateTime(2026, 12, 12),
          TripRecurrenceFrequency.biweekly,
          today: today,
        ),
        [DateTime(2026, 12, 26), DateTime(2027, 1, 9), DateTime(2027, 1, 23)],
      );
    });

    test('chaque mois : même jour, ramené au dernier jour d\'un mois court, '
        'sans dériver ensuite', () {
      expect(
        TripRecurrenceDates.compute(
          DateTime(2027, 1, 31),
          TripRecurrenceFrequency.monthly,
          today: today,
        ),
        [DateTime(2027, 2, 28), DateTime(2027, 3, 31), DateTime(2027, 4, 30)],
      );
    });

    test('29 février d\'une année bissextile', () {
      expect(
        TripRecurrenceDates.nth(
          DateTime(2028, 1, 29),
          TripRecurrenceFrequency.monthly,
          1,
        ),
        DateTime(2028, 2, 29),
      );
      expect(
        TripRecurrenceDates.nth(
          DateTime(2028, 2, 29),
          TripRecurrenceFrequency.monthly,
          12,
        ),
        DateTime(2029, 2, 28),
      );
      expect(
        TripRecurrenceDates.nth(
          DateTime(2028, 2, 22),
          TripRecurrenceFrequency.weekly,
          1,
        ),
        DateTime(2028, 2, 29),
      );
    });

    test('bornes : jamais au-delà de la fenêtre du calendrier', () {
      // Fenêtre : jusqu'à la fin de novembre 2027 (12 mois après le mois
      // courant).
      final dates = TripRecurrenceDates.compute(
        DateTime(2027, 10, 15),
        TripRecurrenceFrequency.monthly,
        today: today,
      );
      expect(dates, [DateTime(2027, 11, 15)]);
      expect(TripRecurrenceDates.limitFor(today), DateTime(2027, 12));
    });

    test('bornes : au plus le plafond du back', () {
      final dates = TripRecurrenceDates.compute(
        DateTime(2026, 12),
        TripRecurrenceFrequency.weekly,
        today: today,
        count: 40,
      );
      expect(dates, hasLength(TripSeriesCubit.maxDates));
    });

    test('nom technique lu et relu', () {
      for (final f in TripRecurrenceFrequency.values) {
        expect(TripRecurrenceFrequency.fromWire(f.wire), f);
      }
      expect(TripRecurrenceFrequency.fromWire('yearly'), isNull);
      expect(TripRecurrenceFrequency.fromWire(null), isNull);
    });
  });

  group('TripRecurrenceCubit', () {
    late _MockAnalytics analytics;

    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    });

    TripRecurrenceCubit build() =>
        TripRecurrenceCubit(analytics, now: () => today);

    test('éteinte par défaut, rien à publier en série', () {
      final cubit = build();
      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.frequency, TripRecurrenceFrequency.monthly);
      cubit.departureDateChanged(DateTime(2026, 12, 12, 14));
      expect(cubit.state.departureDate, DateTime(2026, 12, 12));
      expect(cubit.state.seriesDates, isEmpty);
      expect(cubit.state.totalTrips, 4);
    });

    test('allumer : dates calculées, analytics enabled', () {
      final cubit = build()..departureDateChanged(DateTime(2026, 12, 12));
      cubit.setEnabled(true);
      expect(cubit.state.seriesDates, hasLength(3));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripRecurrenceToggled,
          properties: {'enabled': true},
        ),
      ).called(1);
      // Même valeur : rien ne change, rien n'est mesuré.
      cubit.setEnabled(true);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.tripRecurrenceToggled,
          properties: {'enabled': false},
        ),
      );
    });

    test('allumée sans date de départ : aucune date', () {
      final cubit = build()..setEnabled(true);
      expect(cubit.state.seriesDates, isEmpty);
      expect(cubit.state.dates, isEmpty);
    });

    test('rythme choisi : dates recalculées, analytics frequency', () {
      final cubit = build()
        ..departureDateChanged(DateTime(2026, 12, 12))
        ..setEnabled(true)
        ..chooseFrequency(TripRecurrenceFrequency.weekly);
      expect(cubit.state.totalTrips, 5);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripRecurrenceFrequencyChosen,
          properties: {'frequency': 'weekly'},
        ),
      ).called(1);
      // Même rythme sans retouche : sans effet.
      cubit.chooseFrequency(TripRecurrenceFrequency.weekly);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.tripRecurrenceFrequencyChosen,
          properties: any(named: 'properties'),
        ),
      );
    });

    test('date de départ changée ou effacée : dates recalculées', () {
      final cubit = build()
        ..departureDateChanged(DateTime(2026, 12, 12))
        ..setEnabled(true);
      cubit.departureDateChanged(DateTime(2027, 1, 5));
      expect(cubit.state.dates.first, DateTime(2027, 2, 5));
      cubit.departureDateChanged(DateTime(2027, 1, 5, 18));
      expect(cubit.state.dates.first, DateTime(2027, 2, 5));
      cubit.departureDateChanged(null);
      expect(cubit.state.departureDate, isNull);
      expect(cubit.state.dates, isEmpty);
    });

    test('calendrier : retouche, plafond, jours non cochables, un seul '
        'événement par ouverture', () {
      final cubit = build()
        ..departureDateChanged(DateTime(2026, 12, 12))
        ..setEnabled(true)
        ..customDatesOpened();
      expect(cubit.state.visibleMonth, DateTime(2027));
      expect(cubit.sourceDay, DateTime(2026, 12, 12));

      cubit.toggleDate(DateTime(2026, 12, 20));
      expect(cubit.state.dates, contains(DateTime(2026, 12, 20)));
      expect(cubit.state.customized, isTrue);
      cubit.toggleDate(DateTime(2026, 12, 20));
      expect(cubit.state.dates, isNot(contains(DateTime(2026, 12, 20))));

      // Jour du premier trajet, jour passé, hors fenêtre : refusés.
      final before = cubit.state.dates;
      cubit
        ..toggleDate(DateTime(2026, 12, 12))
        ..toggleDate(DateTime(2026, 11))
        ..toggleDate(DateTime(2028));
      expect(cubit.state.dates, before);

      verify(
        () => analytics.logEvent(AnalyticsEvents.tripRecurrenceDatesCustomized),
      ).called(1);

      // Réouverture : une nouvelle retouche est mesurée.
      cubit
        ..customDatesOpened()
        ..toggleDate(DateTime(2026, 12, 21));
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripRecurrenceDatesCustomized),
      ).called(1);

      // Plafond du back.
      for (var i = 0; i < 20; i++) {
        cubit.toggleDate(DateTime(2027, 6, 1 + i));
      }
      expect(cubit.state.dates, hasLength(TripSeriesCubit.maxDates));

      // Un rythme rechoisi efface la retouche.
      cubit.chooseFrequency(TripRecurrenceFrequency.monthly);
      expect(cubit.state.customized, isFalse);
      expect(cubit.state.dates, hasLength(3));
    });

    test('navigation du calendrier bornée', () {
      final cubit = build()..customDatesOpened();
      expect(cubit.state.visibleMonth, DateTime(2026, 11));
      expect(cubit.canGoBack, isFalse);
      cubit.showMonth(-1);
      expect(cubit.state.visibleMonth, DateTime(2026, 11));
      for (var i = 0; i < 20; i++) {
        cubit.showMonth(1);
      }
      expect(cubit.state.visibleMonth, DateTime(2027, 11));
      expect(cubit.canGoForward, isFalse);
      cubit.showMonth(-1);
      expect(cubit.state.visibleMonth, DateTime(2027, 10));
    });

    test('ouverture : mois de la première date, sinon du départ', () {
      final cubit = build()
        ..departureDateChanged(DateTime(2026, 12, 12))
        ..customDatesOpened();
      expect(cubit.state.visibleMonth, DateTime(2027));
      // Toutes les dates retirées : le mois du départ.
      for (final d in [...cubit.state.dates]) {
        cubit.toggleDate(d);
      }
      cubit.customDatesOpened();
      expect(cubit.state.visibleMonth, DateTime(2026, 12));
    });

    test('brouillon rechargé : aucun événement', () {
      final cubit = build()
        ..departureDateChanged(DateTime(2026, 12, 12))
        ..restore(enabled: true, frequency: TripRecurrenceFrequency.biweekly);
      expect(cubit.state.enabled, isTrue);
      expect(cubit.state.frequency, TripRecurrenceFrequency.biweekly);
      expect(cubit.state.dates, hasLength(3));
      cubit.restore(enabled: false);
      expect(cubit.state.frequency, TripRecurrenceFrequency.biweekly);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });
}
