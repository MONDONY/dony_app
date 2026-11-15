import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/home/bloc/home_search_session_cubit.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const boat = HomeSearchFilters(transportMode: TransportMode.boat);

  test('vide au départ', () {
    final cubit = HomeSearchSessionCubit();
    expect(cubit.state.filters, isNull);
    expect(cubit.state.mode, isNull);
  });

  blocTest<HomeSearchSessionCubit, HomeSearchSessionState>(
    'retient les filtres et le mode de la dernière recherche',
    build: HomeSearchSessionCubit.new,
    act: (cubit) => cubit.remember(filters: boat, mode: SearchMode.trips),
    expect: () => [
      isA<HomeSearchSessionState>()
          .having(
            (s) => s.filters?.transportMode,
            'transportMode',
            TransportMode.boat,
          )
          .having((s) => s.mode, 'mode', SearchMode.trips),
    ],
  );

  blocTest<HomeSearchSessionCubit, HomeSearchSessionState>(
    'reset oublie la recherche (déconnexion, changement de compte)',
    build: HomeSearchSessionCubit.new,
    act: (cubit) => cubit
      ..remember(filters: boat, mode: SearchMode.trips)
      ..reset(),
    skip: 1,
    expect: () => [
      isA<HomeSearchSessionState>()
          .having((s) => s.filters, 'filters', isNull)
          .having((s) => s.mode, 'mode', isNull),
    ],
  );
}
