import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/home_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les phrases de l'accueil qui mêlent un nombre et un corridor étaient
/// construites par concaténation. Elles passent par des messages ICU : les
/// attentes françaises ci-dessous sont écrites en dur, recopiées de ce que
/// l'ancienne concaténation produisait, pour prouver que le français affiché
/// ne change pas.
void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  const none = HomeSearchFilters();
  const depOnly = HomeSearchFilters(departureCity: 'Lyon');
  const arrOnly = HomeSearchFilters(arrivalCity: 'Bamako');
  const both = HomeSearchFilters(departureCity: 'Lyon', arrivalCity: 'Bamako');
  const corridors = {
    'aucun': none,
    'départ': depOnly,
    'arrivée': arrOnly,
    'les deux': both,
  };

  group('homeCorridorLabel (fr)', () {
    const expected = {
      'aucun': 'Tous les corridors',
      'départ': 'Départ de Lyon',
      'arrivée': 'Vers Bamako',
      'les deux': 'Lyon → Bamako',
    };
    for (final c in corridors.entries) {
      test(c.key, () {
        expect(homeCorridorLabel(fr, c.value), expected[c.key]);
      });
    }
  });

  group('homeCrossDiscoveryLabel (fr)', () {
    // Clé : '<mode>|<corridor>|<n>'.
    const expected = {
      'trips|aucun|0': '0 colis cherche un voyageur',
      'trips|aucun|1': '1 colis cherche un voyageur',
      'trips|aucun|2': '2 colis cherchent un voyageur',
      'trips|aucun|12': '12 colis cherchent un voyageur',
      'trips|départ|0': '0 colis cherche un voyageur au départ de Lyon',
      'trips|départ|1': '1 colis cherche un voyageur au départ de Lyon',
      'trips|départ|2': '2 colis cherchent un voyageur au départ de Lyon',
      'trips|départ|12': '12 colis cherchent un voyageur au départ de Lyon',
      'trips|arrivée|0': '0 colis cherche un voyageur vers Bamako',
      'trips|arrivée|1': '1 colis cherche un voyageur vers Bamako',
      'trips|arrivée|2': '2 colis cherchent un voyageur vers Bamako',
      'trips|arrivée|12': '12 colis cherchent un voyageur vers Bamako',
      'trips|les deux|0': '0 colis cherche un voyageur sur Lyon → Bamako',
      'trips|les deux|1': '1 colis cherche un voyageur sur Lyon → Bamako',
      'trips|les deux|2': '2 colis cherchent un voyageur sur Lyon → Bamako',
      'trips|les deux|12': '12 colis cherchent un voyageur sur Lyon → Bamako',
      'parcels|aucun|0': '0 voyageur passe',
      'parcels|aucun|1': '1 voyageur passe',
      'parcels|aucun|2': '2 voyageurs passent',
      'parcels|aucun|12': '12 voyageurs passent',
      'parcels|départ|0': '0 voyageur passe au départ de Lyon',
      'parcels|départ|1': '1 voyageur passe au départ de Lyon',
      'parcels|départ|2': '2 voyageurs passent au départ de Lyon',
      'parcels|départ|12': '12 voyageurs passent au départ de Lyon',
      'parcels|arrivée|0': '0 voyageur passe vers Bamako',
      'parcels|arrivée|1': '1 voyageur passe vers Bamako',
      'parcels|arrivée|2': '2 voyageurs passent vers Bamako',
      'parcels|arrivée|12': '12 voyageurs passent vers Bamako',
      'parcels|les deux|0': '0 voyageur passe sur Lyon → Bamako',
      'parcels|les deux|1': '1 voyageur passe sur Lyon → Bamako',
      'parcels|les deux|2': '2 voyageurs passent sur Lyon → Bamako',
      'parcels|les deux|12': '12 voyageurs passent sur Lyon → Bamako',
    };
    for (final mode in SearchMode.values) {
      for (final c in corridors.entries) {
        for (final n in const [0, 1, 2, 12]) {
          final key = '${mode.name}|${c.key}|$n';
          test(key, () {
            expect(
              homeCrossDiscoveryLabel(
                fr,
                mode: mode,
                filters: c.value,
                count: n,
              ),
              expected[key],
            );
          });
        }
      }
    }
  });

  group('homeAlertForSearchLabel (fr)', () {
    test('trajets', () {
      expect(
        homeAlertForSearchLabel(
          fr,
          mode: SearchMode.trips,
          departureCity: 'Lyon',
          arrivalCity: 'Bamako',
        ),
        "M'alerter dès qu'un trajet apparaît sur Lyon → Bamako",
      );
    });
    test('colis', () {
      expect(
        homeAlertForSearchLabel(
          fr,
          mode: SearchMode.parcels,
          departureCity: 'Lyon',
          arrivalCity: 'Bamako',
        ),
        "M'alerter dès qu'un colis apparaît sur Lyon → Bamako",
      );
    });
  });

  group('homeListTitle (fr)', () {
    // Clé : '<variante>|<corridor>|<n>'.
    const expected = {
      'trips|aucun|0': '0 voyageur · Tous les corridors',
      'trips|aucun|1': '1 voyageur · Tous les corridors',
      'trips|aucun|2': '2 voyageurs · Tous les corridors',
      'trips|aucun|12': '12 voyageurs · Tous les corridors',
      'trips|départ|0': '0 voyageur · Départ de Lyon',
      'trips|départ|1': '1 voyageur · Départ de Lyon',
      'trips|départ|2': '2 voyageurs · Départ de Lyon',
      'trips|départ|12': '12 voyageurs · Départ de Lyon',
      'trips|arrivée|0': '0 voyageur · Vers Bamako',
      'trips|arrivée|1': '1 voyageur · Vers Bamako',
      'trips|arrivée|2': '2 voyageurs · Vers Bamako',
      'trips|arrivée|12': '12 voyageurs · Vers Bamako',
      'trips|les deux|0': '0 voyageur pour Lyon → Bamako',
      'trips|les deux|1': '1 voyageur pour Lyon → Bamako',
      'trips|les deux|2': '2 voyageurs pour Lyon → Bamako',
      'trips|les deux|12': '12 voyageurs pour Lyon → Bamako',
      'parcels|aucun|0': '0 colis à transporter · Tous les corridors',
      'parcels|aucun|1': '1 colis à transporter · Tous les corridors',
      'parcels|aucun|2': '2 colis à transporter · Tous les corridors',
      'parcels|aucun|12': '12 colis à transporter · Tous les corridors',
      'parcels|départ|0': '0 colis à transporter · Départ de Lyon',
      'parcels|départ|1': '1 colis à transporter · Départ de Lyon',
      'parcels|départ|2': '2 colis à transporter · Départ de Lyon',
      'parcels|départ|12': '12 colis à transporter · Départ de Lyon',
      'parcels|arrivée|0': '0 colis à transporter · Vers Bamako',
      'parcels|arrivée|1': '1 colis à transporter · Vers Bamako',
      'parcels|arrivée|2': '2 colis à transporter · Vers Bamako',
      'parcels|arrivée|12': '12 colis à transporter · Vers Bamako',
      'parcels|les deux|0': '0 colis à transporter pour Lyon → Bamako',
      'parcels|les deux|1': '1 colis à transporter pour Lyon → Bamako',
      'parcels|les deux|2': '2 colis à transporter pour Lyon → Bamako',
      'parcels|les deux|12': '12 colis à transporter pour Lyon → Bamako',
      'matching|aucun|0': '0 colis compatible',
      'matching|aucun|1': '1 colis compatible',
      'matching|aucun|2': '2 colis compatibles',
      'matching|aucun|12': '12 colis compatibles',
      'matching|départ|0': '0 colis compatible',
      'matching|départ|1': '1 colis compatible',
      'matching|départ|2': '2 colis compatibles',
      'matching|départ|12': '12 colis compatibles',
      'matching|arrivée|0': '0 colis compatible',
      'matching|arrivée|1': '1 colis compatible',
      'matching|arrivée|2': '2 colis compatibles',
      'matching|arrivée|12': '12 colis compatibles',
      'matching|les deux|0': '0 colis compatible',
      'matching|les deux|1': '1 colis compatible',
      'matching|les deux|2': '2 colis compatibles',
      'matching|les deux|12': '12 colis compatibles',
      'nearMe|aucun|0': '0 voyageur à proximité',
      'nearMe|aucun|1': '1 voyageur à proximité',
      'nearMe|aucun|2': '2 voyageurs à proximité',
      'nearMe|aucun|12': '12 voyageurs à proximité',
      'nearMe|départ|0': '0 voyageur à proximité',
      'nearMe|départ|1': '1 voyageur à proximité',
      'nearMe|départ|2': '2 voyageurs à proximité',
      'nearMe|départ|12': '12 voyageurs à proximité',
      'nearMe|arrivée|0': '0 voyageur à proximité',
      'nearMe|arrivée|1': '1 voyageur à proximité',
      'nearMe|arrivée|2': '2 voyageurs à proximité',
      'nearMe|arrivée|12': '12 voyageurs à proximité',
      'nearMe|les deux|0': '0 voyageur à proximité',
      'nearMe|les deux|1': '1 voyageur à proximité',
      'nearMe|les deux|2': '2 voyageurs à proximité',
      'nearMe|les deux|12': '12 voyageurs à proximité',
    };
    for (final variant in const ['trips', 'parcels', 'matching', 'nearMe']) {
      for (final c in corridors.entries) {
        for (final n in const [0, 1, 2, 12]) {
          final key = '$variant|${c.key}|$n';
          test(key, () {
            final filters = variant == 'nearMe'
                ? c.value.copyWith(nearMeActive: true)
                : c.value;
            final mode = variant == 'trips' || variant == 'nearMe'
                ? SearchMode.trips
                : SearchMode.parcels;
            expect(
              homeListTitle(
                fr,
                mode: mode,
                filters: filters,
                trips: n,
                parcels: n,
                matching: variant == 'matching',
              ),
              expected[key],
            );
          });
        }
      }
    }

    test('3 colis à transporter · Tous les corridors', () {
      expect(
        homeListTitle(
          fr,
          mode: SearchMode.parcels,
          filters: none,
          trips: 0,
          parcels: 3,
          matching: false,
        ),
        '3 colis à transporter · Tous les corridors',
      );
    });

    test('« près de moi » ne change pas le titre du mode colis', () {
      expect(
        homeListTitle(
          fr,
          mode: SearchMode.parcels,
          filters: both.copyWith(nearMeActive: true),
          trips: 0,
          parcels: 2,
          matching: false,
        ),
        '2 colis à transporter pour Lyon → Bamako',
      );
    });
  });

  group('homeListSubtitle (fr)', () {
    const tripsExpected = {
      0: "Personne ne propose ce trajet pour l'instant",
      1: 'Ils peuvent emporter ton colis',
      2: 'Ils peuvent emporter ton colis',
      12: 'Ils peuvent emporter ton colis',
    };
    for (final e in tripsExpected.entries) {
      test('trajets, ${e.key}', () {
        expect(
          homeListSubtitle(
            fr,
            mode: SearchMode.trips,
            trips: e.key,
            parcels: 0,
            matching: false,
            activeTrips: null,
          ),
          e.value,
        );
      });
    }

    const parcelsExpected = {
      0: "Aucune demande d'envoi pour l'instant",
      1: 'Tu peux les emporter sur ton trajet',
      2: 'Tu peux les emporter sur ton trajet',
      12: 'Tu peux les emporter sur ton trajet',
    };
    for (final e in parcelsExpected.entries) {
      test('colis, ${e.key}', () {
        expect(
          homeListSubtitle(
            fr,
            mode: SearchMode.parcels,
            trips: 0,
            parcels: e.key,
            matching: false,
            activeTrips: null,
          ),
          e.value,
        );
      });
    }

    const activeExpected = <int?, String>{
      null: 'Avec tes trajets actifs',
      0: 'Avec ton trajet actif',
      1: 'Avec ton trajet actif',
      3: 'Avec tes 3 trajets actifs',
    };
    for (final e in activeExpected.entries) {
      test('pour mes trajets, ${e.key} trajets actifs', () {
        expect(
          homeListSubtitle(
            fr,
            mode: SearchMode.parcels,
            trips: 0,
            parcels: 2,
            matching: true,
            activeTrips: e.key,
          ),
          e.value,
        );
      });
    }
  });

  group('homePullHintLabel (fr)', () {
    const expected = {
      'trips|0': 'Tirer pour voir la liste',
      'trips|1': 'Tirer pour voir le voyageur',
      'trips|2': 'Tirer pour voir les 2 voyageurs',
      'trips|12': 'Tirer pour voir les 12 voyageurs',
      'parcels|0': 'Tirer pour voir la liste',
      'parcels|1': 'Tirer pour voir le colis',
      'parcels|2': 'Tirer pour voir les 2 colis',
      'parcels|12': 'Tirer pour voir les 12 colis',
    };
    for (final mode in SearchMode.values) {
      for (final n in const [0, 1, 2, 12]) {
        final key = '${mode.name}|$n';
        test(key, () {
          expect(homePullUpLabel(fr, mode: mode, count: n), expected[key]);
          expect(
            homePullHintLabel(fr, mode: mode, count: n, down: false),
            expected[key],
          );
        });
      }
      test('${mode.name}, vers le bas', () {
        expect(
          homePullHintLabel(fr, mode: mode, count: 4, down: true),
          'Tirer vers le bas pour voir la carte',
        );
      });
    }
  });

  group('anglais', () {
    test('découverte croisée, mode trajets', () {
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.trips,
          filters: none,
          count: 1,
        ),
        '1 parcel is looking for a traveler',
      );
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.trips,
          filters: both,
          count: 2,
        ),
        '2 parcels are looking for a traveler on Lyon → Bamako',
      );
    });

    test('découverte croisée, mode colis', () {
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.parcels,
          filters: depOnly,
          count: 12,
        ),
        '12 travelers are traveling from Lyon',
      );
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.parcels,
          filters: arrOnly,
          count: 1,
        ),
        '1 traveler is traveling to Bamako',
      );
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.parcels,
          filters: both,
          count: 2,
        ),
        '2 travelers are traveling on Lyon → Bamako',
      );
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.parcels,
          filters: none,
          count: 1,
        ),
        '1 traveler is traveling',
      );
      expect(
        homeCrossDiscoveryLabel(
          en,
          mode: SearchMode.parcels,
          filters: none,
          count: 5,
        ),
        '5 travelers are traveling',
      );
    });

    test('sous-titre sans voyageur', () {
      expect(
        homeListSubtitle(
          en,
          mode: SearchMode.trips,
          trips: 0,
          parcels: 0,
          matching: false,
          activeTrips: null,
        ),
        'No one is offering this trip yet',
      );
    });

    test('corridor, titre et sous-titre de liste', () {
      expect(homeCorridorLabel(en, depOnly), 'From Lyon');
      expect(homeCorridorLabel(en, none), 'All routes');
      expect(
        homeListTitle(
          en,
          mode: SearchMode.trips,
          filters: both,
          trips: 1,
          parcels: 0,
          matching: false,
        ),
        '1 traveler for Lyon → Bamako',
      );
      expect(
        homeListTitle(
          en,
          mode: SearchMode.parcels,
          filters: none,
          trips: 0,
          parcels: 1,
          matching: false,
        ),
        '1 parcel to carry · All routes',
      );
      expect(
        homeListSubtitle(
          en,
          mode: SearchMode.parcels,
          trips: 0,
          parcels: 2,
          matching: true,
          activeTrips: 3,
        ),
        'With your 3 active trips',
      );
    });

    test('alerte et poignée', () {
      expect(
        homeAlertForSearchLabel(
          en,
          mode: SearchMode.trips,
          departureCity: 'Lyon',
          arrivalCity: 'Bamako',
        ),
        'Alert me when a trip appears on Lyon → Bamako',
      );
      expect(
        homePullHintLabel(en, mode: SearchMode.trips, count: 2, down: false),
        'Pull up to see the 2 travelers',
      );
      expect(
        homePullHintLabel(en, mode: SearchMode.trips, count: 2, down: true),
        'Pull down to see the map',
      );
    });
  });
}
