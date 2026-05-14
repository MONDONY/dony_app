import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/favorite_travelers/bloc/favorite_traveler_bloc.dart';
import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';
import 'package:dony/features/favorite_travelers/data/repositories/favorite_traveler_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFavoriteTravelerRepository extends Mock
    implements FavoriteTravelerRepository {}

const _t1 = FavoriteTraveler(
  id: 'fav-1',
  travelerId: 'traveler-1',
  travelerName: 'Ibrahima Diallo',
  travelerAverageRating: 4.8,
);

const _t2 = FavoriteTraveler(
  id: 'fav-2',
  travelerId: 'traveler-2',
  travelerName: 'Fatoumata Bah',
  travelerAverageRating: 4.5,
);

void main() {
  late MockFavoriteTravelerRepository repository;

  setUp(() {
    repository = MockFavoriteTravelerRepository();
  });

  group('FavoriteTravelerBloc', () {
    test('initial state is correct', () {
      final bloc = FavoriteTravelerBloc(repository);
      expect(bloc.state.status, FavoriteTravelerStatus.initial);
      expect(bloc.state.travelers, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    blocTest<FavoriteTravelerBloc, FavoriteTravelerState>(
      'FavoriteTravelerLoaded → success + list',
      build: () {
        when(() => repository.getAll()).thenAnswer((_) async => [_t1, _t2]);
        return FavoriteTravelerBloc(repository);
      },
      act: (bloc) => bloc.add(const FavoriteTravelerLoaded()),
      expect: () => [
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.loading),
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.success)
            .having((s) => s.travelers, 'travelers', [_t1, _t2]),
      ],
    );

    blocTest<FavoriteTravelerBloc, FavoriteTravelerState>(
      'FavoriteTravelerLoaded → error when repository throws',
      build: () {
        when(() => repository.getAll()).thenThrow(Exception('Network error'));
        return FavoriteTravelerBloc(repository);
      },
      act: (bloc) => bloc.add(const FavoriteTravelerLoaded()),
      expect: () => [
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.loading),
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<FavoriteTravelerBloc, FavoriteTravelerState>(
      'FavoriteTravelerRemoved → removes from list',
      build: () {
        when(() => repository.remove('traveler-1')).thenAnswer((_) async {});
        return FavoriteTravelerBloc(repository)
          ..emit(const FavoriteTravelerState(
            status: FavoriteTravelerStatus.success,
            travelers: [_t1, _t2],
          ));
      },
      act: (bloc) => bloc.add(const FavoriteTravelerRemoved('traveler-1')),
      expect: () => [
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.success)
            .having((s) => s.travelers.length, 'length', 1)
            .having((s) => s.travelers.first.travelerId, 'travelerId', 'traveler-2'),
      ],
    );

    blocTest<FavoriteTravelerBloc, FavoriteTravelerState>(
      'FavoriteTravelerRemoved → error when repository throws',
      build: () {
        when(() => repository.remove('traveler-1'))
            .thenThrow(Exception('Server error'));
        return FavoriteTravelerBloc(repository)
          ..emit(const FavoriteTravelerState(
            status: FavoriteTravelerStatus.success,
            travelers: [_t1],
          ));
      },
      act: (bloc) => bloc.add(const FavoriteTravelerRemoved('traveler-1')),
      expect: () => [
        isA<FavoriteTravelerState>()
            .having((s) => s.status, 'status', FavoriteTravelerStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
