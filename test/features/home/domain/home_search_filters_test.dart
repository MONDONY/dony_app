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
      expect(f.otherModeCountIsMeaningful, isFalse);
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

    test('poids trajets et poids colis ne se propagent jamais l\'un vers l\'autre', () {
      const f = HomeSearchFilters(weightMin: 6, maxWeight: 3);

      // weightMin = « voyageur acceptant au moins 6 kg » — filtre trajets.
      expect(f.toSearchParams().weightKg, 6);
      // maxWeight = « demandes d'au plus 3 kg » — filtre colis.
      expect(f.toPackageRequestQuery().maxWeight, 3);
      // Aucune contamination croisée.
      expect(f.toPackageRequestQuery().maxWeight, isNot(6));
      expect(f.toAnnouncementQuery().minAvailableKg, 6);
      expect(f.toAnnouncementQuery().maxAvailableKg, isNull);
    });

    test(
        'weightMax alimente maxAvailableKg, distinct de maxWeight (défaut 1)',
        () {
      const f = HomeSearchFilters(weightMax: 12, maxWeight: 3);

      expect(f.toAnnouncementQuery().maxAvailableKg, 12);
      expect(f.toAnnouncementQuery().maxAvailableKg, isNot(3));
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

    test('nearMe actif alimente lat/lng/radius dans toAnnouncementQuery',
        () {
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

    test(
        'sans « près de moi », lat/lng/radius ne partent pas dans '
        'toAnnouncementQuery', () {
      const f = HomeSearchFilters(userLat: 48.85, userLng: 2.35);

      final q = f.toAnnouncementQuery();
      expect(q.userLat, isNull);
      expect(q.userLng, isNull);
      expect(q.radiusKm, isNull);
    });

    test(
        'défaut 1 : chaque filtre compté par activeCountFor(trips) est '
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
        kiloProOnly: true,
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
      expect(q.kiloProOnly, true); // kiloProOnly
      expect(q.minRating, 4.5); // minRating
      expect(q.weekendOnly, true); // weekendOnly
      expect(q.kycVerifiedOnly, true); // kycVerifiedOnly
      expect(q.contentType, 'documents'); // contentType
    });

    test(
        'convention serveur : les booléens de toAnnouncementQuery ne '
        'partent jamais à false explicitement', () {
      const f = HomeSearchFilters();

      final q = f.toAnnouncementQuery();
      expect(q.kiloProOnly, isNull);
      expect(q.weekendOnly, isNull);
      expect(q.kycVerifiedOnly, isNull);
      expect(q.urgent, isNull);
    });

    test('« près de moi » seul rend le compteur de l\'autre mode significatif',
        () {
      const f = HomeSearchFilters(nearMeActive: true);

      expect(f.otherModeCountIsMeaningful, isTrue);
    });

    test(
        'urgentOnly seul ne rend pas le compteur de l\'autre mode '
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
  });
}
