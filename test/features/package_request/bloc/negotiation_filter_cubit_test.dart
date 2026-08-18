import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:flutter_test/flutter_test.dart';

NegoEntry _t({
  String? traveler = 'Awa',
  String? arrivee = 'Dakar',
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
}) => NegoEntry.fromRequest(
  NegotiationThread(
    id: 't_${arrivee}_${status.name}',
    packageRequestId: 'p1',
    travelerId: 'v1',
    travelerName: traveler,
    departureCity: 'Paris',
    arrivalCity: arrivee,
    status: status,
    currentPriceEur: 15,
    lastActivityAt: DateTime(2026, 6),
    createdAt: DateTime(2026, 5),
    travelerTravelDate: DateTime(2026, 7),
    travelerAvailableKg: 10,
    roundsCount: 1,
    messages: const [],
  ),
);

void main() {
  // Le prédicat reçoit une requête DÉJÀ normalisée : c'est `applyNegotiationFilters`
  // qui normalise, une fois pour toute la liste.
  group('negoMatchesNormalizedQuery', () {
    test(
      'vide -> tout',
      () => expect(negoMatchesNormalizedQuery(_t(), ''), isTrue),
    );
    test(
      'voyageur',
      () => expect(
        negoMatchesNormalizedQuery(_t(traveler: 'Modou'), 'modou'),
        isTrue,
      ),
    );
    test(
      'ville',
      () => expect(
        negoMatchesNormalizedQuery(_t(arrivee: 'Bamako'), 'bamako'),
        isTrue,
      ),
    );
    test(
      'rien',
      () => expect(negoMatchesNormalizedQuery(_t(), 'zzz'), isFalse),
    );
  });

  group('applyNegotiationFilters', () {
    final all = [
      _t(),
      _t(arrivee: 'Abidjan', status: NegotiationThreadStatus.rejected),
    ];
    test('preset active exclut rejected', () {
      final r = applyNegotiationFilters(
        all,
        const NegotiationFilterState(preset: NegoQuickFilter.active),
      );
      expect(r.single.arrivalCity, 'Dakar');
    });
    test('preset terminal', () {
      final r = applyNegotiationFilters(
        all,
        const NegotiationFilterState(preset: NegoQuickFilter.terminal),
      );
      expect(r.single.arrivalCity, 'Abidjan');
    });

    // La casse, les accents et les espaces de saisie sont absorbés une seule
    // fois, au niveau de la liste : le filtrage doit rester identique.
    test('la requete brute est normalisee avant le filtrage', () {
      final r = applyNegotiationFilters(
        [_t(traveler: 'Modou'), _t(traveler: 'Awa', arrivee: 'Abidjan')],
        const NegotiationFilterState(query: '  MODOU '),
      );
      expect(r.single.counterpartyName, 'Modou');
    });

    test('les accents de la requete sont ignores', () {
      final r = applyNegotiationFilters(
        [_t(traveler: 'Modou', arrivee: 'Bamako'), _t(traveler: 'Awa')],
        const NegotiationFilterState(query: 'bàmakô'),
      );
      expect(r.single.arrivalCity, 'Bamako');
    });

    test('une requete vide ne retire personne', () {
      final r = applyNegotiationFilters(
        all,
        const NegotiationFilterState(query: '   '),
      );
      expect(r, hasLength(2));
    });

    test('normalizeSearch reste la source unique de normalisation', () {
      expect(normalizeSearch('MODOU'), 'modou');
    });
  });

  group('negoMatchesPreset — cancelled', () {
    final cancelled = _t(
      arrivee: 'Bamako',
      status: NegotiationThreadStatus.cancelled,
    );
    test('preset terminal inclut cancelled', () {
      expect(negoMatchesPreset(cancelled, NegoQuickFilter.terminal), isTrue);
    });
    test('preset active exclut cancelled', () {
      expect(negoMatchesPreset(cancelled, NegoQuickFilter.active), isFalse);
    });
  });
}
