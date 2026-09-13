import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_filter_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  group('resolveTripFilter', () {
    test('completed → Terminés, inconnu → tout', () {
      expect(resolveTripFilter('completed'), TripStatusFilter.completed);
      expect(resolveTripFilter('active'), TripStatusFilter.active);
      expect(resolveTripFilter('bidon'), TripStatusFilter.all);
      expect(resolveTripFilter(null), TripStatusFilter.all);
    });
  });

  group('TripFilterCubit.seedFilter', () {
    test('pose le filtre sans tracer d\'événement', () {
      final analytics = _MockAnalytics();
      final cubit = TripFilterCubit(analytics);

      cubit.seedFilter(TripStatusFilter.completed);

      expect(cubit.state.filter, TripStatusFilter.completed);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });
}
