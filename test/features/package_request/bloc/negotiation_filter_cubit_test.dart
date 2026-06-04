import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

NegotiationThread _t({
  String? traveler = 'Awa',
  String? arrivee = 'Dakar',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
}) =>
    NegotiationThread(
      id: 't_${arrivee}_${status.name}',
      packageRequestId: 'p1',
      travelerId: 'v1',
      travelerName: traveler,
      departureCity: 'Paris',
      arrivalCity: arrivee,
      status: status,
      currentPriceEur: 15,
      lastActivityAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 5, 1),
      travelerTravelDate: DateTime(2026, 7, 1),
      travelerAvailableKg: 10,
      roundsCount: 1,
      messages: const [],
    );

void main() {
  group('negoMatchesQuery', () {
    test('vide -> tout', () => expect(negoMatchesQuery(_t(), ''), isTrue));
    test('voyageur', () => expect(negoMatchesQuery(_t(traveler: 'Modou'), 'modou'), isTrue));
    test('ville', () => expect(negoMatchesQuery(_t(arrivee: 'Bamako'), 'bamako'), isTrue));
    test('rien', () => expect(negoMatchesQuery(_t(), 'zzz'), isFalse));
  });

  group('applyNegotiationFilters', () {
    final all = [
      _t(arrivee: 'Dakar', status: NegotiationThreadStatus.open),
      _t(arrivee: 'Abidjan', status: NegotiationThreadStatus.rejected),
    ];
    test('preset active exclut rejected', () {
      final r = applyNegotiationFilters(all, const NegotiationFilterState(preset: NegoQuickFilter.active));
      expect(r.single.arrivalCity, 'Dakar');
    });
    test('preset terminal', () {
      final r = applyNegotiationFilters(all, const NegotiationFilterState(preset: NegoQuickFilter.terminal));
      expect(r.single.arrivalCity, 'Abidjan');
    });
  });
}
