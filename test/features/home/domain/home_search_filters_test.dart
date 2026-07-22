import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeSearchFilters', () {
    test('vide : aucun filtre actif dans les deux modes', () {
      const f = HomeSearchFilters();
      expect(f.activeCountFor(SearchMode.trips), 0);
      expect(f.activeCountFor(SearchMode.parcels), 0);
      expect(f.hasCommonFilter, isFalse);
    });

    test('le corridor est partagé : il survit au changement de mode', () {
      const f = HomeSearchFilters(departureCity: 'Paris', arrivalCity: 'Dakar');

      expect(f.toSearchParams().departureCity, 'Paris');
      expect(f.toSearchParams().arrivalCity, 'Dakar');
      expect(f.toPackageRequestQuery().departure, 'Paris');
      expect(f.toPackageRequestQuery().arrival, 'Dakar');
      expect(f.hasCommonFilter, isTrue);
    });

    test('la date est partagée et se traduit en plage pour les colis', () {
      final f = HomeSearchFilters(
        datePreset: DonyDatePreset.custom,
        customDate: DateTime(2026, 8, 12),
      );

      expect(f.toSearchParams().date, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateFrom, DateTime(2026, 8, 12));
      expect(f.toPackageRequestQuery().dateTo, DateTime(2026, 8, 12));
    });

    test('poids trajets et poids colis ne se propagent jamais l\'un vers l\'autre', () {
      const f = HomeSearchFilters(weightMin: 6, maxWeight: 3);

      // weightMin = « voyageur acceptant au moins 6 kg » — filtre trajets.
      expect(f.toSearchParams().weightKg, 6);
      // maxWeight = « demandes d'au plus 3 kg » — filtre colis.
      expect(f.toPackageRequestQuery().maxWeight, 3);
      // Aucune contamination croisée.
      expect(f.toPackageRequestQuery().maxWeight, isNot(6));
    });

    test('les filtres spécifiques ne comptent que dans leur mode', () {
      const f = HomeSearchFilters(
        kiloProOnly: true,      // trajets
        minRating: 4.5,         // trajets
        parcelSize: ParcelSize.medium, // colis
      );

      expect(f.activeCountFor(SearchMode.trips), 2);
      expect(f.activeCountFor(SearchMode.parcels), 1);
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
  });
}
