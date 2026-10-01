import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/bloc/receptions_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReceptionRepository extends Mock implements ReceptionRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

const _pending = Reception(
  bidId: 'p1',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
);

const _confirmed = Reception(
  bidId: 'c1',
  linkStatus: 'CONFIRMED',
  bidStatus: 'IN_TRANSIT',
);

void main() {
  late MockReceptionRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockReceptionRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<ReceptionsCubit, ReceptionsState>(
    'charge la liste et mesure la section une seule fois',
    build: () {
      when(
        () => repository.getReceptions(),
      ).thenAnswer((_) async => [_pending, _confirmed]);
      return ReceptionsCubit(repository, analytics);
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => [
      const ReceptionsLoading(),
      isA<ReceptionsLoaded>().having((s) => s.receptions.length, 'count', 2),
      isA<ReceptionsLoaded>(),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.receptionsSectionViewed,
        properties: {'count': 2, 'pending': 1},
      ),
    ).called(1),
  );

  blocTest<ReceptionsCubit, ReceptionsState>(
    'liste vide : aucun événement',
    build: () {
      when(() => repository.getReceptions()).thenAnswer((_) async => []);
      return ReceptionsCubit(repository, analytics);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReceptionsLoading(),
      isA<ReceptionsLoaded>().having((s) => s.receptions, 'vide', isEmpty),
    ],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<ReceptionsCubit, ReceptionsState>(
    'ancien back (404) : état d\'erreur, jamais affiché',
    build: () {
      when(() => repository.getReceptions()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/receptions'),
          error: const NotFoundException(),
        ),
      );
      return ReceptionsCubit(repository, analytics);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ReceptionsLoading(),
      isA<ReceptionsError>().having(
        (s) => s.error,
        'error',
        isA<NotFoundException>(),
      ),
    ],
  );

  blocTest<ReceptionsCubit, ReceptionsState>(
    'rafraîchissement raté : la liste affichée reste',
    build: () {
      var calls = 0;
      when(() => repository.getReceptions()).thenAnswer((_) async {
        calls++;
        if (calls > 1) throw Exception('hors ligne');
        return [_pending];
      });
      return ReceptionsCubit(repository, analytics);
    },
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => [const ReceptionsLoading(), isA<ReceptionsLoaded>()],
  );
}
