import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRecurrenceRepository extends Mock
    implements TripRecurrenceRepository {}

TripRecurrence _rec({String id = 'r1', String weekdays = '0000100'}) =>
    TripRecurrence(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      transportMode: 'PLANE',
      capacityUnit: 'SUITCASE_23KG',
      availableKg: 23,
      pricePerKg: 8,
      acceptedCategories: const ['Vêtements'],
      pickupAddress: const RecurrenceAddress(
        label: '12 rue',
        lat: 48.86,
        lng: 2.33,
      ),
      deliveryAddress: const RecurrenceAddress(
        label: 'CDG',
        lat: 49.01,
        lng: 2.55,
      ),
      departureTime: '14:00',
      weekdays: weekdays,
      horizonDays: 14,
      active: true,
    );

void main() {
  late MockTripRecurrenceRepository repo;
  setUp(() => repo = MockTripRecurrenceRepository());

  test('parses departureTime "HH:mm:ss" to "HH:mm"', () {
    final r = TripRecurrence.fromJson({
      'id': 'r1',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'transportMode': 'PLANE',
      'capacityUnit': 'SUITCASE_23KG',
      'availableKg': 23,
      'pricePerKg': 8,
      'acceptedCategories': ['Vêtements'],
      'pickupAddress': {'label': '12 rue', 'lat': 48.86, 'lng': 2.33},
      'deliveryAddress': {'label': 'CDG', 'lat': 49.01, 'lng': 2.55},
      'departureTime': '14:00:00',
      'weekdays': '0000100',
      'horizonDays': 14,
      'active': true,
    });
    expect(r.departureTime, '14:00');
    expect(r.weekdays, '0000100');
  });

  blocTest<TripRecurrenceBloc, TripRecurrenceState>(
    'TripRecurrenceLoaded emits loading then success',
    setUp: () => when(() => repo.getAll()).thenAnswer((_) async => [_rec()]),
    build: () => TripRecurrenceBloc(repo),
    act: (b) => b.add(const TripRecurrenceLoaded()),
    expect: () => [
      isA<TripRecurrenceState>().having(
        (s) => s.status,
        'status',
        TripRecurrenceStatus.loading,
      ),
      isA<TripRecurrenceState>()
          .having((s) => s.status, 'status', TripRecurrenceStatus.success)
          .having((s) => s.recurrences.length, 'count', 1),
    ],
  );

  blocTest<TripRecurrenceBloc, TripRecurrenceState>(
    'TripRecurrenceCreated prepends',
    setUp: () =>
        when(() => repo.create(any())).thenAnswer((_) async => _rec(id: 'new')),
    build: () => TripRecurrenceBloc(repo),
    act: (b) => b.add(const TripRecurrenceCreated({'weekdays': '0000100'})),
    expect: () => [
      isA<TripRecurrenceState>().having(
        (s) => s.status,
        'status',
        TripRecurrenceStatus.loading,
      ),
      isA<TripRecurrenceState>()
          .having((s) => s.status, 'status', TripRecurrenceStatus.success)
          .having((s) => s.recurrences.first.id, 'id', 'new'),
    ],
  );

  blocTest<TripRecurrenceBloc, TripRecurrenceState>(
    'TripRecurrenceDeleted removes',
    setUp: () => when(() => repo.delete('r1')).thenAnswer((_) async {}),
    build: () => TripRecurrenceBloc(repo),
    seed: () => TripRecurrenceState(
      status: TripRecurrenceStatus.success,
      recurrences: [_rec()],
    ),
    act: (b) => b.add(const TripRecurrenceDeleted('r1')),
    expect: () => [
      isA<TripRecurrenceState>()
          .having((s) => s.status, 'status', TripRecurrenceStatus.success)
          .having((s) => s.recurrences.isEmpty, 'empty', true),
    ],
  );

  blocTest<TripRecurrenceBloc, TripRecurrenceState>(
    'TripRecurrenceLoaded emits error on failure',
    setUp: () => when(() => repo.getAll()).thenThrow(Exception('boom')),
    build: () => TripRecurrenceBloc(repo),
    act: (b) => b.add(const TripRecurrenceLoaded()),
    expect: () => [
      isA<TripRecurrenceState>().having(
        (s) => s.status,
        'status',
        TripRecurrenceStatus.loading,
      ),
      isA<TripRecurrenceState>().having(
        (s) => s.status,
        'status',
        TripRecurrenceStatus.error,
      ),
    ],
  );
}
