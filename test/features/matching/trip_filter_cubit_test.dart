import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalyticsService analytics;

  setUp(() {
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<TripFilterCubit, TripFilterState>(
    'setFilter émet le filtre et log trip_filter_applied',
    build: () => TripFilterCubit(analytics),
    act: (c) => c.setFilter(TripStatusFilter.completed),
    expect: () => [const TripFilterState(filter: TripStatusFilter.completed)],
    verify: (_) {
      verify(
        () => analytics.logEvent(
          'trip_filter_applied',
          properties: {'status': 'completed'},
        ),
      ).called(1);
    },
  );

  blocTest<TripFilterCubit, TripFilterState>(
    'setQuery filtre sans log analytics',
    build: () => TripFilterCubit(analytics),
    act: (c) => c.setQuery('dakar'),
    expect: () => [const TripFilterState(query: 'dakar')],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  test('matches applique filtre statut et recherche ville', () {
    const state = TripFilterState(
      filter: TripStatusFilter.active,
      query: 'dak',
    );
    expect(state.matchesStatus('ACTIVE'), isTrue);
    expect(state.matchesStatus('IN_PROGRESS'), isTrue);
    expect(state.matchesStatus('COMPLETED'), isFalse);
    expect(state.matchesQuery('Paris', 'Dakar'), isTrue);
    expect(state.matchesQuery('Paris', 'Bamako'), isFalse);
  });

  test('draft ne matche que DRAFT', () {
    const state = TripFilterState(filter: TripStatusFilter.draft);
    expect(state.matchesStatus('DRAFT'), isTrue);
    expect(state.matchesStatus('ACTIVE'), isFalse);
  });

  test('all matche aussi DRAFT', () {
    const state = TripFilterState();
    expect(state.matchesStatus('DRAFT'), isTrue);
  });
}
