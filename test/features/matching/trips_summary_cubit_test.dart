import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
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
    kgSold: 19,
    revenue: 152.46,
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

  // ─── « Combien de trajets actifs ? » : trois réponses, pas deux ────────────
  //
  // Le filtre « Pour mes trajets » se grise sur cette valeur. La confondre avec
  // zéro en cas d'échec réseau ferait afficher « Aucun trajet actif » à un
  // voyageur qui en a trois, et pour toute la session.
  group('knownActiveTrips', () {
    test('connu et positif → le nombre réel', () {
      expect(const TripsSummaryState.loaded(summary).knownActiveTrips, 3);
    });

    test('connu et nul → zéro, pas inconnu', () {
      const vide = TripsSummaryModel(activeTrips: 0, kgSold: 0, revenue: 0);
      expect(const TripsSummaryState.loaded(vide).knownActiveTrips, 0);
    });

    test('échec réseau → inconnu, jamais zéro', () {
      expect(const TripsSummaryState.hidden().knownActiveTrips, isNull);
    });

    test('avant la réponse → inconnu', () {
      expect(const TripsSummaryState.initial().knownActiveTrips, isNull);
      expect(const TripsSummaryState.loading().knownActiveTrips, isNull);
    });
  });

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load en échec laisse le nombre de trajets INCONNU (et non à zéro)',
    build: () {
      when(
        () => repository.getTripsSummary(period: any(named: 'period')),
      ).thenThrow(Exception('network'));
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(),
    verify: (c) => expect(c.state.knownActiveTrips, isNull),
  );

  blocTest<TripsSummaryCubit, TripsSummaryState>(
    'load transmet la période demandée au repository',
    build: () {
      when(
        () => repository.getTripsSummary(period: any(named: 'period')),
      ).thenAnswer((_) async => summary);
      return TripsSummaryCubit(repository);
    },
    act: (c) => c.load(period: StatsPeriod.twelveMonths),
    verify: (_) {
      verify(() => repository.getTripsSummary(period: '12m')).called(1);
    },
  );
}
