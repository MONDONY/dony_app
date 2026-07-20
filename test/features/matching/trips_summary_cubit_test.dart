import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trips_summary_cubit.dart';
import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

void main() {
  late _MockAnnouncementRepository repository;

  setUp(() => repository = _MockAnnouncementRepository());

  const summary = TripsSummaryModel(
    activeTrips: 3,
    kgSoldThisMonth: 19,
    revenueThisMonth: 152.46,
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load → loading puis loaded avec le résumé',
    build: () {
      when(
        () => repository.getTripsSummary(period: any(named: 'period')),
      ).thenAnswer((_) async => summary);
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(),
    expect: () => [
      const TripsSummaryState.loading(),
      const TripsSummaryState.loaded(summary),
    ],
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load → hidden en cas d\'erreur (bandeau masqué, pas de message)',
    build: () {
      when(
        () => repository.getTripsSummary(period: any(named: 'period')),
      ).thenThrow(Exception('network'));
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(),
    expect: () => [
      const TripsSummaryState.loading(),
      const TripsSummaryState.hidden(),
    ],
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load transmet la période demandée au repository',
    build: () {
      when(
        () => repository.getTripsSummary(period: any(named: 'period')),
      ).thenAnswer((_) async => summary);
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(period: '12m'),
    verify: (_) {
      verify(() => repository.getTripsSummary(period: '12m')).called(1);
    },
  );
}
