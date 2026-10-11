// Événements construits à l'exécution : un constructeur `const` n'est exécuté
// (donc compté par la couverture) que par un appel non `const`.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecurrenceRepo extends Mock implements TripRecurrenceRepository {}

class _MockTemplateRepo extends Mock implements TripTemplateRepository {}

TripRecurrence _rec(String id, {bool active = true}) => TripRecurrence(
  id: id,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: 8,
  acceptedCategories: const ['Vêtements'],
  pickupAddress: const RecurrenceAddress(label: 'A', lat: 48.8, lng: 2.3),
  deliveryAddress: const RecurrenceAddress(label: 'B', lat: 14.7, lng: -17.4),
  departureTime: '14:00',
  weekdays: '0000100',
  horizonDays: 14,
  active: active,
);

TripTemplate _tpl(String id, {String label = 'Paris-Dakar'}) => TripTemplate(
  id: id,
  label: label,
  emoji: '✈️',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: 8,
  acceptedCategories: const ['Vêtements'],
);

void main() {
  group('TripRecurrenceBloc', () {
    late _MockRecurrenceRepo repo;
    setUp(() => repo = _MockRecurrenceRepo());

    TripRecurrenceState seeded() => TripRecurrenceState(
      status: TripRecurrenceStatus.success,
      recurrences: [_rec('r1'), _rec('r2')],
    );

    TypeMatcher<TripRecurrenceState> st(TripRecurrenceStatus s) =>
        isA<TripRecurrenceState>().having((x) => x.status, 'status', s);

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'chargement → loading puis liste',
      build: () {
        when(() => repo.getAll()).thenAnswer((_) async => [_rec('r1')]);
        return TripRecurrenceBloc(repo);
      },
      act: (b) => b.add(TripRecurrenceLoaded()),
      expect: () => [
        st(TripRecurrenceStatus.loading),
        st(
          TripRecurrenceStatus.success,
        ).having((x) => x.recurrences, 'recurrences', hasLength(1)),
      ],
    );

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'création en échec → erreur, liste conservée',
      build: () {
        when(() => repo.create(any())).thenThrow(const ServerException());
        return TripRecurrenceBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripRecurrenceCreated(const {'weekdays': '1000000'})),
      expect: () => [
        st(TripRecurrenceStatus.loading),
        st(TripRecurrenceStatus.error)
            .having((x) => x.error, 'error', isA<ServerException>())
            .having((x) => x.recurrences, 'recurrences', hasLength(2)),
      ],
    );

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'modification → seule la récurrence visée est remplacée',
      build: () {
        when(
          () => repo.update('r2', any()),
        ).thenAnswer((_) async => _rec('r2', active: false));
        return TripRecurrenceBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripRecurrenceUpdated('r2', const {'active': false})),
      expect: () => [
        st(TripRecurrenceStatus.loading),
        st(TripRecurrenceStatus.success).having(
          (x) => x.recurrences.map((r) => r.active).toList(),
          'actives',
          [true, false],
        ),
      ],
      verify: (_) =>
          verify(() => repo.update('r2', const {'active': false})).called(1),
    );

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'modification en échec → erreur',
      build: () {
        when(
          () => repo.update(any(), any()),
        ).thenThrow(const ServerException());
        return TripRecurrenceBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripRecurrenceUpdated('r2', const {})),
      expect: () => [
        st(TripRecurrenceStatus.loading),
        st(TripRecurrenceStatus.error),
      ],
    );

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'suppression → récurrence retirée',
      build: () {
        when(() => repo.delete('r1')).thenAnswer((_) async {});
        return TripRecurrenceBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripRecurrenceDeleted('r1')),
      expect: () => [
        st(
          TripRecurrenceStatus.success,
        ).having((x) => x.recurrences.map((r) => r.id).toList(), 'ids', ['r2']),
      ],
    );

    blocTest<TripRecurrenceBloc, TripRecurrenceState>(
      'suppression en échec → erreur, liste conservée',
      build: () {
        when(() => repo.delete(any())).thenThrow(const ServerException());
        return TripRecurrenceBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripRecurrenceDeleted('r1')),
      expect: () => [
        st(
          TripRecurrenceStatus.error,
        ).having((x) => x.recurrences, 'recurrences', hasLength(2)),
      ],
    );
  });

  group('TripTemplateBloc', () {
    late _MockTemplateRepo repo;
    setUp(() => repo = _MockTemplateRepo());

    TripTemplateState seeded() => TripTemplateState(
      status: TripTemplateStatus.success,
      templates: [_tpl('t1'), _tpl('t2')],
    );

    TypeMatcher<TripTemplateState> st(TripTemplateStatus s) =>
        isA<TripTemplateState>().having((x) => x.status, 'status', s);

    blocTest<TripTemplateBloc, TripTemplateState>(
      'chargement construit à l’exécution → liste',
      build: () {
        when(() => repo.getAll()).thenAnswer((_) async => [_tpl('t1')]);
        return TripTemplateBloc(repo);
      },
      act: (b) => b.add(TripTemplateLoaded()),
      expect: () => [
        st(TripTemplateStatus.loading),
        st(TripTemplateStatus.success),
      ],
    );

    blocTest<TripTemplateBloc, TripTemplateState>(
      'création en échec → erreur',
      build: () {
        when(() => repo.create(any())).thenThrow(const ServerException());
        return TripTemplateBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripTemplateCreated(const {'label': 'X'})),
      expect: () => [
        st(TripTemplateStatus.loading),
        st(TripTemplateStatus.error)
            .having((x) => x.error, 'error', isA<ServerException>())
            .having((x) => x.templates, 'templates', hasLength(2)),
      ],
    );

    blocTest<TripTemplateBloc, TripTemplateState>(
      'modification en échec → erreur',
      build: () {
        when(
          () => repo.update(any(), any()),
        ).thenThrow(const ServerException());
        return TripTemplateBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripTemplateUpdated('t1', const {'label': 'Y'})),
      expect: () => [
        st(TripTemplateStatus.loading),
        st(TripTemplateStatus.error),
      ],
    );

    blocTest<TripTemplateBloc, TripTemplateState>(
      'suppression en échec → erreur, modèles conservés',
      build: () {
        when(() => repo.delete(any())).thenThrow(const ServerException());
        return TripTemplateBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(TripTemplateDeleted('t1')),
      expect: () => [
        st(
          TripTemplateStatus.error,
        ).having((x) => x.templates, 'templates', hasLength(2)),
      ],
    );
  });
}
