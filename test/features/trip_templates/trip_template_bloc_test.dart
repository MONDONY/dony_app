import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTripTemplateRepository extends Mock implements TripTemplateRepository {}

TripTemplate _tpl({String id = 't1', String label = 'Mon Paris-Dakar'}) => TripTemplate(
      id: id,
      label: label,
      emoji: '🇸🇳',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      transportMode: 'PLANE',
      capacityUnit: 'SUITCASE_23KG',
      availableKg: 23,
      pricePerKg: 8,
      acceptedCategories: const ['Vêtements'],
    );

void main() {
  late MockTripTemplateRepository repo;

  setUp(() => repo = MockTripTemplateRepository());

  test('initial state is initial', () {
    expect(TripTemplateBloc(repo).state.status, TripTemplateStatus.initial);
  });

  blocTest<TripTemplateBloc, TripTemplateState>(
    'TripTemplateLoaded emits loading then success with templates',
    setUp: () => when(() => repo.getAll()).thenAnswer((_) async => [_tpl()]),
    build: () => TripTemplateBloc(repo),
    act: (b) => b.add(const TripTemplateLoaded()),
    expect: () => [
      isA<TripTemplateState>().having((s) => s.status, 'status', TripTemplateStatus.loading),
      isA<TripTemplateState>()
          .having((s) => s.status, 'status', TripTemplateStatus.success)
          .having((s) => s.templates.length, 'count', 1),
    ],
  );

  blocTest<TripTemplateBloc, TripTemplateState>(
    'TripTemplateLoaded emits error on failure',
    setUp: () => when(() => repo.getAll()).thenThrow(Exception('boom')),
    build: () => TripTemplateBloc(repo),
    act: (b) => b.add(const TripTemplateLoaded()),
    expect: () => [
      isA<TripTemplateState>().having((s) => s.status, 'status', TripTemplateStatus.loading),
      isA<TripTemplateState>().having((s) => s.status, 'status', TripTemplateStatus.error),
    ],
  );

  blocTest<TripTemplateBloc, TripTemplateState>(
    'TripTemplateCreated prepends the created template',
    setUp: () =>
        when(() => repo.create(any())).thenAnswer((_) async => _tpl(id: 'new', label: 'Lyon')),
    build: () => TripTemplateBloc(repo),
    act: (b) => b.add(const TripTemplateCreated({'label': 'Lyon'})),
    expect: () => [
      isA<TripTemplateState>().having((s) => s.status, 'status', TripTemplateStatus.loading),
      isA<TripTemplateState>()
          .having((s) => s.status, 'status', TripTemplateStatus.success)
          .having((s) => s.templates.first.id, 'first id', 'new'),
    ],
  );

  blocTest<TripTemplateBloc, TripTemplateState>(
    'TripTemplateUpdated replaces the matching template',
    setUp: () => when(() => repo.update('t1', any()))
        .thenAnswer((_) async => _tpl(id: 't1', label: 'Modifié')),
    build: () => TripTemplateBloc(repo),
    seed: () => TripTemplateState(status: TripTemplateStatus.success, templates: [_tpl()]),
    act: (b) => b.add(const TripTemplateUpdated('t1', {'label': 'Modifié'})),
    expect: () => [
      isA<TripTemplateState>().having((s) => s.status, 'status', TripTemplateStatus.loading),
      isA<TripTemplateState>()
          .having((s) => s.status, 'status', TripTemplateStatus.success)
          .having((s) => s.templates.first.label, 'label', 'Modifié'),
    ],
  );

  blocTest<TripTemplateBloc, TripTemplateState>(
    'TripTemplateDeleted removes the template',
    setUp: () => when(() => repo.delete('t1')).thenAnswer((_) async {}),
    build: () => TripTemplateBloc(repo),
    seed: () => TripTemplateState(status: TripTemplateStatus.success, templates: [_tpl()]),
    act: (b) => b.add(const TripTemplateDeleted('t1')),
    expect: () => [
      isA<TripTemplateState>()
          .having((s) => s.status, 'status', TripTemplateStatus.success)
          .having((s) => s.templates.isEmpty, 'empty', true),
    ],
  );
}
