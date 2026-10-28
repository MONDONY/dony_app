import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalytics analytics;
  late TravelerTrackingCardCubit cubit;

  setUp(() {
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = TravelerTrackingCardCubit(analytics: analytics);
  });

  tearDown(() => cubit.close());

  test('cardViewedEventFiredOnce : un seul événement, sans ville', () {
    const t = TravelerTrackingModel(
      status: TravelerTrackingStatus.stale,
      nearestCity: 'Lyon',
    );
    cubit
      ..viewed(t)
      ..viewed(t);

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.travelerTrackingCardViewed,
        properties: {'status': 'stale', 'has_history': false},
      ),
    ).called(1);
  });

  test('chaque statut a son nom', () {
    expect(
      TravelerTrackingCardCubit.statusName(TravelerTrackingStatus.notActivated),
      'not_activated',
    );
    expect(
      TravelerTrackingCardCubit.statusName(TravelerTrackingStatus.arrived),
      'arrived',
    );
  });
}
