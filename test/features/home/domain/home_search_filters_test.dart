import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeSearchFilters', () {
    // FLUTTER-GD / FLUTTER-G0.
    test('escales et moyens de paiement : requête, clés et compteur', () {
      const f = HomeSearchFilters(
        stopsFilter: StopsFilter.directOnly,
        paymentMethods: {BidPaymentMethod.stripe, BidPaymentMethod.cash},
      );
      final q = f.toAnnouncementQuery();
      expect(q.maxStops, 0);
      expect(q.paymentMethods, ['CASH', 'STRIPE']);
      expect(f.activeKeys, {'stops', 'payment_methods'});
      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 0);

      const none = HomeSearchFilters();
      expect(none.toAnnouncementQuery().maxStops, isNull);
      expect(none.toAnnouncementQuery().paymentMethods, isNull);

      final cleared = f.copyWith(clearStopsFilter: true, paymentMethods: {});
      expect(cleared.stopsFilter, isNull);
      expect(cleared.paymentMethods, isEmpty);
      expect(
        f
            .copyWith(stopsFilter: StopsFilter.maxOne)
            .toAnnouncementQuery()
            .maxStops,
        1,
      );
      // L'interversion du corridor ne perd pas ces filtres.
      expect(f.swapCorridor().stopsFilter, StopsFilter.directOnly);
      expect(f.swapCorridor().paymentMethods, hasLength(2));
    });

    test('vide : aucun filtre actif dans les deux modes', () {
      const f = HomeSearchFilters();
      expect(f.activeCountFor(SearchMode.trips), 0);
      expect(f.activeCountFor(SearchMode.parcels), 0);
      expect(f.otherModeCountIsMeaningful, isFalse);
    });

    test('activeKeys : vide, puis une clé par filtre posé, sans valeur', () {
      expect(const HomeSearchFilters().activeKeys, isEmpty);

      const f = HomeSearchFilters(
        departureCity: 'Paris',
        urgentOnly: true,
        maxPricePerKg: 12,
        weightMin: 5,
        weightMax: 20,
        matchingMyTrips: true,
        gpProOnly: true,
      );
      expect(f.activeKeys, {
        'departure',
        'urgent',
        'price',
        'weight',
        'matching_my_trips',
        'gp_pro',
      });
    });

    test('le corridor est partagé : il survit au changement de mode', () {
      const f = HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

      expect(f.toSearchParams().departureCity, 'Paris');
      expect(f.toSearchParams().arrivalCity, 'Dakar');
      expect(f.toPackageRequestQuery().departure, 'Paris');
      expect(f.toPackageRequestQuery().arrival, 'Dakar');
      expect(f.toAnnouncementQuery().departureCity, 'Paris');
      expect(f.toAnnouncementQuery().arrivalCity, 'Dakar');
      expect(f.otherModeCountIsMeaningful, isTrue);
    });

    test('la date est partagée et se traduit en plage pour les colis', () {
      final f = HomeSearchFilters(
        datePreset: DonyDatePreset.custom,
        customDate: DateTime(2026, 8, 12),
      );

      expect(f.toSearchParams().date, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateFrom, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateTo, DateTime(2026, 8, 12));
      // Le preset de date doit désormais aussi agir sur la recherche de
      // trajets (défaut 1) : c'était un filtre fantôme via toSearchParams.
      expect(f.toAnnouncementQuery().departureDateFrom, DateTime(2026, 8, 12));
      expect(f.toAnnouncementQuery().departureDateTo, DateTime(2026, 8, 12));
    });

    group('période choisie au calendrier', () {
      final start = DateTime(2026, 11, 15);
      final end = DateTime(2026, 12, 15);

      test('du … au … : bornes incluses vers trajets et colis', () {
        final f = const HomeSearchFilters().withCustomPeriod(start, end);

        expect(f.datePreset, DonyDatePreset.custom);
        expect(f.dateFrom, start);
        expect(f.dateTo, end);
        expect(f.toAnnouncementQuery().departureDateFrom, start);
        expect(f.toAnnouncementQuery().departureDateTo, end);
        expect(f.toPackageRequestQuery().dateFrom, start);
        expect(f.toPackageRequestQuery().dateTo, end);
        // Clé analytics inchangée : une période reste le filtre « date ».
        expect(f.activeKeys, {'date'});
      });

      test('un seul jour : début = fin, comme avant les périodes', () {
        final f = const HomeSearchFilters().withCustomPeriod(start);
        expect(f.customDateTo, isNull);
        expect(f.dateFrom, start);
        expect(f.dateTo, start);

        // Le même jour touché deux fois au calendrier = un seul jour.
        final same = const HomeSearchFilters().withCustomPeriod(
          start,
          DateTime(2026, 11, 15, 23, 59),
        );
        expect(same.customDateTo, isNull);
        expect(same.dateTo, start);
      });

      test('une fin avant le début est remise dans l\'ordre', () {
        final f = const HomeSearchFilters().withCustomPeriod(end, start);
        expect(f.customDate, start);
        expect(f.customDateTo, end);

        final g = const HomeSearchFilters()
            .withCustomPeriod(start)
            .copyWith(customDateTo: DateTime(2026, 11));
        expect(g.dateFrom, DateTime(2026, 11));
        expect(g.dateTo, start);
      });

      test('un jour posé ensuite remplace la fin de la période', () {
        final f = const HomeSearchFilters()
            .withCustomPeriod(start, end)
            .withCustomPeriod(DateTime(2026, 12));
        expect(f.dateFrom, DateTime(2026, 12));
        expect(f.dateTo, DateTime(2026, 12));
      });

      test('clearCustomDate vide le début et la fin', () {
        final f = const HomeSearchFilters()
            .withCustomPeriod(start, end)
            .copyWith(datePreset: DonyDatePreset.none, clearCustomDate: true);
        expect(f.customDate, isNull);
        expect(f.customDateTo, isNull);
        expect(f.dateFrom, isNull);
        expect(f.dateTo, isNull);
      });

      test('la période survit aux autres modifications', () {
        final f = const HomeSearchFilters()
            .withCustomPeriod(start, end)
            .copyWith(departureCity: 'Paris')
            .swapCorridor();
        expect(f.customDate, start);
        expect(f.customDateTo, end);
      });

      test('un preset ignore la fin d\'une période restée en mémoire', () {
        final f = const HomeSearchFilters()
            .withCustomPeriod(start, end)
            .copyWith(datePreset: DonyDatePreset.today, clearCustomDate: true);
        final today = DateTime.now();
        expect(f.dateTo, DateTime(today.year, today.month, today.day));
      });
    });

    test(
      'poids trajets et poids colis ne se propagent jamais l\'un vers l\'autre',
      () {
        const f = HomeSearchFilters(weightMin: 6, maxWeight: 3);

        // weightMin = « voyageur acceptant au moins 6 kg » — filtre trajets.
        expect(f.toSearchParams().weightKg, 6);
        // maxWeight = « demandes d'au plus 3 kg » — filtre colis.
        expect(f.toPackageRequestQuery().maxWeight, 3);
        // Aucune contamination croisée.
        expect(f.toPackageRequestQuery().maxWeight, isNot(6));
        expect(f.toAnnouncementQuery().minAvailableKg, 6);
        expect(f.toAnnouncementQuery().maxAvailableKg, isNull);
      },
    );

    test(
      'weightMax alimente maxAvailableKg, distinct de maxWeight (défaut 1)',
      () {
        const f = HomeSearchFilters(weightMax: 12, maxWeight: 3);

        expect(f.toAnnouncementQuery().maxAvailableKg, 12);
        expect(f.toAnnouncementQuery().maxAvailableKg, isNot(3));
      },
    );

    test('les filtres spécifiques ne comptent que dans leur mode', () {
      const f = HomeSearchFilters(
        gpProOnly: true, // trajets
        minRating: 4.5, // trajets
        parcelSize: ParcelSize.medium, // colis
      );

      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 1);
    });

    test('activeCount additionne commun + trajets + colis, contrairement à '
        'activeCountFor qui exclut les filtres de l\'autre mode (tracking '
        '`search_submitted`)', () {
      const f = HomeSearchFilters(
        departureCity: 'Paris', // commun
        gpProOnly: true, // trajets
        minRating: 4.5, // trajets
        parcelSize: ParcelSize.medium, // colis
      );

      expect(f.activeCountFor(SearchMode.trips), 3); // commun + 2 trajets
      expect(f.activeCountFor(SearchMode.parcels), 2); // commun + 1 colis
      expect(f.activeCount, 4); // commun + 2 trajets + 1 colis, une fois
    });

    test('activeCount vide vaut zéro', () {
      const f = HomeSearchFilters();
      expect(f.activeCount, 0);
    });

    test('les filtres communs comptent dans les deux modes', () {
      const f = HomeSearchFilters(departureCity: 'Paris', urgentOnly: true);

      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 2);
    });

    test('urgentOnly faux ne part jamais explicitement au serveur', () {
      // urgentOnly par défaut (false) — comportement vérifié explicitement.
      const f = HomeSearchFilters();

      expect(f.toSearchParams().urgencyFilter, isNull);
      expect(f.toPackageRequestQuery().urgent, isNull);
      expect(f.toAnnouncementQuery().urgent, isNull);
    });

    test('nearMe actif neutralise le corridor côté trajets', () {
      const f = HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        nearMeActive: true,
        nearMeRadiusKm: 25,
      );

      // Près de moi cherche tous les voyageurs autour, corridor ignoré.
      expect(f.toSearchParams().departureCity, isNull);
      expect(f.toSearchParams().arrivalCity, isNull);
      expect(f.toAnnouncementQuery().departureCity, isNull);
      expect(f.toAnnouncementQuery().arrivalCity, isNull);
    });

    test('nearMe actif alimente lat/lng/radius dans toAnnouncementQuery', () {
      const f = HomeSearchFilters(
        nearMeActive: true,
        nearMeRadiusKm: 25,
        userLat: 48.85,
        userLng: 2.35,
      );

      final q = f.toAnnouncementQuery();
      expect(q.userLat, 48.85);
      expect(q.userLng, 2.35);
      expect(q.radiusKm, 25);
    });

    test('sans « près de moi », lat/lng/radius ne partent pas dans '
        'toAnnouncementQuery', () {
      const f = HomeSearchFilters(userLat: 48.85, userLng: 2.35);

      final q = f.toAnnouncementQuery();
      expect(q.userLat, isNull);
      expect(q.userLng, isNull);
      expect(q.radiusKm, isNull);
    });

    test('défaut 1 : chaque filtre compté par activeCountFor(trips) est '
        'effectivement transmis par toAnnouncementQuery (pas de filtre '
        'fantôme)', () {
      const f = HomeSearchFilters(
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        datePreset: DonyDatePreset.thisWeek,
        urgentOnly: true,
        maxPricePerKg: 15,
        weightMin: 6,
        weightMax: 20,
        gpProOnly: true,
        minRating: 4.5,
        weekendOnly: true,
        kycVerifiedOnly: true,
        contentType: 'documents',
      );

      // 10 filtres actifs pour le mode trajets (communs + spécifiques
      // trajets), tous vérifiés ci-dessous transmis dans le payload serveur.
      expect(f.activeCountFor(SearchMode.trips), 10);

      final q = f.toAnnouncementQuery();
      expect(q.departureCity, 'Paris'); // corridor
      expect(q.arrivalCity, 'Dakar'); // corridor
      expect(q.departureDateFrom, isNotNull); // datePreset
      expect(q.departureDateTo, isNotNull); // datePreset
      expect(q.urgent, true); // urgentOnly
      expect(q.maxPricePerKg, 15); // maxPricePerKg
      expect(q.minAvailableKg, 6); // weightMin
      expect(q.maxAvailableKg, 20); // weightMax
      expect(q.gpProOnly, true); // gpProOnly
      expect(q.minRating, 4.5); // minRating
      expect(q.weekendOnly, true); // weekendOnly
      expect(q.kycVerifiedOnly, true); // kycVerifiedOnly
      expect(q.contentType, 'documents'); // contentType
    });

    test('convention serveur : les booléens de toAnnouncementQuery ne '
        'partent jamais à false explicitement', () {
      const f = HomeSearchFilters();

      final q = f.toAnnouncementQuery();
      expect(q.gpProOnly, isNull);
      expect(q.weekendOnly, isNull);
      expect(q.kycVerifiedOnly, isNull);
      expect(q.urgent, isNull);
    });

    test(
      '« près de moi » seul rend le compteur de l\'autre mode significatif',
      () {
        const f = HomeSearchFilters(nearMeActive: true);

        expect(f.otherModeCountIsMeaningful, isTrue);
      },
    );

    test('urgentOnly seul ne rend pas le compteur de l\'autre mode '
        'significatif (ne restreint ni zone ni période)', () {
      const f = HomeSearchFilters(urgentOnly: true);

      expect(f.otherModeCountIsMeaningful, isFalse);
    });

    test('copyWith efface un champ via le sentinel de suppression', () {
      const f = HomeSearchFilters(departureCity: 'Paris', minRating: 4.5);

      final sansNote = f.copyWith(clearMinRating: true);

      expect(sansNote.minRating, isNull);
      expect(sansNote.departureCity, 'Paris');
    });

    test('presets de date : today produit une borne basse à aujourd\'hui', () {
      const f = HomeSearchFilters(datePreset: DonyDatePreset.today);
      final today = DateTime.now();

      expect(f.dateFrom!.year, today.year);
      expect(f.dateFrom!.month, today.month);
      expect(f.dateFrom!.day, today.day);
    });
    group('filtre d\'urgence envoyé au serveur (FLUTTER-MH, FLUTTER-JG)', () {
      DateTime day(int offset) {
        final n = DateTime.now();
        return DateTime(n.year, n.month, n.day + offset);
      }

      test('seul, il devient la fenêtre de départ de la requête', () {
        const f = HomeSearchFilters(urgencyFilter: UrgencyFilter.veryUrgent);

        final q = f.toAnnouncementQuery();

        expect(q.departureDateFrom, day(0));
        expect(q.departureDateTo, day(2));
      });

      test('« plus tard » n\'a pas de borne haute', () {
        const f = HomeSearchFilters(urgencyFilter: UrgencyFilter.later);

        final q = f.toAnnouncementQuery();

        expect(q.departureDateFrom, day(14));
        expect(q.departureDateTo, isNull);
      });

      test('croisé avec une date choisie, garde l\'intersection', () {
        const f = HomeSearchFilters(
          urgencyFilter: UrgencyFilter.urgent,
          datePreset: DonyDatePreset.thisMonth,
        );

        final q = f.toAnnouncementQuery();
        final monthEnd = f.dateTo!;
        final urgentEnd = day(6);

        expect(q.departureDateFrom, day(3));
        expect(
          q.departureDateTo,
          monthEnd.isBefore(urgentEnd) ? monthEnd : urgentEnd,
        );
      });

      test('sans filtre d\'urgence, la date choisie part telle quelle', () {
        const f = HomeSearchFilters(datePreset: DonyDatePreset.today);

        final q = f.toAnnouncementQuery();

        expect(q.departureDateFrom, f.dateFrom);
        expect(q.departureDateTo, f.dateTo);
      });
    });

    group('puce « Valise 23 kg » (YADONY-FLUTTER-PROD-Z)', () {
      test('inactive par défaut : rien ne change dans la requête', () {
        const f = HomeSearchFilters();
        expect(f.suitcase23Only, isFalse);
        expect(f.toAnnouncementQuery().minAvailableKg, isNull);
        expect(f.activeKeys, isNot(contains('suitcase_23')));
      });

      test('active seule : minAvailableKg = 23', () {
        const f = HomeSearchFilters(suitcase23Only: true);
        expect(f.toAnnouncementQuery().minAvailableKg, 23);
        expect(f.effectiveMinAvailableKg, kSuitcaseKg);
      });

      test('Capacité sous 23 kg : la puce prime', () {
        const f = HomeSearchFilters(suitcase23Only: true, weightMin: 10);
        expect(f.toAnnouncementQuery().minAvailableKg, 23);
        // La Capacité réglée reste celle de l'utilisateur.
        expect(f.weightMin, 10);
      });

      test('Capacité au-dessus de 23 kg : la plus exigeante est gardée', () {
        const f = HomeSearchFilters(suitcase23Only: true, weightMin: 30);
        expect(f.toAnnouncementQuery().minAvailableKg, 30);
      });

      test('le maximum de capacité part tel quel', () {
        const f = HomeSearchFilters(suitcase23Only: true, weightMax: 40);
        final q = f.toAnnouncementQuery();
        expect(q.minAvailableKg, 23);
        expect(q.maxAvailableKg, 40);
      });

      test('activeKeys : suitcase_23, distincte de weight', () {
        expect(const HomeSearchFilters(suitcase23Only: true).activeKeys, {
          'suitcase_23',
        });
        expect(
          const HomeSearchFilters(
            suitcase23Only: true,
            weightMin: 30,
          ).activeKeys,
          {'suitcase_23', 'weight'},
        );
      });

      test('badge : comptée en mode Trajets seulement', () {
        const f = HomeSearchFilters(suitcase23Only: true);
        expect(f.activeCountFor(SearchMode.trips), 1);
        expect(f.activeCountFor(SearchMode.parcels), 0);
        expect(f.activeCount, 1);
        expect(
          const HomeSearchFilters(
            suitcase23Only: true,
            weightMin: 30,
          ).activeCountFor(SearchMode.trips),
          2,
        );
      });

      test('copyWith : pose, retire, et conserve la puce', () {
        const base = HomeSearchFilters();
        final on = base.copyWith(suitcase23Only: true);
        expect(on.suitcase23Only, isTrue);
        expect(on.copyWith(departureCity: 'Paris').suitcase23Only, isTrue);
        expect(on.copyWith(clearWeight: true).suitcase23Only, isTrue);
        expect(on.swapCorridor().suitcase23Only, isTrue);
        expect(on.copyWith(suitcase23Only: false).suitcase23Only, isFalse);
      });

      test('mode Colis : la puce ne touche pas la recherche de demandes', () {
        const f = HomeSearchFilters(suitcase23Only: true);
        expect(f.toPackageRequestQuery().maxWeight, isNull);
      });

      test(
        "Capacité « jusqu'au bout » (bornes null) : la puce seule compte",
        () {
          final bounds = capacityBoundsFromSlider(
            kCapacitySliderMinKg,
            kCapacitySliderMaxKg,
          );
          final f = const HomeSearchFilters(
            suitcase23Only: true,
          ).copyWith(weightMin: bounds.min, weightMax: bounds.max);
          final q = f.toAnnouncementQuery();
          expect(q.minAvailableKg, 23);
          expect(q.maxAvailableKg, isNull);
          expect(f.activeKeys, {'suitcase_23'});
        },
      );
    });

    group('curseur Capacité : une poignée au bout = pas de borne', () {
      test('les deux poignées aux extrémités : aucune borne', () {
        final b = capacityBoundsFromSlider(
          kCapacitySliderMinKg,
          kCapacitySliderMaxKg,
        );
        expect(b.min, isNull);
        expect(b.max, isNull);
        final f = const HomeSearchFilters().copyWith(
          weightMin: b.min,
          weightMax: b.max,
        );
        expect(f.activeKeys, isNot(contains('weight')));
        expect(f.activeCountFor(SearchMode.trips), 0);
        final q = f.toAnnouncementQuery();
        expect(q.minAvailableKg, isNull);
        expect(q.maxAvailableKg, isNull);
      });

      test('maximum au bout : seul le minimum part', () {
        final b = capacityBoundsFromSlider(10, kCapacitySliderMaxKg);
        expect(b.min, 10);
        expect(b.max, isNull);
      });

      test('minimum au bout : seul le maximum part', () {
        final b = capacityBoundsFromSlider(kCapacitySliderMinKg, 20);
        expect(b.min, isNull);
        expect(b.max, 20);
      });

      test('deux poignées déplacées : les deux bornes partent', () {
        final b = capacityBoundsFromSlider(5, 20);
        expect(b.min, 5);
        expect(b.max, 20);
      });

      test('toSearchParams sans minimum : 0 (aucun minimum)', () {
        expect(const HomeSearchFilters().toSearchParams().weightKg, 0);
      });
    });
  });
}
