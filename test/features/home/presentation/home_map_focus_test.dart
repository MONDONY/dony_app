import 'package:dony/features/home/presentation/home_map_focus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeMapVisibility', () {
    test(
      'pur expéditeur : trajets seuls, jamais de colis (quel que soit le focus)',
      () {
        for (final focus in HomeMapFocus.values) {
          final vis = homeMapVisibility(isTraveler: false, focus: focus);
          expect(vis.showTrips, isTrue);
          expect(vis.showParcels, isFalse);
        }
      },
    );

    test('voyageur focus Tout : les deux', () {
      final vis = homeMapVisibility(isTraveler: true, focus: HomeMapFocus.all);
      expect(vis.showTrips, isTrue);
      expect(vis.showParcels, isTrue);
    });

    test('voyageur focus Colis : colis seuls', () {
      final vis = homeMapVisibility(
        isTraveler: true,
        focus: HomeMapFocus.parcels,
      );
      expect(vis.showTrips, isFalse);
      expect(vis.showParcels, isTrue);
    });

    test('voyageur focus Trajets : trajets seuls', () {
      final vis = homeMapVisibility(
        isTraveler: true,
        focus: HomeMapFocus.trips,
      );
      expect(vis.showTrips, isTrue);
      expect(vis.showParcels, isFalse);
    });
  });
}
