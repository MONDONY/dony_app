import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/pro_stats_bloc.dart';
import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:dony/features/profile/data/pro_stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProStatsRepository extends Mock implements ProStatsRepository {}

ProStatsModel get kStats => const ProStatsModel(
      monthlyRevenue: 1250.0,
      totalRevenue: 8400.0,
      monthlyTrips: 3,
      monthlyParcelsDelivered: 12,
      acceptanceRate: 0.92,
      averageRating: 4.7,
      topDestinations: [
        DestinationStatModel(from: 'Paris', to: 'Dakar', count: 2),
        DestinationStatModel(from: 'Lyon', to: 'Abidjan', count: 1),
      ],
    );

void main() {
  late MockProStatsRepository mockRepo;

  setUp(() {
    mockRepo = MockProStatsRepository();
  });

  ProStatsBloc buildBloc() => ProStatsBloc(mockRepo);

  group('état initial', () {
    test('est ProStatsInitial', () {
      expect(buildBloc().state, isA<ProStatsInitial>());
    });
  });

  group('ProStatsLoadRequested', () {
    blocTest<ProStatsBloc, ProStatsState>(
      'succès → [Loading, Loaded]',
      build: () {
        when(() => mockRepo.fetchStats()).thenAnswer((_) async => kStats);
        return buildBloc();
      },
      act: (bloc) => bloc.add(ProStatsLoadRequested()),
      expect: () => [
        isA<ProStatsLoading>(),
        predicate<ProStatsState>((s) =>
            s is ProStatsLoaded &&
            s.stats.monthlyRevenue == 1250.0 &&
            s.stats.monthlyTrips == 3 &&
            s.stats.topDestinations.length == 2),
      ],
    );

    blocTest<ProStatsBloc, ProStatsState>(
      'AppException → [Loading, Error avec message métier]',
      build: () {
        when(() => mockRepo.fetchStats())
            .thenThrow(const NetworkException('Erreur réseau'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(ProStatsLoadRequested()),
      expect: () => [
        isA<ProStatsLoading>(),
        predicate<ProStatsState>((s) =>
            s is ProStatsError && s.error.message == 'Erreur réseau'),
      ],
    );

    blocTest<ProStatsBloc, ProStatsState>(
      'erreur inconnue → [Loading, Error générique]',
      build: () {
        when(() => mockRepo.fetchStats())
            .thenThrow(Exception('Unknown error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(ProStatsLoadRequested()),
      expect: () => [
        isA<ProStatsLoading>(),
        predicate<ProStatsState>((s) => s is ProStatsError),
      ],
    );

    blocTest<ProStatsBloc, ProStatsState>(
      'deux appels successifs → dernier état est Loaded',
      build: () {
        when(() => mockRepo.fetchStats()).thenAnswer((_) async => kStats);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(ProStatsLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ProStatsLoadRequested());
      },
      expect: () => [
        isA<ProStatsLoading>(),
        isA<ProStatsLoaded>(),
        isA<ProStatsLoading>(),
        isA<ProStatsLoaded>(),
      ],
    );
  });
}
