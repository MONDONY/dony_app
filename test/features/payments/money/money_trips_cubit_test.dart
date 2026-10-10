import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/bloc/money_trips_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockAnalyticsService analytics;

  setUp(() {
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  test('fermé par défaut, trajet ciblé déplié', () {
    expect(MoneyTripsCubit(analytics).state.expanded, isEmpty);
    final focused = MoneyTripsCubit(analytics, focusKey: 'abj');
    expect(focused.state.isExpanded('abj'), isTrue);
    expect(focused.state.visibleCount, kMoneyTripsPageSize);
  });

  blocTest<MoneyTripsCubit, MoneyTripsViewState>(
    'déplie, replie et charge la page suivante',
    build: () => MoneyTripsCubit(analytics),
    act: (c) => c
      ..toggle('a')
      ..toggle('b')
      ..toggle('a')
      ..showMore(),
    expect: () => [
      isA<MoneyTripsViewState>().having((s) => s.expanded, 'a', {'a'}),
      isA<MoneyTripsViewState>().having((s) => s.expanded, 'a+b', {'a', 'b'}),
      isA<MoneyTripsViewState>().having((s) => s.expanded, 'b', {'b'}),
      isA<MoneyTripsViewState>()
          .having((s) => s.expanded, 'b gardé', {'b'})
          .having((s) => s.visibleCount, 'page 2', 2 * kMoneyTripsPageSize),
    ],
  );

  test('consultation tracée une seule fois, sans montant', () {
    final cubit = MoneyTripsCubit(analytics)
      ..trackViewed(tripCount: 3, filtered: false)
      ..trackViewed(tripCount: 3, filtered: false);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyTripsViewed,
        properties: {'trip_count': 3, 'filtered': false},
      ),
    ).called(1);
    cubit.close();
  });
}
