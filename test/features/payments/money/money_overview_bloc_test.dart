import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/data/repositories/money_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'money_fixtures.dart';

class MockMoneyRepository extends Mock implements MoneyRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Samedi 10 octobre 2026, midi.
final _now = DateTime(2026, 10, 10, 12);

void main() {
  late MockMoneyRepository repo;
  late MockAnalyticsService analytics;

  setUp(() {
    repo = MockMoneyRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  MoneyOverviewBloc build({bool secondary = false}) => MoneyOverviewBloc(
    repo,
    analytics,
    trackViews: !secondary,
    now: () => _now,
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'succès : aperçu et échéancier calculés à l\'horloge injectée, '
    'consultation tracée une fois',
    build: () {
      when(() => repo.getOverview()).thenAnswer((_) async => overviewModel());
      return build();
    },
    act: (b) => b
      ..add(const MoneyOverviewLoadRequested())
      ..add(const MoneyOverviewRefreshRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>()
          .having((s) => s.upcomingAvailable, 'upcomingAvailable', isTrue)
          .having((s) => s.overview.travelerItems.length, 'items', 4)
          // Versement auto le dimanche 11 : cette semaine. Séquestre à
          // l'arrivée du lundi 19 : après la semaine prochaine (12-18).
          .having(
            (s) => s.schedule.buckets[MoneyBucket.thisWeek]!.single.amount,
            'cette semaine',
            7950,
          )
          .having(
            (s) => s.schedule.buckets[MoneyBucket.nextWeek],
            'semaine prochaine',
            isEmpty,
          )
          .having(
            (s) => s.schedule.buckets[MoneyBucket.later]!.single.amount,
            'plus tard',
            9450,
          ),
      isA<MoneyOverviewLoaded>(),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': 4,
          'sender_items': 1,
          'trip_count': 4,
          'legacy_backend': false,
        },
      ),
    ).called(1),
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'vide : aperçu sans colis',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenAnswer((_) async => const MoneyOverviewModel());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>()
          .having((s) => s.overview.isEmpty, 'isEmpty', isTrue)
          .having((s) => s.schedule.groups, 'groups', isEmpty),
    ],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'erreur : état d\'erreur avec l\'exception typée',
    build: () {
      when(() => repo.getOverview()).thenThrow(const ServerException());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewError>().having(
        (s) => s.error,
        'error',
        isA<ServerException>(),
      ),
    ],
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'ancien back (404) : vide et marqué indisponible, jamais le portefeuille',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>()
          .having((s) => s.upcomingAvailable, 'upcomingAvailable', isFalse)
          .having((s) => s.overview.isEmpty, 'isEmpty', isTrue),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': 0,
          'sender_items': 0,
          'trip_count': 0,
          'legacy_backend': true,
        },
      ),
    ).called(1),
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'pastille / Mes trajets (ancien back) : aucun tracking',
    build: () {
      when(
        () => repo.getOverview(),
      ).thenThrow(const MoneyOverviewUnavailable());
      return build(secondary: true);
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [
      isA<MoneyOverviewLoading>(),
      isA<MoneyOverviewLoaded>().having(
        (s) => s.upcomingAvailable,
        'upcomingAvailable',
        isFalse,
      ),
    ],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'pastille : succès sans tracking',
    build: () {
      when(() => repo.getOverview()).thenAnswer((_) async => overviewModel());
      return build(secondary: true);
    },
    act: (b) => b.add(const MoneyOverviewLoadRequested()),
    expect: () => [isA<MoneyOverviewLoading>(), isA<MoneyOverviewLoaded>()],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  test('rafraîchissement raté : garde l\'aperçu affiché et termine le '
      'completer', () async {
    var calls = 0;
    when(() => repo.getOverview()).thenAnswer((_) async {
      calls++;
      if (calls == 1) return overviewModel();
      throw const OfflineException();
    });
    final bloc = build();
    bloc.add(const MoneyOverviewLoadRequested());
    await bloc.stream.firstWhere((s) => s is MoneyOverviewLoaded);
    final completer = Completer<void>();
    bloc.add(MoneyOverviewRefreshRequested(completer: completer));
    await completer.future;
    expect(bloc.state, isA<MoneyOverviewLoaded>());
    await bloc.close();
  });

  blocTest<MoneyOverviewBloc, MoneyOverviewState>(
    'rafraîchissement sans données préalables en échec : erreur',
    build: () {
      when(() => repo.getOverview()).thenThrow(const OfflineException());
      return build();
    },
    act: (b) => b.add(const MoneyOverviewRefreshRequested()),
    expect: () => [isA<MoneyOverviewError>()],
  );

  test('horloge par défaut : l\'état calcule l\'échéancier sans `now`', () {
    final state = MoneyOverviewLoaded(overviewModel());
    expect(state.schedule.trips, isNotEmpty);
    expect(
      MoneyOverviewBloc(repo, analytics).state,
      isA<MoneyOverviewInitial>(),
    );
  });
}
