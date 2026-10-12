import 'package:dony/features/flights/bloc/flight_deals_cubit.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

void main() {
  late MockFlightsRepository repository;
  late FlightDealsCubit cubit;

  setUp(() {
    repository = MockFlightsRepository();
    cubit = FlightDealsCubit(repository);
  });

  tearDown(() => cubit.close());

  test('bons plans chargés', () async {
    final deal = FlightDeal(
      offer: offer('d'),
      medianPrice: 600,
      discountPercent: 28,
    );
    when(() => repository.deals()).thenAnswer(
      (_) async =>
          FlightDeals(currency: 'EUR', personalized: true, deals: [deal]),
    );

    await cubit.load();

    expect(cubit.state.status, FlightDealsStatus.loaded);
    expect(cubit.state.personalized, isTrue);
    expect(cubit.state.deals, [deal]);
  });

  test('aucun bon plan ou erreur : section masquée', () async {
    when(() => repository.deals()).thenAnswer(
      (_) async =>
          const FlightDeals(currency: 'EUR', personalized: false, deals: []),
    );
    await cubit.load();
    expect(cubit.state.status, FlightDealsStatus.hidden);

    when(() => repository.deals()).thenThrow(Exception('down'));
    await cubit.load();
    expect(cubit.state.status, FlightDealsStatus.hidden);
  });
}
