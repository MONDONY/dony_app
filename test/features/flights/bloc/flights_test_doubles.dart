import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockFlightsRepository extends Mock implements FlightsRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

MockAnalyticsService silentAnalytics() {
  final analytics = MockAnalyticsService();
  when(
    () => analytics.logEvent(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  return analytics;
}

FlightOffer offer(
  String path, {
  double price = 431,
  int? transfers = 1,
  int? minutes = 585,
  String airline = 'AT',
  DateTime? departureAt,
}) => FlightOffer(
  originCode: 'PAR',
  destinationCode: 'ABJ',
  price: price,
  currency: 'EUR',
  airlineCode: airline,
  transfers: transfers,
  durationMinutes: minutes,
  departureAt: departureAt,
  offerPath: path,
);
