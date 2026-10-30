import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('searchModeForIntent', () {
    test('voyageur : on cherche des colis', () {
      expect(searchModeForIntent(UserIntent.traveler), SearchMode.parcels);
    });

    test('expéditeur : on cherche des trajets', () {
      expect(searchModeForIntent(UserIntent.sender), SearchMode.trips);
    });

    test('les deux : on cherche des trajets', () {
      expect(searchModeForIntent(UserIntent.both), SearchMode.trips);
    });

    test('intention inconnue : on cherche des trajets', () {
      expect(searchModeForIntent(null), SearchMode.trips);
    });
  });
}
